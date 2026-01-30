
--Fraud KPI by channel
SELECT
  channel,
  COUNT(*) AS txns,
  SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_txns,
  ROUND(100.0 * AVG(CASE WHEN is_fraud = 1 THEN 1.0 ELSE 0.0 END), 3) AS fraud_rate_pct
FROM dbo.v_transactions_clean
GROUP BY channel
ORDER BY fraud_rate_pct DESC, txns DESC;

---Fraud by risk segment
SELECT
  c.risk_segment,
  COUNT(*) AS txns,
  SUM(CASE WHEN t.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_txns,
  ROUND(100.0 * AVG(CASE WHEN t.is_fraud = 1 THEN 1.0 ELSE 0.0 END), 3) AS fraud_rate_pct
FROM dbo.v_transactions_clean t
JOIN dbo.accounts_ a ON a.account_id = t.account_id
JOIN dbo.customers_ c ON c.customer_id = a.customer_id
GROUP BY c.risk_segment
ORDER BY fraud_rate_pct DESC;

--Merchant risk leaderboard (min volume filter)
WITH m AS (
  SELECT
    t.merchant_id,
    COUNT(*) AS txns,
    SUM(CASE WHEN t.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_txns,
    AVG(CASE WHEN t.is_fraud = 1 THEN 1.0 ELSE 0.0 END) AS fraud_rate
  FROM dbo.v_transactions_clean t
  WHERE t.merchant_id IS NOT NULL
  GROUP BY t.merchant_id
)
SELECT TOP 20
  me.merchant_name,
  me.country,
  m.txns,
  m.fraud_txns,
  ROUND(100.0 * m.fraud_rate, 3) AS fraud_rate_pct
FROM m
JOIN dbo.merchants_ me ON me.merchant_id = m.merchant_id
WHERE m.txns >= 50
ORDER BY m.fraud_rate DESC, m.txns DESC;

=sdlkflsdj