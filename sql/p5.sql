use mydb;
drop function if exists div_fun;
delimiter //

create function div_fun( n float, m float)
returns float
no sql
deterministic
begin
	declare result float;
    
    if m != 0 then
		set result = n / m;        
	else
		set result = null;
    end if;    
return result;
end //
delimiter ;

SELECT order_id, quantity, div_fun(quantity, 10) AS divided_quantity
FROM order_details;