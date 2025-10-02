import ballerina/http;
import ballerina/log;
import ballerinax/mongodb;
import ballerina/uuid;
import ballerina/time;

// MongoDB configuration
configurable string mongodbUri = ?;

// Service configuration
type User record {|
    string _id?;
    string username;
    string email;
    string password;
    string role; // PASSENGER or ADMIN
    string firstName;
    string lastName;
    string createdAt;
    string updatedAt;
|};

type RegisterRequest record {|
    string username;
    string email;
    string password;
    string firstName;
    string lastName;
|};

type LoginRequest record {|
    string email;
    string password;
|};

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
|};

mongodb:Client mongoClient = check new (mongodbUri);

service /passenger on new http:Listener(9001) {

    // Health check endpoint
    resource function get health() returns json {
        return {
            service: "passenger-service",
            status: "UP",
            timestamp: time:utcNow()
        };
    }

    // Register a new passenger
    resource function post register(RegisterRequest request) returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection users = check db->getCollection("users");

        // Check if user already exists
        map<json> filter = {email: request.email};
        stream<User, error?> existingUsers = check users->find(filter);
        User[]|error userArray = from User user in existingUsers select user;
        
        if userArray is User[] && userArray.length() > 0 {
            return error("User with this email already exists");
        }

        // Create new user
        User newUser = {
            _id: uuid:createType1AsString(),
            username: request.username,
            email: request.email,
            password: request.password, // In production, hash this!
            role: "PASSENGER",
            firstName: request.firstName,
            lastName: request.lastName,
            createdAt: time:utcToString(time:utcNow()),
            updatedAt: time:utcToString(time:utcNow())
        };

        check users->insertOne(newUser);
        
        log:printInfo("New passenger registered: " + request.email);
        
        return {
            message: "Registration successful",
            userId: newUser._id,
            email: newUser.email
        };
    }

    // Login
    resource function post login(LoginRequest request) returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection users = check db->getCollection("users");

        map<json> filter = {email: request.email, password: request.password};
        stream<User, error?> userStream = check users->find(filter);
        User[]|error userArray = from User user in userStream select user;

        if userArray is User[] && userArray.length() > 0 {
            User user = userArray[0];
            log:printInfo("User logged in: " + request.email);
            return {
                message: "Login successful",
                userId: user._id,
                username: user.username,
                email: user.email,
                role: user.role
            };
        }

        return error("Invalid credentials");
    }

    // Get passenger profile
    resource function get profile/[string userId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection users = check db->getCollection("users");

        map<json> filter = {_id: userId};
        stream<User, error?> userStream = check users->find(filter);
        User[]|error userArray = from User user in userStream select user;

        if userArray is User[] && userArray.length() > 0 {
            User user = userArray[0];
            return {
                userId: user._id,
                username: user.username,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                role: user.role
            };
        }

        return error("User not found");
    }

    // Get passenger's tickets
    resource function get tickets/[string passengerId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection tickets = check db->getCollection("tickets");

        map<json> filter = {passengerId: passengerId};
        stream<Ticket, error?> ticketStream = check tickets->find(filter);
        Ticket[]|error ticketArray = from Ticket ticket in ticketStream select ticket;

        if ticketArray is Ticket[] {
            return {
                passengerId: passengerId,
                tickets: ticketArray,
                count: ticketArray.length()
            };
        }

        return {
            passengerId: passengerId,
            tickets: [],
            count: 0
        };
    }
}
