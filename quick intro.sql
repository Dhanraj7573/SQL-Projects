--Monthly trend
SELECT
  txn_month,
  COUNT(*) AS txn_count,
  SUM(amount_usd) AS total_usd,
  AVG(amount_usd) AS avg_usd
FROM dbo.v_transactions_clean
WHERE status = 'SETTLED'
GROUP BY txn_month
ORDER BY txn_month;

---Mix by channel + type
SELECT
  txn_month,
  channel,
  txn_type,
  COUNT(*) AS txn_count,
  SUM(amount_usd) AS total_usd
FROM dbo.v_transactions_clean
WHERE status = 'SETTLED'
GROUP BY txn_month, channel, txn_type
ORDER BY txn_month, total_usd DESC;

--Customer value (Top 50)
SELECT TOP 50
  c.customer_id,
  c.risk_segment,
  c.country,
  COUNT(*) AS txn_count,
  SUM(t.amount_usd) AS total_usd
FROM dbo.v_transactions_clean t
JOIN dbo.accounts_ a ON a.account_id = t.account_id
JOIN dbo.customers_ c ON c.customer_id = a.customer_id
WHERE t.status = 'SETTLED'
GROUP BY c.customer_id, c.risk_segment, c.country
ORDER BY total_usd DESC;
