-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: mariadb:3306
-- Tiempo de generación: 23-12-2024 a las 15:50:05
-- Versión del servidor: 11.5.2-MariaDB-ubu2404
-- Versión de PHP: 8.2.8

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `medic`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`user`@`%` PROCEDURE `addDiagnosis` (IN `p_medical_records_no` INT, IN `p_dis_name` VARCHAR(50), IN `p_patient_id` INT)   begin
    insert into Diagnosis values (p_medical_records_no, p_patient_id, (select dis_id from disease where dis_name = p_dis_name));
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `addPrescription` (IN `p_medical_records_no` INT, IN `p_medication_name` VARCHAR(50), IN `p_dosage` VARCHAR(100), IN `p_frequency` VARCHAR(50), IN `p_duration` INT, IN `p_patient_id` INT)   begin
    insert into Prescription values (p_medical_records_no, p_patient_id,
    (select medication_id from medication where medication_name = p_medication_name), 
    p_dosage, p_frequency, p_duration);
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `allDisease` ()   begin
    select dis_name from Disease;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `allMedication` ()   begin
    select medication_name from medication;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `book_appointment` (IN `app_id` INT, IN `patt_id` INT)   BEGIN
    DECLARE app_patient_id INT;

    -- Check if the appointment exists and if it's available
    SELECT patient_id INTO app_patient_id FROM appointments WHERE appointment_no = app_id;

    IF app_patient_id IS NULL THEN
        -- Reserve the appointment for the patient
        UPDATE appointments SET patient_id = patt_id WHERE appointment_no = app_id;
        SELECT 'Appointment booked successfully' AS result;
    ELSE
        -- Appointment is already reserved, return an error
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment is already reserved', MYSQL_ERRNO = 3001;
    END IF;
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `cancel_appointment` (IN `p_app_no` INT, IN `p_patt_id` INT)   BEGIN
    DECLARE this_patient_id INT DEFAULT NULL;
    DECLARE combined_datetime DATETIME DEFAULT NULL;

    -- Check if this appointment exists for this patient
    SELECT patient_id INTO this_patient_id 
    FROM appointments 
    WHERE appointment_no = p_app_no
    AND patient_id = p_patt_id;

    -- If no matching appointment was found, signal an error
    IF this_patient_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment not found or does not belong to the patient', MYSQL_ERRNO = 3004;
    END IF;

    -- Get the exact time of the appointment
    SELECT TIMESTAMP(app_date, app_time) INTO combined_datetime
    FROM appointments
    WHERE appointment_no = p_app_no;

    -- Check if combined_datetime is NULL
    IF combined_datetime IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid appointment date or time', MYSQL_ERRNO = 3006;
    END IF;

    -- Check if appointment is in the future
    IF combined_datetime < NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot cancel past appointments', MYSQL_ERRNO = 3005;
    END IF;

    -- Proceed to cancel the appointment
    UPDATE appointments
    SET patient_id = NULL
    WHERE appointment_no = p_app_no;
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `CreateEmployeeUser` (IN `p_name` VARCHAR(64), IN `p_date_of_birth` DATE, IN `p_phone` CHAR(10), IN `p_street` VARCHAR(64), IN `p_city` VARCHAR(16), IN `p_state` CHAR(2), IN `p_zipcode` CHAR(5), IN `p_start_date` DATE, IN `p_role` VARCHAR(32), IN `p_spe_name` VARCHAR(32), IN `p_email` VARCHAR(64))   BEGIN
    DECLARE generated_username VARCHAR(32);
    DECLARE default_password VARCHAR(32) DEFAULT 'clinic123';
    DECLARE v_is_doctor BOOL DEFAULT FALSE;
    DECLARE v_is_nurse BOOL DEFAULT FALSE;
    DECLARE v_spe_id INT;
    DECLARE v_emp_id INT;
    DECLARE exit handler for sqlexception
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- generate username based on name and date of birth
    SET generated_username = CONCAT(LEFT(p_name, 1), DATE_FORMAT(p_date_of_birth, '%Y%m%d'));

    -- based on role, set corresponding boolean value
    IF p_role = 'doctor' THEN
        SET v_is_doctor = TRUE;
    ELSEIF p_role = 'nurse' THEN
        SET v_is_nurse = TRUE;
    END IF;

    -- find specialty id based on specialty name
    SELECT spe_id INTO v_spe_id FROM specialty WHERE spe_name = p_spe_name;
    IF v_spe_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Specialty not found';
    END IF;

    -- start transaction
    START TRANSACTION;

    -- insert user information
    INSERT INTO User (username, password, role, email)
    VALUES (generated_username, default_password, 'employee', p_email);

    -- insert employee information
    INSERT INTO Employee (name, date_of_birth, phone, street, city, state, zipcode, start_date, is_doctor, is_nurse, spe_id, username)
    VALUES (p_name, p_date_of_birth, p_phone, p_street, p_city, p_state, p_zipcode, p_start_date, v_is_doctor, v_is_nurse, v_spe_id, generated_username);

    -- get the generated employee id
    SET v_emp_id = LAST_INSERT_ID();

    -- if the employee is a doctor, create a doctor-nurse pair
    IF v_is_doctor THEN
        INSERT INTO DoctorNursePair (doctor_id, nurse_id, pair_time)
        VALUES (v_emp_id, NULL, CURRENT_TIMESTAMP);
    END IF;

    -- commit
    COMMIT;
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `create_appointment_all_doctor` (IN `app_date` DATE)   begin
	declare done int default false;
    declare doctor_id int;
    declare doctor_cursor cursor for select emp_id from Employee where is_doctor = true;
    declare continue handler for not found set done = true;
    
    open doctor_cursor;
    read_loop: LOOP
		fetch doctor_cursor into doctor_id;
        if done then
			leave read_loop;
		end if;
        
        call create_daily_app(doctor_id, app_date);
	end loop;
    close doctor_cursor;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `create_daily_app` (`doctor_id` INT, `app_date` DATE)   begin
	declare time_increment int default 0;
    declare doctor_status enum('active', 'inactive');
    declare is_doctor bool;

    -- check if the employee is doctor and the status of the doctor
    select status, is_doctor into doctor_status, is_doctor from Employee where emp_id = doctor_id;
    
    if doctor_status <> 'active' or is_doctor <> true then
        signal sqlstate '45000'
        set MESSAGE_TEXT = 'The doctor is not active or not a doctor';
    end if;

    -- morning
    set time_increment = 0;
    while time_increment < 6 DO
		INSERT INTO appointments (app_date, app_time, patient_id, doctor_id) 
		VALUES (app_date, ADDTIME('09:00:00', MAKETIME(time_increment DIV 2, (time_increment MOD 2) * 30, 0)), NULL, doctor_id);
		SET time_increment = time_increment + 1;
	END WHILE;
	
    -- afternoon
	SET time_increment = 0;
	WHILE time_increment < 7 DO
		INSERT INTO appointments (app_date, app_time, patient_id, doctor_id) 
		VALUES (app_date, ADDTIME('14:00:00', MAKETIME(time_increment DIV 2, (time_increment MOD 2) * 30, 0)), NULL, doctor_id);
		SET time_increment = time_increment + 1;
	END WHILE;
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `create_medical_record` (`p_patient_id` INT, `p_doctor_id` INT)   begin
    insert into MedicalRecords(record_date, patient_id, doctor_id) values (CURRENT_DATE(), p_patient_id, p_doctor_id);
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `create_medical_record_complete` (IN `p_patient_id` INT, IN `p_doctor_id` INT, IN `p_dis_name` VARCHAR(50), IN `p_medication_name` VARCHAR(50), IN `p_dosage` VARCHAR(100), IN `p_frequency` VARCHAR(50), IN `p_duration` INT)   begin
    declare v_medical_records_no int;
    
    start transaction;
    -- insert into MedicalRecords table
    call create_medical_record(p_patient_id, p_doctor_id);
    -- get the medical record number
    select medical_records_no into v_medical_records_no from MedicalRecords where patient_id = p_patient_id order by medical_records_no desc limit 1;
    -- add diagnosis
    call addDiagnosis(v_medical_records_no, p_dis_name, p_patient_id);
    -- add prescription
    call addPrescription(v_medical_records_no, p_medication_name, p_dosage, p_frequency, p_duration, p_patient_id);
    commit;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `create_user_patient` (IN `p_username` VARCHAR(32), IN `p_password` VARCHAR(32), IN `p_email` VARCHAR(64))   begin
	start transaction;
    -- insert into User table
    insert into User (username, password, role, email) values (p_username, p_password, 'patient', p_email);
    -- insert into Patient table, only username, let patient complete later
    insert into Patient (username) values (p_username);
    commit;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `delete_employee` (IN `employee_id` INT)   BEGIN
    DECLARE user_exists INT;
    DECLARE is_doctor BOOL;
    DECLARE is_nurse BOOL;

    -- Check if the user account exists
    SELECT COUNT(*) INTO user_exists FROM employee WHERE emp_id = employee_id;

    IF user_exists > 0 THEN
        start transaction;
        -- check if the employee is doctor or nurse
        SELECT
            is_doctor, is_nurse INTO is_doctor, is_nurse
        FROM
            Employee
        WHERE emp_id = employee_id;

        -- Delete future appointments for the doctor
        IF is_doctor THEN
            DELETE FROM appointments WHERE doctor_id = employee_id AND app_date > NOW();
            -- Delete doctor-nurse pairs associated with the employee
            DELETE FROM doctor_nurse_pairs WHERE doctor_id = employee_id;
        ELSEIF is_nurse THEN
            -- Delete the nurse from doctor-nurse pairs
            UPDATE doctor_nurse_pairs SET nurse_id = NULL WHERE nurse_id = employee_id;
        END IF;

        -- Delete the user account and update employee record
        DELETE FROM User WHERE username = (SELECT username FROM employee WHERE emp_id = employee_id);

        UPDATE employee SET status = 'inactive', username = NULL WHERE emp_id = employee_id;

        commit;

        SELECT 'Employee deleted successfully' AS result;
    ELSE
        SELECT 'Employee not found' AS result;
    END IF;
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `edit_user_account` (IN `p_username` VARCHAR(32), IN `new_email` VARCHAR(64), IN `new_password` VARCHAR(64))   BEGIN
    declare current_email varchar(64);
    declare current_password varchar(64);
    declare result boolean;

    select email, password into current_email, current_password from User where username = p_username;

    -- Check if email and password are different from the current ones
    if current_email is not null and current_email is not null THEN
        if current_email <> new_email or current_password <> new_password THEN
            update User set email = new_email, password = new_password where username = p_username;
        else
            -- email and password does not change
            signal sqlstate '45000' set MESSAGE_TEXT = 'No changes made to the user account';
        end if;
    else
        -- user does not exist
        signal sqlstate '45000' set MESSAGE_TEXT = 'User does not exist';
    end if;

    -- return result
    select result;
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_all_appointments` ()   begin
    select date_format(app_date, '%Y-%m-%d') as app_date, 
        TIME_FORMAT(app_time, '%H:%i:%s') as app_time,
        Patient.name as patient_name,
        Employee.name as doctor_name
    from appointments 
    left join Patient on appointments.patient_id = Patient.patient_id
    join Employee on appointments.doctor_id = Employee.emp_id
    where appointments.patient_id is not null
    order by app_date desc, app_time desc;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_all_employees` ()   begin
    select emp_id, name, date_format(date_of_birth, '%Y-%m-%d') as date_of_birth,
    phone, street, city, state, zipcode, date_format(start_date, '%Y-%m-%d') as start_date,
    status, is_doctor, is_nurse, biological_sex, spe_name, username
    from Employee
    join specialty on specialty.spe_id = Employee.spe_id
    where Employee.status = 'active'
    order by name;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_all_patients` ()   begin
    select patient_id, name, date_format(date_of_birth, '%Y-%m-%d') as date_of_birth,
    phone, street, city, state, zipcode, emergency_name, emergency_phone, username, biological_sex
    from Patient
    order by name;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_all_specialty` ()   begin
    select spe_name from specialty;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_appoint_by_empId` (IN `employee_id` INT)   Begin
    Select appointment_no, DATE_FORMAT(app_date, '%Y-%m-%d') as app_date, TIME_FORMAT(app_time, '%H:%i:%s') as app_time, a.patient_id, Patient.name 
    from appointments a 
    join DoctorNursePair dnp on a.doctor_id = dnp.doctor_id
    left join Patient on a.patient_id = Patient.patient_id
    where (dnp.doctor_id = employee_id or dnp.nurse_id = employee_id)
    -- and app_date = CURRENT_DATE()
    and a.patient_id is not null;
End$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_appoint_by_patId` (IN `patt_id` INT)   Begin
    Select appointment_no, DATE_FORMAT(app_date, '%Y-%m-%d') as app_date, TIME_FORMAT(app_time, '%H:%i:%s') as app_time, emp_id, Employee.name as doctor_name
    from appointments
    join Employee on appointments.doctor_id = Employee.emp_id
    where patient_id = patt_id
    order by app_date desc, app_time desc;
End$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_available_appointments` ()   BEGIN
    SELECT 
        appointment_no, 
        DATE_FORMAT(app_date, '%Y-%m-%d') AS app_date, 
        TIME_FORMAT(app_time, '%H:%i:%s') AS app_time, 
        Employee.name
    FROM appointments
    join Employee on appointments.doctor_id = Employee.emp_id
    WHERE patient_id IS NULL
      AND app_date >= NOW()
      AND app_date <= DATE_ADD(NOW(), INTERVAL 1 WEEK);
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_billing_patient` (IN `p_patient_id` INT)   begin 
    select amount, status, date_format(created_date, '%Y-%m-%d') as created_date, 
    date_format(payment_date, '%Y-%m-%d') as payment_date
    from Billing 
    where patient_id = p_patient_id
    order by created_date desc;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_billing_time` (IN `p_start_date` DATE, IN `p_end_date` DATE)   begin
    select amount, status, date_format(created_date, '%Y-%m-%d') as created_date,
    date_format(payment_date, '%Y-%m-%d') as payment_date,
    Patient.name as patient_name
    from billing 
    join Patient on billing.patient_id = Patient.patient_id
    where created_date >= p_start_date and created_date <= p_end_date;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_employee_info` (IN `p_username` VARCHAR(32))   begin
    select Employee.emp_id, name, DATE_FORMAT(date_of_birth, '%Y-%m-%d') as date_of_birth, phone, street, city, state, zipcode, biological_sex, spe_name, is_doctor, is_nurse
    from Employee 
    join specialty on specialty.spe_id = Employee.spe_id
    where username = p_username;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_medical_records` (IN `p_patient_id` INT)   BEGIN
    SELECT 
        mr.medical_records_no, 
        mr.record_date, 
        GROUP_CONCAT(distinct d.dis_name order by d.dis_name separator ', ') AS disease,
        GROUP_CONCAT(distinct m.medication_name order by m.medication_name separator ',') as medication,
        GROUP_CONCAT(distinct CONCAT(p.dosage, ' ', p.frequency, ' for ', p.duration, ' days') order by p.medication_id separator '; ') as prescriptions
    FROM MedicalRecords mr
    LEFT JOIN diagnosis dg ON mr.medical_records_no = dg.medical_records_no
    JOIN disease d ON dg.dis_id = d.dis_id
    JOIN prescription p ON mr.medical_records_no = p.medical_records_no
    JOIN medication m ON p.medication_id = m.medication_id
    WHERE mr.patient_id = p_patient_id
    GROUP BY mr.medical_records_no, mr.record_date
    ORDER BY mr.record_date DESC;
END$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_patient_info` (IN `p_username` VARCHAR(32))   begin
    Select name, DATE_FORMAT(date_of_birth, '%Y-%m-%d') as date_of_birth,
    patient_id, phone, street, city, state, zipcode, emergency_name, emergency_phone, username, biological_sex
    From Patient
    Where username = p_username;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `get_user_by_username` (IN `p_username` VARCHAR(32))   begin
    select * from User where username = p_username;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `payment_time` (IN `p_start_date` DATE, IN `p_end_date` DATE)   begin
    select sum(amount) from billing 
    where payment_date >= p_start_date and payment_date <= p_end_date
    order by payment_date desc;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `update_doctor_nurse_pair` (IN `p_doctor_id` INT, IN `p_nurse_id` INT)   begin 
    -- if the nurse_id paired with another doctor, can not update
    if exists(select * from DoctorNursePair where nurse_id = p_nurse_id and doctor_id <> p_doctor_id) then 
        signal sqlstate '45000'
        set MESSAGE_TEXT = 'The nurse is already paired with another doctor';
    else
    -- if the doctor_id exists in the table, then update the nurse_id
        if exists (select * from doctor_nurse_pair where doctor_id = p_doctor_id) then
            update DoctorNursePair 
            set nurse_id = p_nurse_id, pairtime = CURRENT_TIMESTAMP 
            where doctor_id = p_doctor_id;
        else
            -- if the doctor_id does not exist in the table, then insert the pair
            insert into DoctorNursePair(doctor_id, nurse_id, pair_time)
            values (p_doctor_id, p_nurse_id, CURRENT_TIMESTAMP);
        end if;
    end if;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `update_employee_info` (IN `p_employee_id` INT, IN `p_name` VARCHAR(64), IN `p_date_of_birth` DATE, IN `p_phone` CHAR(10), IN `p_street` VARCHAR(64), IN `p_city` VARCHAR(16), IN `p_state` CHAR(2), IN `p_zipcode` CHAR(5), IN `p_biological_sex` ENUM('male','female'), IN `p_spe_name` VARCHAR(32))   begin
    declare v_spe_id int;
    -- get the specialty id
    select spe_id into v_spe_id from specialty where spe_name = p_spe_name;
    -- update the employee record
    update Employee
    SET
        name = p_name,
        date_of_birth = p_date_of_birth,
        phone = p_phone,
        street = p_street,
        city = p_city,
        state = p_state,
        zipcode = p_zipcode,
        biological_sex = p_biological_sex,
        spe_id = v_spe_id
    where
        emp_id = p_employee_id;
end$$

CREATE DEFINER=`user`@`%` PROCEDURE `update_patient_information` (IN `p_patient_id` INT, IN `p_name` VARCHAR(32), IN `p_date_of_birth` DATE, IN `p_phone` CHAR(10), IN `p_street` VARCHAR(64), IN `p_city` VARCHAR(16), IN `p_state` CHAR(2), IN `p_zipcode` CHAR(5), IN `p_emergency_name` VARCHAR(32), IN `p_emergency_phone` CHAR(10), IN `p_biological_sex` ENUM('male','female'))   begin
    -- update the Patient record
    update Patient
    set
        name = p_name,
        date_of_birth = p_date_of_birth,
        phone = p_phone,
        street = p_street,
        city = p_city,
        state = p_state,
        zipcode = p_zipcode,
        emergency_name = p_emergency_name,
        emergency_phone = p_emergency_phone,
        biological_sex = p_biological_sex
    where
        patient_id = p_patient_id;
end$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `appointments`
--

CREATE TABLE `appointments` (
  `appointment_no` int(11) NOT NULL,
  `app_date` date NOT NULL,
  `app_time` time NOT NULL,
  `patient_id` int(11) DEFAULT NULL,
  `doctor_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `appointments`
--

INSERT INTO `appointments` (`appointment_no`, `app_date`, `app_time`, `patient_id`, `doctor_id`) VALUES
(1, '2024-11-14', '09:00:00', NULL, 1),
(2, '2024-11-05', '09:30:00', NULL, 1),
(3, '2024-11-05', '10:00:00', NULL, 1),
(4, '2024-11-05', '10:30:00', NULL, 1),
(5, '2024-11-05', '11:00:00', NULL, 1),
(6, '2024-11-05', '11:30:00', NULL, 1),
(7, '2024-11-05', '14:00:00', NULL, 1),
(8, '2024-11-05', '14:30:00', NULL, 1),
(9, '2024-11-05', '15:00:00', NULL, 1),
(10, '2024-11-05', '15:30:00', NULL, 1),
(11, '2024-11-05', '16:00:00', NULL, 1),
(12, '2024-11-05', '16:30:00', NULL, 1),
(13, '2024-11-05', '17:00:00', NULL, 1),
(14, '2024-11-06', '09:00:00', NULL, 1),
(15, '2024-11-06', '09:30:00', NULL, 1),
(16, '2024-11-06', '10:00:00', NULL, 1),
(17, '2024-11-06', '10:30:00', NULL, 1),
(18, '2024-11-06', '11:00:00', NULL, 1),
(19, '2023-12-06', '11:30:00', NULL, 1),
(20, '2023-12-06', '14:00:00', NULL, 1),
(21, '2023-12-06', '14:30:00', NULL, 1),
(22, '2023-12-06', '15:00:00', NULL, 1),
(23, '2023-12-06', '15:30:00', NULL, 1),
(24, '2023-12-06', '16:00:00', NULL, 1),
(25, '2023-12-06', '16:30:00', NULL, 1),
(26, '2023-12-06', '17:00:00', NULL, 1),
(27, '2023-12-07', '09:00:00', NULL, 1),
(28, '2023-12-07', '09:30:00', NULL, 1),
(29, '2023-12-07', '10:00:00', NULL, 1),
(30, '2023-12-07', '10:30:00', NULL, 1),
(31, '2023-12-07', '11:00:00', NULL, 1),
(32, '2023-12-07', '11:30:00', NULL, 1),
(33, '2023-12-07', '14:00:00', NULL, 1),
(34, '2023-12-07', '14:30:00', NULL, 1),
(35, '2023-12-07', '15:00:00', NULL, 1),
(36, '2023-12-07', '15:30:00', NULL, 1),
(37, '2023-12-07', '16:00:00', NULL, 1),
(38, '2023-12-07', '16:30:00', NULL, 1),
(39, '2023-12-07', '17:00:00', NULL, 1),
(40, '2023-12-08', '09:00:00', NULL, 1),
(41, '2023-12-08', '09:30:00', NULL, 1),
(42, '2023-12-08', '10:00:00', NULL, 1),
(43, '2023-12-08', '10:30:00', NULL, 1),
(44, '2023-12-08', '11:00:00', NULL, 1),
(45, '2023-12-08', '11:30:00', NULL, 1),
(46, '2023-12-08', '14:00:00', NULL, 1),
(47, '2023-12-08', '14:30:00', NULL, 1),
(48, '2023-12-08', '15:00:00', NULL, 1),
(49, '2023-12-08', '15:30:00', NULL, 1),
(50, '2023-12-08', '16:00:00', NULL, 1),
(51, '2023-12-08', '16:30:00', NULL, 1),
(52, '2023-12-08', '17:00:00', NULL, 1),
(53, '2023-12-11', '09:00:00', NULL, 1),
(54, '2023-12-11', '09:30:00', NULL, 1),
(55, '2023-12-11', '10:00:00', NULL, 1),
(56, '2023-12-11', '10:30:00', NULL, 1),
(57, '2023-12-11', '11:00:00', NULL, 1),
(58, '2023-12-11', '11:30:00', NULL, 1),
(59, '2023-12-11', '14:00:00', NULL, 1),
(60, '2023-12-11', '14:30:00', NULL, 1),
(61, '2023-12-11', '15:00:00', NULL, 1),
(62, '2023-12-11', '15:30:00', NULL, 1),
(63, '2023-12-11', '16:00:00', NULL, 1),
(64, '2023-12-11', '16:30:00', NULL, 1),
(65, '2023-12-11', '17:00:00', NULL, 1),
(66, '2023-12-12', '09:00:00', NULL, 1),
(67, '2023-12-12', '09:30:00', NULL, 1),
(68, '2023-12-12', '10:00:00', NULL, 1),
(69, '2023-12-12', '10:30:00', NULL, 1),
(70, '2023-12-12', '11:00:00', NULL, 1),
(71, '2023-12-12', '11:30:00', NULL, 1),
(72, '2023-12-12', '14:00:00', NULL, 1),
(73, '2023-12-12', '14:30:00', NULL, 1),
(74, '2023-12-12', '15:00:00', NULL, 1),
(75, '2023-12-12', '15:30:00', NULL, 1),
(76, '2023-12-12', '16:00:00', NULL, 1),
(77, '2023-12-12', '16:30:00', NULL, 1),
(78, '2023-12-12', '17:00:00', NULL, 1),
(79, '2023-12-13', '09:00:00', NULL, 1),
(80, '2023-12-13', '09:30:00', NULL, 1),
(81, '2023-12-13', '10:00:00', NULL, 1),
(82, '2023-12-13', '10:30:00', NULL, 1),
(83, '2023-12-13', '11:00:00', NULL, 1),
(84, '2023-12-13', '11:30:00', NULL, 1),
(85, '2023-12-13', '14:00:00', NULL, 1),
(86, '2023-12-13', '14:30:00', NULL, 1),
(87, '2023-12-13', '15:00:00', NULL, 1),
(88, '2023-12-13', '15:30:00', NULL, 1),
(89, '2023-12-13', '16:00:00', NULL, 1),
(90, '2023-12-13', '16:30:00', NULL, 1),
(91, '2023-12-13', '17:00:00', NULL, 1),
(92, '2023-12-14', '09:00:00', NULL, 1),
(93, '2023-12-14', '09:30:00', NULL, 1),
(94, '2023-12-14', '10:00:00', NULL, 1),
(95, '2023-12-14', '10:30:00', NULL, 1),
(96, '2023-12-14', '11:00:00', NULL, 1),
(97, '2023-12-14', '11:30:00', NULL, 1),
(98, '2023-12-14', '14:00:00', NULL, 1),
(99, '2023-12-14', '14:30:00', NULL, 1),
(100, '2023-12-14', '15:00:00', NULL, 1),
(101, '2023-12-14', '15:30:00', NULL, 1),
(102, '2023-12-14', '16:00:00', NULL, 1),
(103, '2023-12-14', '16:30:00', NULL, 1),
(104, '2023-12-14', '17:00:00', NULL, 1),
(105, '2023-12-15', '09:00:00', NULL, 1),
(106, '2023-12-15', '09:30:00', NULL, 1),
(107, '2023-12-15', '10:00:00', NULL, 1),
(108, '2023-12-15', '10:30:00', NULL, 1),
(109, '2023-12-15', '11:00:00', NULL, 1),
(110, '2023-12-15', '11:30:00', NULL, 1),
(111, '2023-12-15', '14:00:00', NULL, 1),
(112, '2023-12-15', '14:30:00', NULL, 1),
(113, '2023-12-15', '15:00:00', NULL, 1),
(114, '2023-12-15', '15:30:00', NULL, 1),
(115, '2023-12-15', '16:00:00', NULL, 1),
(116, '2023-12-15', '16:30:00', NULL, 1),
(117, '2023-12-15', '17:00:00', NULL, 1),
(118, '2023-12-05', '09:00:00', NULL, 1),
(119, '2023-12-05', '09:30:00', NULL, 1),
(120, '2023-12-05', '10:00:00', NULL, 1),
(121, '2023-12-05', '10:30:00', NULL, 1),
(122, '2023-12-05', '11:00:00', NULL, 1),
(123, '2023-12-05', '11:30:00', NULL, 1),
(124, '2023-12-05', '14:00:00', NULL, 1),
(125, '2023-12-05', '14:30:00', NULL, 1),
(126, '2023-12-05', '15:00:00', NULL, 1),
(127, '2023-12-05', '15:30:00', NULL, 1),
(128, '2023-12-05', '16:00:00', NULL, 1),
(129, '2023-12-05', '16:30:00', NULL, 1),
(130, '2023-12-05', '17:00:00', NULL, 1),
(131, '2023-12-05', '09:00:00', NULL, 3),
(132, '2023-12-05', '09:30:00', NULL, 3),
(133, '2023-12-05', '10:00:00', NULL, 3),
(134, '2023-12-05', '10:30:00', NULL, 3),
(135, '2023-12-05', '11:00:00', NULL, 3),
(136, '2023-12-05', '11:30:00', NULL, 3),
(137, '2023-12-05', '14:00:00', NULL, 3),
(138, '2023-12-05', '14:30:00', NULL, 3),
(139, '2023-12-05', '15:00:00', NULL, 3),
(140, '2023-12-05', '15:30:00', NULL, 3),
(141, '2023-12-05', '16:00:00', NULL, 3),
(142, '2023-12-05', '16:30:00', NULL, 3),
(143, '2023-12-05', '17:00:00', NULL, 3),
(144, '2023-12-06', '09:00:00', NULL, 1),
(145, '2023-12-06', '09:30:00', NULL, 1),
(146, '2023-12-06', '10:00:00', NULL, 1),
(147, '2023-12-06', '10:30:00', NULL, 1),
(148, '2023-12-06', '11:00:00', NULL, 1),
(149, '2023-12-06', '11:30:00', NULL, 1),
(150, '2023-12-06', '14:00:00', NULL, 1),
(151, '2023-12-06', '14:30:00', NULL, 1),
(152, '2023-12-06', '15:00:00', NULL, 1),
(153, '2023-12-06', '15:30:00', NULL, 1),
(154, '2023-12-06', '16:00:00', NULL, 1),
(155, '2023-12-06', '16:30:00', NULL, 1),
(156, '2023-12-06', '17:00:00', NULL, 1),
(157, '2023-12-06', '09:00:00', NULL, 3),
(158, '2023-12-06', '09:30:00', NULL, 3),
(159, '2023-12-06', '10:00:00', NULL, 3),
(160, '2023-12-06', '10:30:00', NULL, 3),
(161, '2023-12-06', '11:00:00', NULL, 3),
(162, '2023-12-06', '11:30:00', NULL, 3),
(163, '2023-12-06', '14:00:00', NULL, 3),
(164, '2023-12-06', '14:30:00', NULL, 3),
(165, '2023-12-06', '15:00:00', NULL, 3),
(166, '2023-12-06', '15:30:00', NULL, 3),
(167, '2023-12-06', '16:00:00', NULL, 3),
(168, '2023-12-06', '16:30:00', NULL, 3),
(169, '2023-12-06', '17:00:00', NULL, 3),
(170, '2023-12-07', '09:00:00', NULL, 1),
(171, '2023-12-07', '09:30:00', NULL, 1),
(172, '2023-12-07', '10:00:00', NULL, 1),
(173, '2023-12-07', '10:30:00', NULL, 1),
(174, '2023-12-07', '11:00:00', NULL, 1),
(175, '2023-12-07', '11:30:00', NULL, 1),
(176, '2023-12-07', '14:00:00', NULL, 1),
(177, '2023-12-07', '14:30:00', NULL, 1),
(178, '2023-12-07', '15:00:00', NULL, 1),
(179, '2023-12-07', '15:30:00', NULL, 1),
(180, '2023-12-07', '16:00:00', NULL, 1),
(181, '2023-12-07', '16:30:00', NULL, 1),
(182, '2023-12-07', '17:00:00', NULL, 1),
(183, '2023-12-07', '09:00:00', NULL, 3),
(184, '2023-12-07', '09:30:00', NULL, 3),
(185, '2023-12-07', '10:00:00', NULL, 3),
(186, '2023-12-07', '10:30:00', NULL, 3),
(187, '2023-12-07', '11:00:00', NULL, 3),
(188, '2023-12-07', '11:30:00', NULL, 3),
(189, '2023-12-07', '14:00:00', NULL, 3),
(190, '2023-12-07', '14:30:00', NULL, 3),
(191, '2023-12-07', '15:00:00', NULL, 3),
(192, '2023-12-07', '15:30:00', NULL, 3),
(193, '2023-12-07', '16:00:00', NULL, 3),
(194, '2023-12-07', '16:30:00', NULL, 3),
(195, '2023-12-07', '17:00:00', NULL, 3),
(196, '2023-12-08', '09:00:00', NULL, 1),
(197, '2023-12-08', '09:30:00', NULL, 1),
(198, '2023-12-08', '10:00:00', NULL, 1),
(199, '2023-12-08', '10:30:00', NULL, 1),
(200, '2023-12-08', '11:00:00', NULL, 1),
(201, '2023-12-08', '11:30:00', NULL, 1),
(202, '2023-12-08', '14:00:00', NULL, 1),
(203, '2023-12-08', '14:30:00', NULL, 1),
(204, '2023-12-08', '15:00:00', NULL, 1),
(205, '2023-12-08', '15:30:00', NULL, 1),
(206, '2023-12-08', '16:00:00', NULL, 1),
(207, '2023-12-08', '16:30:00', NULL, 1),
(208, '2023-12-08', '17:00:00', NULL, 1),
(209, '2023-12-08', '09:00:00', NULL, 3),
(210, '2023-12-08', '09:30:00', NULL, 3),
(211, '2023-12-08', '10:00:00', NULL, 3),
(212, '2023-12-08', '10:30:00', NULL, 3),
(213, '2023-12-08', '11:00:00', NULL, 3),
(214, '2023-12-08', '11:30:00', NULL, 3),
(215, '2023-12-08', '14:00:00', NULL, 3),
(216, '2023-12-08', '14:30:00', NULL, 3),
(217, '2023-12-08', '15:00:00', NULL, 3),
(218, '2023-12-08', '15:30:00', NULL, 3),
(219, '2023-12-08', '16:00:00', NULL, 3),
(220, '2023-12-08', '16:30:00', NULL, 3),
(221, '2023-12-08', '17:00:00', NULL, 3),
(222, '2023-12-11', '09:00:00', NULL, 1),
(223, '2023-12-11', '09:30:00', NULL, 1),
(224, '2023-12-11', '10:00:00', NULL, 1),
(225, '2023-12-11', '10:30:00', NULL, 1),
(226, '2023-12-11', '11:00:00', NULL, 1),
(227, '2023-12-11', '11:30:00', NULL, 1),
(228, '2023-12-11', '14:00:00', NULL, 1),
(229, '2023-12-11', '14:30:00', NULL, 1),
(230, '2023-12-11', '15:00:00', NULL, 1),
(231, '2023-12-11', '15:30:00', NULL, 1),
(232, '2023-12-11', '16:00:00', NULL, 1),
(233, '2023-12-11', '16:30:00', NULL, 1),
(234, '2023-12-11', '17:00:00', NULL, 1),
(235, '2023-12-11', '09:00:00', NULL, 3),
(236, '2023-12-11', '09:30:00', NULL, 3),
(237, '2023-12-11', '10:00:00', NULL, 3),
(238, '2023-12-11', '10:30:00', NULL, 3),
(239, '2023-12-11', '11:00:00', NULL, 3),
(240, '2023-12-11', '11:30:00', NULL, 3),
(241, '2023-12-11', '14:00:00', NULL, 3),
(242, '2023-12-11', '14:30:00', NULL, 3),
(243, '2023-12-11', '15:00:00', NULL, 3),
(244, '2023-12-11', '15:30:00', NULL, 3),
(245, '2023-12-11', '16:00:00', NULL, 3),
(246, '2023-12-11', '16:30:00', NULL, 3),
(247, '2023-12-11', '17:00:00', NULL, 3),
(248, '2023-12-12', '09:00:00', NULL, 1),
(249, '2023-12-12', '09:30:00', NULL, 1),
(250, '2023-12-12', '10:00:00', NULL, 1),
(251, '2023-12-12', '10:30:00', NULL, 1),
(252, '2023-12-12', '11:00:00', NULL, 1),
(253, '2023-12-12', '11:30:00', NULL, 1),
(254, '2023-12-12', '14:00:00', NULL, 1),
(255, '2023-12-12', '14:30:00', NULL, 1),
(256, '2023-12-12', '15:00:00', NULL, 1),
(257, '2023-12-12', '15:30:00', NULL, 1),
(258, '2023-12-12', '16:00:00', NULL, 1),
(259, '2023-12-12', '16:30:00', NULL, 1),
(260, '2023-12-12', '17:00:00', NULL, 1),
(261, '2023-12-12', '09:00:00', NULL, 3),
(262, '2023-12-12', '09:30:00', NULL, 3),
(263, '2023-12-12', '10:00:00', NULL, 3),
(264, '2023-12-12', '10:30:00', NULL, 3),
(265, '2023-12-12', '11:00:00', NULL, 3),
(266, '2023-12-12', '11:30:00', NULL, 3),
(267, '2023-12-12', '14:00:00', NULL, 3),
(268, '2023-12-12', '14:30:00', NULL, 3),
(269, '2023-12-12', '15:00:00', NULL, 3),
(270, '2023-12-12', '15:30:00', NULL, 3),
(271, '2023-12-12', '16:00:00', NULL, 3),
(272, '2023-12-12', '16:30:00', NULL, 3),
(273, '2023-12-12', '17:00:00', NULL, 3),
(274, '2023-12-13', '09:00:00', NULL, 1),
(275, '2023-12-13', '09:30:00', NULL, 1),
(276, '2023-12-13', '10:00:00', NULL, 1),
(277, '2023-12-13', '10:30:00', NULL, 1),
(278, '2023-12-13', '11:00:00', NULL, 1),
(279, '2023-12-13', '11:30:00', NULL, 1),
(280, '2023-12-13', '14:00:00', NULL, 1),
(281, '2023-12-13', '14:30:00', NULL, 1),
(282, '2023-12-13', '15:00:00', NULL, 1),
(283, '2023-12-13', '15:30:00', NULL, 1),
(284, '2023-12-13', '16:00:00', NULL, 1),
(285, '2023-12-13', '16:30:00', NULL, 1),
(286, '2023-12-13', '17:00:00', NULL, 1),
(287, '2023-12-13', '09:00:00', NULL, 3),
(288, '2023-12-13', '09:30:00', NULL, 3),
(289, '2023-12-13', '10:00:00', NULL, 3),
(290, '2023-12-13', '10:30:00', NULL, 3),
(291, '2023-12-13', '11:00:00', NULL, 3),
(292, '2023-12-13', '11:30:00', NULL, 3),
(293, '2023-12-13', '14:00:00', NULL, 3),
(294, '2023-12-13', '14:30:00', NULL, 3),
(295, '2023-12-13', '15:00:00', NULL, 3),
(296, '2023-12-13', '15:30:00', NULL, 3),
(297, '2023-12-13', '16:00:00', NULL, 3),
(298, '2023-12-13', '16:30:00', NULL, 3),
(299, '2023-12-13', '17:00:00', NULL, 3),
(300, '2023-12-14', '09:00:00', NULL, 1),
(301, '2023-12-14', '09:30:00', NULL, 1),
(302, '2023-12-14', '10:00:00', NULL, 1),
(303, '2023-12-14', '10:30:00', NULL, 1),
(304, '2023-12-14', '11:00:00', NULL, 1),
(305, '2023-12-14', '11:30:00', NULL, 1),
(306, '2023-12-14', '14:00:00', NULL, 1),
(307, '2023-12-14', '14:30:00', NULL, 1),
(308, '2023-12-14', '15:00:00', NULL, 1),
(309, '2023-12-14', '15:30:00', NULL, 1),
(310, '2023-12-14', '16:00:00', NULL, 1),
(311, '2023-12-14', '16:30:00', NULL, 1),
(312, '2023-12-14', '17:00:00', NULL, 1),
(313, '2023-12-14', '09:00:00', NULL, 3),
(314, '2023-12-14', '09:30:00', NULL, 3),
(315, '2023-12-14', '10:00:00', NULL, 3),
(316, '2023-12-14', '10:30:00', NULL, 3),
(317, '2023-12-14', '11:00:00', NULL, 3),
(318, '2023-12-14', '11:30:00', NULL, 3),
(319, '2023-12-14', '14:00:00', NULL, 3),
(320, '2023-12-14', '14:30:00', NULL, 3),
(321, '2023-12-14', '15:00:00', NULL, 3),
(322, '2023-12-14', '15:30:00', NULL, 3),
(323, '2023-12-14', '16:00:00', NULL, 3),
(324, '2023-12-14', '16:30:00', NULL, 3),
(325, '2023-12-14', '17:00:00', NULL, 3),
(326, '2023-12-15', '09:00:00', NULL, 1),
(327, '2023-12-15', '09:30:00', NULL, 1),
(328, '2023-12-15', '10:00:00', NULL, 1),
(329, '2023-12-15', '10:30:00', NULL, 1),
(330, '2023-12-15', '11:00:00', NULL, 1),
(331, '2023-12-15', '11:30:00', NULL, 1),
(332, '2023-12-15', '14:00:00', NULL, 1),
(333, '2023-12-15', '14:30:00', NULL, 1),
(334, '2023-12-15', '15:00:00', NULL, 1),
(335, '2023-12-15', '15:30:00', NULL, 1),
(336, '2023-12-15', '16:00:00', NULL, 1),
(337, '2023-12-15', '16:30:00', NULL, 1),
(338, '2023-12-15', '17:00:00', NULL, 1),
(339, '2023-12-15', '09:00:00', NULL, 3),
(340, '2023-12-15', '09:30:00', NULL, 3),
(341, '2023-12-15', '10:00:00', NULL, 3),
(342, '2023-12-15', '10:30:00', NULL, 3),
(343, '2023-12-15', '11:00:00', NULL, 3),
(344, '2023-12-15', '11:30:00', NULL, 3),
(345, '2023-12-15', '14:00:00', NULL, 3),
(346, '2023-12-15', '14:30:00', NULL, 3),
(347, '2023-12-15', '15:00:00', NULL, 3),
(348, '2023-12-15', '15:30:00', NULL, 3),
(349, '2023-12-15', '16:00:00', NULL, 3),
(350, '2023-12-15', '16:30:00', 2, 3),
(351, '2023-12-15', '17:00:00', 2, 3);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `billing`
--

CREATE TABLE `billing` (
  `bill_no` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(16) NOT NULL,
  `created_date` date NOT NULL,
  `payment_date` date DEFAULT NULL,
  `pay_card` int(11) DEFAULT NULL,
  `patient_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `billing`
--

INSERT INTO `billing` (`bill_no`, `amount`, `status`, `created_date`, `payment_date`, `pay_card`, `patient_id`) VALUES
(1, 25.00, 'paid', '2023-01-15', '2023-11-20', 1, 1),
(2, 25.00, 'unpaid', '2023-02-10', '2023-11-15', 2, 2),
(3, 25.00, 'unpaid', '2023-12-07', NULL, NULL, 1),
(4, 25.00, 'paid', '2023-01-15', '2023-11-20', 1, 1),
(5, 25.00, 'unpaid', '2023-02-10', '2023-11-15', 2, 2);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `credit_card`
--

CREATE TABLE `credit_card` (
  `card_id` int(11) NOT NULL,
  `card_num` char(16) NOT NULL,
  `card_holer_name` varchar(64) NOT NULL,
  `expiration_time` date NOT NULL,
  `card_type` enum('visa','master') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `credit_card`
--

INSERT INTO `credit_card` (`card_id`, `card_num`, `card_holer_name`, `expiration_time`, `card_type`) VALUES
(1, '1234567812345678', 'John Doe', '2025-12-31', 'visa'),
(2, '8765432187654321', 'Jane Doe', '2024-11-30', 'master'),
(3, '1234567812345678', 'John Doe', '2025-12-31', 'visa'),
(4, '8765432187654321', 'Jane Doe', '2024-11-30', 'master');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `diagnosis`
--

CREATE TABLE `diagnosis` (
  `medical_records_no` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `dis_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `diagnosis`
--

INSERT INTO `diagnosis` (`medical_records_no`, `patient_id`, `dis_id`) VALUES
(1, 1, 1),
(1, 1, 4);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `disease`
--

CREATE TABLE `disease` (
  `dis_id` int(11) NOT NULL,
  `dis_name` varchar(32) NOT NULL,
  `dis_descirption` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `disease`
--

INSERT INTO `disease` (`dis_id`, `dis_name`, `dis_descirption`) VALUES
(1, 'Common Cold', 'A common viral respiratory infection, symptoms include cough, sore throat, runny nose, and fever.'),
(2, 'Influenza', 'A respiratory infection affecting the nose, throat, and lungs, symptoms usually include fever, chills, and muscle ache.'),
(3, 'Hypertension', 'A long-term condition where the blood pressure in the arteries is persistently elevated, potentially leading to heart diseases and stroke.'),
(4, 'Diabetes', 'A chronic disease affecting how the body processes blood sugar, common types include Type 1 and Type 2.'),
(5, 'Asthma', 'A chronic disease affecting the lungs, causing breathing difficulties, chest tightness, and coughing.'),
(6, 'Allergies', 'An overreaction of the immune system to certain substances, common allergens include pollen, dust mites, and certain foods.'),
(7, 'Arthritis', 'Inflammation of the joints, causing joint pain, swelling, and stiffness.'),
(8, 'Skin Infection', 'Skin issues caused by bacteria, fungi, or viruses, manifested as redness, itching, or rash.'),
(9, 'Common Cold', 'A common viral respiratory infection, symptoms include cough, sore throat, runny nose, and fever.'),
(10, 'Influenza', 'A respiratory infection affecting the nose, throat, and lungs, symptoms usually include fever, chills, and muscle ache.'),
(11, 'Hypertension', 'A long-term condition where the blood pressure in the arteries is persistently elevated, potentially leading to heart diseases and stroke.'),
(12, 'Diabetes', 'A chronic disease affecting how the body processes blood sugar, common types include Type 1 and Type 2.'),
(13, 'Asthma', 'A chronic disease affecting the lungs, causing breathing difficulties, chest tightness, and coughing.'),
(14, 'Allergies', 'An overreaction of the immune system to certain substances, common allergens include pollen, dust mites, and certain foods.'),
(15, 'Arthritis', 'Inflammation of the joints, causing joint pain, swelling, and stiffness.'),
(16, 'Skin Infection', 'Skin issues caused by bacteria, fungi, or viruses, manifested as redness, itching, or rash.');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `DoctorNursePair`
--

CREATE TABLE `DoctorNursePair` (
  `doctor_id` int(11) NOT NULL,
  `nurse_id` int(11) DEFAULT NULL,
  `pair_time` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `DoctorNursePair`
--

INSERT INTO `DoctorNursePair` (`doctor_id`, `nurse_id`, `pair_time`) VALUES
(1, 2, '2024-11-14 03:27:07');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `Employee`
--

CREATE TABLE `Employee` (
  `emp_id` int(11) NOT NULL,
  `name` varchar(64) NOT NULL,
  `date_of_birth` date NOT NULL,
  `phone` char(10) NOT NULL,
  `street` varchar(64) NOT NULL,
  `city` varchar(16) NOT NULL,
  `state` char(2) NOT NULL,
  `zipcode` char(5) NOT NULL,
  `start_date` date NOT NULL,
  `status` enum('active','invalid') DEFAULT 'active',
  `is_doctor` tinyint(1) DEFAULT 0,
  `is_nurse` tinyint(1) DEFAULT 0,
  `biological_sex` enum('male','female') NOT NULL,
  `spe_id` int(11) DEFAULT NULL,
  `username` varchar(32) DEFAULT NULL
) ;

--
-- Volcado de datos para la tabla `Employee`
--

INSERT INTO `Employee` (`emp_id`, `name`, `date_of_birth`, `phone`, `street`, `city`, `state`, `zipcode`, `start_date`, `status`, `is_doctor`, `is_nurse`, `biological_sex`, `spe_id`, `username`) VALUES
(1, 'Dr. Alice Smith', '1980-04-15', '1234567890', '123 Main St', 'Medville', 'CA', '90210', '2023-11-01', 'active', 1, 0, 'female', 1, 'drsmith'),
(2, 'Nurse Bob Johnson', '1985-08-20', '2345678901', '456 Side Rd', 'Nursville', 'TX', '75001', '2023-11-01', 'active', 0, 1, 'male', 1, 'nursejones'),
(3, 'Dr. Alice Smith', '1980-04-15', '1234567890', '123 Main St', 'Medville', 'CA', '90210', '2023-11-01', 'active', 1, 0, 'female', 1, 'drsmith'),
(4, 'Nurse Bob Johnson', '1985-08-20', '2345678901', '456 Side Rd', 'Nursville', 'TX', '75001', '2023-11-01', 'active', 0, 1, 'male', 1, 'nursejones'),
(5, 'Dr. Alice Smith', '1980-04-15', '1234567890', '123 Main St', 'Medville', 'CA', '90210', '2023-11-01', 'active', 1, 0, 'female', 1, 'drsmith'),
(6, 'Nurse Bob Johnson', '1985-08-20', '2345678901', '456 Side Rd', 'Nursville', 'TX', '75001', '2023-11-01', 'active', 0, 1, 'male', 1, 'nursejones');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `MedicalRecords`
--

CREATE TABLE `MedicalRecords` (
  `medical_records_no` int(11) NOT NULL,
  `record_date` date NOT NULL,
  `patient_id` int(11) NOT NULL,
  `doctor_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `MedicalRecords`
--

INSERT INTO `MedicalRecords` (`medical_records_no`, `record_date`, `patient_id`, `doctor_id`) VALUES
(1, '2023-11-15', 1, 1),
(2, '2023-11-15', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `medication`
--

CREATE TABLE `medication` (
  `medication_id` int(11) NOT NULL,
  `medication_name` varchar(32) NOT NULL,
  `medication_description` varchar(256) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `medication`
--

INSERT INTO `medication` (`medication_id`, `medication_name`, `medication_description`) VALUES
(1, 'Acetaminophen', 'A pain reliever and a fever reducer, used to treat mild to moderate pain and to reduce fever.'),
(2, 'Ibuprofen', 'A nonsteroidal anti-inflammatory drug (NSAID), used to reduce fever and treat pain or inflammation.'),
(3, 'Amoxicillin', 'An antibiotic used to treat a wide variety of bacterial infections.'),
(4, 'Metformin', 'An oral diabetes medicine that helps control blood sugar levels.'),
(5, 'Amlodipine', 'Used to treat high blood pressure (hypertension) and to prevent chest pain (angina).'),
(6, 'Simvastatin', 'Used to lower cholesterol and triglycerides (types of fat) in the blood.'),
(7, 'Omeprazole', 'Used to treat certain stomach and esophagus problems (such as acid reflux, ulcers).'),
(8, 'Cetirizine', 'An antihistamine used to relieve allergy symptoms such as watery eyes, runny nose, itching eyes/nose, and sneezing.'),
(9, 'Acetaminophen', 'A pain reliever and a fever reducer, used to treat mild to moderate pain and to reduce fever.'),
(10, 'Ibuprofen', 'A nonsteroidal anti-inflammatory drug (NSAID), used to reduce fever and treat pain or inflammation.'),
(11, 'Amoxicillin', 'An antibiotic used to treat a wide variety of bacterial infections.'),
(12, 'Metformin', 'An oral diabetes medicine that helps control blood sugar levels.'),
(13, 'Amlodipine', 'Used to treat high blood pressure (hypertension) and to prevent chest pain (angina).'),
(14, 'Simvastatin', 'Used to lower cholesterol and triglycerides (types of fat) in the blood.'),
(15, 'Omeprazole', 'Used to treat certain stomach and esophagus problems (such as acid reflux, ulcers).'),
(16, 'Cetirizine', 'An antihistamine used to relieve allergy symptoms such as watery eyes, runny nose, itching eyes/nose, and sneezing.');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `Patient`
--

CREATE TABLE `Patient` (
  `patient_id` int(11) NOT NULL,
  `name` varchar(32) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `phone` char(10) DEFAULT NULL,
  `street` varchar(64) DEFAULT NULL,
  `city` varchar(16) DEFAULT NULL,
  `state` char(2) DEFAULT NULL,
  `zipcode` char(5) DEFAULT NULL,
  `emergency_name` varchar(32) DEFAULT NULL,
  `emergency_phone` char(10) DEFAULT NULL,
  `username` varchar(32) NOT NULL,
  `biological_sex` enum('male','female') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `Patient`
--

INSERT INTO `Patient` (`patient_id`, `name`, `date_of_birth`, `phone`, `street`, `city`, `state`, `zipcode`, `emergency_name`, `emergency_phone`, `username`, `biological_sex`) VALUES
(1, 'John Doe', '1990-01-01', '3456789012', '789 Circle Ave', 'Patienttown', 'NY', '10001', 'Jane Doe', '4567890123', 'johndoe', 'male'),
(2, 'Jane Doe', '1992-02-02', '4567890123', '321 Square Blvd', 'Healthcity', 'FL', '33101', 'John Doe', '3456789012', 'janedoe', 'female'),
(3, 'John Doe', '1990-01-01', '3456789012', '789 Circle Ave', 'Patienttown', 'NY', '10001', 'Jane Doe', '4567890123', 'johndoe', 'male'),
(4, 'Jane Doe', '1992-02-02', '4567890123', '321 Square Blvd', 'Healthcity', 'FL', '33101', 'John Doe', '3456789012', 'janedoe', 'female');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `prescription`
--

CREATE TABLE `prescription` (
  `medical_records_no` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `medication_id` int(11) NOT NULL,
  `dosage` varchar(100) DEFAULT NULL,
  `frequency` varchar(50) DEFAULT NULL,
  `duration` int(11) DEFAULT NULL
) ;

--
-- Volcado de datos para la tabla `prescription`
--

INSERT INTO `prescription` (`medical_records_no`, `patient_id`, `medication_id`, `dosage`, `frequency`, `duration`) VALUES
(1, 1, 1, '1 tablet', 'three times per day', 3);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `specialty`
--

CREATE TABLE `specialty` (
  `spe_id` int(11) NOT NULL,
  `spe_name` varchar(32) NOT NULL,
  `spe_discription` varchar(256) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `specialty`
--

INSERT INTO `specialty` (`spe_id`, `spe_name`, `spe_discription`) VALUES
(1, 'General Medicine', 'Provides primary healthcare services including diagnosis, treatment, and prevention of common illnesses and injuries.'),
(2, 'Pediatrics', 'Specializes in the medical care of infants, children, and adolescents.'),
(3, 'Cardiology', 'Focuses on diagnosing and treating diseases of the heart and blood vessels.'),
(4, 'Dermatology', 'Concerned with the diagnosis and treatment of skin disorders.'),
(5, 'Orthopedics', 'Specializes in the prevention, diagnosis, and treatment of disorders of the bones, joints, ligaments, tendons and muscles.'),
(6, 'Neurology', 'Deals with disorders of the nervous system including the brain and spinal cord.'),
(7, 'Gynecology', 'Focuses on women reproductive health and childbirth.'),
(8, 'Psychiatry', 'Specializes in the diagnosis, treatment, and prevention of mental illnesses and disorders.'),
(9, 'General Medicine', 'Provides primary healthcare services including diagnosis, treatment, and prevention of common illnesses and injuries.'),
(10, 'Pediatrics', 'Specializes in the medical care of infants, children, and adolescents.'),
(11, 'Cardiology', 'Focuses on diagnosing and treating diseases of the heart and blood vessels.'),
(12, 'Dermatology', 'Concerned with the diagnosis and treatment of skin disorders.'),
(13, 'Orthopedics', 'Specializes in the prevention, diagnosis, and treatment of disorders of the bones, joints, ligaments, tendons and muscles.'),
(14, 'Neurology', 'Deals with disorders of the nervous system including the brain and spinal cord.'),
(15, 'Gynecology', 'Focuses on women reproductive health and childbirth.'),
(16, 'Psychiatry', 'Specializes in the diagnosis, treatment, and prevention of mental illnesses and disorders.'),
(17, 'General Medicine', 'Provides primary healthcare services including diagnosis, treatment, and prevention of common illnesses and injuries.'),
(18, 'Pediatrics', 'Specializes in the medical care of infants, children, and adolescents.'),
(19, 'Cardiology', 'Focuses on diagnosing and treating diseases of the heart and blood vessels.'),
(20, 'Dermatology', 'Concerned with the diagnosis and treatment of skin disorders.'),
(21, 'Orthopedics', 'Specializes in the prevention, diagnosis, and treatment of disorders of the bones, joints, ligaments, tendons and muscles.'),
(22, 'Neurology', 'Deals with disorders of the nervous system including the brain and spinal cord.'),
(23, 'Gynecology', 'Focuses on women reproductive health and childbirth.'),
(24, 'Psychiatry', 'Specializes in the diagnosis, treatment, and prevention of mental illnesses and disorders.');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `User`
--

CREATE TABLE `User` (
  `username` varchar(32) NOT NULL,
  `password` varchar(32) NOT NULL,
  `role` enum('patient','employee','manager') NOT NULL,
  `email` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `User`
--

INSERT INTO `User` (`username`, `password`, `role`, `email`) VALUES
('adminuser', 'adminpass', 'manager', 'admin@example.com'),
('drsmith', 'password123', 'employee', 'drsmith@example.com'),
('janedoe', 'password123', 'patient', 'janedoe@example.com'),
('johndoe', 'password123', 'patient', 'johndoe@example.com'),
('nursejones', 'password123', 'employee', 'nursejones@example.com');

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `appointments`
--
ALTER TABLE `appointments`
  ADD UNIQUE KEY `appointment_no` (`appointment_no`,`doctor_id`),
  ADD KEY `patient_id` (`patient_id`),
  ADD KEY `doctor_id` (`doctor_id`);

--
-- Indices de la tabla `billing`
--
ALTER TABLE `billing`
  ADD UNIQUE KEY `bill_no` (`bill_no`,`patient_id`),
  ADD KEY `pay_card` (`pay_card`),
  ADD KEY `patient_id` (`patient_id`);

--
-- Indices de la tabla `credit_card`
--
ALTER TABLE `credit_card`
  ADD PRIMARY KEY (`card_id`);

--
-- Indices de la tabla `diagnosis`
--
ALTER TABLE `diagnosis`
  ADD UNIQUE KEY `medical_records_no` (`medical_records_no`,`dis_id`,`patient_id`),
  ADD KEY `medical_records_no_2` (`medical_records_no`,`patient_id`),
  ADD KEY `dis_id` (`dis_id`);

--
-- Indices de la tabla `disease`
--
ALTER TABLE `disease`
  ADD PRIMARY KEY (`dis_id`);

--
-- Indices de la tabla `DoctorNursePair`
--
ALTER TABLE `DoctorNursePair`
  ADD UNIQUE KEY `doctor_id` (`doctor_id`,`nurse_id`),
  ADD KEY `nurse_id` (`nurse_id`);

--
-- Indices de la tabla `Employee`
--
ALTER TABLE `Employee`
  ADD PRIMARY KEY (`emp_id`),
  ADD KEY `spe_id` (`spe_id`),
  ADD KEY `username` (`username`);

--
-- Indices de la tabla `MedicalRecords`
--
ALTER TABLE `MedicalRecords`
  ADD UNIQUE KEY `medical_records_no` (`medical_records_no`,`patient_id`),
  ADD KEY `patient_id` (`patient_id`),
  ADD KEY `doctor_id` (`doctor_id`);

--
-- Indices de la tabla `medication`
--
ALTER TABLE `medication`
  ADD PRIMARY KEY (`medication_id`);

--
-- Indices de la tabla `Patient`
--
ALTER TABLE `Patient`
  ADD PRIMARY KEY (`patient_id`),
  ADD KEY `username` (`username`);

--
-- Indices de la tabla `prescription`
--
ALTER TABLE `prescription`
  ADD UNIQUE KEY `medical_records_no` (`medical_records_no`,`medication_id`,`patient_id`),
  ADD KEY `medication_id` (`medication_id`),
  ADD KEY `medical_records_no_2` (`medical_records_no`,`patient_id`);

--
-- Indices de la tabla `specialty`
--
ALTER TABLE `specialty`
  ADD PRIMARY KEY (`spe_id`);

--
-- Indices de la tabla `User`
--
ALTER TABLE `User`
  ADD PRIMARY KEY (`username`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `appointments`
--
ALTER TABLE `appointments`
  MODIFY `appointment_no` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=352;

--
-- AUTO_INCREMENT de la tabla `billing`
--
ALTER TABLE `billing`
  MODIFY `bill_no` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `credit_card`
--
ALTER TABLE `credit_card`
  MODIFY `card_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `disease`
--
ALTER TABLE `disease`
  MODIFY `dis_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT de la tabla `Employee`
--
ALTER TABLE `Employee`
  MODIFY `emp_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `MedicalRecords`
--
ALTER TABLE `MedicalRecords`
  MODIFY `medical_records_no` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `medication`
--
ALTER TABLE `medication`
  MODIFY `medication_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT de la tabla `Patient`
--
ALTER TABLE `Patient`
  MODIFY `patient_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `specialty`
--
ALTER TABLE `specialty`
  MODIFY `spe_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `appointments`
--
ALTER TABLE `appointments`
  ADD CONSTRAINT `appointments_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `Patient` (`patient_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `appointments_ibfk_2` FOREIGN KEY (`doctor_id`) REFERENCES `Employee` (`emp_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `billing`
--
ALTER TABLE `billing`
  ADD CONSTRAINT `billing_ibfk_1` FOREIGN KEY (`pay_card`) REFERENCES `credit_card` (`card_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `billing_ibfk_2` FOREIGN KEY (`patient_id`) REFERENCES `Patient` (`patient_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `diagnosis`
--
ALTER TABLE `diagnosis`
  ADD CONSTRAINT `diagnosis_ibfk_1` FOREIGN KEY (`medical_records_no`,`patient_id`) REFERENCES `MedicalRecords` (`medical_records_no`, `patient_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `diagnosis_ibfk_2` FOREIGN KEY (`dis_id`) REFERENCES `disease` (`dis_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `DoctorNursePair`
--
ALTER TABLE `DoctorNursePair`
  ADD CONSTRAINT `doctornursepair_ibfk_1` FOREIGN KEY (`doctor_id`) REFERENCES `Employee` (`emp_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `doctornursepair_ibfk_2` FOREIGN KEY (`nurse_id`) REFERENCES `Employee` (`emp_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `Employee`
--
ALTER TABLE `Employee`
  ADD CONSTRAINT `employee_ibfk_1` FOREIGN KEY (`spe_id`) REFERENCES `specialty` (`spe_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `employee_ibfk_2` FOREIGN KEY (`username`) REFERENCES `User` (`username`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `MedicalRecords`
--
ALTER TABLE `MedicalRecords`
  ADD CONSTRAINT `medicalrecords_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `Patient` (`patient_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `medicalrecords_ibfk_2` FOREIGN KEY (`doctor_id`) REFERENCES `Employee` (`emp_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `Patient`
--
ALTER TABLE `Patient`
  ADD CONSTRAINT `patient_ibfk_1` FOREIGN KEY (`username`) REFERENCES `User` (`username`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `prescription`
--
ALTER TABLE `prescription`
  ADD CONSTRAINT `prescription_ibfk_1` FOREIGN KEY (`medication_id`) REFERENCES `medication` (`medication_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `prescription_ibfk_2` FOREIGN KEY (`medical_records_no`,`patient_id`) REFERENCES `MedicalRecords` (`medical_records_no`, `patient_id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
