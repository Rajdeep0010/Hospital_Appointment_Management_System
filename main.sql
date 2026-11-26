
-- HOSPITAL Appointment MANAGEMENT SYSTEM
DROP DATABASE IF EXISTS hospital_db;
CREATE DATABASE hospital_db;
USE hospital_db;

-- PART 1: CREATE TABLES
-- 1. DEPARTMENTS

CREATE TABLE departments (
    dept_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL UNIQUE,
    floor_no INT
);


-- 2. DOCTORS

CREATE TABLE doctors (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_id INT NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    consulatation_fee DECIMAL(10,2) NOT NULL,
    shift_start TIME NOT NULL,
    shift_end TIME NOT NULL,
    slot_min INT DEFAULT 30,
    max_daily_appointments INT DEFAULT 20,
    weekly_off INT DEFAULT 6,
    is_active BOOLEAN DEFAULT TRUE,

    FOREIGN KEY (dept_id)
        REFERENCES departments(dept_id)
);


-- 3. PATIENTS

CREATE TABLE patients (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    govt_id_type VARCHAR(30) NOT NULL,
    govt_id_number VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    email VARCHAR(100),
    dob DATE,
    gender VARCHAR(20),
    blood_group VARCHAR(5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (govt_id_type, govt_id_number)
);


-- 4. APPOINTMENTS

CREATE TABLE appointments (
    appoinment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    requested_start DATETIME NOT NULL,
    appt_start DATETIME NOT NULL,
    appt_end DATETIME,
    appt_type VARCHAR(20) DEFAULT 'REGULAR',
    appt_status VARCHAR(20) DEFAULT 'BOOKED',
    reason VARCHAR(255),
    cancel_reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cancelled_at DATETIME,

    FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id),

    FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id)
);


-- 5. BILLS

CREATE TABLE bills (
    bill_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT NOT NULL UNIQUE,
    base_fee DECIMAL(10,2) NOT NULL,
    adjustment DECIMAL(10,2) DEFAULT 0,
    net_ammount DECIMAL(10,2) NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'UNPAID',
    payment_mode VARCHAR(20),
    refund_ammount DECIMAL(10,2) DEFAULT 0,
    billed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (appointment_id)
        REFERENCES appointments(appoinment_id)
);

show tables;

CREATE INDEX idx_appt_doctor_status_start
    ON appointments (doctor_id, appt_status, appt_start); 

CREATE INDEX idx_appt_patient_status_start
    ON appointments (patient_id, appt_status, appt_start);

CREATE INDEX idx_bills_payment_status
    ON bills (payment_status);    
    
SHOW INDEX FROM appointments;    

-- =====================================================
-- PART 2: INSERT DEPARTMENTS
-- =====================================================

INSERT INTO departments (dept_name, floor_no)
VALUES
('Cardiology', 1),
('Neurology', 2),
('Orthopedics', 3),
('Dermatology', 2),
('General Medicine', 1);


-- PART 3: INSERT DOCTORS

INSERT INTO doctors
(dept_id, full_name, email, consulatation_fee,
 shift_start, shift_end, slot_min,
 max_daily_appointments, weekly_off)
VALUES
(1, 'Dr. Amit Sharma', 'amit@hospital.com',
 800, '09:00:00', '17:00:00', 30, 20, 6),

(1, 'Dr. Priya Singh', 'priya@hospital.com',
 700, '10:00:00', '18:00:00', 30, 20, 6),

(2, 'Dr. Rahul Das', 'rahul@hospital.com',
 900, '09:00:00', '16:00:00', 30, 18, 6),

(3, 'Dr. Neha Roy', 'neha@hospital.com',
 600, '10:00:00', '17:00:00', 30, 20, 6),

(4, 'Dr. Karan Mehta', 'karan@hospital.com',
 500, '09:00:00', '15:00:00', 30, 15, 6),

(5, 'Dr. Ananya Sen', 'ananya@hospital.com',
 400, '09:00:00', '17:00:00', 30, 25, 6);

select * from departments;
select * from doctors;

DELIMITER $$


-- TRIGGER 1: check_appointment

CREATE TRIGGER check_appointment
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    DECLARE v_active BOOLEAN;
    DECLARE v_slot INT;
    DECLARE v_max INT;
    DECLARE v_off INT;
    DECLARE v_shift_start TIME;
    DECLARE v_shift_end TIME;
    DECLARE v_count INT;
    DECLARE v_end DATETIME;

    -- 1. Doctor must exist
    SELECT COUNT(*) INTO v_count
    FROM doctors
    WHERE doctor_id = NEW.doctor_id;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor does not exist';
    END IF;

    -- Load the doctor's rules
    SELECT is_active, slot_min, max_daily_appointments,
           weekly_off, shift_start, shift_end
    INTO v_active, v_slot, v_max, v_off,
         v_shift_start, v_shift_end
    FROM doctors
    WHERE doctor_id = NEW.doctor_id;

    -- 2. Doctor must be active
    IF v_active = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor is not active';
    END IF;

    -- 3. Not in the past
    IF NEW.appt_start < NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment cannot be in the past';
    END IF;

    -- 4. Calculate the end time
    SET v_end = DATE_ADD(NEW.appt_start, INTERVAL v_slot MINUTE);
    SET NEW.appt_end = v_end;

    -- 5. Weekly off
    IF WEEKDAY(NEW.appt_start) = v_off THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor has a weekly off';
    END IF;

    -- 6. Working hours
    IF TIME(NEW.appt_start) < v_shift_start
       OR TIME(v_end) > v_shift_end THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Outside doctor working hours';
    END IF;

    -- 7. Slot boundary
    IF MINUTE(NEW.appt_start) MOD v_slot <> 0
       OR SECOND(NEW.appt_start) <> 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid appointment time slot';
    END IF;

    -- 8. Doctor overlap
    SELECT COUNT(*) INTO v_count
    FROM appointments
    WHERE doctor_id = NEW.doctor_id
      AND appt_status IN ('BOOKED', 'CONFIRMED')
      AND NEW.appt_start < appt_end
      AND v_end > appt_start;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor already has an appointment';
    END IF;

	-- 9. Patient overlap
    SELECT COUNT(*) INTO v_count
    FROM appointments
    WHERE patient_id = NEW.patient_id
      AND appt_status IN ('BOOKED', 'CONFIRMED')
      AND NEW.appt_start < appt_end
      AND v_end > appt_start;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Patient already has an appointment';
    END IF;

    -- 10. Daily limit
    SELECT COUNT(*) INTO v_count
    FROM appointments
    WHERE doctor_id = NEW.doctor_id
      AND DATE(appt_start) = DATE(NEW.appt_start)
      AND appt_status IN ('BOOKED', 'CONFIRMED');

    IF v_count >= v_max THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Daily appointment limit reached';
    END IF;

END$$
    

-- trigger 2: trg_appt_before_update
CREATE TRIGGER trg_appt_before_update
BEFORE UPDATE ON appointments
FOR EACH ROW
BEGIN
    -- Cannot move an appointment; cancel it and book again
    IF NEW.appt_start <> OLD.appt_start
       OR NEW.doctor_id <> OLD.doctor_id
       OR NEW.patient_id <> OLD.patient_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot change time, doctor or patient. Cancel and rebook';
    END IF;

    -- Allowed status changes:
    --   BOOKED    -> CONFIRMED or CANCELLED
    --   CONFIRMED -> COMPLETED or CANCELLED
    IF NEW.appt_status <> OLD.appt_status THEN
        IF NOT (
            (OLD.appt_status = 'BOOKED'
                AND NEW.appt_status IN ('CONFIRMED', 'CANCELLED'))
         OR (OLD.appt_status = 'CONFIRMED'
                AND NEW.appt_status IN ('COMPLETED', 'CANCELLED'))
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid appointment status change';
        END IF;
    END IF;
END$$

-- trigger 3: calculate_bill
CREATE TRIGGER calculate_bill
BEFORE INSERT ON bills
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_type VARCHAR(20);
    DECLARE v_fee DECIMAL(10,2);

    SELECT a.appt_status, a.appt_type, d.consulatation_fee
    INTO v_status, v_type, v_fee
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    WHERE a.appoinment_id = NEW.appointment_id;

    -- IS NULL covers an appointment id that does not exist
    IF v_status IS NULL OR v_status <> 'CONFIRMED' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment must be confirmed first';
    END IF;

    SET NEW.base_fee = v_fee;
    SET NEW.adjustment = 0;

    IF v_type = 'FOLLOW_UP' THEN
        SET NEW.adjustment = -(v_fee * 0.50);
    ELSEIF v_type = 'EMERGENCY' THEN
        SET NEW.adjustment = v_fee * 0.25;
    END IF;

    SET NEW.net_ammount = NEW.base_fee + NEW.adjustment;
END$$

-- TRIGGER 4: trg_appt_after_update
CREATE TRIGGER trg_appt_after_update
AFTER UPDATE ON appointments
FOR EACH ROW
BEGIN
    IF OLD.appt_status <> NEW.appt_status THEN

        -- a) create the bill on confirmation
        IF OLD.appt_status = 'BOOKED'
           AND NEW.appt_status = 'CONFIRMED' THEN

            INSERT INTO bills
                (appointment_id, base_fee, adjustment, net_ammount)
            VALUES
                (NEW.appoinment_id, 0, 0, 0);
        END IF;

        -- b) refund policy on cancellation
        IF NEW.appt_status = 'CANCELLED' THEN

            UPDATE bills
            SET refund_ammount =
                    CASE WHEN payment_status = 'PAID'
                         THEN net_ammount * 0.50
                         ELSE 0 END,
                payment_status =
                    CASE WHEN payment_status = 'PAID'
                         THEN 'REFUNDED'
                         ELSE 'VOID' END
            WHERE appointment_id = NEW.appoinment_id;
        END IF;
    END IF;
END$$

DELIMITER ;

-- procedures
-- procedure 1
DELIMITER $$
CREATE PROCEDURE book_appointment(
    IN p_name VARCHAR(100),
    IN p_id_type VARCHAR(30),
    IN p_id_number VARCHAR(100),
    IN p_phone VARCHAR(15),
    IN p_email VARCHAR(100),
    IN p_dept_name VARCHAR(50),
    IN p_doctor_email VARCHAR(100),
    IN p_appt_time DATETIME,
    IN p_appt_type VARCHAR(20)
)
BEGIN
    DECLARE v_patient_id INT;
    DECLARE v_doctor_id INT;
    DECLARE v_lock_id INT;
    DECLARE v_appointment_id INT;
    DECLARE v_id_type VARCHAR(30);
    DECLARE v_id_number VARCHAR(100);
    DECLARE v_type VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Normalize inputs once, and use the SAME values for
    -- both the search and the insert
    SET v_id_type   = UPPER(TRIM(p_id_type));
    SET v_id_number = UPPER(REPLACE(TRIM(p_id_number), ' ', ''));
    SET v_type      = UPPER(TRIM(p_appt_type));

    -- Input validation (no ENUM on the table, so check here)
    IF v_type NOT IN ('REGULAR', 'FOLLOW_UP', 'EMERGENCY') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid appointment type';
    END IF;

    IF p_appt_time IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment time is required';
    END IF;

    START TRANSACTION;

    -- Find the doctor (department name + email, active only)
    SELECT MAX(d.doctor_id)
    INTO v_doctor_id
    FROM doctors d
    JOIN departments dep ON d.dept_id = dep.dept_id
    WHERE dep.dept_name = TRIM(p_dept_name)
      AND d.email = LOWER(TRIM(p_doctor_email))
      AND d.is_active = TRUE;

    IF v_doctor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor not found';
    END IF;

    -- Lock this doctor's row until COMMIT/ROLLBACK.
    -- Two people booking the same doctor now queue up, so the
    -- trigger's overlap and daily-limit checks cannot race.
    SELECT doctor_id
    INTO v_lock_id
    FROM doctors
    WHERE doctor_id = v_doctor_id
    FOR UPDATE;

    -- Find the existing patient
    SELECT MAX(patient_id)
    INTO v_patient_id
    FROM patients
    WHERE govt_id_type = v_id_type
      AND govt_id_number = v_id_number;

    -- Register a new patient if not found
    IF v_patient_id IS NULL THEN
        INSERT INTO patients
            (full_name, govt_id_type, govt_id_number, phone, email)
        VALUES
            (p_name, v_id_type, v_id_number, p_phone, p_email);

        SET v_patient_id = LAST_INSERT_ID();
    END IF;

    -- Create the appointment (trigger check_appointment fires here)
    INSERT INTO appointments
        (patient_id, doctor_id, requested_start,
         appt_start, appt_type, reason)
    VALUES
        (v_patient_id, v_doctor_id, p_appt_time,
         p_appt_time, v_type, 'Hospital appointment');

    SET v_appointment_id = LAST_INSERT_ID();

    COMMIT;

    SELECT
        v_patient_id     AS patient_id,
        v_appointment_id AS appointment_id,
        'Appointment booked successfully' AS message;
END$$

-- procedure 2
CREATE PROCEDURE confirm_appointment(
    IN p_appointment_id INT
)
BEGIN
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT appt_status
    INTO v_status
    FROM appointments
    WHERE appoinment_id = p_appointment_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment not found';
    END IF;

    IF v_status <> 'BOOKED' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment cannot be confirmed';
    END IF;

    UPDATE appointments
    SET appt_status = 'CONFIRMED'
    WHERE appoinment_id = p_appointment_id;

    COMMIT;

    SELECT
        p_appointment_id AS appointment_id,
        'Appointment confirmed and bill created' AS message;
END$$

-- procedure 3
CREATE PROCEDURE cancel_appointment(
    IN p_appointment_id INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT appt_status
    INTO v_status
    FROM appointments
    WHERE appoinment_id = p_appointment_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment not found';
    END IF;

    IF v_status NOT IN ('BOOKED', 'CONFIRMED') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment cannot be cancelled';
    END IF;

    UPDATE appointments
    SET appt_status   = 'CANCELLED',
        cancel_reason = p_reason,
        cancelled_at  = NOW()
    WHERE appoinment_id = p_appointment_id;

    COMMIT;

    SELECT
        p_appointment_id AS appointment_id,
        'Appointment cancelled' AS message;
END$$

-- procedure 4
CREATE PROCEDURE record_payment(
    IN p_bill_id INT,
    IN p_mode VARCHAR(20)
)
BEGIN
    DECLARE v_mode VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_mode = UPPER(TRIM(p_mode));

    IF v_mode IS NULL OR v_mode = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment mode is required';
    END IF;

    START TRANSACTION;

    UPDATE bills
    SET payment_status = 'PAID',
        payment_mode   = v_mode
    WHERE bill_id = p_bill_id
      AND payment_status = 'UNPAID';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bill not found or already paid';
    END IF;

    COMMIT;

    SELECT
        p_bill_id AS bill_id,
        v_mode    AS payment_mode,
        'Payment recorded' AS message;
END$$

DELIMITER ;



-- =====================================================
-- TEST
-- =====================================================
-- CALL book_appointment('Rohan Das','DEMO_ID','DEMO1001','9000000001',
--      'rohan@example.com','Cardiology','amit@hospital.com',
--      '2026-12-01 10:00:00','FOLLOW_UP');
-- CALL confirm_appointment(1);
-- SELECT * FROM bills;                       -- 800 / -400 / 400 / UNPAID
-- CALL record_payment(1,'UPI');
-- CALL cancel_appointment(1,'Patient requested cancellation');
-- SELECT * FROM bills;                       -- REFUNDED, refund_ammount 200
--
-- Error tests:
-- CALL confirm_appointment(999);             -- Appointment not found
-- CALL book_appointment('X','DEMO_ID','X1','9','x@x.com',
--      'Cardiology','amit@hospital.com','2026-12-06 10:00:00','REGULAR');
--                                            -- Doctor has a weekly off
-- CALL book_appointment('X','DEMO_ID','X1','9','x@x.com',
--      'Cardiology','amit@hospital.com','2026-12-02 10:00:00','REGULER');
--                                            -- Invalid appointment type


USE hospital_db;

-- View 1: today's appointment schedule
CREATE OR REPLACE VIEW v_today_schedule AS
SELECT
    a.appoinment_id,
    p.full_name AS patient_name,
    d.full_name AS doctor_name,
    dep.dept_name,
    a.appt_start,
    a.appt_end,
    a.appt_status
FROM appointments a
JOIN patients p     ON a.patient_id = p.patient_id
JOIN doctors d      ON a.doctor_id  = d.doctor_id
JOIN departments dep ON d.dept_id   = dep.dept_id
WHERE a.appt_start >= CURDATE()
  AND a.appt_start <  CURDATE() + INTERVAL 1 DAY;

-- View 2: doctor workload
CREATE OR REPLACE VIEW v_doctor_workload AS
SELECT
    d.doctor_id,
    d.full_name AS doctor_name,
    dep.dept_name,
    COUNT(a.appoinment_id) AS total_appointments
FROM doctors d
JOIN departments dep ON d.dept_id = dep.dept_id
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
GROUP BY d.doctor_id, d.full_name, dep.dept_name;

INSERT INTO patients
(full_name, govt_id_type, govt_id_number,
 phone, email, dob, gender, blood_group)
VALUES
('Rohan Das', 'DEMO_ID', 'DEMO1001',
 '9000000001', 'rohan@example.com',
 '2000-05-10', 'Male', 'O+'),

('Priya Roy', 'DEMO_ID', 'DEMO1002',
 '9000000002', 'priya@example.com',
 '1998-08-15', 'Female', 'A+'),

('Amit Sen', 'DEMO_ID', 'DEMO1003',
 '9000000003', 'amit@example.com',
 '1995-02-20', 'Male', 'B+');


-- Test
-- 1. Doctor already booked at this time (Dr. Neha, appointment 3)
CALL book_appointment('Rohan Das','DEMO_ID','DEMO1001','9000000001',
     'rohan@example.com','Orthopedics','neha@hospital.com',
     '2026-12-02 10:30:00','REGULAR');
-- Doctor already has an appointment

-- 2. Sunday is the doctor's weekly off
CALL book_appointment('Rohan Das','DEMO_ID','DEMO1001','9000000001',
     'rohan@example.com','Orthopedics','neha@hospital.com',
     '2026-12-06 11:00:00','REGULAR');
-- Doctor has a weekly off

-- 3. Before the doctor's shift starts (Dr. Neha starts at 10:00)
CALL book_appointment('Rohan Das','DEMO_ID','DEMO1001','9000000001',
     'rohan@example.com','Orthopedics','neha@hospital.com',
     '2026-12-02 09:00:00','REGULAR');
-- Outside doctor working hours

-- 4. Not on a 30-minute slot
CALL book_appointment('Rohan Das','DEMO_ID','DEMO1001','9000000001',
     'rohan@example.com','Orthopedics','neha@hospital.com',
     '2026-12-02 12:15:00','REGULAR');
-- Invalid appointment time slot

-- 5. Wrong appointment type
CALL book_appointment('Rohan Das','DEMO_ID','DEMO1001','9000000001',
     'rohan@example.com','Orthopedics','neha@hospital.com',
     '2026-12-02 12:00:00','REGULER');
-- Invalid appointment type

-- 6. Appointment does not exist
CALL confirm_appointment(999);
-- Appointment not found

-- 7. Reverse a status by hand
UPDATE appointments SET appt_status = 'BOOKED' WHERE appoinment_id = 1;
-- Invalid appointment status change

-- Deno
USE hospital_db;

-- CASE 1: Follow-up visit (fee 800, 50% off)
CALL book_appointment('Rohan Das','DEMO_ID','DEMO1001','9000000001',
     'rohan@example.com','Cardiology','amit@hospital.com',
     '2026-12-01 10:00:00','FOLLOW_UP');

CALL confirm_appointment(1);
SELECT * FROM bills;                 -- 800 / -400 / 400 / UNPAID

CALL record_payment(1, 'UPI');

UPDATE appointments
SET appt_status = 'COMPLETED'
WHERE appoinment_id = 1;


-- CASE 2: Pay, then cancel (fee 900, refund 450)
CALL book_appointment('Priya Roy','DEMO_ID','DEMO1002','9000000002',
     'priya@example.com','Neurology','rahul@hospital.com',
     '2026-12-02 11:00:00','REGULAR');

CALL confirm_appointment(2);
CALL record_payment(2, 'CARD');
CALL cancel_appointment(2, 'Patient requested cancellation');

SELECT * FROM bills WHERE bill_id = 2;   -- REFUNDED, refund 450


-- CASE 3: Emergency (fee 600, +25%)
CALL book_appointment('Amit Sen','DEMO_ID','DEMO1003','9000000003',
     'amit@example.com','Orthopedics','neha@hospital.com',
     '2026-12-02 10:30:00','EMERGENCY');

CALL confirm_appointment(3);
SELECT * FROM bills WHERE bill_id = 3;   -- 600 / +150 / 750


-- RESULT
SELECT * FROM appointments;
SELECT * FROM bills;
select * from patients;