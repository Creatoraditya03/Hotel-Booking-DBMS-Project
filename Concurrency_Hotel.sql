CREATE DATABASE HotelManagement;
USE HotelManagement;

CREATE TABLE guests (
    guest_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    phone VARCHAR(20),
    city VARCHAR(100)
);

CREATE TABLE rooms (
    room_id INT PRIMARY KEY AUTO_INCREMENT,
    room_type VARCHAR(50) NOT NULL,
    price_per_night DECIMAL(10,2) NOT NULL
);

CREATE TABLE bookings (
    booking_id INT PRIMARY KEY AUTO_INCREMENT,
    guest_id INT NOT NULL,
    room_id INT NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    total_amount DECIMAL(10,2),
    booking_status VARCHAR(20) DEFAULT 'Confirmed',
    FOREIGN KEY (guest_id) REFERENCES guests(guest_id),
    FOREIGN KEY (room_id) REFERENCES rooms(room_id),
    CHECK (check_out_date > check_in_date),
    INDEX idx_room_dates (room_id, check_in_date, check_out_date)
);

CREATE TABLE payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    amount_paid DECIMAL(10,2),
    payment_date DATE,
    payment_method VARCHAR(50),
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);

CREATE TABLE audit_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    action VARCHAR(255),
    table_name VARCHAR(50),
    record_id INT,
    changed_at DATETIME
);

INSERT INTO guests (name, email, phone, city) VALUES
('Rahul Mehta', 'rahul.m@example.com', '9876543210', 'Mumbai'),
('Priya Sharma', 'priya.s@example.com', '9876543211', 'Delhi'),
('Aditya Rao', 'aditya.r@example.com', '9876543212', 'Bangalore'),
('Sneha Iyer', 'sneha.i@example.com', '9876543213', 'Chennai'),
('Karan Singh', 'karan.s@example.com', '9876543214', 'Pune');

INSERT INTO rooms (room_type, price_per_night) VALUES
('Standard', 2500.00),
('Deluxe', 4000.00),
('Suite', 7000.00),
('Standard', 2500.00),
('Deluxe', 4000.00),
('Suite', 7000.00);

SELECT COUNT(*) FROM guests;   
SELECT COUNT(*) FROM rooms;  

USE HotelManagement;

DELIMITER //

CREATE PROCEDURE BookRoom(
    IN p_guest_id INT,
    IN p_room_id INT,
    IN p_checkin DATE,
    IN p_checkout DATE
)
BEGIN
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_guest_count INT;
    DECLARE v_conflicts INT;

    -- If anything unexpected fails, undo everything
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Booking failed: unexpected error' AS message;
    END;

    IF p_checkout <= p_checkin THEN
        SELECT 'Invalid dates: check-out must be after check-in' AS message;
    ELSE
        START TRANSACTION;

        -- Lock this room's row so simultaneous bookings for it have to queue up
        SELECT price_per_night INTO v_price
        FROM rooms WHERE room_id = p_room_id
        FOR UPDATE;

        SELECT COUNT(*) INTO v_guest_count
        FROM guests WHERE guest_id = p_guest_id;

        IF v_price IS NULL THEN
            ROLLBACK;
            SELECT 'Room does not exist' AS message;
        ELSEIF v_guest_count = 0 THEN
            ROLLBACK;
            SELECT 'Guest does not exist' AS message;
        ELSE
            -- Any confirmed booking for this room that overlaps the requested dates?
            SELECT COUNT(*) INTO v_conflicts
            FROM bookings
            WHERE room_id = p_room_id
              AND booking_status = 'Confirmed'
              AND p_checkin < check_out_date
              AND p_checkout > check_in_date;

            IF v_conflicts = 0 THEN
                INSERT INTO bookings
                    (guest_id, room_id, check_in_date, check_out_date, total_amount, booking_status)
                VALUES
                    (p_guest_id, p_room_id, p_checkin, p_checkout,
                     DATEDIFF(p_checkout, p_checkin) * v_price, 'Confirmed');
                COMMIT;
                SELECT 'Booking successful' AS message;
            ELSE
                ROLLBACK;
                SELECT 'Room not available for selected dates' AS message;
            END IF;
        END IF;
    END IF;
END //

DELIMITER ; 

CALL BookRoom(1, 1, '2026-10-10', '2026-10-13'); 
CALL BookRoom(2, 1, '2026-10-12', '2026-10-15');  
CALL BookRoom(2, 1, '2026-10-13', '2026-10-15'); 
CALL BookRoom(3, 1, '2026-10-15', '2026-10-14');  
CALL BookRoom(99, 1, '2026-11-01', '2026-11-03'); 

SELECT * FROM bookings;

USE HotelManagement;

DELIMITER //

-- Trigger 1: log every new booking
CREATE TRIGGER after_booking_insert
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, changed_at)
    VALUES (CONCAT('New booking created, amount: ', NEW.total_amount),
            'bookings', NEW.booking_id, NOW());
END //

-- Trigger 2: log every cancellation with the refund amount due
CREATE TRIGGER after_booking_cancel
AFTER UPDATE ON bookings
FOR EACH ROW
BEGIN
    IF NEW.booking_status = 'Cancelled' AND OLD.booking_status <> 'Cancelled' THEN
        INSERT INTO audit_log (action, table_name, record_id, changed_at)
        VALUES (CONCAT('Booking cancelled, refund due: ', NEW.total_amount),
                'bookings', NEW.booking_id, NOW());
    END IF;
END //

DELIMITER ;

-- 1. Make a new booking (fires Trigger 1)
CALL BookRoom(3, 2, '2026-10-20', '2026-10-22');

-- 2. Cancel booking 1 (fires Trigger 2)
UPDATE bookings SET booking_status = 'Cancelled' WHERE booking_id = 1;

-- 3. Check the audit trail
SELECT * FROM audit_log;

-- 4. Rebook the dates that were just freed up
CALL BookRoom(4, 1, '2026-10-10', '2026-10-12');

USE HotelManagement;

-- Business summary per room
CREATE VIEW room_revenue_report AS
SELECT 
    r.room_id,
    r.room_type,
    COUNT(b.booking_id) AS confirmed_bookings,
    COALESCE(SUM(b.total_amount), 0) AS total_revenue,
    ROUND(AVG(DATEDIFF(b.check_out_date, b.check_in_date)), 1) AS avg_stay_nights
FROM rooms r
LEFT JOIN bookings b 
    ON r.room_id = b.room_id AND b.booking_status = 'Confirmed'
GROUP BY r.room_id, r.room_type;

-- Readable booking list for front-desk style lookups
CREATE VIEW booking_details AS
SELECT b.booking_id, g.name AS guest_name, r.room_type, r.room_id,
       b.check_in_date, b.check_out_date, b.total_amount, b.booking_status
FROM bookings b
JOIN guests g ON b.guest_id = g.guest_id
JOIN rooms r ON b.room_id = r.room_id;

SELECT * FROM room_revenue_report ORDER BY total_revenue DESC;
SELECT * FROM booking_details;

USE HotelManagement;
CALL BookRoom(2, 5, '2026-12-01', '2026-12-03');