# Smart Public Transport Ticketing System

A distributed microservices-based ticketing system for buses and trains, built with Ballerina, Kafka, MongoDB, and Docker.

## Architecture

This system consists of 6 microservices:

1. **Passenger Service** (Port 9001) - User registration, login, and profile management
2. **Transport Service** (Port 9002) - Route and trip management
3. **Ticketing Service** (Port 9003) - Ticket lifecycle management (CREATED → PAID → VALIDATED → EXPIRED)
4. **Payment Service** (Port 9004) - Payment processing simulation
5. **Notification Service** (Port 9005) - Event-driven notifications
6. **Admin Service** (Port 9006) - Administrative functions and reporting

## Technologies

- **Ballerina** - All microservices implementation
- **Apache Kafka** - Event-driven messaging
- **MongoDB** - Persistent data storage
- **Docker & Docker Compose** - Containerization and orchestration

## Kafka Topics

- `ticket.requests` - Ticket creation requests
- `payments.processed` - Payment confirmations
- `schedule.updates` - Schedule changes and disruptions
- `ticket.status` - Ticket status updates

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB of available RAM
- Ports 9001-9006, 27017, 9092, 29092, 2181 available

## Quick Start

### 1. Build and Start All Services

\`\`\`bash
docker-compose up --build
\`\`\`

This will start:
- Zookeeper (port 2181)
- Kafka (ports 9092, 29092)
- MongoDB (port 27017)
- All 6 microservices (ports 9001-9006)

### 2. Wait for Services to Initialize

Wait about 30-60 seconds for all services to start and connect to Kafka and MongoDB.

### 3. Verify Services are Running

Check health endpoints:

\`\`\`bash
curl http://localhost:9001/passenger/health
curl http://localhost:9002/transport/health
curl http://localhost:9003/ticketing/health
curl http://localhost:9004/payment/health
curl http://localhost:9005/notification/health
curl http://localhost:9006/admin/health
\`\`\`

## Usage Examples

### Passenger Registration

\`\`\`bash
curl -X POST http://localhost:9001/passenger/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "password": "password123",
    "firstName": "John",
    "lastName": "Doe"
  }'
\`\`\`

### Login

\`\`\`bash
curl -X POST http://localhost:9001/passenger/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
\`\`\`

### View Available Routes

\`\`\`bash
curl http://localhost:9002/transport/routes
\`\`\`

### Create a Route (Admin)

\`\`\`bash
curl -X POST http://localhost:9002/transport/routes \
  -H "Content-Type: application/json" \
  -d '{
    "routeNumber": "B102",
    "name": "Airport - City Center",
    "type": "BUS",
    "origin": "Hosea Kutako Airport",
    "destination": "City Center",
    "stops": ["Airport", "Klein Windhoek", "City Center"],
    "distance": 45.0,
    "estimatedDuration": 60
  }'
\`\`\`

### Create a Trip

\`\`\`bash
curl -X POST http://localhost:9002/transport/trips \
  -H "Content-Type: application/json" \
  -d '{
    "routeId": "<route-id-from-previous-step>",
    "departureTime": "2025-10-01T08:00:00Z",
    "arrivalTime": "2025-10-01T09:00:00Z",
    "totalSeats": 50,
    "price": 25.00
  }'
\`\`\`

### Purchase a Ticket

\`\`\`bash
curl -X POST http://localhost:9003/ticketing/tickets \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "<user-id-from-registration>",
    "tripId": "<trip-id-from-previous-step>",
    "ticketType": "SINGLE",
    "amount": 25.00
  }'
\`\`\`

### Process Payment

\`\`\`bash
curl -X POST http://localhost:9004/payment/process \
  -H "Content-Type: application/json" \
  -d '{
    "ticketId": "<ticket-id-from-previous-step>",
    "passengerId": "<user-id>",
    "amount": 25.00,
    "paymentMethod": "CARD"
  }'
\`\`\`

### Validate Ticket

\`\`\`bash
curl -X POST http://localhost:9003/ticketing/validate \
  -H "Content-Type: application/json" \
  -d '{
    "ticketId": "<ticket-id>",
    "tripId": "<trip-id>"
  }'
\`\`\`

### View Passenger Tickets

\`\`\`bash
curl http://localhost:9001/passenger/tickets/<passenger-id>
\`\`\`

### View Notifications

\`\`\`bash
curl http://localhost:9005/notification/notifications/<user-id>
\`\`\`

### Generate Sales Report (Admin)

\`\`\`bash
curl http://localhost:9006/admin/reports/sales
\`\`\`

### Publish Service Disruption (Admin)

\`\`\`bash
curl -X POST http://localhost:9006/admin/disruptions \
  -H "Content-Type: application/json" \
  -d '{
    "routeId": "<route-id>",
    "type": "DELAY",
    "message": "Route B101 delayed by 30 minutes due to traffic",
    "startTime": "2025-10-01T08:00:00Z",
    "endTime": "2025-10-01T09:00:00Z"
  }'
\`\`\`

## Database Schema

### Collections

- **users** - Passenger and admin accounts
- **routes** - Bus and train routes
- **trips** - Scheduled trips on routes
- **tickets** - Purchased tickets with lifecycle status
- **payments** - Payment transactions
- **notifications** - User notifications

## Event Flow

1. **Ticket Purchase Flow**:
   - Passenger creates ticket → `ticket.requests` topic
   - Payment processed → `payments.processed` topic
   - Ticket status updated to PAID → `ticket.status` topic
   - Notification sent to passenger

2. **Ticket Validation Flow**:
   - Validator validates ticket
   - Ticket status updated to VALIDATED → `ticket.status` topic
   - Notification sent to passenger

3. **Schedule Update Flow**:
   - Admin publishes disruption → `schedule.updates` topic
   - Notification service notifies affected passengers

## Monitoring

View logs for each service:

\`\`\`bash
docker-compose logs -f passenger-service
docker-compose logs -f ticketing-service
docker-compose logs -f payment-service
docker-compose logs -f notification-service
\`\`\`

## Stopping the System

\`\`\`bash
docker-compose down
\`\`\`

To remove all data:

\`\`\`bash
docker-compose down -v
\`\`\`

## Development

### Project Structure

\`\`\`
.
├── docker-compose.yml
├── mongo-init/
│   └── init-db.js
├── services/
│   ├── passenger-service/
│   │   ├── service.bal
│   │   ├── Config.toml
│   │   └── Dockerfile
│   ├── transport-service/
│   │   ├── service.bal
│   │   ├── Config.toml
│   │   └── Dockerfile
│   ├── ticketing-service/
│   │   ├── service.bal
│   │   ├── Config.toml
│   │   └── Dockerfile
│   ├── payment-service/
│   │   ├── service.bal
│   │   ├── Config.toml
│   │   └── Dockerfile
│   ├── notification-service/
│   │   ├── service.bal
│   │   ├── Config.toml
│   │   └── Dockerfile
│   └── admin-service/
│       ├── service.bal
│       ├── Config.toml
│       └── Dockerfile
└── README.md
\`\`\`

### Testing Individual Services

You can test services individually by running them locally:

\`\`\`bash
cd services/passenger-service
bal run service.bal
\`\`\`

Make sure MongoDB and Kafka are running and accessible.

## Troubleshooting

### Services not connecting to Kafka

Wait 30-60 seconds after starting docker-compose for Kafka to fully initialize.

### MongoDB connection errors

Ensure MongoDB container is running:
\`\`\`bash
docker-compose ps mongodb
\`\`\`

### Port conflicts

If ports are already in use, modify the port mappings in docker-compose.yml.

## Assignment Requirements Checklist

- ✅ Kafka setup & topic management (15%)
- ✅ Database setup & schema design (10%)
- ✅ Microservices implementation in Ballerina (50%)
- ✅ Docker configuration & orchestration (20%)
- ✅ Documentation (5%)

## Future Enhancements

- Seat reservation with concurrency handling
- Real-time dashboard for trips/tickets
- Kubernetes deployment with autoscaling
- Monitoring with Prometheus/Grafana
- Authentication with JWT tokens
- Password hashing with bcrypt
- API Gateway for unified access
- Rate limiting and circuit breakers

## License

This project is for educational purposes as part of the DSA612S course assignment.

## Contributors

Group members should be listed here with their contributions.
