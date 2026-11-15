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