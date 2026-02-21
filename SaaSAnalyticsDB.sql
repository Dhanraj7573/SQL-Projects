
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
ORDER BY revenue_month;


SELECT
    DATEFROMPARTS(YEAR(end_date), MONTH(end_date), 1) AS churn_month,
    COUNT(*) AS churned_subscriptions
FROM dbo.subscriptions
WHERE status = 'CANCELLED'
  AND end_date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(end_date), MONTH(end_date), 1)
ORDER BY churn_month;

SELECT
    COUNT(*) AS active_subscribers
FROM dbo.subscriptions
WHERE status = 'ACTIVE';