--creating test user table in SQL. Data have been uploaded using the following command:
--\COPY preply_test_users FROM '/home/amybirdee/hobby_projects/preply/preply_test_users.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE preply_test_users (
    user_id             INTEGER,
    test_group          TEXT,
    test_entrance_time  TIMESTAMP);
    

--check table

SELECT *
FROM preply_test_users;

--check counts - one row per user and variants are fairly balanced

SELECT COUNT(DISTINCT user_id), COUNT(*)
FROM preply_test_users;

--1918, 1918

SELECT test_group, COUNT(user_id)
FROM preply_test_users
GROUP BY test_group;

--A	964
--B	954


--check test dates

SELECT MIN(test_entrance_time) AS test_start,
       MAX(test_entrance_time) AS test_end
FROM preply_test_users;

--test dates: 2023-06-21 13:40:42 to	2023-07-21 19:59:28



------------------------------------------------------------------------------------------------------------------------------------------



--creating transactions table in SQL. The gmv column has been converted to integer in Python (by removing the dollar sign and then 
--converting to INT)
--data have been uploaded using the following command:
--\COPY preply_test_transactions FROM '/home/amybirdee/hobby_projects/preply/preply_test_transactions_final.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE preply_test_transactions (
    user_id           INTEGER,
    gmv               INTEGER,
    payment_time      TIMESTAMP);
    

--check table

SELECT *
FROM preply_test_transactions;

--check counts - looks like some users made more than one transaction

SELECT COUNT(DISTINCT user_id), COUNT(*)
FROM preply_test_transactions;   

--669, 913 

--check payent dates. Some dates are before or after the test. Transactions outside of the test dates should be excluded from the 
--test results

SELECT MIN(payment_time),
       MAX(payment_time)
FROM preply_test_transactions;

--2023-04-23 22:28:22.0	  2023-07-24 02:02:07.0


-----------------------------------------------------------------------------------------------------------------------------------------

--1) REVENUE
--join tables together and find revenue and payers during the test

WITH test_users AS
(SELECT user_id,
        CASE WHEN test_group = 'A' THEN 'Control' ELSE 'Variant' END AS variant,
        --find test entrance time for each user and global end date
        test_entrance_time,
        MAX(test_entrance_time) OVER () AS test_end
FROM preply_test_users)


--join this to revenue table
SELECT U.user_id,
       U.variant,
       SUM(T.gmv) AS revenue,
       MAX(CASE WHEN T.user_id IS NOT NULL THEN 1 ELSE 0 END) AS payer
FROM test_users U
LEFT JOIN preply_test_transactions T
ON U.user_id = T.user_id
AND T.payment_time BETWEEN U.test_entrance_time AND	U.test_end
GROUP BY U.user_id,
         U.variant;
       


---------------------------------------------------------------------------------------------------------------------------------------

--2) USER FUNNEL
--find user funnel to calculate conversion rates

WITH test_users AS
(SELECT user_id,
        CASE WHEN test_group = 'A' THEN 'Control' ELSE 'Variant' END AS variant,
        --find test entrance time for each user and global end date
        test_entrance_time,
        MAX(test_entrance_time) OVER () AS test_end
FROM preply_test_users),

--find all users who made a payment in the test
conversions AS
(SELECT U.user_id,
        U.variant,
        MAX(CASE WHEN T.user_id IS NOT NULL THEN 1 ELSE 0 END) AS payer
FROM test_users U
LEFT JOIN preply_test_transactions T
ON U.user_id = T.user_id
AND T.payment_time BETWEEN U.test_entrance_time AND	U.test_end
GROUP BY U.user_id,
         U.variant)

         
SELECT variant,
       COUNT(user_id) AS test_users,
       SUM(payer) AS payers
FROM conversions
GROUP BY variant;



---------------------------------------------------------------------------------------------------------------------------------------

--3) PURCHASE DATE
--find when users made a purchase after test entry.

WITH test_users AS
(SELECT user_id,
        CASE WHEN test_group = 'A' THEN 'Control' ELSE 'Variant' END AS variant,
        --find test entrance time for each user and global end date
        test_entrance_time,
        MAX(test_entrance_time) OVER () AS test_end
FROM preply_test_users),

purchases AS
(SELECT U.user_id,
        U.variant,
        U.test_entrance_time,
        --some users made more than one purchase so find the first purchase after test entry
        MIN(T.payment_time) AS first_purchase_time
FROM test_users U
INNER JOIN preply_test_transactions T
ON U.user_id = T.user_id
AND T.payment_time BETWEEN U.test_entrance_time AND	U.test_end
GROUP BY U.user_id,
         U.variant,
         U.test_entrance_time),


--find time between test entry and first purchase. Looks like everyone who made a purchase did so within 3 days
purchase_time AS
(SELECT user_id,
        variant,
        test_entrance_time,
        first_purchase_time,
        EXTRACT(EPOCH FROM first_purchase_time - test_entrance_time) / 3600 AS purchase_time_hours
FROM purchases)


SELECT variant,
       COUNT(CASE WHEN purchase_time_hours <= 24 THEN user_id END) AS day_1_purchase,
       COUNT(CASE WHEN purchase_time_hours > 24 AND purchase_time_hours <= 48 THEN user_id END) AS day_2_purchase,   
       COUNT(CASE WHEN purchase_time_hours > 48 THEN user_id END) AS day_3_purchase    
FROM purchase_time
GROUP BY variant;
       
