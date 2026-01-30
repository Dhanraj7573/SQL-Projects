--Q - Lending health: “Are loans being repaid properly?

--Loan book summary

SELECT
  status,
  COUNT(*) AS loans,
  SUM(principal) AS total_principal,
  AVG(interest_rate) AS avg_rate,
  AVG(term_months) AS avg_term
FROM dbo.loans_
GROUP BY status
ORDER BY loans DESC;

--Payment coverage per loan

select 
     l.loan_id,
     l.customer_id,
     l.status,
     l.principal,
     COALESCE(sum(case when lp.status = 'Paid' then lp.amount END),0) AS total_paid,
     round(
            100.0* COALESCE(SUM(CASE WHEN lp.status = 'paid' then lp.amount END),0) / Nullif(l.principal, 0),
            2
           ) AS pct_principal_paid
from dbo.loans_ l
left join dbo.loan_payments_ lp on lp.loan_id = l.loan_id
group by l.loan_id, l.customer_id, l.status, l.principal
order by Pct_principal_paid ASC;

--Customers with loans + no payments (red flag list)

SELECT TOP 50
  l.customer_id,
  COUNT(*) AS loans,
  SUM(l.principal) AS total_principal
FROM dbo.loans_ l
LEFT JOIN dbo.loan_payments_ lp ON lp.loan_id = l.loan_id
WHERE lp.loan_id IS NULL
GROUP BY l.customer_id
ORDER BY total_principal DESC;
