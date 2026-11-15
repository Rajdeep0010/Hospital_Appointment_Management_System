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

    -- Rule 1: read the doctor's working rules
    select is_active, weekly_off, shift_start, shift_end, slot_min
    into v_active, v_off, v_start, v_end, v_slot
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



    


