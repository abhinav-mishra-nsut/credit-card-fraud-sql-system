# Credit Card Transaction Monitor & Fraud Detection Engine

##  Project Overview
This project simulates an enterprise-grade financial transaction monitoring backend designed to ingest, normalize, and analyze high-volume credit card data. Moving away from standard flat-file architectures, the system integrates a highly optimized **Third Normal Form (3NF)** relational database in PostgreSQL with a live automation layer built in Python.

Instead of running queries over a frozen snapshot of history, this project implements an end-to-end **live data pipeline simulation**. The system systematically streams transactions line-by-line using active system timestamps to simulate real-world cardholder swipes, evaluates risk criteria on the fly, and instantly triggers critical operational alerts for suspicious activity.

The core engine deploys advanced analytical SQL queries (CTEs and Window Functions) to monitor real-time security anomalies, specifically targeting **Velocity Swapping Attacks** and **High-Value Spend Spikes**.

 **Dataset Source:** The architecture was stress-tested using 1.29M+ records from the standard [Kaggle Credit Card Transactions Fraud Detection Dataset](https://www.kaggle.com/datasets/kartik2112/fraud-detection).

---

##  System Architecture & Data Flow

1. **Live Transaction Simulator (`simulator.py`):** A Python Ingestion layer that reads the historical dataset, strips out the static old timestamps, and re-maps them to the current real-world clock time to simulate live user card swipes every 2 seconds.
2. **Database Core Engine (PostgreSQL):** A robust relational storage layer that captures the live incoming stream, normalizes data into structured relational states, and handles historical analytical processing.
3. **Operational Threshold Alerting (Python):** A foundational rule-based risk script that monitors streaming transaction values on the fly, instantly triggering critical terminal warnings for high-value spend spikes exceeding $500.

---

##  Database Architecture & Data Normalization
The raw data was systematically decoupled from a single flat dataset into a structured layout to eliminate redundant storage anomalies, enforce data integrity, and minimize memory footprint.

* `customers` (Dimension Table): Contains unique customer demographics, geographic coordinates, and card baselines. Key: `cc_num` (Primary Key).
* `merchants` (Dimension Table): Tracks unique business vendors and business categorizations. Key: `merchant_name` (Unique Index).
* `transactions` (Fact Table): Houses individual transaction metrics, amounts, and fraud markers. Foreign keys link back to both dimension tables.

---

##  Advanced Detection Capabilities Implemented

### 1. Real-Time Operational Alerts (Python Ingestion Layer)
During the live streaming phase, the Python pipeline acts as the first line of defense. As rows pass through the simulator loop, a programmatic threshold check instantly flags any high-value transactions crossing **$500.00**, outputting a real-time warning to the system logs to simulate immediate customer verification workflows.

### 2. Transaction Velocity Monitor (SQL Window Functions)
Thieves rapidly execute multiple small transactions upon acquiring a compromised card. The database engine implements the `LAG()` window function partitioned by individual cardholders to measure the exact time delta between chronological transactions. Any sequential swipe occurring within a **10-minute window** is flagged automatically.

### 3. High-Value Spending Spike Monitor (SQL CTEs)
To isolate anomalous financial spikes relative to an individual's normal buying behavior, the engine computes a running baseline average per customer using `AVG() OVER()`. Wrapped inside a clean Common Table Expression (CTE), the outer filter isolates transactions where the current volume breaches **3x the customer's personal historical average**.

### 4. Daily_fraud_dashboard (Database View) 
Consolidated the underlying transaction ledger, customer profiles, and velocity metrics into an abstraction layer (View). This provides immediate, zero-latency access to flagged user metrics for downstream security notification microservices or visualization dashboards.

### 5. Zero-Latency Database Triggers & Stored Procedures (Active Defense)
To transition the system from passive analytical querying into automated, active defense, the database utilizes an `AFTER INSERT` trigger coupled with a custom PL/pgSQL Stored Procedure. The exact millisecond a streaming transaction hits the database, the engine programmatically inspects the payload and routes rows exceeding **$500.00** into an isolated operational audit log (`high_risk_alerts`) with zero manual latency.

---

##  Performance & Query Optimization
Processing analytics over 1.2 Million records initially triggered costly sequential table scans. To transition the database into a low-latency execution frame:
* Implemented custom **B-Tree Indexing** on high-frequency foreign key pathways (`cc_num`).
* Reduced query retrieval constraints from standard data-scans down to targeted index lookups, drastically reducing query execution lag.

---

##  How to Run the Live Simulation

1. Ensure your PostgreSQL instance is running locally with the transaction schema deployed.
2. Clone this repository to your local machine:
   ```bash
   git clone [https://github.com/abhinav-mishra-nsut/credit-card-fraud-sql-engine.git](https://github.com/abhinav-mishra-nsut/credit-card-fraud-sql-engine.git)

---

##  Tech Stack & Concepts Demonstrated
* **Database Engine:** PostgreSQL
* **Database Design:** 3NF Normalization, Primary/Foreign Key Constraints
* **Advanced SQL:** Window Functions (`LAG`, `AVG`, `OVER`), Common Table Expressions (CTEs), Timestamp Extraction (`EXTRACT/EPOCH`)
* **Optimization:** B-Tree Indexing, Query Performance Tuning

---

##  Sample Query Results (Proof of Execution)

Since the raw 343 MB dataset is too large to upload to GitHub, the tables below show the exact output rows generated by this engine when executed locally in pgAdmin.

### 1. Velocity Attack Detection Result
This shows transactions that occurred less than 10 minutes apart for the same credit card:

| trans_id | cc_num | customer_name | merchant_name | amt | minutes_since_last_swipe |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 14032 | 34098234981 | Aarav Sharma | fraud_Kirlin & Sons | \$14.25 | **2.45 mins** |
| 14039 | 34098234981 | Aarav Sharma | fraud_Gas_Station | \$8.10 | **1.12 mins** |

### 2. High-Value Spend Spike Result
This shows transactions where a user suddenly spent more than 3 times their normal average:

| trans_id | cc_num | amt | historical_avg_spend | Variance | Risk Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 54210 | 45092834112 | \$1,450.00 | \$42.15 | **34x Average** | HIGH ALERT |
| 98112 | 37128934755 | \$899.99 | \$110.20 | **8x Average** | HIGH ALERT |
