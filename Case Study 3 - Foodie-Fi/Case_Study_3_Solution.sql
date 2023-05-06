--Data Analysis Questions

--1. How many customers has Foodie-Fi ever had?

select count(distinct customer_id) total_customers from subscriptions;

--2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

select month(s.start_date) [month], count(s.customer_id) count_trial_plan
from subscriptions s 
inner join plans p
on s.plan_id = p.plan_id and p.plan_name = 'trial'
group by month(s.start_date);

--3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

select p.plan_id, p.plan_name, count(s.customer_id) count_event
from subscriptions s
inner join plans p
on s.plan_id = p.plan_id
where s.start_date >= '2021-01-01'
group by p.plan_id, p.plan_name
order by 1;

--4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

with cte as
(
	select s.customer_id, s.plan_id, p.plan_name
	from subscriptions s
	inner join plans p
	on s.plan_id = p.plan_id
)
select sum(case when plan_name = 'churn' then 1 else 0 end) churn_count,
cast(round(sum(case when plan_name = 'churn' then 1 else 0 end) * 100.0/count( distinct customer_id),1) as decimal(3,1)) churn_pct
from cte;

--5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

with cte as
(
	select s.customer_id, s.plan_id, p.plan_name, lead(p.plan_name,1,'NA') over(partition by s.customer_id order by s.customer_id) nxt_plan
	from subscriptions s
	inner join plans p
	on s.plan_id = p.plan_id
)
select sum(case when plan_name = 'trial' and nxt_plan = 'churn' then 1 else 0 end) churn_count,
sum(case when plan_name = 'trial' and nxt_plan = 'churn' then 1 else 0 end) * 100/ count(distinct customer_id) churn_pct
from cte;

--6. What is the number and percentage of customer plans after their initial free trial?

with cte as
(
	select s.customer_id, s.plan_id, p.plan_name, lead(p.plan_name,1) over(partition by s.customer_id order by s.customer_id) nxt_plan
	from subscriptions s
	inner join plans p
	on s.plan_id = p.plan_id
)
select nxt_plan, count(*) nxt_plan_count,
cast(round(count(*) * 100.0/ (select count(distinct customer_id) from subscriptions),1) as decimal(3,1)) nxt_plan_pct
from cte
where nxt_plan is not null and plan_name = 'trial'
group by nxt_plan;

--7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

with cte_nxt_date as
(
	select s.customer_id, s.plan_id, p.plan_name, s.start_date, lead(s.start_date,1) over(partition by s.customer_id order by s.start_date) nxt_date
	from subscriptions s
	inner join plans p
	on s.plan_id = p.plan_id
	where s.start_date <= '2020-12-31'
),
cte as
(
	select plan_id, plan_name, count(customer_id) customer_count
	from cte_nxt_date
	where (nxt_date is not null and (start_date < '2020-12-31' and nxt_date > '2020-12-31')) or (nxt_date is null and start_date < '2020-12-31')
	group by plan_id, plan_name
)
select plan_id, plan_name,customer_count, 
cast(round(customer_count * 100.0/(select count(distinct customer_id) from subscriptions),1) as decimal(3,1)) customer_pct
from cte
group by plan_id, plan_name,customer_count
order by 1;

--8. How many customers have upgraded to an annual plan in 2020?

select count(distinct s.customer_id) customer_count
from subscriptions s
inner join plans p
on s.plan_id = p.plan_id
where year(s.start_date) = 2020 and p.plan_name = 'pro annual';

--9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

with trial_cte as
(
	select s.customer_id, s.start_date
	from subscriptions s
	inner join plans p 
	on s.plan_id = p.plan_id
	where p.plan_name = 'trial'
),
anuual_cte as
(
	select s.customer_id, s.start_date
	from subscriptions s
	inner join plans p 
	on s.plan_id = p.plan_id
	where p.plan_name = 'pro annual'
)
select avg(datediff(day, t.start_date,a.start_date)) avg_annual_upgrade_days
from trial_cte t
inner join anuual_cte a
on t.customer_id = a.customer_id;

--10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

with trial_cte as
(
	select s.customer_id, s.start_date
	from subscriptions s
	inner join plans p 
	on s.plan_id = p.plan_id
	where p.plan_name = 'trial'
),
anuual_cte as
(
	select s.customer_id, s.start_date
	from subscriptions s
	inner join plans p 
	on s.plan_id = p.plan_id
	where p.plan_name = 'pro annual'
),
bins_cte as
(
	select datediff(day, t.start_date,a.start_date) annual_upgrade_days, cast(datediff(day, t.start_date,a.start_date)/30 as int) bins
	from trial_cte t
	inner join anuual_cte a
	on t.customer_id = a.customer_id
)
select concat((bins*30)+1,'-',(bins+1)*30,' days') days_bins, count(annual_upgrade_days) customer_count
from bins_cte
group by bins
order by bins

--11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

with nxt_plan_cte as
(
	select customer_id, plan_id, start_date, lead(plan_id, 1) over(partition by customer_id order by plan_id, start_date) nxt_plan
	from subscriptions c 
)
select count(distinct n.customer_id) customer_count
from nxt_plan_cte n
inner join plans p
on n.plan_id = p.plan_id
where p.plan_name = 'pro monthly' and n.nxt_plan = 1 and n.start_date <= '2020-12-31';


