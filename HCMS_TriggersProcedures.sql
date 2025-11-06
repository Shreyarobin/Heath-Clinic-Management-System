USE clinic_db;

-- Always switch the delimiter before creating routines/triggers
DELIMITER $$

/* ------------ Clean drops (safe to re-run) ------------ */
DROP TRIGGER IF EXISTS trg_no_overlap_before_insert $$
DROP TRIGGER IF EXISTS trg_prescription_after_insert $$
DROP TRIGGER IF EXISTS trg_payment_after_insert $$

DROP PROCEDURE IF EXISTS schedule_appointment $$
DROP PROCEDURE IF EXISTS complete_appointment_and_create_visit $$
DROP PROCEDURE IF EXISTS generate_invoice_for_visit $$

DROP FUNCTION  IF EXISTS calc_age $$
DROP FUNCTION  IF EXISTS compute_visit_total $$

/* ------------ Functions ------------ */

-- Age in years from DOB
CREATE FUNCTION calc_age(p_dob DATE)
RETURNS INT
DETERMINISTIC
BEGIN
  RETURN TIMESTAMPDIFF(YEAR, p_dob, CURRENT_DATE());
END $$

-- Total cost for a visit: prescriptions + 12% tax
CREATE FUNCTION compute_visit_total(p_visit_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE v_subtotal DECIMAL(10,2) DEFAULT 0;
  DECLARE v_tax      DECIMAL(10,2) DEFAULT 0;

  SELECT IFNULL(SUM(m.unit_price * pr.quantity),0)
    INTO v_subtotal
  FROM prescriptions pr
  JOIN medications m ON m.med_id = pr.med_id
  WHERE pr.visit_id = p_visit_id;

  SET v_tax = ROUND(v_subtotal * 0.12, 2);
  RETURN v_subtotal + v_tax;
END $$

/* ------------ Procedures ------------ */

-- Schedule an appointment with conflict checks
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

  -- doctor double-booking check
  IF EXISTS (
    SELECT 1 FROM appointments
    WHERE doctor_id = p_doctor_id
      AND appt_date = p_date
      AND status = 'SCHEDULED'
      AND (p_start < end_time AND p_end > start_time)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor already booked in this time window';
  END IF;

  -- room double-booking check
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

-- Complete appointment and create a visit row
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

-- Generate invoice for a visit based on prescriptions
CREATE PROCEDURE generate_invoice_for_visit(p_visit_id INT)
BEGIN
  DECLARE v_subtotal DECIMAL(10,2);
  DECLARE v_tax      DECIMAL(10,2);
  DECLARE v_total    DECIMAL(10,2);

  SELECT IFNULL(SUM(m.unit_price * pr.quantity),0)
    INTO v_subtotal
  FROM prescriptions pr
  JOIN medications m ON m.med_id = pr.med_id
  WHERE pr.visit_id = p_visit_id;

  SET v_tax   = ROUND(v_subtotal * 0.12, 2);
  SET v_total = v_subtotal + v_tax;

  INSERT INTO invoices(visit_id, subtotal, tax, total_amount)
  VALUES (p_visit_id, v_subtotal, v_tax, v_total);
END $$

/* ------------ Triggers ------------ */

-- Block overlapping appointments for same doctor/room
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

-- Reduce stock when a prescription is inserted
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

-- Mark invoice paid when total payments cover total_amount
CREATE TRIGGER trg_payment_after_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
  DECLARE v_paid  DECIMAL(10,2);
  DECLARE v_total DECIMAL(10,2);

  SELECT IFNULL(SUM(amount),0) INTO v_paid
    FROM payments WHERE invoice_id = NEW.invoice_id;

  SELECT total_amount INTO v_total
    FROM invoices WHERE invoice_id = NEW.invoice_id;

  IF v_paid >= v_total THEN
    UPDATE invoices SET paid = 1 WHERE invoice_id = NEW.invoice_id;
  END IF;
END $$

-- Back to normal delimiter
DELIMITER ;
