---- customer segmentation

WITH cust AS (
    SELECT
        h.CustomerID,
        MAX(CAST(h.OrderDate AS date)) AS LastOrderDate,
        COUNT(DISTINCT h.SalesOrderID) AS Orders,
        SUM(d.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader h
    JOIN Sales.SalesOrderDetail d
        ON d.SalesOrderID = h.SalesOrderID
    GROUP BY h.CustomerID
),
scored AS (
    SELECT
        CustomerID,
        LastOrderDate,
        Orders,
        Revenue,
        DATEDIFF(day, LastOrderDate, (SELECT MAX(CAST(OrderDate AS date)) FROM Sales.SalesOrderHeader)) AS RecencyDays
    FROM cust
)
SELECT
    CustomerID,
    LastOrderDate,
    RecencyDays,
    Orders,
    Revenue,
    CASE
        WHEN RecencyDays <= 30 AND Orders >= 5 THEN 'Champions'
        WHEN RecencyDays <= 60 AND Orders >= 3 THEN 'Loyal'
        WHEN RecencyDays <= 90 THEN 'Warm'
        WHEN RecencyDays <= 180 THEN 'At Risk'
        ELSE 'Lost'
    END AS Segment
FROM scored
ORDER BY Revenue DESC;


---Customer retention

-- Change years here
WITH y1 AS (
    SELECT DISTINCT CustomerID
    FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) = 2013
),
y2 AS (
    SELECT DISTINCT CustomerID
    FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) = 2014
)
SELECT CustomerID, 'Both years' AS Cohort
FROM (
    SELECT CustomerID FROM y1
    INTERSECT
    SELECT CustomerID FROM y2
) a

UNION ALL
SELECT CustomerID, 'New in 2014' AS Cohort
FROM (
    SELECT CustomerID FROM y2
    EXCEPT
    SELECT CustomerID FROM y1
) b

UNION ALL
SELECT CustomerID, 'Churned after 2013' AS Cohort
FROM (
    SELECT CustomerID FROM y1
    EXCEPT
    SELECT CustomerID FROM y2
) c;
