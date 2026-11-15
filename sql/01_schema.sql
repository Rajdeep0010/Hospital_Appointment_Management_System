-- Create the database
create database if not exists hospital_db;
use hospital_db;

-- Create the schemas
-- 1. Departments
create table departments(
    dept_id INT auto_increment primary key,
    dept_name varchar(20) NOT NULL unique,
    floor_no int
);

-- 2.doctors
create table doctors(
     doctor_id INT auto_increment primary key,
     dept_id int not null,
     full_name varchar(50) not null,
     email varchar(100) not null,
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
-- 3.patients
create table patients(
	 patient_id int auto_increment primary key,
     full_name varchar(80) not null,
     phone varchar(15) not null unique ,
     dob date,
     gender ENUM('M','F','Others'),
     blood_group varchar(10),
     created_at timestamp default current_timestamp
   );
-- 4.appointments
create table appointments(
     appoinment_id int auto_increment primary key,
     patient_id int not null,
     doctor_id int not null,
     requested_start datetime,
     appt_start datetime not null,
     appt_end datetime,
     appt_type enum('normal','follow-up','emergency') not null,
     appt_status enum('booked','confirmed','complete','cancelled','no_show','wait_listed') not null default 'booked',
     on_full enum('reject','next_slot','waitlisted') not null default 'reject',
     confirm_by datetime,
     reason varchar(200),
     cancel_reason varchar(100),
     created_at timestamp default current_timestamp,
     cancelled_at datetime,
     foreign key(patient_id) references patients(patient_id),
     foreign key(doctor_id) references doctors(doctor_id)     
);
-- 5.bills
create table bills(
      bill_id int auto_increment primary key,
      appointment_id int not null unique,
      base_fee decimal(10,2) not null default 0.00,
      adjustment decimal(10,2) not null default 0.00,
	  net_ammount decimal(10,2) not null default 0.00,
      payment_status enum('pending','paid','part_refunded','refunded','void') not null default 'pending',
      payment_mode varchar(20),
      refund_ammount decimal(10,2) not null default 0.00,
      billed_at timestamp default current_timestamp,
      foreign key (appointment_id) references appointments(appoinment_id)
);

show tables;

-- Indexes for the booking check 
create index idx_appt_doctor_start on appointments(doctor_id,appt_start);
create index idx_appt_patient_start on appointments(patient_id, appt_start);

SHOW INDEX FROM bills;