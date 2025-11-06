CALL schedule_appointment(1, 1, 1, '2025-11-10', '10:00:00', '10:30:00', 'Fever & headache');
-- Find appt_id first
SELECT * FROM appointments;
-- Suppose appt_id = 1
CALL complete_appointment_and_create_visit(1, 'Viral fever suspected');
SELECT * FROM visits;
-- visit_id assumed 1
INSERT INTO prescriptions(visit_id, med_id, quantity, dosage)
VALUES (1, 1, 5, '1 tablet thrice daily');
SELECT * FROM medications; -- stock reduced
CALL generate_invoice_for_visit(1);
SELECT * FROM invoices;

USE clinic_db;

-- 1) See which visit you just created
SELECT visit_id, appt_id, diagnosis, visit_date
FROM visits
ORDER BY visit_id DESC;

-- 2) Create an invoice for that visit (replace 1 with your actual visit_id)
CALL generate_invoice_for_visit(1);

-- 3) Fetch the invoice that was created and note its invoice_id
SELECT invoice_id, visit_id, subtotal, tax, total_amount, paid
FROM invoices
WHERE visit_id = 1;

-- Suppose the line above shows invoice_id = X (e.g., 3). Use that below.

-- 4) Record a payment against the REAL invoice_id
INSERT INTO payments(invoice_id, amount, method)
VALUES (3, 999.00, 'UPI');   -- <-- replace 3 with your invoice_id

-- 5) Verify: trigger marks it paid if fully covered
SELECT * FROM payments WHERE invoice_id = 3;
SELECT * FROM invoices  WHERE invoice_id = 3;




