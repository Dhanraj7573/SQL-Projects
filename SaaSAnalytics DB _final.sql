
CREATE DATABASE SaaSAnalyticsDB;
GO

USE SaaSAnalyticsDB;
GO

-- Users
CREATE TABLE dbo.users (
  user_id            INT IDENTITY(1,1) PRIMARY KEY,
  signup_date        DATE NOT NULL,
  country            VARCHAR(50) NOT NULL,
  acquisition_channel VARCHAR(50) NOT NULL
);

-- Plans
CREATE TABLE dbo.plans (
  plan_id        INT IDENTITY(1,1) PRIMARY KEY,
  plan_name      VARCHAR(50) NOT NULL UNIQUE,
  monthly_price  DECIMAL(10,2) NOT NULL
);

-- Subscriptions (one user can have multiple over time)
CREATE TABLE dbo.subscriptions (
  subscription_id INT IDENTITY(1,1) PRIMARY KEY,
  user_id         INT NOT NULL,
  plan_id         INT NOT NULL,
  start_date      DATE NOT NULL,
  end_date        DATE NULL,
  status          VARCHAR(20) NOT NULL, -- TRIAL/ACTIVE/CANCELLED/PAST_DUE
  CONSTRAINT FK_sub_user FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
  CONSTRAINT FK_sub_plan FOREIGN KEY (plan_id) REFERENCES dbo.plans(plan_id)
);

-- Payments
CREATE TABLE dbo.payments (
  payment_id      INT IDENTITY(1,1) PRIMARY KEY,
  subscription_id INT NOT NULL,
  payment_date    DATE NOT NULL,
  amount          DECIMAL(10,2) NOT NULL,
  status          VARCHAR(20) NOT NULL, -- PAID/FAILED/REFUNDED
  CONSTRAINT FK_pay_sub FOREIGN KEY (subscription_id) REFERENCES dbo.subscriptions(subscription_id)
);

-- Feature usage (event-ish table)
CREATE TABLE dbo.feature_usage (
  usage_id     BIGINT IDENTITY(1,1) PRIMARY KEY,
  user_id      INT NOT NULL,
  feature_name VARCHAR(50) NOT NULL,
  usage_date   DATE NOT NULL,
  usage_count  INT NOT NULL,
  CONSTRAINT FK_usage_user FOREIGN KEY (user_id) REFERENCES dbo.users(user_id)
);
CREATE INDEX IX_subscriptions_user_dates ON dbo.subscriptions(user_id, start_date, end_date);
CREATE INDEX IX_payments_date ON dbo.payments(payment_date);
CREATE INDEX IX_feature_usage_user_date ON dbo.feature_usage(user_id, usage_date);

insert into dbo.plans (plan_name, monthly_price)
values
('Free', 0.00),
('Basic', 19.00),
('pro', 49.00),
('Business', 99.00);

select * from dbo.plans

SELECT DB_NAME() AS current_db;
SELECT OBJECT_ID('dbo.users') AS users_object_id;
;WITH n AS (SELECT TOP (500) 1 AS x FROM sys.all_objects a CROSS JOIN sys.all_objects b) SELECT COUNT(*) AS rows_generated FROM n;


set nocount off;

;with n as (
   select Top(500) ROW_NUMBER() over (order by (select null)) as rn
   from sys.all_objects a 
   cross join sys.all_columns b
),
r as (
   select 
   ABS(checksum(newID())) % 365 as day_back,
   ABS(checksum(newID())) % 5 as country_bucket,
   ABS(checksum(newID())) % 4 channel_bucket
from n
)
Insert into dbo.users (signup_date, country, acquisition_channel)
select 
   DATEADD(day, day_back, cast(getdate() as date)) as signup_date,

   case country_bucket
     when 0 then 'US'
     when 1 then 'UK'
     when 2 then 'IN'
     when 3 then 'CA'
     ELSE 'DE'
   END as country,

   case channel_bucket
     when 0 then 'Organic'
     when 1 then 'Paid Search'
     when 2 then 'Referral'
     ELSE 'outbound'
   END as acquisition_channel
From r


SELECT @@ROWCOUNT AS rows_inserted;
SELECT COUNT(*) AS total_users FROM dbo.users;
SELECT * FROM dbo.users ORDER BY user_id DESC;

delete from dbo.payments;
delete from dbo.subscriptions;


insert into dbo.subscriptions (user_id, plan_id, start_date, end_date, status)

select 
  u.user_id,

  case 
    when ABS(checksum(newid())) % 10 < 4 then 1  --Free 40%
    when ABS(checksum(newid())) % 10 < 7 then 2  --basic 30%
    when ABS(checksum(newid())) % 10 < 9 then 3  --pro 20%
    else 4
 END AS plan_id,

 u.signup_date as start_date,
 --some users churn
 case 
   when ABS(checksum(newid())) % 10 < 3 
      then DATEADD (DAY, 30 + ABS(checksum(newid())) % 120, u.signup_date)
    ELSE Null
   END AS end_Date,

 case 
    when ABS(checksum(newid())) % 10 < 3 THEN 'CANCELLED'
    else 'ACTIVE'
 END as status
 
 from dbo.users u;



 select status, count(*)
 from dbo.subscriptions
 group by status


 select p.plan_name, count(*)
 from dbo.subscriptions s
 join dbo.plans p on s.plan_id = p.plan_id
 group by p.plan_name;

 INSERT INTO dbo.payments (subscription_id, payment_date, amount, status)
SELECT
    s.subscription_id,
    DATEADD(DAY, 30, s.start_date),
    p.monthly_price,
    CASE 
        WHEN ABS(CHECKSUM(NEWID())) % 20 = 0 THEN 'FAILED'
        ELSE 'PAID'
    END
FROM dbo.subscriptions s
JOIN dbo.plans p ON s.plan_id = p.plan_id
WHERE p.monthly_price > 0;

SELECT status, COUNT(*) 
FROM dbo.payments
GROUP BY status;


SELECT
    DATEFROMPARTS(YEAR(payment_date), MONTH(payment_date), 1) AS revenue_month,
    SUM(CASE WHEN status = 'PAID' THEN amount ELSE 0 END) AS mrr
FROM dbo.payments
GROUP BY DATEFROMPARTS(YEAR(payment_date), MONTH(payment_date), 1)
ORDER BY
tatus = 'CANCELLED'
  AND end_date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(end_date), MONTH(end_date), 1)
ORDER BY churn_month;

SELECT
    COUNT(*) AS active_subscribers
FROM dbo.subscriptions
WHERE status = 'ACTIVE';


WITH months AS (
    SELECT DISTINCT
        DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1) AS month_start
    FROM dbo.subscriptions
)
SELECT
    m.month_start,
    COUNT(*) AS active_subscribers
FROM months m
JOIN dbo.subscriptions s
    ON s.start_date <= EOMONTH(m.month_start)
    AND (s.end_date IS NULL OR s.end_date > m.month_start)
GROUP BY m.month_start
ORDER BY m.month_start;

WITH churns AS (
    SELECT
        DATEFROMPARTS(YEAR(end_date), MONTH(end_date), 1) AS month_start,
        COUNT(*) AS churned
    FROM dbo.subscriptions
    WHERE status = 'CANCELLED'
      AND end_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(end_date), MONTH(end_date), 1)
),
active_base AS (
    SELECT
        DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1) AS month_start,
        COUNT(*) AS active_count
    FROM dbo.subscriptions
    GROUP BY DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1)
)
SELECT
    c.month_start,
    c.churned,
    a.active_count,
    CAST(100.0 * c.churned / NULLIF(a.active_count,0) AS decimal(10,2)) AS churn_rate_pct
FROM churns c
JOIN active_base a ON c.month_start = a.month_start
ORDER BY c.month_start;


WITH churns AS (
    SELECT
        DATEFROMPARTS(YEAR(end_date), MONTH(end_date), 1) AS month_start,
        COUNT(*) AS churned
    FROM dbo.subscriptions
    WHERE status = 'CANCELLED'
      AND end_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(end_date), MONTH(end_date), 1)
),
active_base AS (
    SELECT
        DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1) AS month_start,
        COUNT(*) AS active_count
    FROM dbo.subscriptions
    GROUP BY DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1)
)
SELECT
    c.month_start,
    c.churned,
    a.active_count,
    CAST(100.0 * c.churned / NULLIF(a.active_count,0) AS decimal(10,2)) AS churn_rate_pct
FROM churns c
JOIN active_base a ON c.month_start = a.month_start
ORDER BY c.month_start;

WITH avg_revenue AS (
    SELECT AVG(amount) AS avg_payment
    FROM dbo.payments
    WHERE status='PAID'
),
churn_rate AS (
    SELECT
        CAST(AVG(CASE WHEN status='CANCELLED' THEN 1.0 ELSE 0 END) AS decimal(10,4)) AS avg_churn
    FROM dbo.subscriptions
)
SELECT
    a.avg_payment,
    c.avg_churn,
    CASE 
        WHEN c.avg_churn > 0 THEN a.avg_payment / c.avg_churn
        ELSE NULL
    END AS estimated_ltv
FROM avg_revenue a
CROSS JOIN churn_rate c;


WITH cohorts AS (
  SELECT
    u.user_id,
    DATEFROMPARTS(YEAR(u.signup_date), MONTH(u.signup_date), 1) AS cohort_month
  FROM dbo.users u
),
months AS (
  -- months to evaluate based on subscription activity (could use payments too)
  SELECT DISTINCT DATEFROMPARTS(YEAR(s.start_date), MONTH(s.start_date), 1) AS month_start
  FROM dbo.subscriptions s
  UNION
  SELECT DISTINCT DATEFROMPARTS(YEAR(s.end_date), MONTH(s.end_date), 1)
  FROM dbo.subscriptions s
  WHERE s.end_date IS NOT NULL
),
active_by_month AS (
  -- user is active in a month if subscription overlaps that month
  SELECT
    c.user_id,
    c.cohort_month,
    m.month_start,
    DATEDIFF(MONTH, c.cohort_month, m.month_start) AS month_number
  FROM cohorts c
  JOIN months m
    ON m.month_start >= c.cohort_month
  JOIN dbo.subscriptions s
    ON s.user_id = c.user_id
   AND s.start_date <= EOMONTH(m.month_start)
   AND (s.end_date IS NULL OR s.end_date > EOMONTH(m.month_start))
),
cohort_sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_size
  FROM cohorts
  GROUP BY cohort_month
),
retention AS (
  SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT user_id) AS active_users
  FROM active_by_month
  GROUP BY cohort_month, month_number
)
SELECT
  r.cohort_month,
  r.month_number,
  cs.cohort_size,
  r.active_users,
  CAST(100.0 * r.active_users / NULLIF(cs.cohort_size,0) AS decimal(10,2)) AS retention_pct
FROM retention r
JOIN cohort_sizes cs ON cs.cohort_month = r.cohort_month
WHERE r.month_number BETWEEN 0 AND 12
ORDER BY r.cohort_month, r.month_number;


WITH base AS (
  -- use the output of the previous query as a base (retention_pct by cohort_month/month_number)
  WITH cohorts AS (
    SELECT u.user_id, DATEFROMPARTS(YEAR(u.signup_date), MONTH(u.signup_date), 1) AS cohort_month
    FROM dbo.users u
  ),
  months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR(s.start_date), MONTH(s.start_date), 1) AS month_start
    FROM dbo.subscriptions s
    UNION
    SELECT DISTINCT DATEFROMPARTS(YEAR(s.end_date), MONTH(s.end_date), 1)
    FROM dbo.subscriptions s
    WHERE s.end_date IS NOT NULL
  ),
  active_by_month AS (
    SELECT
      c.user_id,
      c.cohort_month,
      m.month_start,
      DATEDIFF(MONTH, c.cohort_month, m.month_start) AS month_number
    FROM cohorts c
    JOIN months m ON m.month_start >= c.cohort_month
    JOIN dbo.subscriptions s
      ON s.user_id = c.user_id
     AND s.start_date <= EOMONTH(m.month_start)
     AND (s.end_date IS NULL OR s.end_date > EOMONTH(m.month_start))
  ),
  cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
  ),
  retention AS (
    SELECT cohort_month, month_number, COUNT(DISTINCT user_id) AS active_users
    FROM active_by_month
    GROUP BY cohort_month, month_number
  )
  SELECT
    r.cohort_month,
    r.month_number,
    CAST(100.0 * r.active_users / NULLIF(cs.cohort_size,0) AS decimal(10,2)) AS retention_pct
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
FROM base
GROUP BY cohort_month
ORDER BY cohort_month;


WITH user_revenue AS (
  SELECT
    s.user_id,
    SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) AS lifetime_revenue
  FROM dbo.subscriptions s
  JOIN dbo.payments p ON p.subscription_id = s.subscription_id
  GROUP BY s.user_id
),
user_lifetime AS (
  SELECT
    user_id,
    DATEDIFF(DAY, MIN(start_date), COALESCE(MAX(end_date), CAST(GETDATE() AS date))) AS lifetime_days
  FROM dbo.subscriptions
  GROUP BY user_id
)
SELECT TOP 100
  u.user_id,
  u.acquisition_channel,
  u.country,
  ur.lifetime_revenue,
  ul.lifetime_days,
  CAST(ur.lifetime_revenue / NULLIF(ul.lifetime_days, 0) AS decimal(10,4)) AS revenue_per_day
FROM dbo.users u
LEFT JOIN user_revenue ur ON ur.user_id = u.user_id
LEFT JOIN user_lifetime ul ON ul.user_id = u.user_id
ORDER BY ur.lifetime_revenue DESC;

SELECT
  u.acquisition_channel,
  SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) AS total_revenue,
  COUNT(DISTINCT u.user_id) AS users,
  CAST(SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) / NULLIF(COUNT(DISTINCT u.user_id),0) AS decimal(10,2)) AS revenue_per_user
FROM dbo.users u
LEFT JOIN dbo.subscriptions s ON s.user_id = u.user_id
LEFT JOIN dbo.payments p ON p.subscription_id = s.subscription_id
GROUP BY u.acquisition_channel
ORDER BY total_revenue DESC;

SELECT
  DATEFROMPARTS(YEAR(p.payment_date), MONTH(p.payment_date), 1) AS revenue_month,
  u.acquisition_channel,
  SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) AS revenue
FROM dbo.payments p
JOIN dbo.subscriptions s ON s.subscription_id = p.subscription_id
JOIN dbo.users u ON u.user_id = s.user_id
GROUP BY
  DATEFROMPARTS(YEAR(p.payment_date), MONTH(p.payment_date), 1),
  u.acquisition_channel
ORDER BY revenue_month, revenue DESC;

WITH trial_users AS (
  SELECT DISTINCT user_id
  FROM dbo.subscriptions
  WHERE status = 'TRIAL'
),
paid_users AS (
  SELECT DISTINCT s.user_id
  FROM dbo.subscriptions s
  JOIN dbo.payments p ON p.subscription_id = s.subscription_id
  WHERE p.status = 'PAID'
)
SELECT
  u.acquisition_channel,
  COUNT(DISTINCT t.user_id) AS trial_users,
  COUNT(DISTINCT CASE WHEN pu.user_id IS NOT NULL THEN t.user_id END) AS converted_users,
  CAST(
    100.0 * COUNT(DISTINCT CASE WHEN pu.user_id IS NOT NULL THEN t.user_id END) / NULLIF(COUNT(DISTINCT t.user_id),0)
    AS decimal(10,2)
  ) AS trial_to_paid_conversion_pct
FROM trial_users t
JOIN dbo.users u ON u.user_id = t.user_id
LEFT JOIN paid_users pu ON pu.user_id = t.user_id
GROUP BY u.acquisition_channel
ORDER BY trial_to_paid_conversion_pct DESC;


---Helper: Month calendar view (makes everything consistent)


IF OBJECT_ID('dbo.v_months', 'V') IS NOT NULL
  DROP VIEW dbo.v_months;
GO

CREATE VIEW dbo.v_months AS
WITH d AS (
  SELECT
    DATEFROMPARTS(YEAR(MIN(s.start_date)), MONTH(MIN(s.start_date)), 1) AS month_start,
    DATEFROMPARTS(YEAR(MAX(COALESCE(s.end_date, CAST(GETDATE() AS date)))), MONTH(MAX(COALESCE(s.end_date, CAST(GETDATE() AS date)))), 1) AS month_end
  FROM dbo.subscriptions s
),
m AS (
  SELECT month_start FROM d
  UNION ALL
  SELECT DATEADD(MONTH, 1, month_start)
  FROM m
  CROSS JOIN d
  WHERE month_start < d.month_end
)
SELECT month_start FROM m;
GO

---Monthly MRR

IF OBJECT_ID('dbo.v_monthly_mrr', 'V') IS NOT NULL
  DROP VIEW dbo.v_monthly_mrr;
GO

CREATE VIEW dbo.v_monthly_mrr AS
SELECT
  DATEFROMPARTS(YEAR(p.payment_date), MONTH(p.payment_date), 1) AS month_start,
  SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) AS mrr
FROM dbo.payments p
GROUP BY DATEFROMPARTS(YEAR(p.payment_date), MONTH(p.payment_date), 1);
GO


---IF OBJECT_ID('dbo.v_monthly_active_subscribers', 'V') IS NOT NULL
  DROP VIEW dbo.v_monthly_active_subscribers;
GO

CREATE VIEW dbo.v_monthly_active_subscribers AS
SELECT
  m.month_start,
  COUNT(DISTINCT s.user_id) AS active_subscribers
FROM dbo.v_months m
JOIN dbo.subscriptions s
  ON s.start_date <= EOMONTH(m.month_start)
 AND (s.end_date IS NULL OR s.end_date > EOMONTH(m.month_start))
GROUP BY m.month_start;
GO

IF OBJECT_ID('dbo.v_monthly_churn_rate', 'V') IS NOT NULL
  DROP VIEW dbo.v_monthly_churn_rate;
GO

CREATE VIEW dbo.v_monthly_churn_rate AS
WITH churned AS (
  SELECT
    DATEFROMPARTS(YEAR(s.end_date), MONTH(s.end_date), 1) AS month_start,
    COUNT(DISTINCT s.user_id) AS churned_users
  FROM dbo.subscriptions s
  WHERE s.status='CANCELLED'
    AND s.end_date IS NOT NULL
  GROUP BY DATEFROMPARTS(YEAR(s.end_date), MONTH(s.end_date), 1)
),
active_start AS (
  SELECT
    m.month_start,
    COUNT(DISTINCT s.user_id) AS active_at_start
  FROM dbo.v_months m
  JOIN dbo.subscriptions s
    ON s.start_date < m.month_start
   AND (s.end_date IS NULL OR s.end_date >= m.month_start)
  GROUP BY m.month_start
)
SELECT
  a.month_start,
  COALESCE(c.churned_users, 0) AS churned_users,
  a.active_at_start,
  CAST(100.0 * COALESCE(c.churned_users, 0) / NULLIF(a.active_at_start, 0) AS decimal(10,2)) AS churn_rate_pct
FROM active_start a
LEFT JOIN churned c ON c.month_start = a.month_start;
GO

---Cohort retention view (signup cohort → active by month_number)

IF OBJECT_ID('dbo.v_cohort_retention', 'V') IS NOT NULL
  DROP VIEW dbo.v_cohort_retention;
GO

CREATE VIEW dbo.v_cohort_retention AS
WITH cohorts AS (
  SELECT
    u.user_id,
    DATEFROMPARTS(YEAR(u.signup_date), MONTH(u.signup_date), 1) AS cohort_month
  FROM dbo.users u
),
active_by_month AS (
  SELECT
    c.user_id,
    c.cohort_month,
    m.month_start,
    DATEDIFF(MONTH, c.cohort_month, m.month_start) AS month_number
  FROM cohorts c
  JOIN dbo.v_months m
    ON m.month_start >= c.cohort_month
  JOIN dbo.subscriptions s
    ON s.user_id = c.user_id
   AND s.start_date <= EOMONTH(m.month_start)
   AND (s.end_date IS NULL OR s.end_date > EOMONTH(m.month_start))
),
cohort_sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_size
  FROM cohorts
  GROUP BY cohort_month
),
retention AS (
  SELECT cohort_month, month_number, COUNT(DISTINCT user_id) AS active_users
  FROM active_by_month
  GROUP BY cohort_month, month_number
)
SELECT
  r.cohort_month,
  r.month_number,
  cs.cohort_size,
  r.active_users,
  CAST(100.0 * r.active_users / NULLIF(cs.cohort_size,0) AS decimal(10,2)) AS retention_pct
FROM retention r
JOIN cohort_sizes cs ON cs.cohort_month = r.cohort_month;
GO

---IF OBJECT_ID('dbo.v_user_ltv_realized', 'V') IS NOT NULL
  DROP VIEW dbo.v_user_ltv_realized;
GO

CREATE VIEW dbo.v_user_ltv_realized AS
SELECT
  u.user_id,
  u.acquisition_channel,
  u.country,
  SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) AS lifetime_revenue
FROM dbo.users u
LEFT JOIN dbo.subscriptions s ON s.user_id = u.user_id
LEFT JOIN dbo.payments p ON p.subscription_id = s.subscription_id
GROUP BY u.user_id, u.acquisition_channel, u.country;
GO

IF OBJECT_ID('dbo.v_user_ltv_realized', 'V') IS NOT NULL
  DROP VIEW dbo.v_user_ltv_realized;
GO

CREATE VIEW dbo.v_user_ltv_realized AS
SELECT
  u.user_id,
  u.acquisition_channel,
  u.country,
  SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) AS lifetime_revenue
FROM dbo.users u
LEFT JOIN dbo.subscriptions s ON s.user_id = u.user_id
LEFT JOIN dbo.payments p ON p.subscription_id = s.subscription_id
GROUP BY u.user_id, u.acquisition_channel, u.country;
GO

SELECT
  u.acquisition_channel,
  SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) AS total_revenue,
  AVG(CAST(l.lifetime_revenue AS decimal(18,2))) AS avg_ltv
FROM dbo.users u
LEFT JOIN dbo.subscriptions s ON s.user_id = u.user_id
LEFT JOIN dbo.payments p ON p.subscription_id = s.subscription_id
LEFT JOIN dbo.v_user_ltv_realized l ON l.user_id = u.user_id
GROUP BY u.acquisition_channel
ORDER BY total_revenue DESC


SELECT
  u.acquisition_channel,
  SUM(CASE WHEN p.status='PAID' THEN p.amount ELSE 0 END) AS total_revenue,
  AVG(CAST(l.lifetime_revenue AS decimal(18,2))) AS avg_ltv
FROM dbo.users u
LEFT JOIN dbo.subscriptions s ON s.user_id = u.user_id
LEFT JOIN dbo.payments p ON p.subscription_id = s.subscription_id
LEFT JOIN dbo.v_user_ltv_realized l ON l.user_id = u.user_id
GROUP BY u.acquisition_channel
ORDER BY total_revenue DESC;;