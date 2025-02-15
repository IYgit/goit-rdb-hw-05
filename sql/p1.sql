use mydb;

select od.*, (select o.customer_id from orders as o where od.order_id = o.id) as customer_id from order_details as od