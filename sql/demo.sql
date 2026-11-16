-- ============================================================
-- HOSPITAL APPOINTMENT DEMO
-- Three receptionists | Three patients | One doctor
-- Run this file in MySQL after your project setup is complete.
-- ============================================================

USE hospital_db;


-- ------------------------------------------------------------
-- SCENE 1 - RECEPTIONIST 1 REGISTERS SOURAV
-- The receptionist enters the details.
-- The database cleans the name, phone number and blood group.
-- ------------------------------------------------------------
select * from patients;
INSERT INTO patients (full_name, phone, dob, gender, blood_group)
VALUES ('  Sourav     Dutta  ', '+91 91234-00011',
        '1998-05-12', 'M', 'b+');

-- Check the saved details.
SELECT full_name, phone, blood_group
FROM patients
WHERE phone = '9123400011';


-- ------------------------------------------------------------
-- SCENE 2 - RECEPTIONIST 2 REGISTERS KABIR
-- ------------------------------------------------------------

INSERT INTO patients (full_name, phone, dob, gender, blood_group)
VALUES ('  KABIR    KHAN ', '9123400012',
        '1995-08-10', 'M', 'o+');

-- Check the saved details.
SELECT full_name, phone, blood_group
FROM patients
WHERE phone = '9123400012';


-- ------------------------------------------------------------
-- SCENE 3 - RECEPTIONIST 3 REGISTERS ROHAN
-- First try wrong details. The database should reject them.
-- ------------------------------------------------------------

-- Wrong phone number - this should show an error.
INSERT INTO patients (full_name, phone, dob, gender, blood_group)
VALUES ('Rohan Das', '12345', '1999-02-15', 'M', 'O+');

-- Wrong blood group - this should show an error.
INSERT INTO patients (full_name, phone, dob, gender, blood_group)
VALUES ('Rohan Das', '9123400013', '1999-02-15', 'Male', 'XYZ');

-- Now enter the correct details.
INSERT INTO patients (full_name, phone, dob, gender, blood_group)
VALUES ('  Rohan    Das ', '9123400013',
        '1999-02-15', 'M', 'o+');

-- Check the saved details.
SELECT full_name, phone, blood_group
FROM patients
WHERE phone = '9123400013';

select * from patients;
-- ------------------------------------------------------------
-- SCENE 4 - SOURAV ASKS FOR AN APPOINTMENT
-- Receptionist chooses a doctor and a time.
-- The database checks the doctor's working hours and free slot.
-- Doctor 8 is used for this demo.
-- ------------------------------------------------------------
select * from doctors;
select * from doctors where doctor_id=8;


INSERT INTO appointments
    (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES
    ((SELECT patient_id FROM patients WHERE phone = '9123400011'),
     8,
     TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '10:00:00'),
     'NORMAL',
     'BOOKED');

-- Show Sourav's appointment.
SELECT p.full_name, d.full_name AS doctor,
       a.appt_start, a.appt_status
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors d ON d.doctor_id = a.doctor_id
WHERE p.phone = '9123400011'
ORDER BY a.appoinment_id DESC
LIMIT 1;


-- ------------------------------------------------------------
-- SCENE 5 - KABIR ASKS FOR A FOLLOW-UP APPOINTMENT
-- The database applies the follow-up fee rule when the bill is made.
-- ------------------------------------------------------------

INSERT INTO appointments
    (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES
    ((SELECT patient_id FROM patients WHERE phone = '9123400012'),
     8,
     TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '10:15:00'),
     'FOLLOW_UP',
     'BOOKED');

-- Show Kabir's appointment.
SELECT p.full_name, d.full_name AS doctor,
       a.appt_start, a.appt_status
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors d ON d.doctor_id = a.doctor_id
WHERE p.phone = '9123400012'
ORDER BY a.appoinment_id DESC
LIMIT 1;


-- ------------------------------------------------------------
-- SCENE 6 - ROHAN TRIES TO TAKE A SLOT ALREADY BOOKED
-- The database should reject the overlapping appointment.
-- ------------------------------------------------------------

INSERT INTO appointments
    (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES
    ((SELECT patient_id FROM patients WHERE phone = '9123400013'),
     8,
     TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '10:00:00'),
     'NORMAL',
     'BOOKED');


-- ------------------------------------------------------------
-- SCENE 7 - ROHAN TRIES TO BOOK OUTSIDE THE DOCTOR'S HOURS
-- The database should reject the 3 PM appointment.
-- ------------------------------------------------------------

INSERT INTO appointments
    (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES
    ((SELECT patient_id FROM patients WHERE phone = '9123400013'),
     8,
     TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '15:00:00'),
     'NORMAL',
     'BOOKED');


-- ------------------------------------------------------------
-- SCENE 8 - ROHAN TRIES TO BOOK A PAST DATE
-- The database should reject the old date.
-- ------------------------------------------------------------

INSERT INTO appointments
    (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES
    ((SELECT patient_id FROM patients WHERE phone = '9123400013'),
     8,
     '2020-01-01 10:00:00',
     'NORMAL',
     'BOOKED');


-- ------------------------------------------------------------
-- SCENE 9 - ROHAN CHOOSES A FREE SLOT
-- This appointment should be accepted.
-- ------------------------------------------------------------

INSERT INTO appointments
    (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES
    ((SELECT patient_id FROM patients WHERE phone = '9123400013'),
     8,
     TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '10:30:00'),
     'NORMAL',
     'BOOKED');

-- Show Rohan's appointment.
SELECT p.full_name, d.full_name AS doctor,
       a.appt_start, a.appt_status
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors d ON d.doctor_id = a.doctor_id
WHERE p.phone = '9123400013'
ORDER BY a.appoinment_id DESC
LIMIT 1;

select * from doctors;
select * from appointments;
select p.full_name , d.full_name as doctors, a.appt_type,a.appt_start, a.appt_end, a.created_at 
from appointments a
join patients p on p.patient_id=a.patient_id
join doctors d on d.doctor_id=a.doctor_id;


-- ------------------------------------------------------------
-- SMALL HELPER COMMANDS FOR THIS DEMO
-- These find the latest appointment using the patient's phone.
-- They let us call your existing confirm/cancel procedures
-- without typing appointment numbers by hand.
-- ------------------------------------------------------------

DELIMITER $$

DROP PROCEDURE IF EXISTS demo_confirm_by_phone$$
CREATE PROCEDURE demo_confirm_by_phone(IN p_phone VARCHAR(20))
BEGIN
    DECLARE v_appt_id INT;

    SELECT appoinment_id INTO v_appt_id
    FROM appointments
    WHERE patient_id = (
        SELECT patient_id FROM patients WHERE phone = p_phone
    )
    ORDER BY appoinment_id DESC
    LIMIT 1;

    CALL confirm_appointment(v_appt_id);
END$$

DROP PROCEDURE IF EXISTS demo_cancel_by_phone$$
CREATE PROCEDURE demo_cancel_by_phone(
    IN p_phone VARCHAR(20), IN p_reason VARCHAR(100)
)
BEGIN
    DECLARE v_appt_id INT;

    SELECT appoinment_id INTO v_appt_id
    FROM appointments
    WHERE patient_id = (
        SELECT patient_id FROM patients WHERE phone = p_phone
    )
    ORDER BY appoinment_id DESC
    LIMIT 1;

    CALL cancel_appointment(v_appt_id, p_reason);
END$$

DROP PROCEDURE IF EXISTS demo_update_status_by_phone$$
CREATE PROCEDURE demo_update_status_by_phone(
    IN p_phone VARCHAR(20), IN p_status VARCHAR(20)
)
BEGIN
    DECLARE v_appt_id INT;

    SELECT appoinment_id INTO v_appt_id
    FROM appointments
    WHERE patient_id = (
        SELECT patient_id FROM patients WHERE phone = p_phone
    )
    ORDER BY appoinment_id DESC
    LIMIT 1;

    UPDATE appointments
    SET appt_status = p_status
    WHERE appoinment_id = v_appt_id;
END$$

DELIMITER ;


-- ------------------------------------------------------------
-- SCENE 10 - RECEPTIONIST 1 CONFIRMS SOURAV'S APPOINTMENT
-- The database creates the bill automatically.
-- ------------------------------------------------------------

CALL demo_confirm_by_phone('9123400011');

-- Show Sourav's bill.
SELECT p.full_name, b.net_ammount, b.payment_status
FROM bills b
JOIN appointments a ON a.appoinment_id = b.appointment_id
JOIN patients p ON p.patient_id = a.patient_id
WHERE p.phone = '9123400011';


-- ------------------------------------------------------------
-- SCENE 11 - RECEPTIONIST 2 CONFIRMS KABIR'S APPOINTMENT
-- The database creates the follow-up bill automatically.
-- ------------------------------------------------------------

CALL demo_confirm_by_phone('9123400012');

-- Show Kabir's bill.
SELECT p.full_name, b.net_ammount, b.payment_status
FROM bills b
JOIN appointments a ON a.appoinment_id = b.appointment_id
JOIN patients p ON p.patient_id = a.patient_id
WHERE p.phone = '9123400012';


-- ------------------------------------------------------------
-- SCENE 12 - RECEPTIONIST 1 RECORDS SOURAV'S UPI PAYMENT
-- ------------------------------------------------------------

UPDATE bills
SET payment_status = 'PAID', payment_mode = 'upi'
WHERE appointment_id = (
    SELECT appoinment_id
    FROM appointments
    WHERE patient_id = (
        SELECT patient_id FROM patients WHERE phone = '9123400011'
    )
    ORDER BY appoinment_id DESC
    LIMIT 1
);


-- ------------------------------------------------------------
-- SCENE 13 - RECEPTIONIST 2 RECORDS KABIR'S CARD PAYMENT
-- ------------------------------------------------------------

UPDATE bills
SET payment_status = 'PAID', payment_mode = 'card'
WHERE appointment_id = (
    SELECT appoinment_id
    FROM appointments
    WHERE patient_id = (
        SELECT patient_id FROM patients WHERE phone = '9123400012'
    )
    ORDER BY appoinment_id DESC
    LIMIT 1
);


-- ------------------------------------------------------------
-- SCENE 14 - KABIR CANCELS HIS APPOINTMENT
-- The database works out the refund automatically.
-- ------------------------------------------------------------

CALL demo_cancel_by_phone('9123400012', 'Patient unable to attend');

-- Check Kabir's refund.
SELECT p.full_name, a.appt_status,
       b.payment_status, b.refund_ammount
FROM bills b
JOIN appointments a ON a.appoinment_id = b.appointment_id
JOIN patients p ON p.patient_id = a.patient_id
WHERE p.phone = '9123400012';


-- ------------------------------------------------------------
-- SCENE 15 - SOURAV ATTENDS HIS APPOINTMENT
-- Receptionist marks the appointment as completed.
-- ------------------------------------------------------------

CALL demo_update_status_by_phone('9123400011', 'COMPLETED');


-- ------------------------------------------------------------
-- SCENE 16 - ROHAN TRIES AN INVALID STATUS CHANGE
-- He has not confirmed his appointment.
-- The database should reject this change.
-- ------------------------------------------------------------

CALL demo_update_status_by_phone('9123400013', 'COMPLETED');


-- ------------------------------------------------------------
-- SCENE 17 - ROHAN TRIES TO GET A BILL BEFORE CONFIRMATION
-- The database should reject the bill.
-- ------------------------------------------------------------

INSERT INTO bills (appointment_id)
SELECT appoinment_id
FROM appointments
WHERE patient_id = (
    SELECT patient_id FROM patients WHERE phone = '9123400013'
)
ORDER BY appoinment_id DESC
LIMIT 1;


-- ------------------------------------------------------------
-- FINAL SCENE - SHOW ALL THREE PATIENTS
-- ------------------------------------------------------------

SELECT p.full_name, a.appt_start, a.appt_status
FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
WHERE p.phone IN ('9123400011', '9123400012', '9123400013')
ORDER BY p.full_name;


-- ------------------------------------------------------------
-- FINAL SCENE - SHOW BILLS AND REFUNDS
-- ------------------------------------------------------------

SELECT p.full_name, b.net_ammount,
       b.payment_status, b.refund_ammount
FROM bills b
JOIN appointments a ON a.appoinment_id = b.appointment_id
JOIN patients p ON p.patient_id = a.patient_id
WHERE p.phone IN ('9123400011', '9123400012')
ORDER BY p.full_name;


-- ------------------------------------------------------------
-- FINAL SCENE - SHOW THE PROJECT REPORTS
-- ------------------------------------------------------------

SELECT * FROM v_today_schedule;
SELECT * FROM v_doctor_workload;
SELECT * FROM v_monthly_revenue;
