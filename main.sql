
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


-- PART 4: APPOINTMENT VALIDATION TRIGGER

DELIMITER //

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

    -- Check whether doctor exists

    SELECT COUNT(*)
    INTO v_count
    FROM doctors
    WHERE doctor_id = NEW.doctor_id;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor does not exist';
    END IF;

    -- Get doctor details

    SELECT is_active, slot_min,
           max_daily_appointments, weekly_off,
           shift_start, shift_end
    INTO v_active, v_slot, v_max, v_off,
         v_shift_start, v_shift_end
    FROM doctors
    WHERE doctor_id = NEW.doctor_id;

    IF v_active = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor is not active';
    END IF;

    -- Check appointment date

    IF NEW.appt_start < NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment cannot be in the past';
    END IF;

    -- Calculate appointment end time

    SET v_end = DATE_ADD(
        NEW.appt_start,
        INTERVAL v_slot MINUTE
    );

    SET NEW.appt_end = v_end;

    -- Check weekly off

    IF WEEKDAY(NEW.appt_start) = v_off THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor has a weekly off';
    END IF;

    -- Check working hours

    IF TIME(NEW.appt_start) < v_shift_start
       OR TIME(v_end) > v_shift_end THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Outside doctor working hours';
    END IF;

    -- Check appointment slot

    IF MINUTE(NEW.appt_start) MOD v_slot <> 0
       OR SECOND(NEW.appt_start) <> 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid appointment time slot';
    END IF;

    -- Check doctor appointment overlap

    SELECT COUNT(*)
    INTO v_count
    FROM appointments
    WHERE doctor_id = NEW.doctor_id
      AND appt_status IN ('BOOKED', 'CONFIRMED')
      AND NEW.appt_start < appt_end
      AND v_end > appt_start;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor already has an appointment';
    END IF;

    -- Check patient appointment overlap

    SELECT COUNT(*)
    INTO v_count
    FROM appointments
    WHERE patient_id = NEW.patient_id
      AND appt_status IN ('BOOKED', 'CONFIRMED')
      AND NEW.appt_start < appt_end
      AND v_end > appt_start;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Patient already has an appointment';
    END IF;

    -- Check daily appointment limit

    SELECT COUNT(*)
    INTO v_count
    FROM appointments
    WHERE doctor_id = NEW.doctor_id
      AND DATE(appt_start) = DATE(NEW.appt_start)
      AND appt_status IN ('BOOKED', 'CONFIRMED');

    IF v_count >= v_max THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Daily appointment limit reached';
    END IF;

END //

-- PART 5: BILL CALCULATION TRIGGER

CREATE TRIGGER calculate_bill
BEFORE INSERT ON bills
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_type VARCHAR(20);
    DECLARE v_fee DECIMAL(10,2);

    SELECT a.appt_status, a.appt_type,
           d.consulatation_fee
    INTO v_status, v_type, v_fee
    FROM appointments a
    JOIN doctors d
        ON a.doctor_id = d.doctor_id
    WHERE a.appoinment_id = NEW.appointment_id;

    IF v_status <> 'CONFIRMED' THEN
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

    SET NEW.net_ammount =
        NEW.base_fee + NEW.adjustment;

END //

DELIMITER ;


-- PART 6: BOOK APPOINTMENT PROCEDURE


DELIMITER //

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
    DECLARE v_appointment_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Find existing patient

    SELECT MAX(patient_id)
    INTO v_patient_id
    FROM patients
    WHERE govt_id_type = UPPER(TRIM(p_id_type))
      AND govt_id_number =
          UPPER(REPLACE(TRIM(p_id_number), ' ', ''));

    -- Register new patient if not found

    IF v_patient_id IS NULL THEN

        INSERT INTO patients
        (full_name, govt_id_type, govt_id_number,
         phone, email)
        VALUES
        (p_name, p_id_type, p_id_number,
         p_phone, p_email);

        SET v_patient_id = LAST_INSERT_ID();

    END IF;

    -- Find doctor using department and email

    SELECT MAX(d.doctor_id)
    INTO v_doctor_id
    FROM doctors d
    JOIN departments dep
        ON d.dept_id = dep.dept_id
    WHERE dep.dept_name = p_dept_name
      AND d.email = LOWER(TRIM(p_doctor_email))
      AND d.is_active = TRUE;

    IF v_doctor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor not found';
    END IF;

    -- Create appointment

    INSERT INTO appointments
    (patient_id, doctor_id, requested_start,
     appt_start, appt_type, reason)
    VALUES
    (v_patient_id, v_doctor_id, p_appt_time,
     p_appt_time, p_appt_type, 'Hospital appointment');

    SET v_appointment_id = LAST_INSERT_ID();

    COMMIT;

    SELECT
        v_patient_id AS patient_id,
        v_appointment_id AS appointment_id,
        'Appointment booked successfully' AS message;

END //


-- PART 7: CONFIRM APPOINTMENT PROCEDURE


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
    WHERE appoinment_id = p_appointment_id;

    IF v_status <> 'BOOKED' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment cannot be confirmed';
    END IF;

    UPDATE appointments
    SET appt_status = 'CONFIRMED'
    WHERE appoinment_id = p_appointment_id;

    INSERT INTO bills
    (appointment_id, base_fee, adjustment, net_ammount)
    VALUES
    (p_appointment_id, 0, 0, 0);

    COMMIT;

END //



-- PART 8: CANCEL APPOINTMENT PROCEDURE

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
    WHERE appoinment_id = p_appointment_id;

    IF v_status NOT IN ('BOOKED', 'CONFIRMED') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment cannot be cancelled';
    END IF;

    UPDATE appointments
    SET appt_status = 'CANCELLED',
        cancel_reason = p_reason,
        cancelled_at = NOW()
    WHERE appoinment_id = p_appointment_id;

    -- Apply simple refund policy

    UPDATE bills
    SET refund_ammount =
            CASE
                WHEN payment_status = 'PAID'
                THEN net_ammount * 0.50
                ELSE 0
            END,

        payment_status =
            CASE
                WHEN payment_status = 'PAID'
                THEN 'REFUNDED'
                ELSE 'VOID'
            END

    WHERE appointment_id = p_appointment_id;

    COMMIT;

END //


-- PART 9: RECORD PAYMENT PROCEDURE

CREATE PROCEDURE record_payment(
    IN p_bill_id INT,
    IN p_mode VARCHAR(20)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE bills
    SET payment_status = 'PAID',
        payment_mode = p_mode
    WHERE bill_id = p_bill_id
      AND payment_status = 'UNPAID';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bill not found or already paid';
    END IF;

    COMMIT;

END //

DELIMITER ;


-- PART 10: CREATE VIEWS

-- View 1: Today's appointment schedule

CREATE VIEW v_today_schedule AS
SELECT
    a.appoinment_id,
    p.full_name AS patient_name,
    d.full_name AS doctor_name,
    dep.dept_name,
    a.appt_start,
    a.appt_end,
    a.appt_status
FROM appointments a
JOIN patients p
    ON a.patient_id = p.patient_id
JOIN doctors d
    ON a.doctor_id = d.doctor_id
JOIN departments dep
    ON d.dept_id = dep.dept_id
WHERE DATE(a.appt_start) = CURDATE();


-- View 2: Doctor workload

CREATE VIEW v_doctor_workload AS
SELECT
    d.doctor_id,
    d.full_name AS doctor_name,
    dep.dept_name,
    COUNT(a.appoinment_id) AS total_appointments
FROM doctors d
JOIN departments dep
    ON d.dept_id = dep.dept_id
LEFT JOIN appointments a
    ON d.doctor_id = a.doctor_id
GROUP BY
    d.doctor_id,
    d.full_name,
    dep.dept_name;

-- PART 11: INSERT SAMPLE PATIENTS

-- These are fictional demonstration IDs.

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


-- PART 12: TEST THE PROJECT

-- 1. Book an appointment

CALL book_appointment(
    'Rohan Das',
    'DEMO_ID',
    'DEMO1001',
    '9000000001',
    'rohan@example.com',
    'Cardiology',
    'amit@hospital.com',
    DATE_ADD(NOW(), INTERVAL 1 DAY),
    'REGULAR'
);


-- 2. Display appointments

SELECT * FROM appointments;


-- 3. Confirm appointment
-- Use the actual appointment ID returned above.

CALL confirm_appointment(1);


-- 4. Display bills

SELECT * FROM bills;


-- 5. Record payment
-- Use the actual bill ID.

CALL record_payment(1, 'CASH');


-- 6. Complete appointment

UPDATE appointments
SET appt_status = 'COMPLETED'
WHERE appoinment_id = 1
AND appt_status = 'CONFIRMED';


-- 7. Cancel another appointment
-- Use an existing appointment ID.

CALL cancel_appointment(
    2,
    'Patient requested cancellation'
);

-- PART 13: IMPORTANT SELECT QUERIES

-- Display all patients

SELECT * FROM patients;


-- Display all doctors

SELECT * FROM doctors;


-- Display all departments

SELECT * FROM departments;


-- Search patient

SELECT *
FROM patients
WHERE govt_id_type = 'DEMO_ID'
AND govt_id_number = 'DEMO1001';


-- Doctors with department names

SELECT
    d.full_name,
    dep.dept_name,
    d.consulatation_fee
FROM doctors d
JOIN departments dep
    ON d.dept_id = dep.dept_id;


-- Appointments with patient and doctor names

SELECT
    p.full_name AS patient_name,
    d.full_name AS doctor_name,
    a.appt_start,
    a.appt_status
FROM appointments a
JOIN patients p
    ON a.patient_id = p.patient_id
JOIN doctors d
    ON a.doctor_id = d.doctor_id;


-- Count appointments for each doctor

SELECT
    doctor_id,
    COUNT(*) AS total_appointments
FROM appointments
GROUP BY doctor_id;


-- Display unpaid bills

SELECT *
FROM bills
WHERE payment_status = 'UNPAID';


-- Display today's schedule

SELECT * FROM v_today_schedule;


-- Display doctor workload

SELECT * FROM v_doctor_workload;


-- PART 14: UPDATE AND DELETE QUERIES

-- Update patient phone number

UPDATE patients
SET phone = '9111111111'
WHERE patient_id = 1;


-- Update doctor's consultation fee

UPDATE doctors
SET consulatation_fee = 900
WHERE doctor_id = 1;


-- Delete a patient without appointments

DELETE FROM patients
WHERE patient_id = 3;



