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


