USE hocsql;

--Yêu cầu: lấy ra danh sách 5 tỉnh có nhiều đơn hàng nhất 
select TOP 5 
	province
	, count(1) Total_Order_Quantity
from orders
group by province
order by Total_Order_Quantity DESC;


--Yêu cầu: lấy ra danh sách 3 nhà quản lý có nhiều đơn hàng nhất 
WITH bang5 AS (
select 
	manager
	, order_id
from orders
inner join profiles
on Orders.province = Profiles.province
)
, bang6 AS (
select 
	manager
	, order_id
from bang5 
group by manager, order_id
)
select TOP 3
	manager
	, count (order_id) Total_Order_Quantity
from bang6
group by manager
order by Total_Order_Quantity desc;


--Yêu cầu: lấy ra danh sách Product_category có lợi nhuận trung bình lớn hơn lợi nhuận trung bình của tất cả các đơn hàng
select 
	product_category
	, avg(profit) Profit_Avg
from orders
group by product_category
having avg(profit) > (select avg(profit) from orders);


--Yêu cầu: lấy ra danh sách top 5 sản phẩm (product_name) có total_value lớn nhất của mỗi khu vực (region).
WITH Bang1 AS (
select 
	region
	, product_name
	, sum(value) Total_value
from orders
group by region, product_name
)
, Bang2 AS (
select
	*
	, Rank() over (PARTITION BY Region order by Total_value DESC) as Ranks
from Bang1
)
select *
from Bang2
WHERE Ranks >= 1 and Ranks <=5;



--Yêu cầu: Hãy tạo bảng Revenue gồm các cột: year, month, total_revenue, total_revenue_returned, acc_revenue, group_revenue
--Trong đó:
	--Revenue = order_quantity * unit_price * (1-discount)
	--acc_revenue = total_revenue - total_revenue_returned
	--Group_revenuel là 'Thấp' khi acc_revenue < 10000 , Group_revenue là 'Trung bình' khi acc_revenue < 20000 , Group_revenue là 'Cao' khi acc_revenue >= 20000


CREATE TABLE Revenue (
		Year int
		, Month int
		, Total_Revenue float 
		, Total_Revenue_Returned float
		, Acc_Revenue float
		, Group_Revenue nvarchar(30)
		)



WITH bangA AS (
select 
	orders.order_date
	, orders.order_id
	, orders.order_quantity
	, orders.unit_price
	, orders.discount
	, returns.status 
	, returns.returned_date
	, year(order_date) as Year
	, month(order_date) as Month
	, order_quantity * unit_price * (1 - discount) as Total_Revenue
from Orders
left join Returns
on orders.order_id = returns.order_id and returns.status = 'Returned'
)
, BangB AS (
select 
	* 
	, CASE 
		WHEN status <> 'Null' THEN order_quantity * unit_price * (1 - discount)
		ELSE 0
	END AS Total_Revenue_Returned 
from bangA
)
, BangC AS (
select 
	*
	, Total_Revenue - Total_Revenue_Returned as Acc_Revenue
from BangB
)
, BangD AS (
select
	*
	, CASE 
		WHEN Acc_Revenue < 10000 THEN N'Thấp'
		WHEN Acc_Revenue > 10000 and Acc_Revenue < 20000 THEN N'Trung bình'
		ELSE N'Cao'
	END 
	AS Group_Revenue 
from BangC
)
INSERT INTO Revenue (Year , Month , Total_Revenue , Total_Revenue_Returned , Acc_Revenue , Group_Revenue) 
SELECT 
	year
	, month
	, Total_Revenue
	, Total_Revenue_Returned
	, Acc_Revenue
	, Group_Revenue 
FROM BangD;


select * 
from Revenue
order by 1, 2;