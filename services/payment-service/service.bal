import ballerina/http;
import ballerina/log;
import ballerinax/mongodb;
import ballerinax/kafka;
import ballerina/uuid;
import ballerina/time;
import ballerina/random;

// Configuration
configurable string mongodbUri = ?;
configurable string kafkaBootstrapServers = ?;

// Types
type Payment record {|
    string _id?;
    string ticketId;
    string passengerId;
    decimal amount;
    string paymentMethod; // CARD, MOBILE_MONEY, CASH
    string status; // PENDING, COMPLETED, FAILED
    string transactionId;
    string createdAt;
    string updatedAt;
|};

type PaymentRequest record {|
    string ticketId;
    string passengerId;
    decimal amount;
    string paymentMethod;
|};

type PaymentConfirmation record {|
    string paymentId;
    string ticketId;
    string passengerId;
    decimal amount;
    string status;
    string transactionId;
    string timestamp;
|};

mongodb:Client mongoClient = check new (mongodbUri);

kafka:ProducerConfiguration producerConfig = {
    clientId: "payment-service-producer",
    acks: "all",
    retryCount: 3
};

kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

service /payment on new http:Listener(9004) {

    // Health check
    resource function get health() returns json {
        return {
            service: "payment-service",
            status: "UP",
            timestamp: time:utcNow()
        };
    }

    // Process payment
    resource function post process(PaymentRequest request) returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection payments = check db->getCollection("payments");

        // Simulate payment processing
        int randomNum = check random:createIntInRange(1, 100);
        boolean paymentSuccess = randomNum > 10; // 90% success rate

        string status = paymentSuccess ? "COMPLETED" : "FAILED";
        string transactionId = "TXN-" + uuid:createType1AsString();

        Payment newPayment = {
            _id: uuid:createType1AsString(),
            ticketId: request.ticketId,
            passengerId: request.passengerId,
            amount: request.amount,
            paymentMethod: request.paymentMethod,
            status: status,
            transactionId: transactionId,
            createdAt: time:utcToString(time:utcNow()),
            updatedAt: time:utcToString(time:utcNow())
        };

        check payments->insertOne(newPayment);

        if paymentSuccess {
            // Publish payment confirmation to Kafka
            PaymentConfirmation confirmation = {
                paymentId: newPayment._id.toString(),
                ticketId: request.ticketId,
                passengerId: request.passengerId,
                amount: request.amount,
                status: "COMPLETED",
                transactionId: transactionId,
                timestamp: time:utcToString(time:utcNow())
            };

            check kafkaProducer->send({
                topic: "payments.processed",
                value: confirmation.toJsonString().toBytes()
            });

            log:printInfo("Payment processed successfully: " + transactionId);

            return {
                message: "Payment processed successfully",
                paymentId: newPayment._id,
                transactionId: transactionId,
                status: "COMPLETED"
            };
        } else {
            log:printError("Payment failed: " + transactionId);
            return error("Payment processing failed. Please try again.");
        }
    }

    // Get payment by ID
    resource function get payments/[string paymentId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection payments = check db->getCollection("payments");

        map<json> filter = {_id: paymentId};
        stream<Payment, error?> paymentStream = check payments->find(filter);
        Payment[]|error paymentArray = from Payment payment in paymentStream select payment;

        if paymentArray is Payment[] && paymentArray.length() > 0 {
            return paymentArray[0];
        }

        return error("Payment not found");
    }

    // Get payments by passenger
    resource function get payments/passenger/[string passengerId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase("transport_ticketing");
        mongodb:Collection payments = check db->getCollection("payments");

        map<json> filter = {passengerId: passengerId};
        stream<Payment, error?> paymentStream = check payments->find(filter);
        Payment[]|error paymentArray = from Payment payment in paymentStream select payment;

        if paymentArray is Payment[] {
            return {
                passengerId: passengerId,
                payments: paymentArray,
                count: paymentArray.length()
            };
        }

        return {
            passengerId: passengerId,
            payments: [],
            count: 0
        };
    }
}
