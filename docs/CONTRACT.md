# Project Contract: Hospital Appointment Management
Database: hospital_db |

## 1. Final column names

| Table | Columns |
|---|---|
| departments | dept_id PK, dept_name UNIQUE, floor_no |
| doctors | doctor_id PK, dept_id FK, full_name, email UNIQUE, consulatation_fee, shift_start, shift_end, slot_min, max_daily_appointments, weekly_off, is_active |
| patients | patient_id PK, full_name, phone UNIQUE, dob, gender, blood_group, created_at |
| appointments | appoinment_id PK, patient_id FK, doctor_id FK, requested_start, appt_start, appt_end, appt_type, appt_status, on_full, confirm_by, reason, cancel_reason, created_at, cancelled_at |
| bills | bill_id PK, appointment_id FK UNIQUE, base_fee, adjustment, net_ammount, payment_status, payment_mode, refund_ammount, billed_at |

Note: appointments PK is `appoinment_id`, bills FK is `appointment_id`. Be careful.

## 2. Conventions
- weekly_off uses MySQL WEEKDAY(): 0 = Monday ... 6 = Sunday, NULL = no off day
- ENUM values are UPPERCASE (see section 3)
- adjustment: negative = discount, positive = surcharge
- Money is DECIMAL(10,2)
- appt_end, base_fee, adjustment, net_ammount are filled by triggers

## 3. Status meanings

| Column | Values |
|---|---|
| appt_type | NORMAL, FOLLOW_UP, EMERGENCY |
| appt_status | BOOKED (reserved, no bill), CONFIRMED (bill exists), COMPLETED, CANCELLED, NO_SHOW, WAITLISTED (queue, holds no slot) |
| on_full | REJECT (default), NEXT_SLOT, WAITLIST |
| payment_status | PENDING, PAID, PART_REFUNDED, REFUNDED, VOID |

## 4. Legal status moves (state machine)

| From | Allowed to |
|---|---|
| WAITLISTED | BOOKED, CANCELLED |
| BOOKED | CONFIRMED, CANCELLED, NO_SHOW |
| CONFIRMED | COMPLETED, CANCELLED, NO_SHOW |
| COMPLETED, CANCELLED, NO_SHOW | none (final) |

A slot is held only by BOOKED and CONFIRMED rows.

## 5. Policy constants

| Rule | Value |
|---|---|
| Default slot length | 15 minutes (per doctor, column slot_min) |
| Follow-up window | 14 days after a COMPLETED visit, same doctor |
| Follow-up discount | 50% |
| Emergency surcharge | 25% |
| Refund: cancelled 24 h or more before | 100% |
| Refund: cancelled 2 h to 24 h before | 50% |
| Refund: cancelled under 2 h before | 0% |
| No-show / unpaid bill on cancel | bill becomes VOID, no refund |
| Waiting-list offer window | 30 minutes (confirm_by) |
| Offer cutoff | no offer or joining under 1 hour before the slot |
| Waiting queue cap | 3 per doctor and slot |
| NEXT_SLOT search | 7 days, never for EMERGENCY |
| Phone | 10 digits, starts with 6 to 9 |
| Emergency | skips slot grid and daily limit, still checks patient clash |

## 6. Error messages (SIGNAL SQLSTATE '45000')

Rules (owner: B)
| Situation | MESSAGE_TEXT |
|---|---|
| Doctor inactive | Doctor is not active |
| Weekly off | Doctor is off on this day |
| Outside shift | Time is outside the doctor shift |
| Not on slot grid | Time is not on the slot grid |
| In the past | Cannot book in the past |
| Overlap | Doctor is busy at this time |
| Patient clash | Patient already has an appointment at this time |
| Daily limit | Doctor daily limit reached |
| Fake follow-up | No completed visit in the last 14 days for follow-up |
| Illegal status move | Illegal status change |
| Bill not allowed | Bill needs a CONFIRMED appointment |
| Queue full | Waiting list is full for this slot |
| No slot found | No slot available in the next 7 days |

Cleaning (owner: A)
| Situation | MESSAGE_TEXT |
|---|---|
| Bad phone | Invalid phone number |
| Empty name | Name cannot be empty |
| Bad email | Invalid email |
| Bad blood group | Invalid blood group |
| Future or too old dob | Invalid date of birth |

## 7. File owners and build order

| Order | File | Owner |
|---|---|---|
| 1 | sql/01_schema.sql | A (B reviews) |
| 2 | sql/02_cleaning.sql | A |
| 3 | sql/03_seed_history.sql (BEFORE the rule triggers) | A |
| 4 | sql/04_triggers_rules.sql | B |
| 5 | sql/05_procedures.sql | B |
| 6 | sql/06_views.sql | A |
| 7 | sql/07_seed_live.sql | A |

## 8. Change rule
After tag v0.1-schema: no column or message changes without a GitHub issue
that the other person approves. Never edit the other person's file directly.