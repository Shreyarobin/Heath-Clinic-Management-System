import streamlit as st
import mysql.connector
import pandas as pd
from datetime import date, time
import hashlib

# ---- DB helpers ----
def get_conn():
    import config  # local file with credentials
    return mysql.connector.connect(
        host=config.HOST, user=config.USER, password=config.PASSWORD, database=config.DATABASE
    )

def run_query(sql, params=None):
    conn = get_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute(sql, params or ())
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows

def run_execute(sql, params=None):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(sql, params or ())
    conn.commit()
    cur.close()
    conn.close()

def call_proc(name, args):
    conn = get_conn()
    cur = conn.cursor()
    cur.callproc(name, args)
    conn.commit()
    cur.close()
    conn.close()

# ---- UI ----
st.set_page_config(page_title="Clinic Management System", page_icon="💊", layout="wide")
st.title("💊 Clinic Management System")

tab_pat, tab_doc, tab_appt, tab_visit, tab_rx, tab_bill, tab_queries = st.tabs(
    ["Patients", "Doctors", "Appointments", "Visits", "Prescriptions", "Billing", "Queries/Reports"]
)

with tab_pat:
    st.subheader("Patients — Create & View")
    with st.form("add_pat"):
        c1, c2, c3 = st.columns(3)
        first = c1.text_input("First name")
        last  = c2.text_input("Last name")
        dob   = c3.date_input("Date of birth", value=date(2000,1,1))
        c1, c2, c3 = st.columns(3)
        sex   = c1.selectbox("Sex", ["F","M","O"])
        phone = c2.text_input("Phone")
        email = c3.text_input("Email")
        submitted = st.form_submit_button("Add patient")
    if submitted:
        try:
            run_execute(
                "INSERT INTO patients(first_name,last_name,dob,sex,phone,email) VALUES (%s,%s,%s,%s,%s,%s)",
                (first,last,dob.isoformat(),sex,phone,email)
            )
            st.success("Patient added.")
        except Exception as e:
            st.error(f"Error: {e}")
    st.dataframe(pd.DataFrame(run_query("SELECT patient_id, first_name, last_name, dob, sex, phone, email FROM patients")))

with tab_doc:
    st.subheader("Doctors — Create & View")
    with st.form("add_doc"):
        c1, c2, c3 = st.columns(3)
        first = c1.text_input("First name", key="doc_first")
        last  = c2.text_input("Last name", key="doc_last")
        spec  = c3.text_input("Specialization")
        c1, c2 = st.columns(2)
        phone = c1.text_input("Phone", key="doc_phone")
        email = c2.text_input("Email", key="doc_email")
        submitted = st.form_submit_button("Add doctor")
    if submitted:
        try:
            run_execute(
                "INSERT INTO doctors(first_name,last_name,specialization,phone,email) VALUES (%s,%s,%s,%s,%s)",
                (first,last,spec,phone,email)
            )
            st.success("Doctor added.")
        except Exception as e:
            st.error(f"Error: {e}")
    st.dataframe(pd.DataFrame(run_query("SELECT doctor_id, first_name, last_name, specialization, phone, email FROM doctors")))

with tab_appt:
    st.subheader("Appointments — Schedule via Stored Procedure")
    patients = run_query("SELECT patient_id, CONCAT(first_name,' ',last_name) AS name FROM patients")
    doctors  = run_query("SELECT doctor_id, CONCAT(first_name,' ',last_name) AS name FROM doctors")
    rooms    = run_query("SELECT room_id, room_name FROM rooms")

    with st.form("add_appt"):
        c1, c2, c3 = st.columns(3)
        p = c1.selectbox("Patient", options=patients, format_func=lambda r: f"{r['patient_id']} — {r['name']}")
        d = c2.selectbox("Doctor",  options=doctors,  format_func=lambda r: f"{r['doctor_id']} — {r['name']}")
        r = c3.selectbox("Room",    options=rooms,    format_func=lambda r: f"{r['room_id']} — {r['room_name']}")
        c1, c2, c3 = st.columns(3)
        adate = c1.date_input("Date")
        start = c2.time_input("Start time", value=time(10,0,0))
        end   = c3.time_input("End time", value=time(10,30,0))
        notes = st.text_input("Notes")
        submitted = st.form_submit_button("Schedule appointment")
    if submitted:
        try:
            call_proc("schedule_appointment", (p['patient_id'], d['doctor_id'], r['room_id'], adate.isoformat(), start.isoformat(), end.isoformat(), notes))
            st.success("Appointment scheduled.")
        except Exception as e:
            st.error(f"Error from procedure/trigger: {e}")

    st.caption("Overlaps are blocked by procedure + trigger. Try overlapping times to see the error.")
    st.dataframe(pd.DataFrame(run_query("""
        SELECT a.appt_id, a.appt_date, a.start_time, a.end_time, a.status,
               CONCAT(p.first_name,' ',p.last_name) AS patient,
               CONCAT(d.first_name,' ',d.last_name) AS doctor,
               r.room_name
        FROM appointments a
        JOIN patients p ON p.patient_id = a.patient_id
        JOIN doctors d  ON d.doctor_id  = a.doctor_id
        JOIN rooms   r  ON r.room_id    = a.room_id
        ORDER BY a.appt_date DESC, a.start_time
    """)))

with tab_visit:
    st.subheader("Complete Appointment → Create Visit (Stored Procedure)")
    appts = run_query("SELECT appt_id, appt_date, start_time, end_time, status FROM appointments WHERE status='SCHEDULED'")
    if appts:
        with st.form("complete_visit"):
            a = st.selectbox("Appointment to complete", options=appts, format_func=lambda r: f"{r['appt_id']} on {r['appt_date']} {r['start_time']} - {r['end_time']}")
            dx = st.text_input("Diagnosis")
            submitted = st.form_submit_button("Complete & create visit")
        if submitted:
            try:
                call_proc("complete_appointment_and_create_visit", (a['appt_id'], dx))
                st.success("Visit created.")
            except Exception as e:
                st.error(f"Error: {e}")
    st.dataframe(pd.DataFrame(run_query("""
        SELECT v.visit_id, v.visit_date, v.diagnosis, a.appt_id
        FROM visits v JOIN appointments a ON a.appt_id = v.appt_id
        ORDER BY v.visit_date DESC
    """)))

with tab_rx:
    st.subheader("Prescriptions — Insert (Trigger will reduce stock)")
    visits = run_query("SELECT visit_id, diagnosis FROM visits ORDER BY visit_id DESC")
    meds   = run_query("SELECT med_id, med_name, stock_qty, unit_price FROM medications")
    with st.form("add_rx"):
        v = st.selectbox("Visit", options=visits, format_func=lambda r: f"Visit {r['visit_id']} — {r['diagnosis']}")
        m = st.selectbox("Medication", options=meds, format_func=lambda r: f"{r['med_name']} (Stock: {r['stock_qty']})")
        qty = st.number_input("Quantity", min_value=1, step=1)
        dosage = st.text_input("Dosage (e.g., 1-0-1 for 5 days)")
        submitted = st.form_submit_button("Add prescription")
    if submitted:
        try:
            run_execute("INSERT INTO prescriptions(visit_id, med_id, quantity, dosage) VALUES (%s,%s,%s,%s)",
                        (v['visit_id'], m['med_id'], int(qty), dosage))
            st.success("Prescription added. Stock decreased by trigger.")
        except Exception as e:
            st.error(f"Error: {e}")

    st.dataframe(pd.DataFrame(run_query("""
        SELECT pr.prescription_id, pr.visit_id, m.med_name, pr.quantity, pr.dosage
        FROM prescriptions pr JOIN medications m ON m.med_id = pr.med_id
        ORDER BY pr.prescription_id DESC
    """)))
    st.write("Medication Inventory")
    st.dataframe(pd.DataFrame(run_query("SELECT * FROM medications ORDER BY med_name")))

with tab_bill:
    st.subheader("Billing — Generate Invoice & Record Payments")
    visits = run_query("""
        SELECT v.visit_id, CONCAT('Visit ', v.visit_id, ' (Appt ', a.appt_id, ')') AS label
        FROM visits v JOIN appointments a ON a.appt_id = v.appt_id
        WHERE v.visit_id NOT IN (SELECT visit_id FROM invoices)
        ORDER BY v.visit_id DESC
    """)
    with st.form("gen_inv"):
        v = st.selectbox("Visit (no invoice yet)", options=visits, format_func=lambda r: r['label']) if visits else None
        submitted = st.form_submit_button("Generate invoice")
    if submitted and v:
        try:
            call_proc("generate_invoice_for_visit", (v['visit_id'],))
            st.success("Invoice created.")
        except Exception as e:
            st.error(f"Error: {e}")

    st.write("Invoices")
    invs = run_query("SELECT * FROM invoices ORDER BY invoice_id DESC")
    st.dataframe(pd.DataFrame(invs))

    if invs:
        with st.form("add_pay"):
            inv = st.selectbox("Invoice", options=invs, format_func=lambda r: f"Invoice {r['invoice_id']} — Total ₹{r['total_amount']} — Paid {r['paid']}")
            amt = st.number_input("Amount", min_value=1.0, step=1.0)
            method = st.selectbox("Method", ["CASH","CARD","UPI"])
            pay_submit = st.form_submit_button("Record payment")
        if pay_submit:
            try:
                run_execute("INSERT INTO payments(invoice_id, amount, method) VALUES (%s,%s,%s)",
                            (inv['invoice_id'], float(amt), method))
                st.success("Payment recorded. Trigger will mark invoice paid if fully covered.")
            except Exception as e:
                st.error(f"Error: {e}")

    st.write("Payments")
    st.dataframe(pd.DataFrame(run_query("SELECT * FROM payments ORDER BY payment_id DESC")))

with tab_queries:
    st.subheader("Queries & Reports (Examples)")
    c1, c2 = st.columns(2)
    if c1.button("Upcoming appointments (next 7 days)"):
        rows = run_query("""
            SELECT a.appt_id, a.appt_date, a.start_time,
                   CONCAT(p.first_name,' ',p.last_name) AS patient,
                   CONCAT(d.first_name,' ',d.last_name) AS doctor
            FROM appointments a
            JOIN patients p ON p.patient_id = a.patient_id
            JOIN doctors  d ON d.doctor_id  = a.doctor_id
            WHERE a.appt_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)
              AND a.status='SCHEDULED'
            ORDER BY a.appt_date, a.start_time
        """)
        st.dataframe(pd.DataFrame(rows))
    if c2.button("Low stock medications (< 20)"):
        rows = run_query("SELECT med_name, stock_qty FROM medications WHERE stock_qty < 20 ORDER BY stock_qty")
        st.dataframe(pd.DataFrame(rows))

st.caption("Errors (like overlaps or stock issues) are thrown by stored procedures/triggers and shown here as messages. This demonstrates DB constraints via UI.")
