use hospital_db;

-- a) commit: confirm appointment 28 and create its bill together
ROLLBACK;
SELECT appoinment_id, appt_status FROM appointments WHERE appoinment_id = 28;

ROLLBACK;
SELECT COUNT(*) AS total_appointments FROM appointments;
SELECT appoinment_id, appt_status FROM appointments ORDER BY appoinment_id;

start transaction;
update appointments set appt_status = 'confirmed' where appoinment_id = 28;
insert into bills (appointment_id) values (28);
commit;

-- check a: expect confirmed and a bill of 300.00
select a.appoinment_id, a.appt_status, b.net_ammount
from appointments a
join bills b on b.appointment_id = a.appoinment_id
where a.appoinment_id = 28;

-- b) rollback: the second bill fails (duplicate), so the confirmation is undone
start transaction;
update appointments set appt_status = 'confirmed' where appoinment_id = 29;
insert into bills (appointment_id) values (29);
insert into bills (appointment_id) values (29);   -- error 1062 here
rollback;

-- check b: expect booked and 0 bills
select appoinment_id, appt_status from appointments where appoinment_id = 29;
select count(*) as bills_of_29 from bills where appointment_id = 29;

-- c) savepoint (bonus): keep appointment 30, undo appointment 31
start transaction;
update appointments set appt_status = 'confirmed' where appoinment_id = 30;
insert into bills (appointment_id) values (30);
savepoint after_first;
update appointments set appt_status = 'confirmed' where appoinment_id = 31;
insert into bills (appointment_id) values (31);
rollback to savepoint after_first;
commit;

-- check c: expect 30 confirmed with a bill, 31 booked with null
select a.appoinment_id, a.appt_status, b.net_ammount
from appointments a
left join bills b on b.appointment_id = a.appoinment_id
where a.appoinment_id in (30, 31);