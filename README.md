HEALTH CLINIC MANAGEMENT SYSTEM
MySQL + Streamlit

A simple end-to-end clinic workflow application demonstrating DB-driven logic, CRUD operations, and a Streamlit UI.

REQUIREMENTS

Python 3.10+

MySQL 8.x + MySQL Workbench

VS Code (recommended)

Web browser

PROJECT STRUCTURE
clinic-app/
app.py
config.py
config_example.py
test_connect.py
mini_query.py
README.md

db/
    clinic_setup.sql

.venv/


DATABASE SETUP

Open MySQL Workbench.
Create a new SQL tab.
Run the file:
db/clinic_setup.sql

This creates:

database clinic_db

schema tables

triggers, functions, procedures

sample data

(Optional) Create a dedicated database user:
CREATE USER IF NOT EXISTS 'clinic_user'@'localhost' IDENTIFIED BY 'StrongPass123!';
GRANT ALL PRIVILEGES ON clinic_db.* TO 'clinic_user'@'localhost';
FLUSH PRIVILEGES;

CREATE VIRTUAL ENVIRONMENT

Inside clinic-app folder:
python -m venv .venv

Activate (Windows PowerShell):
. ..venv\Scripts\Activate.ps1

INSTALL DEPENDENCIES

pip install streamlit mysql-connector-python pandas

CONFIGURE DATABASE CREDENTIALS

Copy config_example.py → rename to config.py.
Edit config.py with real values:

HOST = "localhost"
USER = "clinic_user"
PASSWORD = "StrongPass123!"
DATABASE = "clinic_db"
PORT = 3306


Keep config.py private. Do not commit it to Git.

TEST DATABASE CONNECTION

python test_connect.py

Expected output:
Connected!
Database: clinic_db
MySQL version: ...

If it fails:

Check username and password

Ensure MySQL service is running

Confirm PORT is correct

RUN THE APPLICATION

streamlit run app.py

A browser tab should open automatically.
If not, manually visit: http://localhost:8501

APPLICATION WORKFLOW

Within Streamlit UI:

Add patients

Add doctors

Schedule appointments (overlap protection)

Complete appointments (visit automatically created)

Add prescriptions (medication stock decreases)

Generate invoices

Record payments (invoice automatically marked paid)

View upcoming appointments

View low-stock medications

RESETTING DATABASE

Re-run:
db/clinic_setup.sql

This drops and recreates everything.

NOTES

Most business logic (scheduling rules, stock updates, invoice status changes, DOB checks) is enforced inside the database using triggers, stored procedures, and functions.

Streamlit handles user interface and calls to the database.

This project demonstrates:

CRUD operations

Stored procedures

Functions

Triggers

Basic reporting
