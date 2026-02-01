DECLARE @months_back INT = 6;

DECLARE @end_month  DATE = (SELECT MAX(txn_month) FROM dbo.v_transactions_clean);
DECLARE @start_month DATE = DATEADD(MONTH, -(@months_back-1), @end_month);

WITH base AS (
    SELECT
        t.txn_month,
        t.txn_id,
        t.account_id,
        a.customer_id,
        t.merchant_id,
        ISNULL(m.merchant_name, CONCAT('merchant_id=', CAST(t.merchant_id AS varchar(50)))) AS merchant_name,
        m.city,
        m.country,
        UPPER(LTRIM(RTRIM(t.status))) AS status_norm,
        t.amount_usd,
        t.is_fraud,
        t.reversal_of_txn_id
    FROM dbo.v_transactions_clean t
    JOIN dbo.accounts_ a
      ON a.account_id = t.account_id
    LEFT JOIN dbo.merchants_ m
      ON m.merchant_id = t.merchant_id
    WHERE t.merchant_id IS NOT NULL
      AND t.txn_month BETWEEN @start_month AND @end_month
      AND t.txn_ts_parsed IS NOT NULL
),
cust_by_merchant AS (
    -- customer repeat rate per merchant (based on SETTLED only)
    SELECT
        merchant_id,
        customer_id,
        COUNT(*) AS settled_txn_per_customer
    FROM base
    WHERE status_norm = 'SETTLED'
    GROUP BY merchant_id, customer_id
),
repeat_stats AS (
    SELECT
        merchant_id,
        COUNT(*) AS customers_with_settled,
        SUM(CASE WHEN settled_txn_per_customer >= 2 THEN 1 ELSE 0 END) AS repeat_customers
    FROM cust_by_merchant
    GROUP BY merchant_id
),
agg AS (
    SELECT
        merchant_id,
        MAX(merchant_name) AS merchant_name,
        MAX(city) AS city,
        MAX(country) AS country,

        COUNT(*) AS attempted_txns,
        SUM(amount_usd) AS attempted_usd,

        SUM(CASE WHEN status_norm = 'SETTLED' THEN 1 ELSE 0 END) AS settled_txns,
        SUM(CASE WHEN status_norm = 'SETTLED' THEN amount_usd ELSE 0 END) AS settled_usd,

        SUM(CASE WHEN status_norm IN ('DECLINED','FAILED') THEN 1 ELSE 0 END) AS declined_txns,
        SUM(CASE WHEN status_norm IN ('DECLINED','FAILED') THEN amount_usd ELSE 0 END) AS declined_usd,

        -- reversals: either explicitly REVERSED or referencing an original txn
        SUM(CASE WHEN status_norm = 'REVERSED' OR reversal_of_txn_id IS NOT NULL THEN 1 ELSE 0 END) AS reversed_txns,
        SUM(CASE WHEN status_norm = 'REVERSED' OR reversal_of_txn_id IS NOT NULL THEN amount_usd ELSE 0 END) AS reversed_usd,

        SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_txns,
        SUM(CASE WHEN is_fraud = 1 THEN amount_usd ELSE 0 END) AS fraud_usd,

        COUNT(DISTINCT customer_id) AS unique_customers,
        AVG(CASE WHEN status_norm = 'SETTLED' THEN amount_usd END) AS avg_ticket_usd
    FROM base
    GROUP BY merchant_id
)
SELECT
    a.merchant_id,
    a.merchant_name,
    a.city,
    a.country,

    a.attempted_txns,
    a.attempted_usd,
    a.settled_txns,
    a.settled_usd,

    -- operational quality rates
    a.declined_txns,
    CAST(100.0 * a.declined_txns / NULLIF(a.attempted_txns, 0) AS decimal(10,2)) AS decline_rate_pct,

    a.reversed_txns,
    CAST(100.0 * a.reversed_txns / NULLIF(a.settled_txns, 0) AS decimal(10,2)) AS reversal_rate_pct,

    -- risk quality
    a.fraud_txns,
    CAST(100.0 * a.fraud_txns / NULLIF(a.attempted_txns, 0) AS decimal(10,2)) AS fraud_rate_pct,

    -- customer + commercial
    a.unique_customers,
    CAST(ISNULL(rs.repeat_customers, 0) AS int) AS repeat_customers,
    CAST(100.0 * ISNULL(rs.repeat_customers, 0) / NULLIF(ISNULL(rs.customers_with_settled, 0), 0) AS decimal(10,2)) AS repeat_customer_rate_pct,

    CAST(a.avg_ticket_usd AS decimal(12,2)) AS avg_ticket_usd,

    -- net USD (simple approach): settled minus reversed USD
    CAST((a.settled_usd - a.reversed_usd) AS decimal(18,2)) AS net_settled_usd,

    -- simple quality score (tweak weights as you like)
    CAST(
      100
      - (2.0 * (100.0 * a.fraud_txns / NULLIF(a.attempted_txns, 0)))
      - (1.0 * (100.0 * a.declined_txns / NULLIF(a.attempted_txns, 0)))
      - (1.0 * (100.0 * a.reversed_txns / NULLIF(a.settled_txns, 0)))
      AS decimal(10,2)
    ) AS quality_score,

    -- quick flags
    CASE
      WHEN (1.0 * a.fraud_txns / NULLIF(a.attempted_txns, 0)) >= 0.02 THEN 'HIGH_FRAUD'
      WHEN (1.0 * a.declined_txns / NULLIF(a.attempted_txns, 0)) >= 0.15 THEN 'HIGH_DECLINE'
      WHEN (1.0 * a.reversed_txns / NULLIF(a.settled_txns, 0)) >= 0.05 THEN 'HIGH_REVERSAL'
      ELSE 'OK'
    END AS primary_flag

FROM agg a
LEFT JOIN repeat_stats rs
  ON rs.merchant_id = a.merchant_id
WHERE a.attempted_txns >= 50
ORDER BY quality_score ASC, a.attempted_txns DESC;
