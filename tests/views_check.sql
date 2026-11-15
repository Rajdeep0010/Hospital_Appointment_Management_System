use hospital_db;

select * from v_today_schedule;
select * from v_doctor_workload order by total_appointments desc;
select * from v_monthly_revenue order by month;