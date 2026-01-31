---Customer cohort retention (activation + stickiness)
--customer active month
IF OBJECT_ID('dbo.v_customer_txn_month', 'V') IS NOT NULL
    DROP VIEW dbo.v_customer_txn_month;
GO

CREATE VIEW dbo.v_customer_txn_month AS
SELECT DISTINCT
  c.customer_id,
  t.txn_month
FROM dbo.v_transactions_clean t
JOIN dbo.accounts_ a ON a.account_id = t.account_id
JOIN dbo.customers_ c ON c.customer_id = a.customer_id
WHERE t.status = 'SETTLED'
  AND t.txn_ts_parsed IS NOT NULL;
GO
--Cohort sizes
WITH cohorts AS (
  SELECT
    customer_id,
    MIN(txn_month) AS cohort_month
  FROM dbo.v_customer_txn_month
  GROUP BY customer_id
)
SELECT
  cohort_month,
  COUNT(*) AS cohort_size
FROM cohorts
GROUP BY cohort_month
ORDER BY cohort_month;

--Retention table
WITH cohorts AS (
  SELECT
    customer_id,
    MIN(txn_month) AS cohort_month
  FROM dbo.v_customer_txn_month
  GROUP BY customer_id
),
activity AS (
  SELECT
    m.customer_id,
    c.cohort_month,
    m.txn_month,
    DATEDIFF(MONTH, c.cohort_month, m.txn_month) AS month_number
  FROM dbo.v_customer_txn_month m
  JOIN cohorts c ON c.customer_id = m.customer_id
),
retention AS (
  SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_id) AS active_customers
  FROM activity
  GROUP BY cohort_month, month_number
),
cohort_sizes AS (
  SELECT
    cohort_month,
    COUNT(*) AS cohort_size
  FROM cohorts
  GROUP BY cohort_month
)
SELECT
  r.cohort_month,
  r.month_number,
  cs.cohort_size,
  r.active_customers,
  ROUND(100.0 * r.active_customers / NULLIF(cs.cohort_size, 0), 2) AS retention_pct
FROM retention r
JOIN cohort_sizes cs ON cs.cohort_month = r.cohort_month
ORDER BY r.cohort_month, r.month_number;

--pivot to a cohort matrix

WITH cohorts AS (
  SELECT customer_id, MIN(txn_month) AS cohort_month
  FROM dbo.v_customer_txn_month
  GROUP BY customer_id
),
activity AS (
  SELECT
    m.customer_id,
    c.cohort_month,
    DATEDIFF(MONTH, c.cohort_month, m.txn_month) AS month_number
  FROM dbo.v_customer_txn_month m
  JOIN cohorts c ON c.customer_id = m.customer_id
),
retention AS (
  SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_id) AS active_customers
  FROM activity
  GROUP BY cohort_month, month_number
),
cohort_sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_size
  FROM cohorts
  GROUP BY cohort_month
),
final AS (
  SELECT
    r.cohort_month,
    r.month_number,
    ROUND(100.0 * r.active_customers / NULLIF(cs.cohort_size, 0), 2) AS retention_pct
  FROM retention r
  JOIN cohort_sizes cs ON cs.cohort_month = r.cohort_month
)
SELECT
  cohort_month,
  MAX(CASE WHEN month_number = 0 THEN retention_pct END) AS m0,
  MAX(CASE WHEN month_number = 1 THEN retention_pct END) AS m1,
  MAX(CASE WHEN month_number = 2 THEN retention_pct END) AS m2,
  MAX(CASE WHEN month_number = 3 THEN retention_pct END) AS m3,
  MAX(CASE WHEN month_number = 4 THEN retention_pct END) AS m4,
  MAX(CASE WHEN month_number = 5 THEN retention_pct END) AS m5,
  MAX(CASE WHEN month_number = 6 THEN retention_pct END) AS m6
FROM final
GROUP BY cohort_month
ORDER BY cohort_month;
