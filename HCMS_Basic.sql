/* ============================
   CLINIC DB — FULL CLEAN SETUP
   Tested on MySQL 8.x (Windows)
   ============================ */

-- Start fresh
DROP DATABASE IF EXISTS clinic_db;
CREATE DATABASE clinic_db;
USE clinic_db;

-- Optional: stricter errors on bad inserts
SET SESSION sql_mode = 'STRICT_ALL_TABLES';

-- =========================
-- Tables (safe constraints)
-- =========================

-- Patients (DOB rule via triggers, not CHECK)
CREATE TABLE patients (
  patient_id   INT AUTO_INCREMENT PRIMARY KEY,
  first_name   VARCHAR(50) NOT NULL,
  last_name    VARCHAR(50) NOT NULL,
  dob          DATE NOT NULL,
  sex          ENUM('F','M','O') NOT NULL,
  phone        VARCHAR(15) UNIQUE,
  email        VARCHAR(100) UNIQUE,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Doctors
CREATE TABLE doctors (
  doctor_id      INT AUTO_INCREMENT PRIMARY KEY,
  first_name     VARCHAR(50) NOT NULL,
  last_name      VARCHAR(50) NOT NULL,
  specialization VARCHAR(100) NOT NULL,
  phone          VARCHAR(15) UNIQUE,
  email          VARCHAR(100) UNIQUE
) ENGINE=InnoDB;

-- Rooms
CREATE TABLE rooms (
  room_id   INT AUTO_INCREMENT PRIMARY KEY,
  room_name VARCHAR(50) UNIQUE NOT NULL
) ENGINE=InnoDB;

-- Appointments
CREATE TABLE appointments (
  appt_id    INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id  INT NOT NULL,
  room_id    INT NOT NULL,
  appt_date  DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time   TIME NOT NULL,
  status     ENUM('SCHEDULED','COMPLETED','CANCELLED') DEFAULT 'SCHEDULED',
  notes      VARCHAR(255),
  CONSTRAINT fk_appt_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
  CONSTRAINT fk_appt_doctor  FOREIGN KEY (doctor_id)  REFERENCES doctors(doctor_id) ON DELETE CASCADE,
  CONSTRAINT fk_appt_room    FOREIGN KEY (room_id)    REFERENCES rooms(room_id),
  CONSTRAINT chk_time_order CHECK (start_time < end_time)
) ENGINE=InnoDB;

-- Medications
CREATE TABLE medications (
  med_id     INT AUTO_INCREMENT PRIMARY KEY,
  med_name   VARCHAR(100) UNIQUE NOT NULL,
  stock_qty  INT NOT NULL DEFAULT 0,
  unit_price DECIMAL(10,2) NOT NULL,
  CONSTRAINT chk_stock_nonneg CHECK (stock_qty >= 0),
  CONSTRAINT chk_price_nonneg CHECK (unit_price >= 0)
) ENGINE=InnoDB;

-- Visits (1:1 with completed appointment)
CREATE TABLE visits (
  visit_id   INT AUTO_INCREMENT PRIMARY KEY,
  appt_id    INT NOT NULL UNIQUE,
  diagnosis  VARCHAR(255),
  visit_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_visit_appt FOREIGN KEY (appt_id) REFERENCES appointments(appt_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Prescriptions (per visit)
CREATE TABLE prescriptions (
  prescription_id INT AUTO_INCREMENT PRIMARY KEY,
  visit_id        INT NOT NULL,
  med_id          INT NOT NULL,
  quantity        INT NOT NULL,
  dosage          VARCHAR(100),
  CONSTRAINT fk_presc_visit FOREIGN KEY (visit_id) REFERENCES visits(visit_id) ON DELETE CASCADE,
  CONSTRAINT fk_presc_med   FOREIGN KEY (med_id)   REFERENCES medications(med_id),
  CONSTRAINT chk_qty_pos    CHECK (quantity > 0)
) ENGINE=InnoDB;

-- Invoices (1:1 with visit)
CREATE TABLE invoices (
  invoice_id   INT AUTO_INCREMENT PRIMARY KEY,
  visit_id     INT NOT NULL UNIQUE,
  subtotal     DECIMAL(10,2) NOT NULL DEFAULT 0,
  tax          DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  paid         TINYINT(1) NOT NULL DEFAULT 0,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_inv_visit FOREIGN KEY (visit_id) REFERENCES visits(visit_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Payments
CREATE TABLE payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id INT NOT NULL,
  amount     DECIMAL(10,2) NOT NULL,
  paid_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  method     ENUM('CASH','CARD','UPI') NOT NULL,
  CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id) ON DELETE CASCADE,
  CONSTRAINT chk_amt_pos CHECK (amount > 0)
) ENGINE=InnoDB;

-- Optional: Users (for a login demo later)
CREATE TABLE app_users (
  user_id       INT AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('ADMIN','STAFF','DOCTOR') NOT NULL DEFAULT 'STAFF'
) ENGINE=InnoDB;

-- ==============================
-- Triggers (safe, MySQL-legal)
-- ==============================
DELIMITER $$

-- Clean re-create helpers
DROP TRIGGER IF EXISTS trg_patients_dob_check_bi $$
DROP TRIGGER IF EXISTS trg_patients_dob_check_bu $$
DROP TRIGGER IF EXISTS trg_no_overlap_before_insert $$
DROP TRIGGER IF EXISTS trg_prescription_after_insert $$
DROP TRIGGER IF EXISTS trg_payment_after_insert $$

/* Enforce: patients.dob <= CURRENT_DATE (no CURDATE() in CHECK) */
CREATE TRIGGER trg_patients_dob_check_bi
BEFORE INSERT ON patients
FOR EACH ROW
BEGIN
  IF NEW.dob > CURRENT_DATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'DOB cannot be in the future';
  END IF;
END $$

CREATE TRIGGER trg_patients_dob_check_bu
BEFORE UPDATE ON patients
FOR EACH ROW
BEGIN
  IF NEW.dob > CURRENT_DATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'DOB cannot be in the future';
  END IF;
END $$

/* Prevent overlapping appointments for same doctor or room */
CREATE TRIGGER trg_no_overlap_before_insert
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
  IF NEW.start_time >= NEW.end_time THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Start time must be before end time';
  END IF;

  IF EXISTS (
      SELECT 1 FROM appointments a
      WHERE a.doctor_id = NEW.doctor_id
        AND a.appt_date = NEW.appt_date
        AND a.status = 'SCHEDULED'
        AND (NEW.start_time < a.end_time AND NEW.end_time > a.start_time)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor overlap (trigger)';
  END IF;

  IF EXISTS (
      SELECT 1 FROM appointments a
      WHERE a.room_id = NEW.room_id
        AND a.appt_date = NEW.appt_date
        AND a.status = 'SCHEDULED'
        AND (NEW.start_time < a.end_time AND NEW.end_time > a.start_time)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room overlap (trigger)';
  END IF;
END $$

/* Reduce medication stock when a prescription is added */
CREATE TRIGGER trg_prescription_after_insert
AFTER INSERT ON prescriptions
FOR EACH ROW
BEGIN
  UPDATE medications
    SET stock_qty = stock_qty - NEW.quantity
    WHERE med_id = NEW.med_id;

  IF (SELECT stock_qty FROM medications WHERE med_id = NEW.med_id) < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient medication stock';
  END IF;
END $$

/* Mark invoice paid when total payments cover total_amount */
CREATE TRIGGER trg_payment_after_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
  DECLARE v_paid DECIMAL(10,2);
  DECLARE v_total DECIMAL(10,2);

  SELECT IFNULL(SUM(amount),0) INTO v_paid
  FROM payments WHERE invoice_id = NEW.invoice_id;

  SELECT total_amount INTO v_total
  FROM invoices WHERE invoice_id = NEW.invoice_id;

  IF v_paid >= v_total THEN
    UPDATE invoices SET paid = 1 WHERE invoice_id = NEW.invoice_id;
  END IF;
END $$

DELIMITER ;

-- ===================================
-- Functions & Stored Procedures
-- ===================================
DELIMITER $$

-- Clean re-create helpers
DROP FUNCTION IF EXISTS calc_age $$
DROP FUNCTION IF EXISTS compute_visit_total $$
DROP PROCEDURE IF EXISTS schedule_appointment $$
DROP PROCEDURE IF EXISTS complete_appointment_and_create_visit $$
DROP PROCEDURE IF EXISTS generate_invoice_for_visit $$

-- Age from DOB (deterministic)
CREATE FUNCTION calc_age(p_dob DATE)
RETURNS INT
DETERMINISTIC
BEGIN
  RETURN TIMESTAMPDIFF(YEAR, p_dob, CURRENT_DATE());
END $$

-- Schedule appointment with server-side checks (duplicates trigger checks)
CREATE PROCEDURE schedule_appointment(
  IN p_patient_id INT,
  IN p_doctor_id  INT,
  IN p_room_id    INT,
  IN p_date       DATE,
  IN p_start      TIME,
  IN p_end        TIME,
  IN p_notes      VARCHAR(255)
)
BEGIN
  IF p_start >= p_end THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Start time must be before end time';
  END IF;

  IF EXISTS (
    SELECT 1 FROM appointments
    WHERE doctor_id = p_doctor_id
      AND appt_date = p_date
      AND status = 'SCHEDULED'
      AND (p_start < end_time AND p_end > start_time)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor already booked in this time window';
  END IF;

  IF EXISTS (
    SELECT 1 FROM appointments
    WHERE room_id = p_room_id
      AND appt_date = p_date
      AND status = 'SCHEDULED'
      AND (p_start < end_time AND p_end > start_time)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room already booked in this time window';
  END IF;

  INSERT INTO appointments(patient_id, doctor_id, room_id, appt_date, start_time, end_time, notes)
  VALUES (p_patient_id, p_doctor_id, p_room_id, p_date, p_start, p_end, p_notes);
END $$

-- Complete appointment and create visit
CREATE PROCEDURE complete_appointment_and_create_visit(
  IN p_appt_id INT,
  IN p_diagnosis VARCHAR(255)
)
BEGIN
  UPDATE appointments
    SET status = 'COMPLETED'
    WHERE appt_id = p_appt_id;

  INSERT INTO visits(appt_id, diagnosis) VALUES (p_appt_id, p_diagnosis);
END $$

-- Compute visit total = sum(m.price*qty) + 12% tax
CREATE FUNCTION compute_visit_total(p_visit_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE v_subtotal DECIMAL(10,2) DEFAULT 0;
  DECLARE v_tax DECIMAL(10,2) DEFAULT 0;

  SELECT IFNULL(SUM(m.unit_price * pr.quantity),0)
    INTO v_subtotal
  FROM prescriptions pr
  JOIN medications m ON m.med_id = pr.med_id
  WHERE pr.visit_id = p_visit_id;

  SET v_tax = ROUND(v_subtotal * 0.12, 2);
  RETURN v_subtotal + v_tax;
END $$

-- Generate invoice for a visit
CREATE PROCEDURE generate_invoice_for_visit(p_visit_id INT)
BEGIN
  DECLARE v_subtotal DECIMAL(10,2);
  DECLARE v_tax DECIMAL(10,2);
  DECLARE v_total DECIMAL(10,2);

  SELECT IFNULL(SUM(m.unit_price * pr.quantity),0)
    INTO v_subtotal
  FROM prescriptions pr
  JOIN medications m ON m.med_id = pr.med_id
  WHERE pr.visit_id = p_visit_id;

  SET v_tax = ROUND(v_subtotal * 0.12, 2);
  SET v_total = v_subtotal + v_tax;

  INSERT INTO invoices(visit_id, subtotal, tax, total_amount)
  VALUES (p_visit_id, v_subtotal, v_tax, v_total);
END $$

DELIMITER ;

-- ===============
-- Seed Data
-- ===============
INSERT INTO patients (first_name, last_name, dob, sex, phone, email) VALUES
('Asha','Kumar','1995-08-15','F','9990011001','asha@example.com'),
('Rohit','Mehta','1988-01-20','M','9990011002','rohit@example.com');

INSERT INTO doctors (first_name, last_name, specialization, phone, email) VALUES
('Neha','Singh','General Physician','9880010001','neha.singh@clinic.com'),
('Arun','Pillai','Dermatologist','9880010002','arun.pillai@clinic.com');

INSERT INTO rooms (room_name) VALUES ('Room-101'), ('Room-102');

INSERT INTO medications (med_name, stock_qty, unit_price) VALUES
('Paracetamol 500mg', 200, 2.00),
('Amoxicillin 250mg', 100, 5.50),
('Cetirizine 10mg', 150, 3.00);

-- (Optional) quick smoke test calls:
-- CALL schedule_appointment(1, 1, 1, '2025-11-10', '10:00:00', '10:30:00', 'Fever & headache');
-- CALL schedule_appointment(2, 1, 1, '2025-11-10', '10:15:00', '10:45:00', 'Overlap test'); -- should error
-- STEP 2: Seed data
USE clinic_db;

