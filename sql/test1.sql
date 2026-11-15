use hospital_db;

INSERT INTO departments VALUES (NULL,'Cardiology', 2);

INSERT INTO doctors (dept_id, full_name, email, consulatation_fee,
                     shift_start, shift_end, weekly_off)
VALUES (1, 'Dr. Roy', 'roy@clinic.com', 600.00, '10:00:00', '13:00:00', 6);

INSERT INTO patients (full_name, phone) VALUES ('Ananya Sen', '9830012345');

INSERT INTO appointments (patient_id, doctor_id, appt_start, appt_end)
VALUES (1, 1, '2026-12-01 11:00:00', '2026-12-01 11:15:00');

INSERT INTO bills (appointment_id, base_fee, net_ammount)
VALUES (1, 600.00, 600.00);

-- 2. these three MUST fail (that proves the rules work)
INSERT INTO bills (appointment_id) VALUES (1);              -- expect 1062
INSERT INTO appointments (patient_id, doctor_id, appt_start)
VALUES (99, 1, '2026-12-01 12:00:00');                      -- expect 1452
DELETE FROM doctors WHERE doctor_id = 1;                    -- expect 1451

-- 3. look at the result
SELECT a.appoinment_id, p.full_name, d.full_name AS doctor, a.appt_start
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors  d ON d.doctor_id  = a.doctor_id;

select * from departments;
select * from doctors;
select * from patients;
select * from appointments;
select * from bills;


DELETE FROM bills        WHERE bill_id > 0;
DELETE FROM appointments WHERE appoinment_id > 0;   
DELETE FROM patients     WHERE patient_id > 0;
DELETE FROM doctors      WHERE doctor_id > 0;
DELETE FROM departments  WHERE dept_id > 0;
