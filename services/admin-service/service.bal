import ballerina/http;
import ballerina/log;
import ballerinax/mongodb;
import ballerinax/kafka;
import ballerina/time;

// Configuration
configurable string mongodbUri = ?;
configurable string kafkaBootstrapServers = ?;

// Types
type SalesReport record {|
    string period;
    int totalTickets;
    decimal totalRevenue;
    map<int> ticketsByType;
    map<decimal> revenueByType;
    string generatedAt;
|};

type DisruptionNotice record {|
    string routeId;
    string 'type; // DELAY, CANCELLATION, MAINTENANCE
    string message;
    string startTime;
    string endTime?;
|};

mongodb:Client mongoClient = check new (mongodbUri);

kafka:ProducerConfiguration producerConfig = {
    clientId: "admin-service-producer",
    acks: "all",
    retryCount: 3
};

kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

service /admin on new http:Listener(9006) {

    // Health check
    resource function get health() returns json {
        return {
            service: "admin-service",
            status: "UP",
            timestamp: time:utcNow()
        };
    }

    // Generate sales report
    resource function get reports/sales() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection tickets = check db->getCollection("tickets");
        mongodb:Collection payments = check db->getCollection("payments");

        // Get all paid tickets
        map<json> ticketFilter = {status: "PAID"};
        stream<record {|string ticketType; decimal amount;|}, error?> ticketStream = check tickets->find(ticketFilter);
        record {|string ticketType; decimal amount;|}[]|error ticketArray = from var ticket in ticketStream select ticket;

        int totalTickets = 0;
        decimal totalRevenue = 0.0;
        map<int> ticketsByType = {};
        map<decimal> revenueByType = {};

        if ticketArray is record {|string ticketType; decimal amount;|}[] {
            totalTickets = ticketArray.length();

            foreach var ticket in ticketArray {
                totalRevenue += ticket.amount;

                // Count by type
                if ticketsByType.hasKey(ticket.ticketType) {
                    ticketsByType[ticket.ticketType] = ticketsByType.get(ticket.ticketType) + 1;
                } else {
                    ticketsByType[ticket.ticketType] = 1;
                }

                // Revenue by type
                if revenueByType.hasKey(ticket.ticketType) {
                    revenueByType[ticket.ticketType] = revenueByType.get(ticket.ticketType) + ticket.amount;
                } else {
                    revenueByType[ticket.ticketType] = ticket.amount;
                }
            }
        }

        SalesReport report = {
            period: "All Time",
            totalTickets: totalTickets,
            totalRevenue: totalRevenue,
            ticketsByType: ticketsByType,
            revenueByType: revenueByType,
            generatedAt: time:utcToString(time:utcNow())
        };

        log:printInfo("Sales report generated");
        return report;
    }

    // Get all routes (admin view)
    resource function get routes() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection routes = check db->getCollection("routes");

        stream<record {}, error?> routeStream = check routes->find();
        record {}[]|error routeArray = from var route in routeStream select route;

        if routeArray is record {}[] {
            return {routes: routeArray, count: routeArray.length()};
        }

        return {routes: [], count: 0};
    }

    // Get all trips (admin view)
    resource function get trips() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection trips = check db->getCollection("trips");

        stream<record {}, error?> tripStream = check trips->find();
        record {}[]|error tripArray = from var trip in tripStream select trip;

        if tripArray is record {}[] {
            return {trips: tripArray, count: tripArray.length()};
        }

        return {trips: [], count: 0};
    }

    // Publish service disruption
    resource function post disruptions(DisruptionNotice notice) returns json|error {
        // Publish to Kafka schedule.updates topic
        json disruptionEvent = {
            tripId: "ALL",
            routeId: notice.routeId,
            updateType: notice.'type,
            message: notice.message,
            startTime: notice.startTime,
            endTime: notice.endTime,
            timestamp: time:utcToString(time:utcNow())
        };

        check kafkaProducer->send({
            topic: "schedule.updates",
            value: disruptionEvent.toJsonString().toBytes()
        });

        log:printInfo("Service disruption published for route: " + notice.routeId);

        return {
            message: "Service disruption published successfully",
            routeId: notice.routeId,
            type: notice.'type
        };
    }

    // Get passenger statistics
    resource function get statistics/passengers() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection users = check db->getCollection("users");

        map<json> filter = {role: "PASSENGER"};
        stream<record {}, error?> userStream = check users->find(filter);
        record {}[]|error userArray = from var user in userStream select user;

        int totalPassengers = 0;
        if userArray is record {}[] {
            totalPassengers = userArray.length();
        }

        return {
            totalPassengers: totalPassengers,
            generatedAt: time:utcToString(time:utcNow())
        };
    }

    // Get ticket statistics
    resource function get statistics/tickets() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection tickets = check db->getCollection("tickets");

        stream<record {|string status;|}, error?> ticketStream = check tickets->find();
        record {|string status;|}[]|error ticketArray = from var ticket in ticketStream select ticket;

        map<int> ticketsByStatus = {};
        int totalTickets = 0;

        if ticketArray is record {|string status;|}[] {
            totalTickets = ticketArray.length();

            foreach var ticket in ticketArray {
                if ticketsByStatus.hasKey(ticket.status) {
                    ticketsByStatus[ticket.status] = ticketsByStatus.get(ticket.status) + 1;
                } else {
                    ticketsByStatus[ticket.status] = 1;
                }
            }
        }

        return {
            totalTickets: totalTickets,
            ticketsByStatus: ticketsByStatus,
            generatedAt: time:utcToString(time:utcNow())
        };
    }
}
