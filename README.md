Health Clinic Management System
MySQL • Streamlit • DB-Driven Logic

Overview

This project implements an end-to-end clinic workflow system using MySQL for data management and Streamlit for the user interface. It models real-world clinic operations such as patient registration, appointment scheduling, medical visits, prescriptions, and billing. Core business rules are enforced directly in the database via triggers, stored procedures, and functions, ensuring data integrity and consistent behavior. The Streamlit interface allows users to interact with the system easily without writing SQL.

Database Summary

The database stores all clinic-related information. Records are linked through primary and foreign key relationships to preserve consistency.

Key tables include:
patients (personal details), doctors (specialization and contact), rooms (consultation allocation), appointments (scheduled visits), visits (post-appointment records), prescriptions (medicine assignment), medications (inventory details), invoices (billing information), and payments (tracking bill settlement).

Important fields: patient details, doctor specialization, appointment dates and times, medication stock/price, visit diagnosis, invoice totals, and payment method.

Business-rule constraints ensure data validity. For example, appointments cannot overlap for the same doctor or room, medication stock cannot drop below zero, and invoice status automatically updates once payments meet or exceed the total amount.

Features Implemented

The system supports core clinic workflows. Users can register patients and doctors, schedule and complete appointments, and record prescriptions. Medication inventory is automatically updated when prescriptions are added. Invoices are generated based on visit details, and payments update invoice status in real time.

Rules are handled through stored procedures and triggers, such as scheduling checks, DOB validation, visit creation after appointment completion, automatic stock reduction, and invoice settlement status.

Evaluation

Because the logic resides inside the database, clinical operations remain consistent regardless of user interface. Data validation, logical constraints, and business operations are handled reliably using procedures and triggers, preventing errors like double-booking and invalid billing. This design supports clean CRUD workflows and dependable behavior during demonstrations or production extension.

How It Works (High Level)

The database is created first and contains all clinic logic. Users operate the system through Streamlit: they enter patient details, create appointments, complete visits, add prescriptions, and settle invoices. Behind the scenes, database routines enforce rules such as preventing scheduling conflicts and updating medication inventory. The interface simply calls the database and displays results.

Requirements

The project requires Python 3.10 or higher. MySQL 8.x is used for data storage. Streamlit powers the UI, and mysql-connector-python enables communication between Python and MySQL. Other tools such as pandas may be used for handling data and simple reporting.
