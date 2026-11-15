use hospital_db;

-- View 1: today's appointments for each doctor
-- (it will be empty for now, because the seed data is in the past)
create view v_today_schedule as
select d.full_name as doctor,
       a.appt_start,
       a.appt_end,
       p.full_name as patient,
       a.appt_type,
       a.appt_status
from appointments a
join doctors  d on d.doctor_id  = a.doctor_id
join patients p on p.patient_id = a.patient_id
where date(a.appt_start) = curdate()
  and a.appt_status in ('BOOKED', 'CONFIRMED');

-- View 2: how busy each doctor is
-- LEFT JOIN keeps doctors who have no appointments yet
create view v_doctor_workload as
select d.doctor_id,
       d.full_name as doctor,
       dp.dept_name,
       count(a.appoinment_id) as total_appointments,
       sum(a.appt_status = 'COMPLETED') as completed,
       sum(a.appt_status = 'CANCELLED') as cancelled,
       sum(a.appt_status = 'NO_SHOW')   as no_shows
from doctors d
join departments dp on dp.dept_id = d.dept_id
left join appointments a on a.doctor_id = d.doctor_id
group by d.doctor_id, d.full_name, dp.dept_name;

-- View 3: revenue per month = money billed minus money refunded
-- (the month comes from the appointment date, void bills are left out)
create view v_monthly_revenue as
select date_format(a.appt_start, '%Y-%m') as month,
       count(*) as bills,
       sum(b.net_ammount - b.refund_ammount) as revenue
from bills b
join appointments a on a.appoinment_id = b.appointment_id
where b.payment_status in ('PAID', 'PART_REFUNDED', 'REFUNDED')
group by date_format(a.appt_start, '%Y-%m');