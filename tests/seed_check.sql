use hospital_db;

-- expect: 'Dr. Das' and 'das@clinic.com'
select doctor_id, full_name, email from doctors where doctor_id = 3;

-- expect: 9831122334 / Priya Ghosh / 9123456789 / B+
select patient_id, full_name, phone, blood_group
from patients
where patient_id in (2, 3, 4, 6);