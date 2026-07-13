-- ====================================================================
--  CRISIS RESPONSE & HIGH-SCALE ANALYTICS DRILLS
-- ====================================================================

-- OPTIMIZATION CASE: Temporal Data Isolation via Temporary Tables
-- Purpose: Shield live production ledgers from heavy sequential scans during active breaches.

-- 1. Purge memory if session clone exists
DROP TABLE IF EXISTS temp_holiday_anomaly;

-- 2. Isolate a high-risk temporal window into local session memory
CREATE TEMP TABLE temp_holiday_anomaly AS
SELECT trans_id, cc_num, amt, merchant_name 
FROM transactions
WHERE EXTRACT(MONTH FROM trans_date_trans_time::timestamp) = 11
  AND EXTRACT(DAY FROM trans_date_trans_time::timestamp) BETWEEN 25 AND 30
  AND amt > 50.00;

-- 3. Execute low-overhead, rapid iterative grouping queries on the isolated subset
SELECT merchant_name, COUNT(*), SUM(amt) 
FROM temp_holiday_anomaly 
GROUP BY merchant_name 
ORDER BY COUNT(*) DESC 
LIMIT 5;


-- DATA SHIFTING CASE: Permanent Dataset Instantiation via CTAS
-- Purpose: Package and decouple static anomaly snapshots for downstream ML modeling pipelines.

DROP TABLE IF EXISTS ml_breach_training_set;

CREATE TABLE ml_breach_training_set AS
SELECT t.trans_id, t.amt, t.merchant_name, c.age, c.city
FROM temp_holiday_anomaly t
JOIN customers c ON t.cc_num = c.cc_num;
