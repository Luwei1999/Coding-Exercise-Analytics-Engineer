--Second
--1.What are the top 5 brands by receipts scanned for most recent month?
SELECT b._id, b.name, COUNT(r._id) AS cnt_receipt
FROM brands b
JOIN items i ON b.barcode = i.barcode
JOIN receipts r ON r._id = i.receiptId
--convert unix ts to standard format and filter the receipts scanned by recent month
WHERE LEFT(DATEADD(SECOND, r.dateScanned/1000, '1970-01-01'), 7) = LEFT(CURRENT_DATE, 7)
GROUP BY b._id, b.name
ORDER BY cnt_receipt DESC
LIMIT 5;

--2. How does the ranking of the top5 brands by receipts scanned for the recent month compare to the ranking for the previous month?
--top5 brands of current month
WITH CurrentMonthTop5 AS (
    SELECT 
        b._id AS brand_id, 
        b.name AS brand_name, 
        COUNT(r._id) AS cnt_receipt,
        ROW_NUMBER() OVER (ORDER BY COUNT(r._id) DESC) AS rnk
    FROM brands b
    JOIN items i ON b.barcode = i.barcode
    JOIN receipts r ON r._id = i.receiptId
    WHERE LEFT(DATEADD(SECOND, r.dateScanned/1000, '1970-01-01'), 7) = LEFT(CURRENT_DATE, 7)
    GROUP BY b._id, b.name
    ORDER BY cnt_receipt DESC
    LIMIT 5
),
--top5 brands of previous month
PreviousMonthTop5 AS (
    SELECT 
        b._id AS brand_id, 
        b.name AS brand_name, 
        COUNT(r._id) AS cnt_receipt,
        ROW_NUMBER() OVER (ORDER BY COUNT(r._id) DESC) AS rnk
    FROM brands b
    JOIN items i ON b.barcode = i.barcode
    JOIN receipts r ON r._id = i.receiptId
    WHERE LEFT(DATEADD(SECOND, r.dateScanned/1000, '1970-01-01'), 7) = LEFT(DATEADD(MONTH, -1, CURRENT_DATE), 7)
    GROUP BY b._id, b.name
    ORDER BY cnt_receipt DESC
    LIMIT 5
)
SELECT 
    c.rnk AS ranking,
    c.brand_name AS current_month_top5_brands,
    p.brand_name AS previous_month_top5_brands
FROM CurrentMonthTop5 c
JOIN PreviousMonthTop5 p
ON c.rnk = p.rnk
ORDER BY ranking;

--3. When considering average spend from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?
SELECT r.rewardsReceiptStatus, AVG(r.totalSpent) AS average_spend
FROM receipts r
WHERE r.rewardsReceiptStatus IN ('Accepted', 'Rejected')
GROUP BY r.rewardsReceiptStatus;

--4. When considering total number of items purchased from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?
SELECT r.rewardsReceiptStatus, SUM(r.purchasedItemCount) AS total_items
FROM receipts r
WHERE r.rewardsReceiptStatus IN ('accepted', 'rejected')
GROUP BY r.rewardsReceiptStatus;

--5. Which brand has the most spend among users who were created within the past 6 months?
SELECT b.name AS brand_name, SUM(r.totalSpent) AS total_spent
FROM receipts r
JOIN users u ON r.userId = u._id
JOIN items i ON r._id = i.receiptId
JOIN brands b ON i.barcode = b.barcode
WHERE DATEADD(SECOND, u.dateCreated/1000, '1970-01-01') >= DATEADD(MONTH, -6, CURRENT_DATE)
GROUP BY b.name
ORDER BY total_spent DESC
LIMIT 1;

--6. Which brand has the most transactions among users who were created within the past 6 months?
SELECT b.name AS brand_name, COUNT(r._id) AS transaction_count
FROM receipts r
JOIN users u ON r.userId = u._id
JOIN items i ON r._id = i.receiptId
JOIN brands b ON i.barcode = b.barcode
WHERE DATEADD(SECOND, u.dateCreated/1000, '1970-01-01') >= DATEADD(MONTH, -6, CURRENT_DATE)
GROUP BY b.name
ORDER BY transaction_count DESC
LIMIT 1;


--Third
--I will apply some general data quality check method, such as null values, duplicates and data volume outliers:

--check latest null data for userid
SELECT COUNT(*) AS cnt_null
FROM users
WHERE _id is null AND DATEADD(SECOND, createdDate/1000, '1970-01-01')::DATE =  CURRENT_DATE - 1

--check duplicate for brand
SELECT _id, barcode, count(*)
FROM brands
GROUP BY _id, barcode
HAVING count(*) > 1

--check if latest receipt volume as usual
WITH 30_DAYS_COUNTS AS(
SELECT DATEADD(SECOND, dateScanned/1000, '1970-01-01')::DATE AS receipt_scanned_date, COUNT(*) AS cnt_daily_receipts
FROM receipts 
WHERE DATEADD(SECOND, dateScanned/1000, '1970-01-01')::DATE >= CURRENT_DATE - 31
GROUP BY DATEADD(SECOND, dateScanned/1000, '1970-01-01')::DATE
),
Stats AS (
    SELECT 
        AVG(cnt_daily_receipts) AS avg_daily_count,
        STDDEV(cnt_daily_receipts) AS std_dev_daily_count
    FROM 30_DAYS_COUNTS
),
Latest_Volume AS (
SELECT COUNT(*) AS cnt_latest
FROM receipts
WHERE DATEADD(SECOND, dateScanned/1000, '1970-01-01')::DATE = CURRENT_DATE - 1
)
SELECT CASE WHEN cnt_latest < (SELECT avg_daily_count - 3 * std_dev_daily_count FROM Stats) THEN 'Low Outliter'
            WHEN cnt_latest > (SELECT avg_daily_count + 3 * std_dev_daily_count FROM Stats) THEN 'High Outliter'
            ELSE 'Normal Volume'
        END AS Volume_check
FROM Latest_Volume


--Fourth

/*
Hi There,

Hope this email finds you weel. I'd like to share some insight from our recent data analysis, along with a few quality issues and our plans, to make sure we are one the same page:

First of all, we have a few questions that could help us resolve the issues more effectively, and we'd apprecaite any insights on the following:
• Is there any marketing campaign or events recently? It will help us better understand the spikes in activity
• Are there multiple source for our data feeding? If yes, we will add more data quality check on the data source consistency


Additionally, our team built the daily data quality notification, so that we could receive timely notification email regarding the quality report for latest data, that could make us aware any data quality issue. 
I applied a series of general data quality checks using SQL to identify potential issues across our user, brand, and receipt data:
• Null Values in User Data: I ran a query to check for null values in the user table, focusing on recent records (_id is null). This check helps identify any missing user information that could impact analysis. 
• Duplicate Entries in Brand Data: I used a query to identify duplicate brand records based on _id and barcode, which could lead to inaccurate brand metrics or skewed insights. 
• Volume Outliers in Receipt Data: To ensure that receipt volumes are consistent with historical patterns, I calculated the daily receipt counts over the past 30 days, and then compared yesterday’s receipt count to the average, using a threshold of three standard deviations to flag significant deviations. This analysis helps detect potential system issues or unusual activity.


In order to better resolve the data quality issues, we need to understand the below information:
• Clarify with upstream data provider to identify the root cause
• If upstream is great, check any changes in exsiting pipeline and go through the whole pipeline to debug
• Ask product/marketing team for any campaign or event that might affect the spike


To further optimize our data assets, insights on the following would be valuable and helpful:
• Customer feedback on existing reports and dashboards to better meet user needs
• Identify which tables are involved in long-running queries
• Identify the access pattern across user-brand-receipt model

We're also planning for potential changes as we grow:
• Long-running query. As data volume grows, we’re concerned about the performance of some queries. To address this, we’re planning to optimize our SQL queries and implement a new indexing strategy.
• Automated data quality check.  As more data sources are integrated, maintaining data quality will become more complex. We’re working on automating checks and setting up alert notifications to quickly identify any quality issues.
• Scalability of storage and compute. As the system scales, both storage and compute needs will increase. It is helpful to use cloud-based solution like Snowflake, that can scale storage independently of compute resources.


Please let me know if you have any questions. Looking forward to your insights. Thanks for your time.

Best,
Luwei
*/