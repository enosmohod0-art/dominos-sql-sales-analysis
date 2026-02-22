-- ============================================================
-- Domino's Sales Analysis
-- Database: PostgreSQL
-- Tables: customers, orders, order_details, pizzas, pizza_types
-- Author: Enos Mohod
-- ============================================================


-- ============================================================
-- 1️⃣ Order Volume Analysis
-- ============================================================

-- Total Unique Orders
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM orders;


-- Month-over-Month Order Growth
WITH monthly_orders AS (
    SELECT 
        EXTRACT(MONTH FROM order_date) AS month_num,
        TO_CHAR(order_date, 'Month') AS month,
        COUNT(order_id) AS order_count
    FROM orders
    GROUP BY month_num, month
)
SELECT 
    month_num,
    month,
    order_count,
    LAG(order_count) OVER (ORDER BY month_num) AS prev_month_orders,
    ROUND(
        100.0 * (order_count - LAG(order_count) OVER (ORDER BY month_num))
        / NULLIF(LAG(order_count) OVER (ORDER BY month_num), 0),
        2
    ) AS mom_growth_percentage
FROM monthly_orders
ORDER BY month_num;


-- Orders by Weekday
SELECT 
    TO_CHAR(order_date, 'Day') AS day_of_week,
    COUNT(DISTINCT order_id) AS order_count
FROM orders
GROUP BY day_of_week
ORDER BY order_count DESC;


-- Orders by Hour of Day
SELECT 
    EXTRACT(HOUR FROM order_time::time) AS order_hour,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_hour
ORDER BY order_hour;



-- ============================================================
-- 2️⃣ Revenue Analysis
-- ============================================================

-- Total Revenue
SELECT 
    ROUND(SUM(p.price * od.quantity), 2) AS total_revenue
FROM order_details od
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id;


-- Revenue by Month
SELECT 
    EXTRACT(MONTH FROM o.order_date) AS month,
    ROUND(SUM(p.price * od.quantity), 2) AS revenue
FROM orders o
JOIN order_details od 
    ON o.order_id = od.order_id
JOIN pizzas p 
    ON p.pizza_id = od.pizza_id
GROUP BY month
ORDER BY month;


-- Cumulative Revenue Trend
WITH monthly_revenue AS (
    SELECT 
        EXTRACT(MONTH FROM o.order_date) AS month,
        SUM(p.price * od.quantity) AS revenue
    FROM orders o
    JOIN order_details od 
        ON o.order_id = od.order_id
    JOIN pizzas p 
        ON p.pizza_id = od.pizza_id
    GROUP BY month
)
SELECT 
    month,
    revenue,
    SUM(revenue) OVER (ORDER BY month) AS cumulative_revenue
FROM monthly_revenue
ORDER BY month;



-- ============================================================
-- 3️⃣ Product Performance Analysis
-- ============================================================

-- Most Common Pizza Size
SELECT 
    p.size,
    COUNT(od.order_id) AS total_orders
FROM pizzas p
JOIN order_details od 
    ON p.pizza_id = od.pizza_id
GROUP BY p.size
ORDER BY total_orders DESC;


-- Revenue by Pizza Size
SELECT 
    p.size,
    ROUND(SUM(od.quantity * p.price), 2) AS revenue
FROM order_details od
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id
GROUP BY p.size
ORDER BY revenue DESC;


-- Total Quantity by Category
SELECT 
    pt.category,
    SUM(od.quantity) AS total_quantity
FROM pizza_types pt
JOIN pizzas p 
    ON pt.pizza_type_id = p.pizza_type_id
JOIN order_details od 
    ON od.pizza_id = p.pizza_id
GROUP BY pt.category
ORDER BY total_quantity DESC;


-- Category-wise Order Distribution (% Share)
SELECT 
    pt.category,
    COUNT(od.pizza_id) AS total_orders,
    ROUND(
        COUNT(od.pizza_id)::numeric 
        / SUM(COUNT(od.pizza_id)) OVER () * 100,
        2
    ) AS percentage_share
FROM pizza_types pt
JOIN pizzas p 
    ON pt.pizza_type_id = p.pizza_type_id
JOIN order_details od 
    ON od.pizza_id = p.pizza_id
GROUP BY pt.category
ORDER BY total_orders DESC;



-- ============================================================
-- 4️⃣ Top Performers Analysis
-- ============================================================

-- Top 3 Pizzas by Revenue
WITH pizza_revenue AS (
    SELECT 
        pt.name,
        SUM(p.price * od.quantity) AS revenue,
        DENSE_RANK() OVER (
            ORDER BY SUM(p.price * od.quantity) DESC
        ) AS rank
    FROM pizza_types pt
    JOIN pizzas p 
        ON pt.pizza_type_id = p.pizza_type_id
    JOIN order_details od 
        ON p.pizza_id = od.pizza_id
    GROUP BY pt.name
)
SELECT name, ROUND(revenue, 2) AS revenue
FROM pizza_revenue
WHERE rank <= 3;


-- Top 3 Pizzas by Category
WITH category_rank AS (
    SELECT 
        pt.category,
        pt.name,
        SUM(p.price * od.quantity) AS revenue,
        DENSE_RANK() OVER (
            PARTITION BY pt.category 
            ORDER BY SUM(p.price * od.quantity) DESC
        ) AS rank
    FROM pizza_types pt
    JOIN pizzas p 
        ON pt.pizza_type_id = p.pizza_type_id
    JOIN order_details od 
        ON od.pizza_id = p.pizza_id
    GROUP BY pt.category, pt.name
)
SELECT category, name, ROUND(revenue, 2) AS revenue
FROM category_rank
WHERE rank <= 3
ORDER BY category;



-- ============================================================
-- 5️⃣ Customer Insights
-- ============================================================

-- Top 10 Customers by Spending
SELECT 
    c.custid,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    ROUND(SUM(od.quantity * p.price), 2) AS total_spent
FROM customers c
JOIN orders o 
    ON c.custid = o.custid
JOIN order_details od 
    ON o.order_id = od.order_id
JOIN pizzas p 
    ON p.pizza_id = od.pizza_id
GROUP BY c.custid, customer_name
ORDER BY total_spent DESC
LIMIT 10;


-- Average Order Size (Pizzas per Order)
SELECT 
    ROUND(AVG(order_size), 2) AS avg_pizzas_per_order
FROM (
    SELECT 
        order_id,
        SUM(quantity) AS order_size
    FROM order_details
    GROUP BY order_id
) t;
