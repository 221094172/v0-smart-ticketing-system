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
type Route record {|
    string _id?;
    string routeNumber;
    string name;
    string 'type; // BUS or TRAIN
    string origin;
    string destination;
    string[] stops;
    decimal distance;
    int estimatedDuration;
    string status; // ACTIVE, INACTIVE, MAINTENANCE
    string createdAt;
    string updatedAt;
|};

type Trip record {|
    string _id?;
    string routeId;
    string departureTime;
    string arrivalTime;
    int availableSeats;
    int totalSeats;
    decimal price;
    string status; // SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED
    string createdAt;
    string updatedAt;
|};

type CreateRouteRequest record {|
    string routeNumber;
    string name;
    string 'type;
    string origin;
    string destination;
    string[] stops;
    decimal distance;
    int estimatedDuration;
|};

type CreateTripRequest record {|
    string routeId;
    string departureTime;
    string arrivalTime;
    int totalSeats;
    decimal price;
|};

type ScheduleUpdate record {|
    string tripId;
    string routeId;
    string updateType; // DELAY, CANCELLATION, SCHEDULE_CHANGE
    string message;
    string timestamp;
|};

mongodb:Client mongoClient = check new (mongodbUri);

kafka:ProducerConfiguration producerConfig = {
    clientId: "transport-service-producer",
    acks: "all",
    retryCount: 3
};

kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

service /transport on new http:Listener(9002) {

    // Health check
    resource function get health() returns json {
        return {
            service: "transport-service",
            status: "UP",
            timestamp: time:utcNow()
        };
    }

    // Get all routes
    resource function get routes() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection routes = check db->getCollection("routes");

        stream<Route, error?> routeStream = check routes->find();
        Route[]|error routeArray = from Route route in routeStream select route;

        if routeArray is Route[] {
            return {routes: routeArray, count: routeArray.length()};
        }

        return {routes: [], count: 0};
    }

    // Get route by ID
    resource function get routes/[string routeId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection routes = check db->getCollection("routes");

        map<json> filter = {_id: routeId};
        stream<Route, error?> routeStream = check routes->find(filter);
        Route[]|error routeArray = from Route route in routeStream select route;

        if routeArray is Route[] && routeArray.length() > 0 {
            return routeArray[0];
        }

        return error("Route not found");
    }

    // Create new route (admin only)
    resource function post routes(CreateRouteRequest request) returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection routes = check db->getCollection("routes");

        Route newRoute = {
            _id: uuid:createType1AsString(),
            routeNumber: request.routeNumber,
            name: request.name,
            'type: request.'type,
            origin: request.origin,
            destination: request.destination,
            stops: request.stops,
            distance: request.distance,
            estimatedDuration: request.estimatedDuration,
            status: "ACTIVE",
            createdAt: time:utcToString(time:utcNow()),
            updatedAt: time:utcToString(time:utcNow())
        };

        check routes->insertOne(newRoute);
        log:printInfo("New route created: " + request.routeNumber);

        return {
            message: "Route created successfully",
            routeId: newRoute._id,
            routeNumber: newRoute.routeNumber
        };
    }

    // Get trips for a route
    resource function get routes/[string routeId]/trips() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection trips = check db->getCollection("trips");

        map<json> filter = {routeId: routeId};
        stream<Trip, error?> tripStream = check trips->find(filter);
        Trip[]|error tripArray = from Trip trip in tripStream select trip;

        if tripArray is Trip[] {
            return {routeId: routeId, trips: tripArray, count: tripArray.length()};
        }

        return {routeId: routeId, trips: [], count: 0};
    }

    // Create new trip
    resource function post trips(CreateTripRequest request) returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection trips = check db->getCollection("trips");

        Trip newTrip = {
            _id: uuid:createType1AsString(),
            routeId: request.routeId,
            departureTime: request.departureTime,
            arrivalTime: request.arrivalTime,
            availableSeats: request.totalSeats,
            totalSeats: request.totalSeats,
            price: request.price,
            status: "SCHEDULED",
            createdAt: time:utcToString(time:utcNow()),
            updatedAt: time:utcToString(time:utcNow())
        };

        check trips->insertOne(newTrip);
        log:printInfo("New trip created for route: " + request.routeId);

        return {
            message: "Trip created successfully",
            tripId: newTrip._id,
            routeId: newTrip.routeId,
            departureTime: newTrip.departureTime
        };
    }

    // Publish schedule update
    resource function post schedule\-updates(ScheduleUpdate update) returns json|error {
        // Publish to Kafka
        check kafkaProducer->send({
            topic: "schedule.updates",
            value: update.toJsonString().toBytes()
        });

        log:printInfo("Schedule update published for trip: " + update.tripId);

        return {
            message: "Schedule update published successfully",
            tripId: update.tripId,
            updateType: update.updateType
        };
    }
}
