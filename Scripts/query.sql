-- check table schema from db
SELECT sql 
FROM sqlite_schema; 

-- retrieve first names, last names and titles of the employees and the first names and last names of their managers
SELECT e.firstName, e.lastName, e. title, mng.firstName AS managerFirstName, mng.lastName AS managerLastName
FROM employee AS e
INNER JOIN employee AS mng
  ON e.managerID = mng.employeeId; 

-- find sales ppl with 0 sales 
SELECT e.firstName, e.lastName, e.title, s.salesId
FROM employee AS e
LEFT JOIN sales AS s
  ON e.employeeId = s.employeeId
WHERE e.title = 'Sales Person' 
  AND s.salesId IS NULL;

-- retrieve information of all customers and sales, even if some data is gone
-- note: sqlite db does not allow full outter join :/
SELECT c.firstName, c.lastName, c.email, s.salesAmount, s.soldDate
FROM customer AS c
-- customerId on both table, records with no null values
INNER JOIN sales AS s
  ON c.customerId = s.customerId
-- UNION with customers who have no sales 
UNION
SELECT c.firstName, c.lastName, c.email, s.salesAmount, s.soldDate
FROM customer AS c
LEFT JOIN sales AS s
  ON c.customerId = s.customerId
WHERE s.salesId IS NULL
-- UNION with sales that does not have customer data 
UNION
SELECT c.firstName, c.lastName, c.email, s.salesAmount, s.soldDate
FROM sales AS s
LEFT JOIN customer AS c
  ON s.customerId = c.customerId
WHERE c.customerId IS NULL;

-- retrieve total cars have sold per employee
SELECT e.employeeId, e.firstName, e.lastName, COUNT(*) AS carsSold
FROM employee AS e
INNER JOIN sales AS s 
  ON e.employeeId = s.employeeId
GROUP BY e.employeeId
ORDER BY carsSold DESC; 

-- find the least and most expensive car sold by each employee this year
SELECT e.employeeId, e.firstName, e.lastName, MAX(s.salesAmount) AS mostExpensive, MAX(s.salesAmount) AS leastExpensive
FROM employee AS e
INNER JOIN sales AS s
  ON e.employeeId = s.employeeId
WHERE s.soldDate >= date('now', 'start of year')
GROUP BY e.employeeId; 

-- find employees who made more than 5 sales this year
SELECT e.employeeId, e.firstName, e.lastName, COUNT(*) AS carsSold, FORMAT('$%.2f', SUM(salesAmount)) AS totalSalesAmount
FROM employee AS e 
INNER JOIN sales AS s
  ON e.employeeId = s.employeeId
WHERE s.soldDate >= date('now', 'start of year')
GROUP BY e.employeeId
HAVING COUNT(*) > 5
ORDER BY totalSalesAmount DESC; 

-- Summarize total sales per year by using a CTE 
WITH cte AS (
  SELECT strftime('%Y', soldDate) AS soldYear, salesAmount
  FROM sales
)
SELECT soldYear, FORMAT('$%.2f', SUM(salesAmount)) AS AnnualSales
FROM cte 
GROUP BY soldYear 
ORDER BY soldYear;

SELECT strftime('%Y', soldDate) AS soldYear, FORMAT('$%.2f', SUM(salesAmount)) AS AnnualSales 
FROM sales
GROUP BY soldYear
ORDER BY soldYear; 

-- create a report shows the amount of sales per month per employee in 2021
SELECT e.firstName, e.lastName, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '01'
        THEN salesAmount END) AS JanSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '02'
        THEN salesAmount END) AS FebSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '03'
        THEN salesAmount END) AS MarSales,
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '04'
        THEN salesAmount END) AS AprSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '05'
        THEN salesAmount END) AS MaySales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '06'
        THEN salesAmount END) AS JunSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '07'
        THEN salesAmount END) AS JulSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '08'
        THEN salesAmount END) AS AugSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '09'
        THEN salesAmount END) AS SepSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '10'
        THEN salesAmount END) AS OctSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '11'
        THEN salesAmount END) AS NovSales, 
  SUM(CASE 
        WHEN strftime('%m', soldDate) = '12'
        THEN salesAmount END) AS DecSales
FROM sales AS s
INNER JOIN employee AS e
  ON s.employeeId = e.employeeId
WHERE strftime('%Y', s.soldDate) = '2021'
GROUP BY e.firstName, e.lastName;
 
-- find all sales where the car purchased was electric 
SELECT * 
FROM sales AS s
WHERE s.inventoryId IN 
  (SELECT i.inventoryId 
  FROM inventory as i
  WHERE i.modelId IN
    (SELECT m.modelId
    FROM model as m
    WHERE m.EngineType = 'Electric')); 

-- get a list of sales ppl and rank the car models they've sold the most of 
-- step 1: join neccessary tables 
-- step 2: count number of each model sold by each employee
-- step 3: partition by employee Id, ordeer by the number of models, and rank 
SELECT e.firstName, e.lastName, m.model, COUNT(model) AS numSold, 
  -- window function 
  RANK() OVER (PARTITION BY s.employeeId 
              ORDER BY COUNT(model) DESC) AS rank
FROM employee AS e
INNER JOIN sales AS s
  ON e.employeeId = s.employeeId
INNER JOIN inventory AS i 
  ON s.inventoryId = i.inventoryId
INNER JOIN model AS m 
  ON i.modelId = m.modelId
GROUP BY e.firstName, e.lastName, m.model; 

-- total sales per month and an annual running total

-- step 1: retrieve all records needed
-- SELECT strftime('%Y', soldDate) AS soldYear, 
--   strftime('%m', soldDate) AS soldMonth, 
--   salesAmount
-- FROM sales; 

-- step 2: apply grouping for amount of sales per month per year, save it as a cte
WITH cte1 AS (
  SELECT strftime('%Y', soldDate) AS soldYear, 
    strftime('%m', soldDate) AS soldMonth, 
    SUM(salesAmount) AS monthlySales 
  FROM sales
  GROUP BY soldYear, soldMonth
  ORDER BY soldYear, soldMonth
)
-- step 3: apply window function to get the running total of each year 
SELECT soldYear, soldMonth, 
  SUM(monthlySales) OVER (PARTITION BY soldYear
                          ORDER BY soldYear, soldMonth) AS AnnualRunningTotal
FROM cte1
ORDER BY soldYear, soldMonth; 

-- create a report showing the number of cars sold this month and last month for each month
SELECT strftime('%Y-%m', soldDate) AS MonthSold,  
  COUNT(*) AS CarsSold, 
  LAG (COUNT(*), 1, 0) OVER calMonth AS LastMonthCarsSold 
FROM sales 
GROUP BY MonthSold
WINDOW calMonth AS (ORDER BY strftime('%Y-%m', soldDate))
ORDER BY strftime('%Y-%m', soldDate); 