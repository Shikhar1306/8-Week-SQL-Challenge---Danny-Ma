/* --------------------
   Case Study Questions
   --------------------*/
-- 1. What is the total amount each customer spent at the restaurant?

select s.customer_id, sum(m.price) total_amount_spent
from sales s
inner join menu m
on s.product_id = m.product_id
group by s.customer_id;


-- 2. How many days has each customer visited the restaurant?

select customer_id, count(distinct order_date) days_visited
from sales
group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?

with sales_cte as
(
	select customer_id, product_id, order_date,
	dense_rank() over(partition by customer_id order by order_date) rn
	from sales
)
select s.customer_id, s.order_date, m.product_name
from sales_cte s
inner join menu m
on s.product_id = m.product_id
where rn = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

with product_purchase_count_cte as
(
	select top 1 product_id, count(product_id) purchased_count 
	from sales
	group by product_id
	order by 2 desc
),
most_purchased_product_cte as
(
	select product_id, product_name
	from menu
	where product_id = (select product_id 
						 from product_purchase_count_cte
						)
)
select s.customer_id, mp.product_id, mp.product_name, count(mp.product_id) purchase_count
from sales s
inner join most_purchased_product_cte mp
on s.product_id = mp.product_id
group by s.customer_id, mp.product_id, mp.product_name;

-- 5. Which item was the most popular for each customer?

with product_count_cte as
(
	select customer_id, product_id, count(product_id) product_count
	from sales
	group by customer_id, product_id
),
product_count_rank_cte as
(
	select customer_id, product_id, product_count,
	dense_rank() over(partition by customer_id order by product_count desc) rnk
	from product_count_cte
)
select pcr.customer_id, pcr.product_id, concat(product_name, ' (', product_count ,' times)') most_popular_item
from product_count_rank_cte pcr
inner join menu m
on pcr.product_id = m.product_id
where rnk = 1;

-- 6. Which item was purchased first by the customer after they became a member?

with cte as
(
	select s.customer_id, s.order_date, m.join_date, s.product_id, me.product_name,
	dense_rank() over(partition by s.customer_id order by s.order_date) rn
	from sales s
	inner join menu me
	on s.product_id = me.product_id
	inner join members m
	on s.customer_id = m.customer_id
	where s.order_date >= m.join_date
)
select customer_id, product_name
from cte
where rn = 1;

-- 7. Which item was purchased just before the customer became a member?

with cte as
(
	select s.customer_id, s.order_date, m.join_date, s.product_id, me.product_name,
	dense_rank() over(partition by s.customer_id order by s.order_date desc) rn
	from sales s
	inner join menu me
	on s.product_id = me.product_id
	inner join members m
	on s.customer_id = m.customer_id
	where s.order_date < m.join_date
)
select customer_id, product_name
from cte
where rn = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

with cte as
(
	select s.customer_id, s.order_date, m.join_date, s.product_id, me.price
	from sales s
	inner join menu me
	on s.product_id = me.product_id
	inner join members m
	on s.customer_id = m.customer_id
	where s.order_date < m.join_date
)
select customer_id, count(product_id) total_items, sum(price) total_amount_spent
from cte
group by customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

with cte as
(
	select s.customer_id, s.product_id, m.product_name, m.price
	from sales s
	inner join menu m
	on s.product_id = m.product_id
)
select customer_id, sum(case when product_name = 'sushi' then price * 20 else price * 10 end) total_points
from cte
group by customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

with cte as
(
	select s.customer_id, s.product_id, m.product_name, m.price, s.order_date, me.join_date
	from sales s
	inner join menu m
	on s.product_id = m.product_id
	inner join members me
	on s.customer_id = me.customer_id
	where month(s.order_date) = 1
)

select customer_id,
sum(
	case when product_name = 'sushi' then price * 20 
	when order_date between join_date and dateadd(day, 6, join_date) then price * 20
	else price * 10 end) total_points
from cte
group by customer_id;

-----------------------------------------------------------------------------------------------------------------------------

												--Bonus Questions--
-- Join All The Things

select s.customer_id, s.order_date, m.product_name, m.price,
case 
	when order_date >= join_date then 'Y'
	else 'N' end member 
from sales s
inner join menu m
on s.product_id = m.product_id
left join members me
on s.customer_id = me.customer_id

-- Rank All The Things

with cte as
(
	select s.customer_id, s.order_date, m.product_name, m.price,
	case 
		when order_date >= join_date then 'Y'
		else 'N' end member 
	from sales s
	inner join menu m
	on s.product_id = m.product_id
	left join members me
	on s.customer_id = me.customer_id
)

select *, 
case
	when member = 'N' then null
	else rank() over(partition by  customer_id, member order by order_date) end ranking
from cte;