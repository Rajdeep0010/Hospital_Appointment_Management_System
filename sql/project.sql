/* HOSPITAL MANAGEMENT SYSTEM — FRESH END-TO-END TEST
   Run this entire file in MySQL Workbench on a disposable database server.
   It drops hospital_db first. Do NOT run against data you need to keep.
   MySQL 8.x recommended. */
DROP DATABASE IF EXISTS hospital_db;

-- 1) SCHEMA
-- Create the database
create database if not exists hospital_db;
use hospital_db;

-- 1. departments
create table departments(
    dept_id INT auto_increment primary key,
    dept_name varchar(20) NOT NULL unique,
    floor_no int
);

-- 2. doctors
create table doctors(
     doctor_id INT auto_increment primary key,
     dept_id int not null,
     full_name varchar(50) not null,
     email varchar(100) not null unique,
     consulatation_fee decimal(10,2),
     shift_start time not null,
     shift_end time not null,
     slot_min int not null default 15,
     max_daily_appointments int not null default 20,
     weekly_off tinyint null check(weekly_off between 0 and 6),
     is_active tinyint not null default 1,
     check(shift_end>shift_start),
     foreign key (dept_id) references departments(dept_id)
);

-- 3. patients
create table patients(
     patient_id int auto_increment primary key,
     full_name varchar(80) not null,
     phone varchar(15) not null unique,
     dob date,
     gender ENUM('M','F','Others'),
     blood_group varchar(10),
     created_at timestamp default current_timestamp
);

-- 4. appointments
create table appointments(
     appoinment_id int auto_increment primary key,
     patient_id int not null,
     doctor_id int not null,
     requested_start datetime,
     appt_start datetime not null,
     appt_end datetime,
     appt_type enum('NORMAL','FOLLOW_UP','EMERGENCY') not null,
     appt_status enum('BOOKED','CONFIRMED','COMPLETED','CANCELLED','NO_SHOW','WAITLISTED') not null default 'BOOKED',
     on_full enum('REJECT','NEXT_SLOT','WAITLIST') not null default 'REJECT',
     confirm_by datetime,
     reason varchar(200),
     cancel_reason varchar(100),
     created_at timestamp default current_timestamp,
     cancelled_at datetime,
     foreign key(patient_id) references patients(patient_id),
     foreign key(doctor_id) references doctors(doctor_id)
);

-- 5. bills
create table bills(
      bill_id int auto_increment primary key,
      appointment_id int not null unique,
      base_fee decimal(10,2) not null default 0.00,
      adjustment decimal(10,2) not null default 0.00,
      net_ammount decimal(10,2) not null default 0.00,
      payment_status enum('PENDING','PAID','PART_REFUNDED','REFUNDED','VOID') not null default 'PENDING',
      payment_mode varchar(20),
      refund_ammount decimal(10,2) not null default 0.00,
      billed_at timestamp default current_timestamp,
      foreign key (appointment_id) references appointments(appoinment_id)
);

show tables;

-- Indexes
create index idx_appt_doctor_start on appointments(doctor_id, appt_start);
create index idx_appt_patient_start on appointments(patient_id, appt_start);
create index idx_bills_status on bills(payment_status);
-- 2) DATA-CLEANING TRIGGERS
use hospital_db;

delimiter $$

-- Cleaning 1: patients BEFORE INSERT
create trigger trg_patient_clean_insert
before insert on patients
for each row
begin
    declare p varchar(30);

    -- name: remove extra spaces, reject if empty
    set new.full_name = trim(new.full_name);
    set new.full_name = replace(new.full_name, '  ', ' ');
    set new.full_name = replace(new.full_name, '  ', ' ');
    if new.full_name = '' then
        signal sqlstate '45000' set message_text = 'Name cannot be empty';
    end if;

    -- phone: remove spaces, dashes and +91, then check 10 digits
    set p = replace(new.phone, ' ', '');
    set p = replace(p, '-', '');
    set p = replace(p, '+91', '');
    if length(p) = 11 and left(p, 1) = '0' then
        set p = substring(p, 2);          -- remove leading 0
    end if;
    if p not regexp '^[6-9][0-9]{9}$' then
        signal sqlstate '45000' set message_text = 'Invalid phone number';
    end if;
    set new.phone = p;

    -- blood group: "a +" becomes "A+", must be one of 8 values
    if new.blood_group is not null then
        set new.blood_group = upper(replace(trim(new.blood_group), ' ', ''));
        if new.blood_group not in ('A+','A-','B+','B-','AB+','AB-','O+','O-') then
            signal sqlstate '45000' set message_text = 'Invalid blood group';
        end if;
    end if;

    -- date of birth: not in the future, not before 1900
    if new.dob > curdate() or new.dob < '1900-01-01' then
        signal sqlstate '45000' set message_text = 'Invalid date of birth';
    end if;
end$$

-- Cleaning 2: patients BEFORE UPDATE (same rules, copy of the above)
create trigger trg_patient_clean_update
before update on patients
for each row
begin
    declare p varchar(30);

    set new.full_name = trim(new.full_name);
    set new.full_name = replace(new.full_name, '  ', ' ');
    set new.full_name = replace(new.full_name, '  ', ' ');
    if new.full_name = '' then
        signal sqlstate '45000' set message_text = 'Name cannot be empty';
    end if;

    set p = replace(new.phone, ' ', '');
    set p = replace(p, '-', '');
    set p = replace(p, '+91', '');
    if length(p) = 11 and left(p, 1) = '0' then
        set p = substring(p, 2);
    end if;
    if p not regexp '^[6-9][0-9]{9}$' then
        signal sqlstate '45000' set message_text = 'Invalid phone number';
    end if;
    set new.phone = p;

    if new.blood_group is not null then
        set new.blood_group = upper(replace(trim(new.blood_group), ' ', ''));
        if new.blood_group not in ('A+','A-','B+','B-','AB+','AB-','O+','O-') then
            signal sqlstate '45000' set message_text = 'Invalid blood group';
        end if;
    end if;

    if new.dob > curdate() or new.dob < '1900-01-01' then
        signal sqlstate '45000' set message_text = 'Invalid date of birth';
    end if;
end$$

-- Cleaning 3: doctors BEFORE INSERT
create trigger trg_doctor_clean_insert
before insert on doctors
for each row
begin
    set new.full_name = trim(new.full_name);
    set new.full_name = replace(new.full_name, '  ', ' ');
    if new.full_name = '' then
        signal sqlstate '45000' set message_text = 'Name cannot be empty';
    end if;

    -- email: lowercase, no spaces, must look like a@b.c
    set new.email = lower(trim(new.email));
    if new.email not like '%_@_%._%' or new.email like '% %' then
        signal sqlstate '45000' set message_text = 'Invalid email';
    end if;
end$$

-- Cleaning 4: doctors BEFORE UPDATE (copy of the above)
create trigger trg_doctor_clean_update
before update on doctors
for each row
begin
    set new.full_name = trim(new.full_name);
    set new.full_name = replace(new.full_name, '  ', ' ');
    if new.full_name = '' then
        signal sqlstate '45000' set message_text = 'Name cannot be empty';
    end if;

    set new.email = lower(trim(new.email));
    if new.email not like '%_@_%._%' or new.email like '% %' then
        signal sqlstate '45000' set message_text = 'Invalid email';
    end if;
end$$

delimiter ;

show triggers;
-- 3) SEED DATA (5 departments, 8 doctors, 12 patients, 25 appointments, 22 bills)
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
-- 4) APPOINTMENT AND BILL TRIGGERS (daily-limit variable fixed in this test copy)
use hospital_db;

-- Trigger 1: Before insert on appointments (Booking rules)
delimiter $$
create trigger trg_appt_before_insert
before insert on appointments
for each row
begin
    declare v_active int;
    declare v_off    int;
    declare v_start  time;
    declare v_end    time;
    declare v_slot   int;
    declare v_count int;
    declare v_max int;

    -- Rule 1: read the doctor's working rules
    select is_active, weekly_off, shift_start, shift_end, slot_min, max_daily_appointments
    into v_active, v_off, v_start, v_end, v_slot, v_max
    from doctors where doctor_id = new.doctor_id;

    -- Rule 2: the doctor must exist and be active
    if v_active is null or v_active = 0 then
        signal sqlstate '45000' set message_text = 'Doctor not found or not active';
    end if;

    -- Rule 3: no booking in the past (emergency is allowed)
    if new.appt_start < now() and new.appt_type <> 'EMERGENCY' then
        signal sqlstate '45000' set message_text = 'Cannot book in the past';
    end if;

    -- Rule 4: not on the doctor's weekly off day
    if weekday(new.appt_start) = v_off then
        signal sqlstate '45000' set message_text = 'Doctor is off on this day';
    end if;

    -- Rule 5: fill the end time
    set new.appt_end = new.appt_start + interval v_slot minute;

    -- Rule 6: the visit must be inside the shift
    if time(new.appt_start) < v_start or time(new.appt_end) > v_end then
        signal sqlstate '45000' set message_text = 'Time is outside the doctor shift';
    end if;

    -- Rule 7: the minute must fit the slot size (emergency is allowed)
    if minute(new.appt_start) % v_slot <> 0 and new.appt_type <> 'EMERGENCY' then
        signal sqlstate '45000' set message_text = 'Time is not on the slot grid';
    end if;
    
	-- rule 8: the doctor must not be busy at this time (time overlap)
	select count(*) into v_count
	from appointments
	where doctor_id = new.doctor_id
	  and appt_status in ('BOOKED', 'CONFIRMED')
	  and new.appt_start < appt_end
	  and new.appt_end > appt_start;

	if v_count > 0 then
		signal sqlstate '45000' set message_text = 'Doctor is busy at this time';
	end if;
    
	-- rule 9: the patient must not have another visit at this time
	select count(*) into v_count
	from appointments
	where patient_id = new.patient_id
	  and appt_status in ('BOOKED', 'CONFIRMED')
	  and new.appt_start < appt_end
	  and new.appt_end > appt_start;

	if v_count > 0 then
		signal sqlstate '45000' set message_text = 'Patient already has an appointment at this time';
	end if;

	-- rule 10: the doctor's daily limit (emergency is allowed)
	select count(*) into v_count
	from appointments
	where doctor_id = new.doctor_id
	  and appt_status in ('BOOKED', 'CONFIRMED')
	  and date(appt_start) = date(new.appt_start);

	if v_count >= v_max and new.appt_type <> 'EMERGENCY' then
		signal sqlstate '45000' set message_text = 'Doctor daily limit reached';
	end if;

end$$

-- Trigger 2: Before update on appointments (habdling Status state)
create trigger trg_appt_before_update
before update on appointments
for each row
begin
    -- rule 1: only legal status moves are allowed
    if old.appt_status <> new.appt_status
       and not (
            (old.appt_status = 'BOOKED'     and new.appt_status in ('CONFIRMED', 'CANCELLED', 'NO_SHOW'))
         or (old.appt_status = 'CONFIRMED'  and new.appt_status in ('COMPLETED', 'CANCELLED', 'NO_SHOW'))
         or (old.appt_status = 'WAITLISTED' and new.appt_status in ('BOOKED', 'CANCELLED'))
       ) then
        signal sqlstate '45000' set message_text = 'Illegal status change';
    end if;

    -- rule 2: stamp the time when an appointment is cancelled
    if new.appt_status = 'CANCELLED' and old.appt_status <> 'CANCELLED' then
        set new.cancelled_at = now();
    end if;
end $$

-- Trigger 3: Before insert on bills
create trigger trg_bill_before_insert
before insert on bills
for each row
begin
    declare v_status varchar(20);
    declare v_type   varchar(20);
    declare v_doctor int;
    declare v_fee    decimal(10,2);

    -- rule 1: read the appointment
    select appt_status, appt_type, doctor_id
    into v_status, v_type, v_doctor
    from appointments where appoinment_id = new.appointment_id;

    -- rule 2: a bill needs a confirmed appointment
    if v_status is null or v_status <> 'CONFIRMED' then
        signal sqlstate '45000' set message_text = 'Bill needs a CONFIRMED appointment';
    end if;

    -- rule 3: copy the doctor's fee
    select consulatation_fee into v_fee from doctors where doctor_id = v_doctor;
    set new.base_fee = v_fee;

    -- rule 4: follow-up gets 50 percent off, emergency pays 25 percent extra
    if v_type = 'FOLLOW_UP' then
        set new.adjustment = -(v_fee * 0.50);
    elseif v_type = 'EMERGENCY' then
        set new.adjustment = v_fee * 0.25;
    else
        set new.adjustment = 0;
    end if;

    -- rule 5: the final amount
    set new.net_ammount = new.base_fee + new.adjustment;
end$$

-- Trigger 4: After update on appointments(Refund policy)
create trigger trg_appt_after_update
after update on appointments
for each row
begin
    declare v_pay     varchar(20);
    declare v_net     decimal(10,2);
    declare v_minutes int;

    -- only when the status just became cancelled or no_show
    if new.appt_status in ('CANCELLED', 'NO_SHOW')
       and old.appt_status <> new.appt_status then

        -- rule 1: read the bill, if there is one
        select payment_status, net_ammount into v_pay, v_net
        from bills where appointment_id = new.appoinment_id;

        -- rule 2: an unpaid bill is voided
        if v_pay = 'PENDING' then
            update bills set payment_status = 'VOID', refund_ammount = 0
            where appointment_id = new.appoinment_id;
        end if;

        -- rule 3: a paid bill is refunded by the time left (cancel only)
        if v_pay = 'PAID' and new.appt_status = 'CANCELLED' then
            set v_minutes = timestampdiff(minute, now(), new.appt_start);

            if v_minutes >= 1440 then
                update bills set refund_ammount = v_net, payment_status = 'REFUNDED'
                where appointment_id = new.appoinment_id;
            elseif v_minutes >= 120 then
                update bills set refund_ammount = v_net * 0.50, payment_status = 'PART_REFUNDED'
                where appointment_id = new.appoinment_id;
            end if;
        end if;
    end if;
end$$

delimiter ;

show triggers;



    



-- 5) VIEWS
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
-- 6) STORED PROCEDURES
USE hospital_db;

DELIMITER $$
DROP PROCEDURE IF EXISTS confirm_appointment$$
CREATE PROCEDURE confirm_appointment(IN p_appt_id INT)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT appt_status INTO v_status
    FROM appointments
    WHERE appoinment_id = p_appt_id
    FOR UPDATE;

    IF v_status IS NULL OR v_status <> 'BOOKED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment must be BOOKED';
    END IF;

    UPDATE appointments
    SET appt_status = 'CONFIRMED'
    WHERE appoinment_id = p_appt_id;

    INSERT INTO bills (appointment_id)
    VALUES (p_appt_id);

    COMMIT;

    SELECT a.appoinment_id, a.appt_status, b.bill_id,
           b.base_fee, b.adjustment, b.net_ammount, b.payment_status
    FROM appointments a
    LEFT JOIN bills b ON b.appointment_id = a.appoinment_id
    WHERE a.appoinment_id = p_appt_id;
END$$

DROP PROCEDURE IF EXISTS cancel_appointment$$
CREATE PROCEDURE cancel_appointment(IN p_appt_id INT, IN p_reason VARCHAR(100))
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT appt_status INTO v_status
    FROM appointments
    WHERE appoinment_id = p_appt_id
    FOR UPDATE;

    IF v_status IS NULL OR v_status NOT IN ('BOOKED', 'CONFIRMED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only BOOKED or CONFIRMED appointments can be cancelled';
    END IF;

    UPDATE appointments
    SET appt_status = 'CANCELLED', cancel_reason = p_reason
    WHERE appoinment_id = p_appt_id;

    COMMIT;

    SELECT a.appoinment_id, a.appt_status, a.cancel_reason,
           a.cancelled_at, b.payment_status, b.net_ammount, b.refund_ammount
    FROM appointments a
    LEFT JOIN bills b ON b.appointment_id = a.appoinment_id
    WHERE a.appoinment_id = p_appt_id;
END$$
DELIMITER ;

-- ================================================================
-- 7) POSITIVE END-TO-END TESTS
-- ================================================================
-- Check seeded counts and cleaning results.
SELECT 'departments' AS check_name, COUNT(*) AS actual, 5 AS expected FROM departments
UNION ALL SELECT 'doctors', COUNT(*), 8 FROM doctors
UNION ALL SELECT 'patients', COUNT(*), 12 FROM patients
UNION ALL SELECT 'appointments', COUNT(*), 25 FROM appointments
UNION ALL SELECT 'bills', COUNT(*), 22 FROM bills;

SELECT doctor_id, full_name, email FROM doctors WHERE doctor_id = 3;
SELECT patient_id, full_name, phone, blood_group FROM patients WHERE patient_id IN (2,3,4,6);

-- Create two future slots on a weekday (doctor 1 works 10:00–13:00; Sunday is weekly off).
-- DATE_ADD(CURDATE(), INTERVAL 1 DAY) is adjusted to the next Tuesday if it lands on Sunday.
SET @test_day = DATE_ADD(CURDATE(), INTERVAL 1 DAY);

SET @test_day = IF(WEEKDAY(@test_day) = 6, DATE_ADD(@test_day, INTERVAL 1 DAY), @test_day);
SET @slot1 = TIMESTAMP(@test_day, '10:00:00');
SET @slot2 = TIMESTAMP(@test_day, '10:15:00');

-- Booking trigger should fill appt_end automatically and allow these valid slots.
INSERT INTO appointments (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES (1, 1, @slot1, 'NORMAL', 'BOOKED');
SET @confirm_id = LAST_INSERT_ID();

INSERT INTO appointments (patient_id, doctor_id, appt_start, appt_type, appt_status)
VALUES (2, 1, @slot2, 'NORMAL', 'BOOKED');
SET @cancel_id = LAST_INSERT_ID();

SELECT appoinment_id, patient_id, doctor_id, appt_start, appt_end, appt_status
FROM appointments WHERE appoinment_id IN (@confirm_id, @cancel_id);

-- Confirm procedure changes BOOKED -> CONFIRMED and creates the bill atomically.
CALL confirm_appointment(@confirm_id);

-- Mark the second bill as PAID after confirming, then cancel it to exercise refund logic.
CALL confirm_appointment(@cancel_id);
UPDATE bills SET payment_status = 'PAID', payment_mode = 'upi'
WHERE appointment_id = @cancel_id;
CALL cancel_appointment(@cancel_id, 'End-to-end refund test');

-- Confirm the resulting records.
SELECT a.appoinment_id, a.appt_status, b.base_fee, b.adjustment,
       b.net_ammount, b.payment_status, b.refund_ammount
FROM appointments a LEFT JOIN bills b
  ON b.appointment_id = a.appoinment_id
WHERE a.appoinment_id IN (@confirm_id, @cancel_id)
ORDER BY a.appoinment_id;

-- Views should execute. Today's schedule can legitimately be empty.
SELECT * FROM v_today_schedule;
SELECT * FROM v_doctor_workload ORDER BY doctor_id;
SELECT * FROM v_monthly_revenue ORDER BY month;

-- Run the SELECT/UPDATE/DELETE exercises from queries.sql separately if desired.
-- Do NOT run its final DELETE (doctor_id=1) as a success test: it must fail with FK error 1451.

-- ================================================================
-- 8) NEGATIVE TESTS — RUN ONE AT A TIME, NOT AS PART OF THE FULL RUN
-- Each statement below is expected to raise an error. Uncomment one, execute,
-- then comment it again before trying the next.
-- ================================================================
-- Invalid phone (cleaning trigger):
INSERT INTO patients (full_name, phone) VALUES ('Bad Phone', '12345');

-- Invalid blood group:
INSERT INTO patients (full_name, phone, blood_group) VALUES ('Bad Blood', '9000012345', 'XYZ');

-- Booking in the past (non-emergency):
INSERT INTO appointments (patient_id, doctor_id, appt_start, appt_type)
VALUES (3, 1, '2020-01-01 10:00:00', 'NORMAL');

-- Booking outside doctor 1 shift:
INSERT INTO appointments (patient_id, doctor_id, appt_start, appt_type)
VALUES (3, 1, TIMESTAMP(@test_day, '14:00:00'), 'NORMAL');

-- Illegal state transition (COMPLETED cannot go back to BOOKED):
UPDATE appointments SET appt_status='BOOKED' WHERE appoinment_id=1;

-- Duplicate bill (choose an appointment which already has a bill, e.g. 1):
INSERT INTO bills (appointment_id) VALUES (1);

-- Foreign-key protected doctor delete:
DELETE FROM doctors WHERE doctor_id=1;



-- ================================================================
-- 9) ORIGINAL QUERY / UPDATE / DELETE EXERCISES
-- D3 is commented because its expected FK failure would interrupt execution.
-- ================================================================
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
-- EXPECTED FAILURE (FK 1451): delete from doctors where doctor_id = 1;