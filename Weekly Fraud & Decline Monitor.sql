--Weekly Fraud & Decline Monitor (KPI table)

SELECT
  DATEADD(DAY, 1 - DATEPART(WEEKDAY, txn_ts_parsed), CAST(txn_ts_parsed AS date)) AS week_start,
  channel,
  COUNT(*) AS attempted_txns,
  SUM(CASE WHEN status = 'SETTLED' THEN 1 ELSE 0 END) AS settled_txns,
  SUM(CASE WHEN status IN ('DECLINED','FAILED') THEN 1 ELSE 0 END) AS declined_txns,
  ROUND(100.0 * SUM(CASE WHEN status IN ('DECLINED','FAILED') THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 2) AS decline_rate_pct,
  SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_txns,
  ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 2) AS fraud_rate_pct,
  SUM(amount_usd) AS attempted_usd
FROM dbo.v_transactions_clean
WHERE txn_ts_parsed IS NOT NULL
GROUP BY DATEADD(DAY, 1 - DATEPART(WEEKDAY, txn_ts_parsed), CAST(txn_ts_parsed AS date)), channel
ORDER BY week_start, channel;


--Turn weekly KPI query into a view (reusable)


IF OBJECT_ID('dbo.v_weekly_kpi_channel', 'V') IS NOT NULL
    DROP VIEW dbo.v_weekly_kpi_channel;
GO

CREATE VIEW dbo.v_weekly_kpi_channel AS
SELECT 
  DATEADD(DAY, 1 - DATEPART(WEEKDAY, txn_ts_parsed), CAST(txn_ts_parsed AS date)) AS week_start,
  channel,
  COUNT(*) AS attempted_txns,
  SUM(CASE WHEN status = 'SETTLED' THEN 1 ELSE 0 END) AS settled_txns,
  SUM(CASE WHEN status IN ('DECLINED','FAILED') THEN 1 ELSE 0 END) AS declined_txns,
  CAST(100.0 * SUM(CASE WHEN status IN ('DECLINED','FAILED') THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(10,2)) AS declined_rate_pct,
  SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_txns,
  CAST(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(10,2)) AS fraud_rate_pct,
  SUM(amount_usd) AS attempted_usd
FROM dbo.v_transactions_clean
WHERE txn_ts_parsed IS NOT NULL
GROUP BY DATEADD(DAY, 1 - DATEPART(WEEKDAY, txn_ts_parsed), CAST(txn_ts_parsed AS date)), channel;
GO

SET DATEFIRST 1;  -- Monday
SELECT * FROM dbo.v_weekly_kpi_channel ORDER BY week_start, channel;



