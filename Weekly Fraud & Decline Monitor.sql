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

---trend view

IF OBJECT_ID('dbo.v_weekly_kpi_channel_trend', 'V') IS NOT NULL
    DROP VIEW dbo.v_weekly_kpi_channel_trend;
GO

CREATE VIEW dbo.v_weekly_kpi_channel_trend AS
WITH x AS (
    SELECT *
    FROM dbo.v_weekly_kpi_channel
)
SELECT
    week_start,
    channel,

    attempted_txns,
    attempted_usd,
    declined_rate_pct,
    fraud_rate_pct,

    LAG(attempted_txns) OVER (PARTITION BY channel ORDER BY week_start) AS prev_attempted_txns,
    LAG(attempted_usd)  OVER (PARTITION BY channel ORDER BY week_start) AS prev_attempted_usd,
    LAG(declined_rate_pct) OVER (PARTITION BY channel ORDER BY week_start) AS prev_declined_rate_pct,
    LAG(fraud_rate_pct)    OVER (PARTITION BY channel ORDER BY week_start) AS prev_fraud_rate_pct
FROM x;
GO

if object_id('dbo.v_weekly_kpi_channel_trend','V') is not null
    drop view dbo.v_weekly_kpi_channel_trend;
go

SELECT * 
FROM dbo.v_weekly_kpi_channel_trend
ORDER BY week_start, channel;

--Turn trends into alerts 

SELECT
    week_start,
    channel,
    attempted_txns,
    declined_rate_pct,
    fraud_rate_pct,

    CASE
        WHEN attempted_txns < 50 THEN 'LOW_VOLUME'
        WHEN prev_fraud_rate_pct IS NOT NULL
             AND fraud_rate_pct - prev_fraud_rate_pct >= 0.50
             THEN 'FRAUD_SPIKE'
        WHEN prev_declined_rate_pct IS NOT NULL
             AND declined_rate_pct - prev_declined_rate_pct >= 2.00
             THEN 'DECLINE_SPIKE'
        ELSE 'OK'
    END AS alert_flag
FROM dbo.v_weekly_kpi_channel_trend
ORDER BY week_start DESC, alert_flag DESC, channel;


