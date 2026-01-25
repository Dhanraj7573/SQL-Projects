;WITH customer_dim AS (
    SELECT
        c.CustomerID,
        CASE
            WHEN c.PersonID IS NOT NULL THEN 'Individual'
            WHEN c.StoreID IS NOT NULL THEN 'Store'
            ELSE 'Unknown'
        END AS CustomerType
    FROM Sales.Customer c
),
order_fact AS (
    SELECT
        h.SalesOrderID,
        h.CustomerID,
        DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1) AS OrderMonth,
        h.TerritoryID,
        h.OnlineOrderFlag,
        SUM(d.LineTotal) AS OrderRevenue,
        AVG(CASE WHEN d.UnitPriceDiscount > 0 THEN 1.0 ELSE 0.0 END) AS DiscountedLinePct
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
        DATEDIFF(month, fm.CohortMonth, ofc.OrderMonth) AS MonthIndex,
        cd.CustomerType,
        ofc.CustomerID,
        ofc.SalesOrderID,
        ofc.OrderRevenue,
        ofc.OnlineOrderFlag,
        ofc.DiscountedLinePct
    FROM order_fact ofc
    JOIN first_month fm ON fm.CustomerID = ofc.CustomerID
    JOIN customer_dim cd ON cd.CustomerID = ofc.CustomerID
    WHERE DATEDIFF(month, fm.CohortMonth, ofc.OrderMonth) BETWEEN 0 AND 12
),
cohort_metrics AS (
    SELECT
        CohortMonth,
        CustomerType,
        MonthIndex,
        COUNT(DISTINCT CustomerID) AS ActiveCustomers,
        COUNT(DISTINCT SalesOrderID) AS ActiveOrders,
        SUM(OrderRevenue) AS Revenue,
        AVG(CASE WHEN OnlineOrderFlag = 1 THEN 1.0 ELSE 0.0 END) AS OnlineOrderPct,
        AVG(DiscountedLinePct) AS AvgDiscountedLinePct
    FROM cohort_activity
    GROUP BY CohortMonth, CustomerType, MonthIndex
),
cohort_base AS (
    SELECT
        CohortMonth,
        CustomerType,
        MAX(CASE WHEN MonthIndex = 0 THEN ActiveCustomers END) AS CohortCustomers,
        MAX(CASE WHEN MonthIndex = 0 THEN ActiveOrders END)    AS CohortOrders,
        MAX(CASE WHEN MonthIndex = 0 THEN Revenue END)         AS CohortRevenue
    FROM cohort_metrics
    GROUP BY CohortMonth, CustomerType
)
SELECT
    m.CohortMonth,
    m.CustomerType,
    m.MonthIndex,
    m.ActiveCustomers,
    b.CohortCustomers,
    m.ActiveOrders,
    m.Revenue,
    CAST(m.ActiveCustomers * 1.0 / NULLIF(b.CohortCustomers, 0) AS decimal(10,4)) AS CustomerRetentionRate,
    CAST(m.Revenue * 1.0 / NULLIF(b.CohortRevenue, 0) AS decimal(10,4)) AS RevenueRetentionRate,
    CAST(m.Revenue * 1.0 / NULLIF(m.ActiveOrders, 0) AS decimal(12,2)) AS AOV,
    CAST(m.ActiveOrders * 1.0 / NULLIF(m.ActiveCustomers, 0) AS decimal(12,4)) AS OrdersPerCustomer,
    CAST(m.OnlineOrderPct AS decimal(10,4)) AS OnlineOrderPct,
    CAST(m.AvgDiscountedLinePct AS decimal(10,4)) AS AvgDiscountedLinePct
FROM cohort_metrics m
JOIN cohort_base b
  ON b.CohortMonth = m.CohortMonth
 AND b.CustomerType = m.CustomerType
ORDER BY m.CohortMonth, m.CustomerType, m.MonthIndex;
