-- Scalar Functions:
--------------------
-- Convert film title to upper case 
SELECT 
	UPPER(se_film.title) AS uppercase_title
FROM public.film AS se_film 

-- Calculate length in hours for all films
SELECT
	film_id, 
	ROUND(length/60.0, 2) as length_in_hours
FROM public.film

-- Extract the year from the last_update column in the actor table.
SELECT DISTINCT 
	EXTRACT(YEAR FROM last_update) as year_last_update
FROM public.actor


-- Aggregate Functions:
-----------------------
-- Count the total number of films in the film table.
SELECT 
	COUNT(se_film.film_id) as total_films
FROM public.film as se_film

-- Calculate the average rental rate of films in the film table.
SELECT 
	ROUND(AVG(se_film.rental_rate), 2) as avg_rental_rate
FROM public.film as se_film

-- Determine the highest and lowest film lengths.
SELECT 
	MAX(se_film.length) as highest_film_length,
	MIN(se_film.length) AS lowest_film_length
FROM film as se_film

-- Find the total number of films in each film category.
SELECT
	se_category.name as category_name,
	COUNT(se_film.film_id) as total_films
FROM public.film as se_film
INNER JOIN public.film_category as se_film_category
	ON se_film_category.film_id = se_film.film_id
INNER JOIN public.category as se_category
	ON se_category.category_id = se_film_category.category_id
GROUP BY se_category.name


-- WINDOW FUNCTIONS:
--------------------
-- Rank films in the film table by length using the RANK() function.
SELECT 
	se_film.title as film_title, 
	se_film.length, 
	RANK()OVER(ORDER BY se_film.length) as rank_by_length
FROM public.film as se_film

-- Calculate the cumulative sum of film lengths in the film table using the SUM() window function.
SELECT
	se_film.film_id,
	SUM(se_film.length) OVER(ORDER BY film_id) as cumulative_length_sum
FROM public.film as se_film

-- For each film in the film table, retrieve the title of the next film in terms of alphabetical order using the LEAD() function.
SELECT
	se_film.title, 
	LEAD(se_film.title) OVER (ORDER BY se_film.title) as next_film_title
FROM public.film as se_film

-- CONDITIONAL FUNCTIONS:
-------------------------
-- Classify films based on their length:
SELECT
	se_film.title, 
	CASE
		WHEN se_film.length < 60 THEN 'Short'
		WHEN se_film.length > 60 and se_film.length < 120 THEN 'Medium'
		WHEN se_film.length > 120 THEN 'Long'
	END as film_length
FROM public.film as se_film

-- For each payment in the payment table, use the COALESCE function to replace null values in the amount column with the average payment amount.
SELECT
	se_payment.payment_id, 
	se_payment.amount,
	COALESCE(se_payment.amount, avg(se_payment.amount)OVER()) AS corrected_amount
FROM public.payment as se_payment

-- USER DEFINED FUNCTIONS:
--------------------------
--Create a UDF named film_category that accepts a film title as input and returns the category of the film.
CREATE OR REPLACE FUNCTION film_category(film_title TEXT)
RETURNS TEXT AS
$$
DECLARE 
	category_name TEXT;
BEGIN
	SELECT 
		se_category.name
	INTO category_name
	FROM public.category as se_category
	INNER JOIN public.film_category as se_film_category
		ON se_film_category.category_id = se_category.category_id
	INNER JOIN public.film AS se_film
		ON se_film.film_id = se_film_category.film_id
	WHERE se_film.title = film_title;
	RETURN category_name;
END;
$$ 
LANGUAGE PLPGSQL;

SELECT * FROM film_category('UPRISING UPTOWN')


-- Develop a UDF named total_rentals that takes a film title as an argument 
-- and returns the total number of times the film has been rented.
CREATE OR REPLACE FUNCTION total_rentals(film_title TEXT)
RETURNS NUMERIC AS
$$
DECLARE 
	total_rentals_film NUMERIC;
BEGIN
	SELECT
		--se_film.title AS film_title, 
		COUNT(se_rental.rental_id) 
	INTO total_rentals_film
	FROM public.rental as se_rental
	INNER JOIN public.inventory as se_inventory
		ON se_inventory.inventory_id = se_rental.inventory_id
	INNER JOIN public.film as se_film
		ON se_film.film_id = se_inventory.film_id
	WHERE se_film.title = film_title;
	RETURN total_rentals_film;
END;
$$
LANGUAGE PLPGSQL;

SELECT * FROM total_rentals('UPRISING UPTOWN')

-- Design a UDF named customer_stats which takes a customer ID as input 
-- and returns a JSON containing the customer's name, total rentals, and total amount spent.
CREATE OR REPLACE FUNCTION customer_stats(input_customer_id INT )
RETURNS JSONB AS 
$$
DECLARE 
	return_jsonb JSONB;
	customer_name TEXT;
    total_rentals INT;
    total_amount NUMERIC;
BEGIN 
	SELECT 
		CONCAT(se_customer.first_name, ' ', se_customer.last_name),
        COUNT(se_rental.rental_id),
        COALESCE(SUM(se_payment.amount), 0)
	INTO 
		customer_name,
		total_rentals,
		total_amount
	 FROM public.customer as  se_customer
	 INNER JOIN public.rental as se_rental
		ON se_rental.customer_id = se_customer.customer_id
	LEFT OUTER JOIN public.payment as se_payment
		ON se_payment.customer_id = se_rental.customer_id
	WHERE se_customer.customer_id = input_customer_id
	GROUP BY
		CONCAT(se_customer.first_name, ' ', se_customer.last_name);
		
	return_jsonb = JSONB_BUILD_OBJECT(
        'customer_name', customer_name,
        'total_rentals', total_rentals,
        'total_amount', total_amount
    );
	
	RETURN return_jsonb;
END;
$$ 
LANGUAGE PLPGSQL;

SELECT * FROM customer_stats(1)