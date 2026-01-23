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
    SELECT CustomerID, MIN(OrderMonth) AS FirstOrderMonth
    FROM order_fact
    GROUP BY CustomerID
),
labeled_orders AS (
    SELECT
        f.OrderMonth,
        f.TerritoryID,
        f.CustomerID,
        f.SalesOrderID,
        f.OrderRevenue,
        f.OnlineOrderFlag,
        f.DiscountedLinePct,
        CASE WHEN f.OrderMonth = fm.FirstOrderMonth THEN 'New' ELSE 'Returning' END AS CustomerStage
    FROM order_fact f
    JOIN first_month fm
        ON fm.CustomerID = f.CustomerID
)
SELECT
    lo.OrderMonth,
    cd.CustomerType,
    lo.CustomerStage,
    lo.TerritoryID,
    COUNT(DISTINCT lo.CustomerID) AS Customers,
    COUNT(DISTINCT lo.SalesOrderID) AS Orders,
    SUM(lo.OrderRevenue) AS Revenue,
    SUM(lo.OrderRevenue) * 1.0 / NULLIF(COUNT(DISTINCT lo.SalesOrderID), 0) AS AOV,
    AVG(CASE WHEN lo.OnlineOrderFlag = 1 THEN 1.0 ELSE 0.0 END) AS OnlineOrderPct,
    AVG(lo.DiscountedLinePct) AS AvgDiscountedLinePct
FROM labeled_orders lo
JOIN customer_dim cd
    ON cd.CustomerID = lo.CustomerID
GROUP BY
    lo.OrderMonth, cd.CustomerType, lo.CustomerStage, lo.TerritoryID
ORDER BY
    lo.OrderMonth, cd.CustomerType, lo.CustomerStage, lo.TerritoryID;
