--- Customer 360” cleaned dimension (name/email/phone + flags)


WITH base AS (
    SELECT
        c.CustomerID,
        c.PersonID,
        c.StoreID,
        CASE
            WHEN c.PersonID IS NOT NULL THEN 'Individual'
            WHEN c.StoreID IS NOT NULL THEN 'Store'
            ELSE 'Unknown'
        END AS CustomerType
    FROM Sales.Customer c
),
one_email AS (
    SELECT
        BusinessEntityID,
        LOWER(LTRIM(RTRIM(EmailAddress))) AS EmailClean,
        ROW_NUMBER() OVER (
            PARTITION BY BusinessEntityID
            ORDER BY ModifiedDate DESC, EmailAddressID DESC
        ) AS rn
    FROM Person.EmailAddress
),
one_phone AS (
    SELECT
        BusinessEntityID,
        -- basic cleanup: remove common characters
        REPLACE(REPLACE(REPLACE(REPLACE(PhoneNumber,'-',''),'(',''),')',''),' ','') AS PhoneClean,
        ROW_NUMBER() OVER (
            PARTITION BY BusinessEntityID
            ORDER BY ModifiedDate DESC
        ) AS rn
    FROM Person.PersonPhone
)
SELECT
    b.CustomerID,
    b.CustomerType,
    -- clean name for individuals, store name for stores
    CASE
        WHEN b.PersonID IS NOT NULL THEN
            LTRIM(RTRIM(CONCAT(p.FirstName, ' ',
                               COALESCE(NULLIF(p.MiddleName,'') + ' ', ''),
                               p.LastName)))
        WHEN b.StoreID IS NOT NULL THEN
            LTRIM(RTRIM(s.Name))
        ELSE 'Unknown'
    END AS CleanName,
    e.EmailClean,
    ph.PhoneClean,
    CASE WHEN e.EmailClean IS NULL THEN 0 ELSE 1 END AS HasEmail,
    CASE WHEN ph.PhoneClean IS NULL THEN 0 ELSE 1 END AS HasPhone
FROM base b
LEFT JOIN Person.Person p
    ON p.BusinessEntityID = b.PersonID
LEFT JOIN Sales.Store s
    ON s.BusinessEntityID = b.StoreID
LEFT JOIN one_email e
    ON e.BusinessEntityID = b.PersonID AND e.rn = 1
LEFT JOIN one_phone ph
    ON ph.BusinessEntityID = b.PersonID AND ph.rn = 1;


--Data quality issues report (single output table)

    WITH emails AS (
    SELECT
        BusinessEntityID,
        LOWER(LTRIM(RTRIM(EmailAddress))) AS EmailClean
    FROM Person.EmailAddress
)
SELECT 'Missing email' AS Issue, COUNT(*) AS BadRows
FROM Sales.Customer c
WHERE c.PersonID IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM emails e WHERE e.BusinessEntityID = c.PersonID)

UNION ALL
SELECT 'Invalid email format' AS Issue, COUNT(*) AS BadRows
FROM emails
WHERE EmailClean NOT LIKE '%_@_%._%'

UNION ALL
SELECT 'Products with missing/blank color' AS Issue, COUNT(*) AS BadRows
FROM Production.Product
WHERE Color IS NULL OR LTRIM(RTRIM(Color)) = '';