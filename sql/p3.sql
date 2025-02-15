use mydb;

select limited_deteails.order_id, avg(limited_deteails.quantity) 
from (select order_id, quantity from order_details where quantity > 10) as limited_deteails
group by limited_deteails.order_id