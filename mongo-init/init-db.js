// Initialize MongoDB collections and indexes for the transport ticketing system
const db = db.getSiblingDB("transport_ticketing")

// Create users collection
db.createCollection("users")
db.users.createIndex({ email: 1 }, { unique: true })
db.users.createIndex({ username: 1 }, { unique: true })
db.users.createIndex({ role: 1 })

// Create routes collection
db.createCollection("routes")
db.routes.createIndex({ routeNumber: 1 }, { unique: true })
db.routes.createIndex({ status: 1 })

// Create trips collection
db.createCollection("trips")
db.trips.createIndex({ routeId: 1 })
db.trips.createIndex({ departureTime: 1 })
db.trips.createIndex({ status: 1 })

// Create tickets collection
db.createCollection("tickets")
db.tickets.createIndex({ passengerId: 1 })
db.tickets.createIndex({ tripId: 1 })
db.tickets.createIndex({ status: 1 })
db.tickets.createIndex({ validUntil: 1 })

// Create payments collection
db.createCollection("payments")
db.payments.createIndex({ ticketId: 1 })
db.payments.createIndex({ passengerId: 1 })
db.payments.createIndex({ status: 1 })
db.payments.createIndex({ createdAt: 1 })

// Create notifications collection
db.createCollection("notifications")
db.notifications.createIndex({ userId: 1 })
db.notifications.createIndex({ createdAt: -1 })
db.notifications.createIndex({ read: 1 })

// Insert sample admin user
db.users.insertOne({
  username: "admin",
  email: "admin@windhoek.gov.na",
  password: "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy", // password: admin123
  role: "ADMIN",
  firstName: "System",
  lastName: "Administrator",
  createdAt: new Date(),
  updatedAt: new Date(),
})

// Insert sample routes
db.routes.insertMany([
  {
    routeNumber: "B101",
    name: "City Center - Katutura",
    type: "BUS",
    origin: "City Center",
    destination: "Katutura",
    stops: ["City Center", "Wernhil Park", "Soweto Market", "Katutura"],
    distance: 12.5,
    estimatedDuration: 35,
    status: "ACTIVE",
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    routeNumber: "T201",
    name: "Windhoek - Rehoboth",
    type: "TRAIN",
    origin: "Windhoek Central Station",
    destination: "Rehoboth Station",
    stops: ["Windhoek Central", "Brakwater", "Rehoboth"],
    distance: 87.0,
    estimatedDuration: 90,
    status: "ACTIVE",
    createdAt: new Date(),
    updatedAt: new Date(),
  },
])

print("Database initialized successfully with collections, indexes, and sample data")
