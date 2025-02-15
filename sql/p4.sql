use mydb;

with temp as (select order_id, quantity from order_details where quantity > 10)

select temp.order_id, avg(temp.quantity) 
from temp
group by temp.order_id