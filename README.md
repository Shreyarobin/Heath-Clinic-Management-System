🏥 Health Clinic Management System

MySQL + Streamlit

A simple end-to-end clinic workflow application demonstrating DB-driven logic, CRUD operations, and a Streamlit UI.

✅ Requirements

Python 3.10+

MySQL 8.x + MySQL Workbench

VS Code (recommended)

Internet browser

📁 Project Structure
clinic-app/
│  app.py
│  config.py
│  config_example.py
│  test_connect.py
│  mini_query.py
│  README.md
│
├─ db/
│   clinic_setup.sql
│
└─ .venv/

⚙️ 1) Database Setup

Open MySQL Workbench

Create a new SQL tab

Open and run the script:

db/clinic_setup.sql


This will:

Create database clinic_db

Build all tables

Add triggers, functions, procedures

Insert initial sample data

(Optional) Create a dedicated user
CREATE USER IF NOT EXISTS 'clinic_user'@'localhost' IDENTIFIED BY 'StrongPass123!';
GRANT ALL PRIVILEGES ON clinic_db.* TO 'clinic_user'@'localhost';
FLUSH PRIVILEGES;

🐍 2) Create Virtual Environment

From inside the clinic-app folder:

python -m venv .venv


Activate it:

Windows (PowerShell)

. .\.venv\Scripts\Activate.ps1

📦 3) Install Dependencies
pip install streamlit mysql-connector-python pandas

🔑 4) Configure DB Credentials

Open config_example.py → review structure

Copy → rename to config.py

Fill in your real credentials:

HOST = "localhost"
USER = "clinic_user"     # or your MySQL user
PASSWORD = "StrongPass123!"
DATABASE = "clinic_db"
PORT = 3306


Keep config.py private.
Do not commit it to Git.

🔍 5) Test DB Connection

Run:

python test_connect.py


Expected:

Connected!
Database: clinic_db
MySQL version: ...


If it fails:

Check username/password

Check MySQL is running

Check PORT is correct

▶️ 6) Run the Application
streamlit run app.py


A browser tab will open.
If not, copy the URL shown (e.g., http://localhost:8501) and paste it into your browser.

🖥️ 7) App Workflow

Inside Streamlit:

Add patient records

Add doctor records

Schedule appointment

Overlaps are blocked

Complete appointment → visit auto-creates

Add prescriptions

Stock decreases

Generate invoice

Record payment

Invoice auto-marks as paid

View reports

Upcoming appointments

Low-stock medication

🔁 Resetting Database

Re-run clinic_setup.sql in Workbench.
It will drop and recreate everything.

📚 Notes

Most business logic lives in the DB (triggers + procedures)

Streamlit only displays and calls backend logic

Demonstrates:

CRUD

Stored Procedures

Functions

Triggers

Basic reporting
