import ballerina/http;
import ballerina/log;
import ballerinax/mongodb;
import ballerinax/kafka;
import ballerina/uuid;
import ballerina/time;

// Configuration
configurable string mongodbUri = ?;
configurable string kafkaBootstrapServers = ?;

// Types
type Ticket record {|
    string _id?;
    string passengerId;
    string tripId;
    string ticketType; // SINGLE, MULTIPLE, PASS
    string status; // CREATED, PAID, VALIDATED, EXPIRED
    decimal amount;
    string validFrom;
    string validUntil;
    int ridesRemaining?;
    string createdAt;
    string updatedAt;
|};

type TicketRequest record {|
    string passengerId;
    string tripId;
    string ticketType;
    decimal amount;
    int ridesRemaining?;
|};

type ValidateTicketRequest record {|
    string ticketId;
    string tripId;
|};

type TicketStatusUpdate record {|
    string ticketId;
    string status;
    string timestamp;
    string message;
|};

mongodb:Client mongoClient = check new (mongodbUri);

kafka:ProducerConfiguration producerConfig = {
    clientId: "ticketing-service-producer",
    acks: "all",
    retryCount: 3
};

kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

// Kafka consumer for ticket requests
kafka:ConsumerConfiguration consumerConfig = {
    groupId: "ticketing-service-group",
    topics: ["ticket.requests", "payments.processed"],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    autoCommit: true
};

listener kafka:Listener kafkaListener = new (kafkaBootstrapServers, consumerConfig);

service /ticketing on new http:Listener(9003) {

    // Health check
    resource function get health() returns json {
        return {
            service: "ticketing-service",
            status: "UP",
            timestamp: time:utcNow()
        };
    }

    // Create ticket request
    resource function post tickets(TicketRequest request) returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection tickets = check db->getCollection("tickets");

        // Calculate validity period based on ticket type
        time:Utc now = time:utcNow();
        time:Utc validUntil = now;
        
        if request.ticketType == "SINGLE" {
            validUntil = time:utcAddSeconds(now, 86400); // 24 hours
        } else if request.ticketType == "MULTIPLE" {
            validUntil = time:utcAddSeconds(now, 2592000); // 30 days
        } else if request.ticketType == "PASS" {
            validUntil = time:utcAddSeconds(now, 7776000); // 90 days
        }

        Ticket newTicket = {
            _id: uuid:createType1AsString(),
            passengerId: request.passengerId,
            tripId: request.tripId,
            ticketType: request.ticketType,
            status: "CREATED",
            amount: request.amount,
            validFrom: time:utcToString(now),
            validUntil: time:utcToString(validUntil),
            ridesRemaining: request.ridesRemaining,
            createdAt: time:utcToString(now),
            updatedAt: time:utcToString(now)
        };

        check tickets->insertOne(newTicket);

        // Publish ticket request to Kafka
        check kafkaProducer->send({
            topic: "ticket.requests",
            value: newTicket.toJsonString().toBytes()
        });

        log:printInfo("Ticket created: " + newTicket._id.toString());

        return {
            message: "Ticket created successfully",
            ticketId: newTicket._id,
            status: newTicket.status,
            amount: newTicket.amount
        };
    }

    // Get ticket by ID
    resource function get tickets/[string ticketId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection tickets = check db->getCollection("tickets");

        map<json> filter = {_id: ticketId};
        stream<Ticket, error?> ticketStream = check tickets->find(filter);
        Ticket[]|error ticketArray = from Ticket ticket in ticketStream select ticket;

        if ticketArray is Ticket[] && ticketArray.length() > 0 {
            return ticketArray[0];
        }

        return error("Ticket not found");
    }

    // Validate ticket
    resource function post validate(ValidateTicketRequest request) returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection tickets = check db->getCollection("tickets");

        map<json> filter = {_id: request.ticketId};
        stream<Ticket, error?> ticketStream = check tickets->find(filter);
        Ticket[]|error ticketArray = from Ticket ticket in ticketStream select ticket;

        if ticketArray is Ticket[] && ticketArray.length() > 0 {
            Ticket ticket = ticketArray[0];

            // Check if ticket is valid
            if ticket.status != "PAID" {
                return error("Ticket is not in PAID status");
            }

            // Check if ticket is expired
            time:Utc validUntil = check time:utcFromString(ticket.validUntil);
            if time:utcNow() > validUntil {
                // Update ticket status to EXPIRED
                map<json> updateFilter = {_id: request.ticketId};
                map<json> update = {"$set": {status: "EXPIRED", updatedAt: time:utcToString(time:utcNow())}};
                _ = check tickets->updateOne(updateFilter, update);
                return error("Ticket has expired");
            }

            // Update ticket status to VALIDATED
            map<json> updateFilter = {_id: request.ticketId};
            map<json> update = {"$set": {status: "VALIDATED", updatedAt: time:utcToString(time:utcNow())}};
            
            // If multiple rides, decrement ridesRemaining
            if ticket.ticketType == "MULTIPLE" && ticket.ridesRemaining is int {
                int remaining = <int>ticket.ridesRemaining - 1;
                update = {"$set": {status: "VALIDATED", ridesRemaining: remaining, updatedAt: time:utcToString(time:utcNow())}};
            }

            _ = check tickets->updateOne(updateFilter, update);

            // Publish validation event
            TicketStatusUpdate statusUpdate = {
                ticketId: request.ticketId,
                status: "VALIDATED",
                timestamp: time:utcToString(time:utcNow()),
                message: "Ticket validated successfully"
            };

            check kafkaProducer->send({
                topic: "ticket.status",
                value: statusUpdate.toJsonString().toBytes()
            });

            log:printInfo("Ticket validated: " + request.ticketId);

            return {
                message: "Ticket validated successfully",
                ticketId: request.ticketId,
                status: "VALIDATED"
            };
        }

        return error("Ticket not found");
    }
}

// Kafka consumer service for processing payment confirmations
service on kafkaListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:ConsumerRecord[] records) returns error? {
        foreach kafka:ConsumerRecord kafkaRecord in records {
            string topic = kafkaRecord.topic;
            byte[] value = kafkaRecord.value;
            string message = check string:fromBytes(value);

            if topic == "payments.processed" {
                // Update ticket status to PAID
                json paymentData = check message.fromJsonString();
                string ticketId = check paymentData.ticketId;

                mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
                mongodb:Collection tickets = check db->getCollection("tickets");

                map<json> filter = {_id: ticketId};
                map<json> update = {"$set": {status: "PAID", updatedAt: time:utcToString(time:utcNow())}};
                _ = check tickets->updateOne(filter, update);

                // Publish ticket status update
                TicketStatusUpdate statusUpdate = {
                    ticketId: ticketId,
                    status: "PAID",
                    timestamp: time:utcToString(time:utcNow()),
                    message: "Payment processed successfully"
                };

                check kafkaProducer->send({
                    topic: "ticket.status",
                    value: statusUpdate.toJsonString().toBytes()
                });

                log:printInfo("[v0] Payment processed for ticket: " + ticketId);
            }
        }
    }
}
