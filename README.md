# Hospital Appointment Management System

A MySQL database for a small clinic that protects itself. Instead of trusting
the booking screen, the rules live inside the database as triggers, so every
way of entering data (a form, a CSV import, or someone typing SQL) must pass
the same checks.

Capstone project for Sayan Sir's Tutorials (CoE Kolkata), MySQL Capstone
Project Handbook, topic 11: Hospital Appointment Management.

## The problem

In a simple clinic system, receptionists make typing mistakes and several
people use the system at once. That causes:

- double bookings, including partial time overlaps (10:00-10:15 vs 10:10)
- wrong bill amounts typed by hand
- illegal status changes (a COMPLETED visit going back to BOOKED)
- unfair refunds
- messy data (phone numbers in different formats, empty names, bad emails)

## What the database does

- **Cleans data at the door.** Spaces, `+91` prefixes and letter case are fixed
  silently. Anything that would need a guess (a 7-digit phone, a future date of
  birth, a bad email) is rejected with a clear message.
- **Accepts only valid bookings.** Doctor active, not on the weekly off day,
  inside shift, on the slot grid, not in the past, no overlap with the doctor's
  or the patient's other visits, daily limit respected. Emergencies skip the
  slot grid and the daily limit.
- **Calculates bills itself.** Follow-up visits get 50% off, emergencies pay
  25% extra. The amount is stored so old bills keep what was really charged.
- **Controls the appointment life cycle** with a state machine of legal status
  moves.
- **Applies a time-based refund:** 100% at 24 hours or more before the visit,
  50% at 2 to 24 hours, 0% under 2 hours. A no-show or an unpaid bill is voided.
- TODO: describe the waiting list, if it is in `project.sql`.

## Database design

Five tables, as the handbook requires:

- `departments`
- `doctors` (shift, slot length, fee, daily limit, weekly off day)
- `patients`
- `appointments`
- `bills`

Conventions (see `CONTRACT.md`):

- `weekly_off` uses MySQL `WEEKDAY()`: 0 = Monday ... 6 = Sunday, NULL = no off day
- ENUM values are UPPERCASE
- `adjustment`: negative = discount, positive = surcharge
- money is `DECIMAL(10,2)`
- `appt_end`, `base_fee`, `adjustment` and `net_ammount` are filled by triggers
- the primary key of `appointments` is `appoinment_id` and the foreign key in
  `bills` is `appointment_id` (the spelling is kept on purpose)

TODO: add the ER diagram image, for example `docs/er_diagram.png`.

## Triggers

Cleaning triggers (patients and doctors, BEFORE INSERT and BEFORE UPDATE):

- `trg_patient_clean_insert`, `trg_patient_clean_update`
- `trg_doctor_clean_insert`, `trg_doctor_clean_update`

Rule triggers:

- `trg_appt_before_insert`: booking rules
- `trg_appt_before_update`: legal status moves, cancelled time stamp
- `trg_appt_after_update`: refund policy on the bill
- `trg_bill_before_insert`: bill must come from a CONFIRMED appointment,
  amount is calculated

## Views

- `v_today_schedule`: today's appointments for each doctor
- `v_doctor_workload`: appointments, completed, cancelled and no-shows per doctor
- `v_monthly_revenue`: money billed minus refunds, per month
- TODO: list any waiting-list views that exist in `project.sql`

## Procedures and transactions

 list the procedures and the COMMIT / ROLLBACK / SAVEPOINT demos from
`project.sql` and `sql/demo.sql`.

## Repository layout

```
sql/
  01_schema.sql          tables and indexes
  02_cleaning.sql        cleaning triggers
  03_seed_history.sql    past data (5 departments, 8 doctors, 12 patients,
                         25 appointments, 22 bills)
  04_triggers.sql        booking, status, refund and bill triggers
  06_views.sql           reporting views
  queries.sql            SELECT, UPDATE and DELETE statements
  transactions.sql       COMMIT and ROLLBACK demos
  demo.sql               TODO: describe
  project.sql            everything above joined in the right order
tests/                   cleaning tests and check queries
data/                    TODO: import CSV, bad CSV, exported CSV
CONTRACT.md              agreed column names, messages and policy values
```

## How to run

1. Install MySQL 8.0 or later (CHECK constraints need 8.0.16+).
2. Build everything from scratch:
   ```
   mysql -u root -p < sql/project.sql
   ```
   or, inside the MySQL shell: `source sql/project.sql;`
3. Run `sql/demo.sql` to see the rules in action. 


## Policy constants

- slot length: 15 minutes (per doctor)
- follow-up window: 14 days, 50% discount
- emergency surcharge: 25%
- refund: 100% at 24 h or more, 50% at 2 to 24 h, 0% under 2 h
- phone: 10 digits, starting with 6 to 9
- blood group: one of A+, A-, B+, B-, AB+, AB-, O+, O-

## Limits

A database cannot phone a patient, and it checks that data has the right
format, not that it is true.

## Team

- Ananya Manna (Person A): schema, cleaning layer, seed data, views, queries
- Rajdeep (Person B): rule triggers, procedures, transactions.

<img width="1137" height="798" alt="ER Diagram" src="https://github.com/user-attachments/assets/529ce2ea-b5ed-4e80-a996-2227290309ab" />

