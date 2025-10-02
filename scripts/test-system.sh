#!/bin/bash

# Test script for the Smart Public Transport Ticketing System
# This script demonstrates the complete flow of the system

echo "=== Smart Public Transport Ticketing System - Test Script ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Base URLs
PASSENGER_URL="http://localhost:9001/passenger"
TRANSPORT_URL="http://localhost:9002/transport"
TICKETING_URL="http://localhost:9003/ticketing"
PAYMENT_URL="http://localhost:9004/payment"
NOTIFICATION_URL="http://localhost:9005/notification"
ADMIN_URL="http://localhost:9006/admin"

echo -e "${BLUE}Step 1: Checking service health${NC}"
curl -s $PASSENGER_URL/health | jq '.'
curl -s $TRANSPORT_URL/health | jq '.'
curl -s $TICKETING_URL/health | jq '.'
curl -s $PAYMENT_URL/health | jq '.'
curl -s $NOTIFICATION_URL/health | jq '.'
curl -s $ADMIN_URL/health | jq '.'
echo ""

echo -e "${BLUE}Step 2: Registering a new passenger${NC}"
REGISTER_RESPONSE=$(curl -s -X POST $PASSENGER_URL/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test_passenger",
    "email": "test@example.com",
    "password": "password123",
    "firstName": "Test",
    "lastName": "Passenger"
  }')
echo $REGISTER_RESPONSE | jq '.'
PASSENGER_ID=$(echo $REGISTER_RESPONSE | jq -r '.userId')
echo -e "${GREEN}Passenger ID: $PASSENGER_ID${NC}"
echo ""

echo -e "${BLUE}Step 3: Logging in${NC}"
LOGIN_RESPONSE=$(curl -s -X POST $PASSENGER_URL/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }')
echo $LOGIN_RESPONSE | jq '.'
echo ""

echo -e "${BLUE}Step 4: Viewing available routes${NC}"
ROUTES_RESPONSE=$(curl -s $TRANSPORT_URL/routes)
echo $ROUTES_RESPONSE | jq '.'
ROUTE_ID=$(echo $ROUTES_RESPONSE | jq -r '.routes[0]._id')
echo -e "${GREEN}Selected Route ID: $ROUTE_ID${NC}"
echo ""

echo -e "${BLUE}Step 5: Creating a new trip${NC}"
TRIP_RESPONSE=$(curl -s -X POST $TRANSPORT_URL/trips \
  -H "Content-Type: application/json" \
  -d "{
    \"routeId\": \"$ROUTE_ID\",
    \"departureTime\": \"2025-10-01T08:00:00Z\",
    \"arrivalTime\": \"2025-10-01T08:35:00Z\",
    \"totalSeats\": 50,
    \"price\": 25.00
  }")
echo $TRIP_RESPONSE | jq '.'
TRIP_ID=$(echo $TRIP_RESPONSE | jq -r '.tripId')
echo -e "${GREEN}Trip ID: $TRIP_ID${NC}"
echo ""

echo -e "${BLUE}Step 6: Purchasing a ticket${NC}"
TICKET_RESPONSE=$(curl -s -X POST $TICKETING_URL/tickets \
  -H "Content-Type: application/json" \
  -d "{
    \"passengerId\": \"$PASSENGER_ID\",
    \"tripId\": \"$TRIP_ID\",
    \"ticketType\": \"SINGLE\",
    \"amount\": 25.00
  }")
echo $TICKET_RESPONSE | jq '.'
TICKET_ID=$(echo $TICKET_RESPONSE | jq -r '.ticketId')
echo -e "${GREEN}Ticket ID: $TICKET_ID${NC}"
echo ""

echo -e "${BLUE}Step 7: Processing payment${NC}"
PAYMENT_RESPONSE=$(curl -s -X POST $PAYMENT_URL/process \
  -H "Content-Type: application/json" \
  -d "{
    \"ticketId\": \"$TICKET_ID\",
    \"passengerId\": \"$PASSENGER_ID\",
    \"amount\": 25.00,
    \"paymentMethod\": \"CARD\"
  }")
echo $PAYMENT_RESPONSE | jq '.'
echo ""

echo -e "${BLUE}Step 8: Waiting for payment processing (5 seconds)${NC}"
sleep 5
echo ""

echo -e "${BLUE}Step 9: Checking ticket status${NC}"
TICKET_STATUS=$(curl -s $TICKETING_URL/tickets/$TICKET_ID)
echo $TICKET_STATUS | jq '.'
echo ""

echo -e "${BLUE}Step 10: Validating ticket${NC}"
VALIDATE_RESPONSE=$(curl -s -X POST $TICKETING_URL/validate \
  -H "Content-Type: application/json" \
  -d "{
    \"ticketId\": \"$TICKET_ID\",
    \"tripId\": \"$TRIP_ID\"
  }")
echo $VALIDATE_RESPONSE | jq '.'
echo ""

echo -e "${BLUE}Step 11: Viewing passenger tickets${NC}"
PASSENGER_TICKETS=$(curl -s $PASSENGER_URL/tickets/$PASSENGER_ID)
echo $PASSENGER_TICKETS | jq '.'
echo ""

echo -e "${BLUE}Step 12: Viewing notifications${NC}"
sleep 2
NOTIFICATIONS=$(curl -s $NOTIFICATION_URL/notifications/$PASSENGER_ID)
echo $NOTIFICATIONS | jq '.'
echo ""

echo -e "${BLUE}Step 13: Generating sales report (Admin)${NC}"
SALES_REPORT=$(curl -s $ADMIN_URL/reports/sales)
echo $SALES_REPORT | jq '.'
echo ""

echo -e "${BLUE}Step 14: Publishing service disruption (Admin)${NC}"
DISRUPTION_RESPONSE=$(curl -s -X POST $ADMIN_URL/disruptions \
  -H "Content-Type: application/json" \
  -d "{
    \"routeId\": \"$ROUTE_ID\",
    \"type\": \"DELAY\",
    \"message\": \"Route delayed by 15 minutes due to traffic\",
    \"startTime\": \"2025-10-01T08:00:00Z\",
    \"endTime\": \"2025-10-01T09:00:00Z\"
  }")
echo $DISRUPTION_RESPONSE | jq '.'
echo ""

echo -e "${GREEN}=== Test completed successfully! ===${NC}"
