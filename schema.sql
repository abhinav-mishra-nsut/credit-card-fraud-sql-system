-- ========================================================
-- CREDIT CARD TRANSACTION MONITOR & FRAUD DETECTION ENGINE
-- Architecture: Relational 3NF Schema & Advanced Analytics
-- ========================================================

-- 1. SCHEMA DEFINITION
CREATE TABLE customers (
    cc_num BIGINT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    gender CHAR(1),
    job VARCHAR(100),
    dob DATE,
    street VARCHAR(150),
    city VARCHAR(100),
    state CHAR(2),
    zip VARCHAR(10),
    lat DECIMAL(9,6),
    long DECIMAL(9,6),
    city_pop INT
);

CREATE TABLE merchants (
    merchant_id SERIAL PRIMARY KEY,
    merchant_name VARCHAR(150) UNIQUE,
    category VARCHAR(50)
);

CREATE TABLE transactions (
    trans_id INT PRIMARY KEY,
    trans_num VARCHAR(50) UNIQUE,
    trans_date_time TIMESTAMP,
    unix_time BIGINT,
    cc_num BIGINT REFERENCES customers(cc_num),
    merchant_name VARCHAR(150) REFERENCES merchants(merchant_name),
    amt DECIMAL(10,2),
    merch_lat DECIMAL(9,6),
    merch_long DECIMAL(9,6),
    is_fraud INT
);

-- 2. PERFORMANCE OPTIMIZATION
CREATE INDEX idx_transactions_cc_num ON transactions (cc_num);

-- 3. ADVANCED DETECTION ENGINES (CTEs & WINDOW FUNCTIONS)

-- Engine 1: Velocity Attack Monitor (< 10 Minute Gaps)
WITH VelocityStaging AS (
    SELECT 
        trans_id,
        cc_num,
        trans_date_time,
        amt,
        EXTRACT(EPOCH FROM (trans_date_time - LAG(trans_date_time, 1) OVER (
            PARTITION BY cc_num 
            ORDER BY trans_date_time
        ))) / 60 AS minutes_since_last_trans
    FROM transactions
)
SELECT * FROM VelocityStaging
WHERE minutes_since_last_trans < 10 
  AND minutes_since_last_trans IS NOT NULL;

-- Engine 2: High-Value Spend Threshold Monitor (3x Personal Average)
WITH spend_threshold AS (
    SELECT 
        trans_id,
        cc_num,
        amt,
        AVG(amt) OVER(PARTITION BY cc_num) AS historical_avg_spend
    FROM transactions
)
SELECT * FROM spend_threshold 
WHERE amt > 3 * historical_avg_spend;

CREATE VIEW daily_fraud_dashboard AS
WITH VelocityStaging AS (
    SELECT 
        t.trans_id,
        t.cc_num,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.job,
        t.merchant_name,
        t.amt,
        t.trans_date_time,
        EXTRACT(EPOCH FROM (t.trans_date_time - LAG(t.trans_date_time, 1) OVER (
            PARTITION BY t.cc_num 
            ORDER BY t.trans_date_time
        ))) / 60 AS minutes_since_last_trans
    FROM transactions t
    JOIN customers c ON t.cc_num = c.cc_num
)
SELECT 
    trans_id,
    cc_num,
    customer_name,
    job,
    merchant_name,
    amt,
    trans_date_time,
    ROUND(minutes_since_last_trans::numeric, 2) AS minutes_since_last_swipe
FROM VelocityStaging
WHERE minutes_since_last_trans < 10 
  AND minutes_since_last_trans IS NOT NULL;

SELECT * FROM daily_fraud_dashboard LIMIT 10;

-- ====================================================================
-- ⚡ ADVANCED AUTOMATION & STATE MANAGEMENT (PRODUCTION LIFECYCLE)
-- ====================================================================

-- 1. Create an isolated Operational Audit Table for high-risk flags
CREATE TABLE IF NOT EXISTS high_risk_alerts (
    alert_id SERIAL PRIMARY KEY,
    trans_id INT,
    cc_num BIGINT,
    merchant_name VARCHAR(255),
    amt NUMERIC(10, 2),
    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    review_status VARCHAR(50) DEFAULT 'PENDING_REVIEW'
);

-- 2. Stored Procedure: Core Risk Assessment Engine
-- Evaluates streaming transaction parameters before final table persistence
CREATE OR REPLACE FUNCTION evaluate_transaction_risk()
RETURNS TRIGGER AS $$
BEGIN
    -- Real-time Operational Thresholding (Programmatic Trigger)
    IF NEW.amt > 500.00 THEN
        INSERT INTO high_risk_alerts (trans_id, cc_num, merchant_name, amt)
        VALUES (NEW.trans_id, NEW.cc_num, NEW.merchant_name, NEW.amt);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Database Trigger: Zero-Latency Ingestion Interceptor
-- Automatically fires the risk assessment engine the millisecond a transaction hits the database
DROP TRIGGER IF EXISTS trg_transaction_ingest_monitor ON transactions;
CREATE TRIGGER trg_transaction_ingest_monitor
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION evaluate_transaction_risk();
