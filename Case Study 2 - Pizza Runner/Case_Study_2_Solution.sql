----------------------------------------Data Cleaning----------------------------------------

-------customer_orders table---------------

select * 
from customer_orders;

select order_id, customer_id, pizza_id, 
case 
	when exclusions is null or exclusions like 'null' then ' '
	else exclusions
end as exclusions,
case 
	when extras is null or extras like 'null' then ' '
	else extras 
end as extras, 
order_time
into #customer_orders -- create temp table
from customer_orders;

--removed nulls and replaced with blank ('')

select * 
from #customer_orders;

--------------runner_orders table-----------------------

select *
from runner_orders;

select order_id, runner_id,
case 
	when pickup_time like 'null' then ' '
	else pickup_time 
end as pickup_time,
case 
	when distance like 'null' then ' '
	when distance like '%km' then trim('km' from distance) 
	else distance 
end as distance,
case 
	when duration like 'null' then ' ' 
	when duration like '%mins' then trim('mins' from duration) 
	when duration like '%minute' then trim('minute' from duration) 
	when duration like '%minutes' then trim('minutes' from duration) 
	else duration 
end as duration,
case 
	when cancellation is null or cancellation like 'null' then ''
	else cancellation
end as cancellation
into #runner_orders
from runner_orders;

--removed nulls and trimmed values for  better analysis

select *
from #runner_orders;

--alter column datatypes in #runner_orders table

alter table #runner_orders
alter column pickup_time datetime;

alter table #runner_orders
alter column distance float;

alter table #runner_orders
alter column duration int;

select *
from #runner_orders;


--------------------------Case Study Questions--------------------------

--A. Pizza Metrics

--1 How many pizzas were ordered?

select count(*) pizza_count
from #customer_orders;

--2. How many unique customer orders were made?

select count(distinct order_id) unique_customer_orders
from #customer_orders;

--3. How many successful orders were delivered by each runner?

select runner_id,
sum(case when cancellation = '' then 1 else 0 end) successful_orders_count
from #runner_orders
group by runner_id;

--4. How many of each type of pizza was delivered?

select pn.pizza_name, count(co.pizza_id) delivered_count
from #customer_orders co
inner join #runner_orders ro
on co.order_id = ro.order_id
and ro.cancellation = ''
inner join pizza_names pn
on co.pizza_id = pn.pizza_id
group by pn.pizza_name;

--5. How many Vegetarian and Meatlovers were ordered by each customer?

select co.customer_id,pn.pizza_name, count(co.pizza_id) order_count
from #customer_orders co
inner join pizza_names pn
on co.pizza_id = pn.pizza_id
group by co.customer_id, pn.pizza_name;

--6. What was the maximum number of pizzas delivered in a single order?

with single_max_order as
(
	select co.order_id, count(pizza_id) total_pizzas 
	from #customer_orders co
	inner join #runner_orders ro
	on co.order_id = ro.order_id
	and ro.cancellation = ''
	group by co.order_id
)
select max(total_pizzas) max_pizza_count
from single_max_order;

--7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

select co.customer_id,
sum(case when co.exclusions = '' and co.extras = '' then 1 else 0 end)  count_no_change,
sum(case when co.exclusions != '' or co.extras != '' then 1 else 0 end) count_atleast_1_change
from #customer_orders co
inner join #runner_orders ro
on co.order_id = ro.order_id and cancellation = ''
group by co.customer_id;


--8. How many pizzas were delivered that had both exclusions and extras?

select count(co.order_id) count_pizza_delivered
from #customer_orders co
inner join #runner_orders ro
on co.order_id = ro.order_id and cancellation = ''
where co.exclusions != '' and co.extras != '';

--9. What was the total volume of pizzas ordered for each hour of the day?

select datepart(hour, order_time) order_hour, count(order_id) orders_count
from #customer_orders
group by datepart(hour, order_time);

--10. What was the volume of orders for each day of the week?

select datename(weekday, dateadd(day,2,order_time)) order_day, count(order_id) orders_count
from #customer_orders
group by datename(weekday, dateadd(day,2,order_time));


---------------------------------------------------------------------------------------------------------------------
--B. Runner and Customer Experience

--1 How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

set datefirst 5;

select datepart(week, registration_date) signup_week, count(runner_id) runners_count
from runners
group by datepart(week, registration_date);

set datefirst 7

--2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

with time_to_arrive_cte as
(
	select co.order_id, ro.runner_id, co.order_time, ro.pickup_time, datediff(minute, co.order_time, ro.pickup_time) time_to_arrive
	from #customer_orders co
	inner join #runner_orders ro
	on co.order_id = ro.order_id and ro.cancellation = ''
	group by co.order_id, ro.runner_id, co.order_time, ro.pickup_time
)
select runner_id, avg(time_to_arrive) avg_time_to_arrive
from time_to_arrive_cte
group by runner_id;

--3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

with time_to_prepare_cte as
(
	select co.order_id, count(co.pizza_id) pizza_count ,co.order_time, ro.pickup_time, datediff(minute, co.order_time, ro.pickup_time) time_to_prepare
	from #customer_orders co
	inner join #runner_orders ro
	on co.order_id = ro.order_id 
	where ro.cancellation = ''
	group by co.order_id, co.order_time, ro.pickup_time
)
select pizza_count, avg(time_to_prepare) avg_time_to_prepare
from time_to_prepare_cte
group by pizza_count;

--4. What was the average distance travelled for each customer?

select co.customer_id, round(avg(ro.distance),2) avg_distance_travelled
from #customer_orders co
inner join #runner_orders ro
on co.order_id = ro.order_id 
where ro.cancellation = ''
group by co.customer_id;

--5. What was the difference between the longest and shortest delivery times for all orders?

select max(duration) - min(duration) difference_delivery_time
from #runner_orders
where cancellation = '';

--6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

select runner_id, order_id, distance, duration, (duration * 1.0 / 60) duration_hrs, round(distance / (duration * 1.0/60),2) speed
from #runner_orders
where cancellation = ''
order by runner_id;

--7. What is the successful delivery percentage for each runner?

with successful_deliveries_cte as
(
	select runner_id, count(order_id) total_deliveries_assigned, 
	sum(case when cancellation = '' then 1 else 0 end) successful_deliveries
	from #runner_orders
	group by runner_id
)
select *, 100 * successful_deliveries / total_deliveries_assigned successful_delivery_pct
from successful_deliveries_cte;

-----------------------------------------------------------------------------------------------------------
--C. Ingredient Optimisation

--1. What are the standard ingredients for each pizza?

with toppings_cte as
(
	select a.pizza_id, b.value topping
	from pizza_recipes a
	cross apply string_split(a.toppings, N',') b
),
pizza_cte as
(
	select pn.pizza_id, pn.pizza_name, tc.topping, pt.topping_name
	from pizza_names pn
	inner join toppings_cte tc
	on pn.pizza_id = tc.pizza_id
	inner join pizza_toppings pt
	on tc.topping = pt.topping_id
)
select pizza_id, pizza_name, string_agg(topping_name,', ')  standard_ingredients
from pizza_cte
group by pizza_id, pizza_name;

--2. What was the most commonly added extra?

with extras_cte as
(
	select a.order_id, b.value extras
	from #customer_orders a
	cross apply string_split(a.extras,N',') b
),
extras_count_cte as
(
	select extras, count(extras) extras_count,
	dense_rank() over(order by count(extras) desc) rnk
	from extras_cte
	where extras != ''
	group by extras
)
select pt.topping_name most_used_extra, ecc.extras_count times_used_as_extra
from extras_count_cte ecc
inner join pizza_toppings pt
on ecc.extras = pt.topping_id
where ecc.rnk = 1;

--3. What was the most common exclusion?

with exclusion_cte as
(
	select a.order_id, b.value exclusion
	from #customer_orders a
	cross apply string_split(a.exclusions, N',') b
),
exclusion_count_cte as
(
	select exclusion, count(exclusion) exclusion_count,
	dense_rank() over(order by count(exclusion) desc) rnk
	from exclusion_cte
	where exclusion != ''
	group by exclusion
)
select pt.topping_name most_common_exclusion, ecc.exclusion_count times_excluded
from exclusion_count_cte ecc
inner join pizza_toppings pt
on ecc.exclusion = pt.topping_id
where ecc.rnk = 1;

/* 
4. Generate an order item for each record in the customers_orders table in the format of one of the following:
Meat Lovers
Meat Lovers - Exclude Beef
Meat Lovers - Extra Bacon
Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
*/


