use hospital_db;

-- ========== 1. departments (5) ==========
insert into departments (dept_name, floor_no) values
('Cardiology', 2),
('Neurology', 3),
('Paediatrics', 1),
('Orthopaedics', 2),
('General Medicine', 1);

-- ========== 2. doctors (8) ==========
-- weekly_off: 0 = Monday ... 6 = Sunday, NULL = no off day
-- Row 3 has messy spaces and a messy email on purpose (cleaning trigger fixes it)
insert into doctors (dept_id, full_name, email, consulatation_fee, shift_start, shift_end, weekly_off) values
(1, 'Dr. Roy',        'roy@clinic.com',         600.00, '10:00:00', '13:00:00', 6),
(2, 'Dr. Sen',        'sen@clinic.com',         800.00, '11:00:00', '15:00:00', 6),
(3, '  Dr.   Das ',   ' Das@Clinic.COM ',       500.00, '09:00:00', '12:00:00', 0),
(4, 'Dr. Banerjee',   'banerjee@clinic.com',    700.00, '14:00:00', '18:00:00', 6),
(5, 'Dr. Ghosh',      'ghosh@clinic.com',       300.00, '09:00:00', '17:00:00', 6),
(1, 'Dr. Mitra',      'mitra@clinic.com',       650.00, '15:00:00', '18:00:00', 5),
(3, 'Dr. Paul',       'paul@clinic.com',        450.00, '16:00:00', '19:00:00', 6),
(5, 'Dr. Chatterjee', 'chatterjee@clinic.com',  350.00, '10:00:00', '14:00:00', NULL);

-- ========== 3. patients (12) ==========
-- Rows 2, 3, 4 and 6 are messy on purpose (phone format, spaces, blood group)
insert into patients (full_name, phone, dob, gender, blood_group) values
('Ananya Sen',       '9830012345',      '1995-03-12', 'F', 'A+'),
('Rahul Das',        '+91 98311-22334', '1988-07-21', 'M', 'B+'),
('  Priya   Ghosh ', '9876543210',      '2001-11-02', 'F', 'O+'),
('Arjun Mitra',      '09123456789',     '1975-01-30', 'M', 'AB+'),
('Sneha Roy',        '8001234567',      '1999-05-18', 'F', 'A-'),
('Imran Sheikh',     '7003456789',      '1982-09-09', 'M', 'b +'),
('Debjani Paul',     '9433011122',      '1968-12-25', 'F', 'O-'),
('Rohit Banerjee',   '9831098765',      '2015-04-04', 'M', 'A+'),
('Meena Kapoor',     '9988776655',      '1990-08-15', 'F', 'B-'),
('Sourav Dutta',     '8697000111',      '1993-02-28', 'M', 'O+'),
('Tanushree Basu',   '9674123456',      '2018-06-10', 'F', 'AB-'),
('Kabir Khan',       '7699887766',      '1970-10-05', 'M', NULL);

-- ========== 4. appointments (25, all in the past) ==========
-- columns: patient_id, doctor_id, appt_start, appt_end (start + 15 min), appt_type, appt_status
insert into appointments (patient_id, doctor_id, appt_start, appt_end, appt_type, appt_status) values
(1,  1, '2026-10-27 10:00:00', '2026-10-27 10:15:00', 'NORMAL',    'COMPLETED'),  -- 1
(2,  1, '2026-10-27 10:15:00', '2026-10-27 10:30:00', 'NORMAL',    'COMPLETED'),  -- 2
(3,  2, '2026-10-28 11:00:00', '2026-10-28 11:15:00', 'NORMAL',    'COMPLETED'),  -- 3
(4,  4, '2026-10-28 14:00:00', '2026-10-28 14:15:00', 'NORMAL',    'COMPLETED'),  -- 4
(5,  5, '2026-10-29 09:00:00', '2026-10-29 09:15:00', 'NORMAL',    'COMPLETED'),  -- 5
(6,  5, '2026-10-29 09:15:00', '2026-10-29 09:30:00', 'NORMAL',    'COMPLETED'),  -- 6
(8,  3, '2026-10-30 09:00:00', '2026-10-30 09:15:00', 'NORMAL',    'COMPLETED'),  -- 7
(1,  1, '2026-11-03 10:00:00', '2026-11-03 10:15:00', 'FOLLOW_UP', 'COMPLETED'),  -- 8  (7 days after #1)
(7,  6, '2026-11-03 15:00:00', '2026-11-03 15:15:00', 'NORMAL',    'COMPLETED'),  -- 9
(9,  5, '2026-11-04 10:00:00', '2026-11-04 10:15:00', 'NORMAL',    'COMPLETED'),  -- 10
(10, 4, '2026-11-04 14:30:00', '2026-11-04 14:45:00', 'NORMAL',    'COMPLETED'),  -- 11
(11, 3, '2026-11-05 09:30:00', '2026-11-05 09:45:00', 'NORMAL',    'COMPLETED'),  -- 12
(12, 2, '2026-11-05 12:00:00', '2026-11-05 12:15:00', 'NORMAL',    'COMPLETED'),  -- 13
(3,  8, '2026-11-06 10:00:00', '2026-11-06 10:15:00', 'NORMAL',    'COMPLETED'),  -- 14
(2,  1, '2026-11-09 10:00:00', '2026-11-09 10:15:00', 'FOLLOW_UP', 'COMPLETED'),  -- 15 (13 days after #2)
(4,  6, '2026-11-10 16:00:00', '2026-11-10 16:15:00', 'NORMAL',    'CANCELLED'),  -- 16
(5,  2, '2026-11-10 11:30:00', '2026-11-10 11:45:00', 'NORMAL',    'CANCELLED'),  -- 17
(6,  7, '2026-11-11 16:15:00', '2026-11-11 16:30:00', 'NORMAL',    'CANCELLED'),  -- 18
(7,  5, '2026-11-11 11:00:00', '2026-11-11 11:15:00', 'NORMAL',    'NO_SHOW'),    -- 19
(10, 8, '2026-11-11 10:30:00', '2026-11-11 10:45:00', 'NORMAL',    'NO_SHOW'),    -- 20
(9,  6, '2026-11-12 15:15:00', '2026-11-12 15:30:00', 'EMERGENCY', 'COMPLETED'),  -- 21
(12, 4, '2026-11-12 15:00:00', '2026-11-12 15:15:00', 'NORMAL',    'COMPLETED'),  -- 22
(8,  7, '2026-11-12 16:00:00', '2026-11-12 16:15:00', 'NORMAL',    'COMPLETED'),  -- 23
(11, 3, '2026-11-13 09:00:00', '2026-11-13 09:15:00', 'FOLLOW_UP', 'COMPLETED'),  -- 24 (8 days after #12)
(1,  5, '2026-11-13 09:30:00', '2026-11-13 09:45:00', 'NORMAL',    'COMPLETED');  -- 25

-- ========== 5. bills (22) ==========
-- columns: appointment_id, base_fee, adjustment, net_ammount, payment_status, payment_mode, refund_ammount
-- follow-up = 50% off (negative), emergency = 25% extra (positive)
insert into bills (appointment_id, base_fee, adjustment, net_ammount, payment_status, payment_mode, refund_ammount) values
(1,  600.00,    0.00, 600.00, 'PAID',     'cash', 0.00),
(2,  600.00,    0.00, 600.00, 'PAID',     'upi',  0.00),
(3,  800.00,    0.00, 800.00, 'PAID',     'card', 0.00),
(4,  700.00,    0.00, 700.00, 'PAID',     'cash', 0.00),
(5,  300.00,    0.00, 300.00, 'PAID',     'cash', 0.00),
(6,  300.00,    0.00, 300.00, 'PAID',     'upi',  0.00),
(7,  500.00,    0.00, 500.00, 'PAID',     'cash', 0.00),
(8,  600.00, -300.00, 300.00, 'PAID',     'upi',  0.00),
(9,  650.00,    0.00, 650.00, 'PAID',     'card', 0.00),
(10, 300.00,    0.00, 300.00, 'PAID',     'cash', 0.00),
(11, 700.00,    0.00, 700.00, 'PAID',     'upi',  0.00),
(12, 500.00,    0.00, 500.00, 'PAID',     'cash', 0.00),
(13, 800.00,    0.00, 800.00, 'PAID',     'card', 0.00),
(14, 350.00,    0.00, 350.00, 'PAID',     'upi',  0.00),
(15, 600.00, -300.00, 300.00, 'PAID',     'cash', 0.00),
(17, 800.00,    0.00, 800.00, 'REFUNDED', 'card', 800.00),  -- cancelled long before, full refund
(19, 300.00,    0.00, 300.00, 'VOID',     NULL,   0.00),    -- no-show, unpaid bill voided
(21, 650.00,  162.50, 812.50, 'PAID',     'cash', 0.00),    -- emergency, 25% extra
(22, 700.00,    0.00, 700.00, 'PAID',     'upi',  0.00),
(23, 450.00,    0.00, 450.00, 'PAID',     'cash', 0.00),
(24, 500.00, -250.00, 250.00, 'PAID',     'upi',  0.00),
(25, 300.00,    0.00, 300.00, 'PAID',     'cash', 0.00);

-- ========== 6. check counts ==========
select count(*) as departments  from departments;
select count(*) as doctors      from doctors;
select count(*) as patients     from patients;
select count(*) as appointments from appointments;
select count(*) as bills        from bills;