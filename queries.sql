drop table if exists goldusers_signup;
CREATE TABLE goldusers_signup(userid integer,gold_signup_date date); 

INSERT INTO goldusers_signup(userid,gold_signup_date) 
 VALUES (1,'09-22-2017'),
(3,'04-21-2017');

drop table if exists users;
CREATE TABLE users(userid integer,signup_date date); 


INSERT INTO users(userid,signup_date) 
 VALUES (1,'09-02-2014'),
(2,'01-15-2015'),
(3,'04-11-2014');

drop table if exists sales;
CREATE TABLE sales(userid integer,created_date date,product_id integer); 

INSERT INTO sales(userid,created_date,product_id) 
 VALUES (1,'04-19-2017',2),
(3,'12-18-2019',1),
(2,'07-20-2020',3),
(1,'10-23-2019',2),
(1,'03-19-2018',3),
(3,'12-20-2016',2),
(1,'11-09-2016',1),
(1,'05-20-2016',3),
(2,'09-24-2017',1),
(1,'03-11-2017',2),
(1,'03-11-2016',1),
(3,'11-10-2016',1),
(3,'12-07-2017',2),
(3,'12-15-2016',2),
(2,'11-08-2017',2),
(2,'09-10-2018',3);

drop table if exists product;
CREATE TABLE product(product_id integer,product_name text,price integer); 

INSERT INTO product(product_id,product_name,price) 
 VALUES
(1,'p1',980),
(2,'p2',870),
(3,'p3',330);

select * from sales;
select * from product;
select * from goldusers_signup;
select * from users;

-- 1. What is the total amount each customer spent on Zomato?
SELECT s.userid, SUM(p.price) AS total_amt_spent
	FROM product p
	INNER JOIN sales s
	ON p.product_id = s.product_id
	GROUP BY s.userid;

-- 2. How many days each customer visisted Zomato?
SELECT userid, COUNT(DISTINCT created_date) distinct_days FROM sales
GROUP BY userid;

-- 3. What is the First product purchased by each customer?
SELECT * FROM (
	SELECT *,RANK() OVER(PARTITION BY s.userid ORDER BY s.created_date ASC) AS rankk 
		FROM sales s)a WHERE rankk = 1;

SELECT * FROM (
SELECT s.userid, s.created_date, p.product_name, p.product_id,RANK() OVER(PARTITION BY s.userid ORDER BY s.created_date ASC) AS rankk 
		FROM sales s
		INNER JOIN product p
		ON s.product_id = p.product_id) a WHERE rankk = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by each customers?
SELECT TOP 1 CAST(p.product_name AS VARCHAR(255)) AS most_purchased, COUNT(*) AS CNT
	FROM product p
	INNER JOIN sales s
	ON p.product_id = s.product_id
	GROUP BY CAST(p.product_name AS VARCHAR(255))
	ORDER BY COUNT(*) DESC

SELECT userid, COUNT(product_id) AS most_purchased 
	FROM sales
	WHERE product_id = (SELECT TOP 1 product_id 
	FROM sales 
	GROUP BY product_id
	ORDER BY COUNT(product_id) DESC)
	GROUP BY userid;

--5. Which item was the most popular for each customer?
-- WITH ProductCounts AS (
-- 	SELECT 
--		s.userid,
--		s.product_id,
--		COUNT(*) AS purchase_count,
--		ROW_NUMBER() OVER (PARTITION BY s.userid ORDER BY COUNT(*) DESC) AS rn
--	FROM 
--		sales s
--	GROUP BY 
--		s.userid, s.product_id
--)

--SELECT * FROM ProductCounts;

WITH ProductCounts AS (
    SELECT 
        s.userid,
        s.product_id,
        COUNT(*) AS purchase_count,
        RANK() OVER (PARTITION BY s.userid ORDER BY COUNT(*) DESC) AS rnk
    FROM 
        sales s
    GROUP BY 
        s.userid, s.product_id
)

SELECT 
    pc.userid,
    pc.product_id,
    pc.purchase_count
FROM 
    ProductCounts pc
WHERE 
    pc.rnk = 1
ORDER BY 
    pc.userid;

-- 6. Which item was purchased first by the customer after they became a member?
WITH FirstPurchases AS (
    SELECT 
        s.userid,
        s.product_id,
        s.created_date,
		u.gold_signup_date,
        ROW_NUMBER() OVER (PARTITION BY s.userid ORDER BY s.created_date) AS rn
    FROM sales s
    INNER JOIN goldusers_signup u ON s.userid = u.userid
    WHERE s.created_date >= u.gold_signup_date
)
SELECT 
    userid,
    product_id,
    created_date,
	gold_signup_date
FROM FirstPurchases
WHERE rn = 1;

-- 7. Which item was purchased just before the customer became a member?

WITH FirstPurchases AS (
    SELECT 
        s.userid,
        s.product_id,
        s.created_date,
		u.gold_signup_date,
        ROW_NUMBER() OVER (PARTITION BY s.userid ORDER BY s.created_date DESC) AS rn
    FROM sales s
    INNER JOIN goldusers_signup u ON s.userid = u.userid
    WHERE s.created_date < u.gold_signup_date
)
SELECT 
    userid,
    product_id,
    created_date,
	gold_signup_date
FROM FirstPurchases
WHERE rn = 1;
	
-- 8. What is the total orders and amount spent by each member before they signed up for gold?
SELECT s.userid, COUNT(*) AS total_orders, SUM(p.price) AS amount 
	FROM sales s
	INNER JOIN goldusers_signup g
	ON s.userid = g.userid
	INNER JOIN product p 
	ON s.product_id = p.product_id
	WHERE s.created_date < g.gold_signup_date
	GROUP BY s.userid;

--9. If Buying each product generates certain points and each product is having different purchase points
-- for example: for p1 5rs = 1 point, for p2 10rs = 5 points and for p3 5rs = 1 point
-- calculate the points collected by each customer and the product with most points

WITH PointsTable AS (
	SELECT s.userid, s.product_id, SUM(p.price) AS product_total,
	CASE 
		WHEN s.product_id = 1 THEN (SUM(p.price)/5)*1
		WHEN s.product_id = 2 THEN (SUM(p.price)/10)*5
		WHEN s.product_id = 3 THEN (SUM(p.price)/5)*1
	END AS points
	FROM sales s
	INNER JOIN product p
	ON s.product_id = p.product_id
	GROUP BY s.userid, s.product_id
)
-- SELECT userid, product_id, product_total, points
-- FROM PointsTable;
SELECT product_id, SUM(points) 
FROM PointsTable 
GROUP BY product_id;

-- 10. In the first one year after a customer buys a Gold membership (From their joining date) 
-- irrespective of the products purchased they earn 5 Zomato points for every 10rs spent.
-- Calculate the points earned by each user in the first year and list which user has more points.
SELECT TOP 1 s.userid, SUM(p.price) AS amount, SUM(p.price)/2 AS points
	FROM sales s
	INNER JOIN goldusers_signup g
	ON s.userid = g.userid
	INNER JOIN product p
	ON s.product_id = p.product_id
	WHERE s.created_date BETWEEN g.gold_signup_date AND DATEADD(YEAR, 1, gold_signup_date)
	GROUP BY s.userid
	ORDER BY points DESC;


-- 11. Rank all the transactions of the customers
SELECT *, RANK() OVER(PARTITION BY userid ORDER BY created_date) AS rnk
	FROM sales;

-- 12. Rank all the transactions for each user considering their gold memebership, 
-- if they do not have a gold membership mark the transaction as NA 
WITH RankedSales AS(
SELECT s.userid, s.product_id, s.created_date, g.gold_signup_date, 
	CAST(RANK() OVER(PARTITION BY s.userid ORDER BY s.created_date DESC) AS VARCHAR) AS rnk
	FROM sales s
	LEFT JOIN goldusers_signup g
	ON s.userid = g.userid
	AND s.created_date >= g.gold_signup_date
)
SELECT userid, product_id, created_date, gold_signup_date,
CASE 
	WHEN gold_signup_date IS NULL THEN 'NA'
	ELSE rnk
END AS rnk
FROM RankedSales
