use hospital_db;

-- ==========================================================
-- SELECT QUERIES (11)
-- ==========================================================

-- Q1: doctors with their department (inner JOIN)
select d.full_name, dp.dept_name, d.consulatation_fee
from doctors d
join departments dp on dp.dept_id = d.dept_id;

-- Q2: appointments in a date range (BETWEEN)
select appoinment_id, patient_id, doctor_id, appt_start
from appointments
where appt_start between '2026-11-01' and '2026-11-10 23:59:59';

-- Q3: cancelled or no-show appointments (IN)
select appoinment_id, doctor_id, appt_status
from appointments
where appt_status in ('CANCELLED', 'NO_SHOW');

-- Q4: patients whose name starts with A (LIKE)
select patient_id, full_name, phone
from patients
where full_name like 'A%';

-- Q5: patients per department (GROUP BY)
select dp.dept_name, count(distinct a.patient_id) as patients
from appointments a
join doctors d      on d.doctor_id = a.doctor_id
join departments dp on dp.dept_id  = d.dept_id
group by dp.dept_name
order by patients desc;

-- Q6: doctors with no appointments (LEFT JOIN + IS NULL)
-- no rows is a correct result if every doctor has visits
select d.doctor_id, d.full_name
from doctors d
left join appointments a on a.doctor_id = d.doctor_id
where a.appoinment_id is null;

-- Q7: busy doctors with 3 or more appointments (HAVING)
select d.full_name, count(*) as total
from doctors d
join appointments a on a.doctor_id = d.doctor_id
group by d.doctor_id, d.full_name
having total >= 3
order by total desc;

-- Q8: top 3 doctors by money earned (ORDER BY + LIMIT)
select d.full_name, sum(b.net_ammount - b.refund_ammount) as earned
from bills b
join appointments a on a.appoinment_id = b.appointment_id
join doctors d      on d.doctor_id = a.doctor_id
where b.payment_status in ('PAID', 'PART_REFUNDED', 'REFUNDED')
group by d.doctor_id, d.full_name
order by earned desc
limit 3;

-- Q9: money collected by payment mode (GROUP BY)
select payment_mode, count(*) as bills, sum(net_ammount) as total
from bills
where payment_status = 'PAID'
group by payment_mode;

-- Q10: full details of each appointment (3-table JOIN)
select a.appoinment_id, p.full_name as patient, d.full_name as doctor,
       a.appt_start, a.appt_type, a.appt_status
from appointments a
join patients p on p.patient_id = a.patient_id
join doctors d  on d.doctor_id  = a.doctor_id
order by a.appt_start;

-- Q11: different blood groups of patients (DISTINCT)
select distinct blood_group from patients where blood_group is not null;

-- ==========================================================
-- UPDATE STATEMENTS (3)
-- ==========================================================

-- U1: change a patient's phone (the cleaning trigger cleans it on update)
select patient_id, full_name, phone from patients where patient_id = 9;
update patients set phone = '+91 98300-99887' where patient_id = 9;
select patient_id, full_name, phone from patients where patient_id = 9;   -- expect 9830099887

-- U2: raise one doctor's daily appointment limit
select doctor_id, full_name, max_daily_appointments from doctors where doctor_id = 1;
update doctors set max_daily_appointments = 30 where doctor_id = 1;
select doctor_id, full_name, max_daily_appointments from doctors where doctor_id = 1;

-- U3: correct the payment mode of one bill
select bill_id, payment_status, payment_mode from bills where bill_id = 2;
update bills set payment_mode = 'card' where bill_id = 2;
select bill_id, payment_status, payment_mode from bills where bill_id = 2;

-- ==========================================================
-- DELETE STATEMENTS (2 that work, 1 that must fail)
-- ==========================================================

-- D1: add a temporary patient and delete it again
insert into patients (full_name, phone) values ('Temp Patient', '9000011111');
select patient_id, full_name from patients where patient_id = last_insert_id();
delete from patients where patient_id = last_insert_id();
select count(*) as patients_after_delete from patients;

-- D2: add a temporary doctor and delete it again
insert into doctors (dept_id, full_name, email, consulatation_fee, shift_start, shift_end) values (1, 'Dr. Temp', 'temp@clinic.com', 400, '10:00:00', '12:00:00');
select doctor_id, full_name from doctors where doctor_id = last_insert_id();
delete from doctors where doctor_id = last_insert_id();
select count(*) as doctors_after_delete from doctors;

-- D3: this DELETE must FAIL (error 1451): Dr. Roy has appointments
delete from doctors where doctor_id = 1;