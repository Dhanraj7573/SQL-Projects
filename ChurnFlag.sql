;WITH order_fact AS (
    SELECT
        h.SalesOrderID,
        h.CustomerID,
        CAST(h.OrderDate AS date) AS OrderDate,
        SUM(d.LineTotal) AS OrderRevenue
    FROM Sales.SalesOrderHeader h
    JOIN Sales.SalesOrderDetail d
      ON d.SalesOrderID = h.SalesOrderID
    GROUP BY h.SalesOrderID, h.CustomerID, CAST(h.OrderDate AS date)
),
customer_dim AS (
    SELECT
        c.CustomerID,
        CASE
            WHEN c.PersonID IS NOT NULL THEN 'Individual'
            WHEN c.StoreID IS NOT NULL THEN 'Store'
            ELSE 'Unknown'
        END AS CustomerType
    FROM Sales.Customer c
),
cust_stats AS (
    SELECT
        CustomerID,
        MIN(OrderDate) AS FirstOrderDate,
        MAX(OrderDate) AS LastOrderDate,
        COUNT(DISTINCT SalesOrderID) AS LifetimeOrders,
        SUM(OrderRevenue) AS LifetimeRevenue
    FROM order_fact
    GROUP BY CustomerID
),
gaps AS (
    SELECT
        CustomerID,
        DATEDIFF(day,
            LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate),
            OrderDate
        ) AS GapDays
    FROM order_fact
),
avg_gap AS (
    SELECT
        CustomerID,
        AVG(CAST(GapDays AS float)) AS AvgDaysBetweenOrders
    FROM gaps
    WHERE GapDays IS NOT NULL
    GROUP BY CustomerID
),
anchor AS (
    SELECT MAX(OrderDate) AS DataMaxDate
    FROM order_fact
)
SELECT
    cs.CustomerID,
    cd.CustomerType,
    cs.FirstOrderDate,
    cs.LastOrderDate,
    DATEDIFF(day, cs.LastOrderDate, a.DataMaxDate) AS RecencyDays,
    cs.LifetimeOrders,
    cs.LifetimeRevenue,
    CAST(cs.LifetimeRevenue * 1.0 / NULLIF(cs.LifetimeOrders, 0) AS decimal(12,2)) AS LifetimeAOV,
    CAST(ag.AvgDaysBetweenOrders AS decimal(12,2)) AS AvgDaysBetweenOrders,
    CASE WHEN DATEDIFF(day, cs.LastOrderDate, a.DataMaxDate) > 90 THEN 1 ELSE 0 END AS ChurnFlag_90d
FROM cust_stats cs
JOIN customer_dim cd ON cd.CustomerID = cs.CustomerID
CROSS JOIN anchor a
LEFT JOIN avg_gap ag ON ag.CustomerID = cs.CustomerID
ORDER BY cs.LifetimeRevenue DESC;
