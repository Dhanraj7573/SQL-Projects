;WITH order_fact AS (
    SELECT
        h.SalesOrderID,
        h.CustomerID,
        DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1) AS OrderMonth,
        h.TerritoryID,
        h.OnlineOrderFlag,
        SUM(d.LineTotal) AS OrderRevenue
    FROM Sales.SalesOrderHeader h
    JOIN Sales.SalesOrderDetail d
        ON d.SalesOrderID = h.SalesOrderID
    GROUP BY
        h.SalesOrderID,
        h.CustomerID,
        DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1),
        h.TerritoryID,
        h.OnlineOrderFlag
),
first_month AS (
    SELECT CustomerID, MIN(OrderMonth) AS CohortMonth
    FROM order_fact
    GROUP BY CustomerID
),
cohort_activity AS (
    SELECT
        fm.CohortMonth,
        ofc.OrderMonth,
        DATEDIFF(month, fm.CohortMonth, ofc.OrderMonth) AS MonthIndex,
        ofc.CustomerID
    FROM order_fact ofc
    JOIN first_month fm
        ON fm.CustomerID = ofc.CustomerID
),
cohort_counts AS (
    SELECT
        CohortMonth,
        MonthIndex,
        COUNT(DISTINCT CustomerID) AS ActiveCustomers
    FROM cohort_activity
    GROUP BY CohortMonth, MonthIndex
),
cohort_size AS (
    SELECT
        CohortMonth,
        COUNT(DISTINCT CustomerID) AS CohortCustomers
    FROM cohort_activity
    WHERE MonthIndex = 0
    GROUP BY CohortMonth
)
SELECT
    c.CohortMonth,
    c.MonthIndex,
    c.ActiveCustomers,
    s.CohortCustomers,
    CAST(c.ActiveCustomers * 1.0 / NULLIF(s.CohortCustomers, 0) AS decimal(10,4)) AS RetentionRate
FROM cohort_counts c
JOIN cohort_size s
    ON s.CohortMonth = c.CohortMonth
WHERE c.MonthIndex BETWEEN 0 AND 12
ORDER BY c.CohortMonth, c.MonthIndex;

   