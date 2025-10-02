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
type Notification record {|
    string _id?;
    string userId;
    string 'type; // TICKET_STATUS, SCHEDULE_UPDATE, PAYMENT_CONFIRMATION
    string title;
    string message;
    boolean read;
    string createdAt;
|};

mongodb:Client mongoClient = check new (mongodbUri);

// Kafka consumer for notifications
kafka:ConsumerConfiguration consumerConfig = {
    groupId: "notification-service-group",
    topics: ["ticket.status", "schedule.updates", "payments.processed"],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    autoCommit: true
};

listener kafka:Listener kafkaListener = new (kafkaBootstrapServers, consumerConfig);

service /notification on new http:Listener(9005) {

    // Health check
    resource function get health() returns json {
        return {
            service: "notification-service",
            status: "UP",
            timestamp: time:utcNow()
        };
    }

    // Get notifications for a user
    resource function get notifications/[string userId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection notifications = check db->getCollection("notifications");

        map<json> filter = {userId: userId};
        stream<Notification, error?> notificationStream = check notifications->find(filter);
        Notification[]|error notificationArray = from Notification notification in notificationStream select notification;

        if notificationArray is Notification[] {
            return {
                userId: userId,
                notifications: notificationArray,
                count: notificationArray.length()
            };
        }

        return {
            userId: userId,
            notifications: [],
            count: 0
        };
    }

    // Mark notification as read
    resource function put notifications/[string notificationId]/read() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection notifications = check db->getCollection("notifications");

        map<json> filter = {_id: notificationId};
        map<json> update = {"$set": {read: true}};
        mongodb:UpdateResult result = check notifications->updateOne(filter, update);

        if result.modifiedCount > 0 {
            return {
                message: "Notification marked as read",
                notificationId: notificationId
            };
        }

        return error("Notification not found");
    }
}

// Kafka consumer service for processing events
service on kafkaListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:ConsumerRecord[] records) returns error? {
        foreach kafka:ConsumerRecord kafkaRecord in records {
            string topic = kafkaRecord.topic;
            byte[] value = kafkaRecord.value;
            string message = check string:fromBytes(value);
            json eventData = check message.fromJsonString();

            mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
            mongodb:Collection notifications = check db->getCollection("notifications");

            if topic == "ticket.status" {
                // Create notification for ticket status update
                string ticketId = check eventData.ticketId;
                string status = check eventData.status;
                string eventMessage = check eventData.message;

                // Get ticket to find passenger ID
                mongodb:Collection tickets = check db->getCollection("tickets");
                map<json> ticketFilter = {_id: ticketId};
                stream<record {|string passengerId;|}, error?> ticketStream = check tickets->find(ticketFilter);
                record {|string passengerId;|}[]|error ticketArray = from var ticket in ticketStream select ticket;

                if ticketArray is record {|string passengerId;|}[] && ticketArray.length() > 0 {
                    string passengerId = ticketArray[0].passengerId;

                    Notification notification = {
                        _id: uuid:createType1AsString(),
                        userId: passengerId,
                        'type: "TICKET_STATUS",
                        title: "Ticket Status Update",
                        message: "Your ticket status has been updated to: " + status + ". " + eventMessage,
                        read: false,
                        createdAt: time:utcToString(time:utcNow())
                    };

                    check notifications->insertOne(notification);
                    log:printInfo("[v0] Notification created for ticket status update: " + ticketId);
                }

            } else if topic == "schedule.updates" {
                // Create notification for schedule update
                string tripId = check eventData.tripId;
                string updateType = check eventData.updateType;
                string updateMessage = check eventData.message;

                // In a real system, we would notify all passengers with tickets for this trip
                // For now, we'll just log it
                log:printInfo("[v0] Schedule update received: " + tripId + " - " + updateType);

            } else if topic == "payments.processed" {
                // Create notification for payment confirmation
                string passengerId = check eventData.passengerId;
                string transactionId = check eventData.transactionId;
                decimal amount = check eventData.amount;

                Notification notification = {
                    _id: uuid:createType1AsString(),
                    userId: passengerId,
                    'type: "PAYMENT_CONFIRMATION",
                    title: "Payment Confirmed",
                    message: "Your payment of N$" + amount.toString() + " has been processed successfully. Transaction ID: " + transactionId,
                    read: false,
                    createdAt: time:utcToString(time:utcNow())
                };

                check notifications->insertOne(notification);
                log:printInfo("[v0] Payment confirmation notification created for passenger: " + passengerId);
            }
        }
    }
}
