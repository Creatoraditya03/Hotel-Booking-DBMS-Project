# Hotel Booking Management System (MySQL)

A database project focused on booking correctness: preventing double-bookings, enforcing data integrity, and auditing changes.

**Tools:** MySQL, MySQL Workbench

## Schema
`guests`, `rooms`, `bookings`, `payments`, `audit_log`

## Key Design Decisions
- **Availability is derived from booking dates**, not a status flag. A room is free if no confirmed booking overlaps the requested range (`new_checkin < existing_checkout AND new_checkout > existing_checkin`), so same-day turnover works and future dates stay bookable.
- **Concurrency safety:** `BookRoom` runs in a transaction and locks the room row with `SELECT ... FOR UPDATE`. Two simultaneous bookings for the same room are serialized, so the second one sees the first and is rejected. Without the lock, both could pass the availability check and double-book the room.
- **Integrity at the database level:** foreign keys, a `CHECK` constraint on dates, and a composite index on `(room_id, check_in_date, check_out_date)` to support the overlap query.
- **Triggers:** every new booking is logged to `audit_log`, and every cancellation is logged with the refund amount due. Cancelled bookings are ignored by the overlap check, so dates free up automatically.
- **Views:** `room_revenue_report` (revenue, booking count, and average stay per room) and `booking_details` (readable booking list).

## Concurrency Demo
`concurrency_demo.sql` simulates two guests booking the same room at once using two sessions.

## Files
- `hotel_management.sql`: schema, sample data, procedure, triggers, views
- `concurrency_demo.sql`: two-session locking demo
