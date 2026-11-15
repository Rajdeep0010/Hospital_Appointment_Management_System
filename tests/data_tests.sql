use hospital_db;

insert into departments (dept_name, floor_no) values ('Cardiology', 2);

-- Test 1: messy data is saved clean
-- expect: 'Anil Kumar', '9830054321', 'A+'
insert into patients (full_name, phone, blood_group)
values ('   Anil    Kumar  ', '+91 98300-54321', 'a +');
select * from patients where phone = '9830054321';

-- Test 2: same phone in another format -> error 1062 (duplicate)
insert into patients (full_name, phone) values ('Anil K', '09830054321');

-- Test 3: short phone -> Invalid phone number
insert into patients (full_name, phone) values ('Rahul Das', '98300123');

-- Test 4: empty name -> Name cannot be empty
insert into patients (full_name, phone) values ('   ', '9830099999');

-- Test 5: future date of birth -> Invalid date of birth
insert into patients (full_name, phone, dob) values ('Meena Roy', '9830088888', '2030-01-01');

-- Test 6: bad blood group -> Invalid blood group
insert into patients (full_name, phone, blood_group) values ('Meena Roy', '9830088888', 'Z+');

-- Test 7: bad email -> Invalid email
insert into doctors (dept_id, full_name, email, consulatation_fee, shift_start, shift_end)
values (1, 'Dr. Roy', 'roy-at-clinic', 600, '10:00:00', '13:00:00');

-- Test 8: good doctor, email is saved in lowercase
-- expect: 'Dr. Test', 'testdoc@clinic.com'
insert into doctors (dept_id, full_name, email, consulatation_fee, shift_start, shift_end)
values (1, 'Dr. Test', 'TestDoc@Clinic.com', 600, '10:00:00', '13:00:00');
select * from doctors where email = 'testdoc@clinic.com';