-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT distinct(c.market) -- getting the countries cutomers are located 
FROM 
	gdb023.dim_customer as c
WHERE 
	customer = "Atliq Exclusive" 
    and 
    region = "APAC"
ORDER BY 
	market;

/*2. What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg */

SELECT 
  COUNT(DISTINCT CASE WHEN sm.fiscal_year = 2020 THEN sm.product_code END) AS unique_products_2020,
  COUNT(DISTINCT CASE WHEN sm.fiscal_year  = 2021 THEN sm.product_code END) AS unique_products_2021,
  ROUND(
		(COUNT(DISTINCT CASE WHEN sm.fiscal_year = 2021 THEN sm.product_code END) - COUNT(DISTINCT CASE WHEN sm.fiscal_year  = 2020 THEN sm.product_code END)) / COUNT(DISTINCT CASE WHEN sm.fiscal_year  = 2020 THEN sm.product_code END) * 100,2
        ) AS percentage_chg
FROM 
	gdb023.fact_sales_monthly AS sm
WHERE 
	sm.fiscal_year IN (2020, 2021);

/*3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
 The final output contains 2 fields, segment product_count */
 
SELECT
	p.segment, 
	count(distinct p.product_code) AS product_count
FROM 
	gdb023.dim_product AS p
GROUP BY 
	p.segment
ORDER BY 
	product_count desc;
        
/*4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
 The final output contains these fields, segment product_count_2020 product_count_2021 difference */

SELECT 
	segment,
  COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN p.product_code END) AS unique_products_2020,
  COUNT(DISTINCT CASE WHEN fiscal_year  = 2021 THEN p.product_code END) AS unique_products_2021,
  (COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN p.product_code END) - COUNT(DISTINCT CASE WHEN fiscal_year  = 2020 THEN p.product_code END)) AS deference
FROM 
	gdb023.fact_sales_monthly AS sm
	LEFT JOIN 
		gdb023.dim_product AS p ON sm.product_code = p.product_code
WHERE 
	fiscal_year IN (2020, 2021)
GROUP BY
	segment
ORDER BY 
	deference desc;

/*5. Get the products that have the highest and lowest manufacturing costs.
 The final output should contain these fields, product_code product manufacturing_cost */

SELECT 
    product_code, 
    product, 
    manufacturing_cost
FROM (
    SELECT 
        mc.product_code, 
        product, 
        manufacturing_cost
    FROM 
        gdb023.fact_manufacturing_cost AS mc
        LEFT JOIN gdb023.dim_product AS p ON mc.product_code = p.product_code
    ) AS subquery
WHERE
	manufacturing_cost = (
        SELECT 
            MAX(manufacturing_cost)
        FROM 
            gdb023.fact_manufacturing_cost
    )
    OR 
    manufacturing_cost = (
        SELECT 
            MIN(manufacturing_cost)
        FROM 
            gdb023.fact_manufacturing_cost
    );

/* 6. Generate a report which contains the top 5 customers who received an average high 
pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
The final output contains these fields, customer_code customer average_discount_percentage */

SELECT 
	c.customer_code,customer, 
    ROUND(AVG(pre_invoice_discount_pct)*100,2) AS average_discount_percentage
FROM
	gdb023.dim_customer AS c 
	LEFT JOIN
		gdb023.fact_pre_invoice_deductions AS pre_inv ON c.customer_code = pre_inv.customer_code
WHERE
	market = "India" 
    AND
    fiscal_year = 2021
GROUP BY
	c.customer_code,
	customer
ORDER BY 
	average_discount_percentage desc
limit 5
;

/* 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.
 This analysis helps to get an idea of low and high-performing months and take strategic decisions.
 The final report contains these columns: Month Year Gross sales Amount */
 
SELECT 
	MONTH(date) as Month, YEAR(date) as Year, round(sum(gross_sales_amount),3) as gross_sales_amount
    FROM( 
			SELECT sm.date as date, gross_price*sold_quantity as gross_sales_amount
					FROM  gdb023.fact_gross_price AS gp
						JOIN gdb023.fact_sales_monthly AS sm ON gp.product_code = sm.product_code
                        JOIN gdb023.dim_customer AS c ON sm.customer_code = c.customer_code
					WHERE 
						customer = "Atliq Exclusive"
					)as subquery
	GROUP BY 
		Month,
		Year
	ORDER BY
		Year,
        Month;

/* 8. In which quarter of 2020, got the maximum total_sold_quantity?
 The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity */
 
SELECT 
    CONCAT('Q', QUARTER(date)) AS Quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM 
    gdb023.fact_sales_monthly
WHERE 
    YEAR(date) = 2020
GROUP BY 
    Quarter
ORDER BY 
    total_sold_quantity DESC
LIMIT 
    4;
    


/*9. Which channel helped to bring more gross sales in the fiscal year 2021 
and the percentage of contribution? 
The final output contains these fields, channel gross_sales_mln percentage */

SELECT 
    channel, 
	  concat(ROUND(SUM(gross_sales_mln)/1000000,2),"m") AS gross_sales_mln, 
    ROUND(( SUM(gross_sales_mln)/ SUM(SUM(gross_sales_mln)) OVER()) * 100, 2) AS percentage 
FROM( 
			SELECT  channel, gross_price*sold_quantity  AS gross_sales_mln
					FROM  gdb023.fact_gross_price AS gp
						JOIN gdb023.fact_sales_monthly AS sm ON gp.product_code = sm.product_code
                        JOIN gdb023.dim_customer AS c ON sm.customer_code = c.customer_code
					WHERE 
						sm.fiscal_year = 2021
					)as subquery
GROUP BY 
    channel
ORDER BY 
    percentage DESC
LIMIT 
    4;

/*10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields, division product_code product total_sold_quantity rank_order */

SELECT * FROM ( -- subquery to provide all needed data
SELECT 
	p.division, 
    p.product_code, 
    p.product, 
    SUM(sm.sold_quantity) AS total_sold,
RANK() OVER (PARTITION BY p.division ORDER BY SUM(sm.sold_quantity) DESC) AS rank_order -- window function for rank of products in every division
FROM 
	gdb023.dim_product AS p
JOIN gdb023.fact_sales_monthly AS sm ON p.product_code = sm.product_code
WHERE 
	sm.fiscal_year = 2021
GROUP BY 1, 2, 3) AS x
WHERE x.rank_order <= 3 -- fetching only top 3 of products for ecery division
;
