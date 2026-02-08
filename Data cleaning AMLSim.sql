---Row counts (control totals baseline)

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM dbo.customers
UNION ALL SELECT 'accounts', COUNT(*) FROM dbo.accounts
UNION ALL SELECT 'transactions', COUNT(*) FROM dbo.transactions
UNION ALL SELECT 'alerts', COUNT(*) FROM dbo.alerts
UNION ALL SELECT 'alert_members', COUNT(*) FROM dbo.alert_members;

-- Primary key duplicate checks

select customer_id, count(*) as cnt
from dbo.customers
group by customer_id
having count(*)>1

select account_id, count(*) as cnt
from dbo.accounts
group by account_id
having count(*)>1

SELECT tx_id, COUNT(*) AS cnt
FROM dbo.transactions
GROUP BY tx_id
HAVING COUNT(*) > 1;

SELECT tx_id, COUNT(*) AS cnt
FROM dbo.transactions
GROUP BY tx_id
HAVING COUNT(*) > 1;

---Null / blank checks on key fields

-- Customers: key fields
SELECT
  SUM(CASE WHEN customer_id IS NULL OR LTRIM(RTRIM(customer_id)) = '' THEN 1 ELSE 0 END) AS bad_customer_id,
  SUM(CASE WHEN full_name   IS NULL OR LTRIM(RTRIM(full_name))   = '' THEN 1 ELSE 0 END) AS bad_full_name
FROM dbo.customers;

-- Accounts
SELECT
  SUM(CASE WHEN account_id  IS NULL OR LTRIM(RTRIM(account_id))  = '' THEN 1 ELSE 0 END) AS bad_account_id,
  SUM(CASE WHEN customer_id IS NULL OR LTRIM(RTRIM(customer_id)) = '' THEN 1 ELSE 0 END) AS bad_customer_id
FROM dbo.accounts;

-- Transactions
SELECT
  SUM(CASE WHEN tx_id IS NULL OR LTRIM(RTRIM(tx_id)) = '' THEN 1 ELSE 0 END) AS bad_tx_id,
  SUM(CASE WHEN sender_account_id IS NULL OR LTRIM(RTRIM(sender_account_id)) = '' THEN 1 ELSE 0 END) AS bad_sender,
  SUM(CASE WHEN receiver_account_id IS NULL OR LTRIM(RTRIM(receiver_account_id)) = '' THEN 1 ELSE 0 END) AS bad_receiver,
  SUM(CASE WHEN tx_timestamp IS NULL OR LTRIM(RTRIM(tx_timestamp)) = '' THEN 1 ELSE 0 END) AS bad_timestamp
FROM dbo.transactions;

---Referential integrity (“orphan records”)

select top 50 a.*
from dbo.accounts a 
left join dbo.customers c on c.customer_id = a.customer_id
where c.customer_id is null;

select top 50 t.*
from dbo.transactions t
left join dbo.accounts a1 on a1.account_id = t.sender_account_id
left join dbo.accounts a2 on a2.account_id = t.receiver_account_id
where a1.account_id is null or a2.account_id is null;

SELECT TOP 50 am.*
FROM dbo.alert_members am
LEFT JOIN dbo.alerts al ON al.alert_id = am.alert_id
WHERE al.alert_id IS NULL;

-- Alert members whose account_id doesn't exist
SELECT TOP 50 am.*
FROM dbo.alert_members am
LEFT JOIN dbo.accounts a ON a.account_id = am.account_id
WHERE a.account_id IS NULL;

---Datatype / parsing checks (timestamp + amount)

select top 50 tx_id, tx_amount
from dbo.transactions
where tx_amount is not null
  and TRY_CONVERT(decimal(18,2), tx_amount) is null;

select top 50 tx_id, tx_timestamp
from dbo.transactions
where tx_timestamp is not null
  and TRY_CONVERT(datetime2(0), tx_timestamp) is null

---Business-rule sanity checks

-- Negative or zero amounts (usually invalid unless you model reversals as negative)
SELECT TOP 50 tx_id, tx_amount, status
FROM dbo.transactions
WHERE TRY_CONVERT(decimal(18,2), tx_amount) <= 0;

-- Sender = Receiver (often invalid)
SELECT TOP 50 tx_id, sender_account_id, receiver_account_id, tx_amount
FROM dbo.transactions
WHERE sender_account_id = receiver_account_id;

-- Status distribution
SELECT status, COUNT(*) AS cnt
FROM dbo.transactions
GROUP BY status
ORDER BY cnt DESC;

-- Channel distribution
SELECT channel, COUNT(*) AS cnt
FROM dbo.transactions
GROUP BY channel
ORDER BY cnt DESC;

-- Currency distribution (if present)
SELECT currency, COUNT(*) AS cnt
FROM dbo.transactions
GROUP BY currency
ORDER BY cnt DESC;


---clean transactions” view

create or alter view dbo.vw_transaction_clean AS
select
  tx_id,
  TRY_CONVERT(datetime2(0), tx_timestamp) as tx_ts,
  sender_account_id,
  receiver_account_id,
  TRY_CONVERT(decimal(18,2), tx_amount) as tx_amount,
  currency,
  channel,
  status,
  merchant_category,
  reference
from dbo.transactions

--Daily control totals

select
  cast(tx_ts as date) as tx_date,
  channel,
  status,
  count(*) as tx_count,
  sum(tx_amount) as total_amount,
  sum(case when status = 'posted' then 1 else 0 end) as posted_count,
  sum(case when status = 'pending' then 1 else 0 end) as pending_count,
  sum(case when status = 'reversed' then 1 else 0 end) as reversed_count,
  cast(1.0 * sum(case when status = 'reversed' then 1 else 0 end) / nullif(count(*),0) as decimal(10,4)) as reversed_rate 
from dbo.vw_transaction_clean
where tx_ts is not null and tx_amount is not null
group by cast(tx_ts as date), channel, status
order by tx_date;