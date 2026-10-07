# Hotel Booking Management System (SQL/DBMS Project)

A relational database project demonstrating core DBMS concepts — stored procedures, triggers, and views — built around a hotel booking system.

# Tools
MySQL, MySQL Workbench

## Schema
- `guests` — guest information
- `rooms` — room inventory and availability status
- `staff` — hotel staff records
- `bookings` — booking transactions linking guests to rooms
- `payments` — payment records per booking
- `audit_log` — automated change-tracking table

# Key Features
- Stored Procedure: `BookRoom` — handles availability check, booking insertion, and room status update as a single atomic operation
- Triggers: automatic audit logging on new bookings, automatic room status updates on cancellation
- Views: simplified lookup for current active bookings
