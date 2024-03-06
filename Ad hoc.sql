  # request 1. List of products with a base price greater than 500 and that are featured in promo type of 'BOGOF' (Buy One Get One Free)
 select 
	distinct p.product_name, 
    f.base_price,
    f.promo_type
from 
	dim_products p
join 
	fact_events f
on 
	p.product_code = f.product_code
where 
	base_price > 500
    and
    promo_type = 'BOGOF';

# request 2. Overview of the number of stores in each city
 select
	city,
    count(store_id) as store_count
from 
	dim_stores
group by 
	city
order by 
	store_count desc;
    
 #Request 3 Total revenue generated before and after by campaign.
  select 
    c.campaign_name, 
    concat(
        round(sum(f.base_price * `quantity_sold(before_promo)` / 1000000),2), 'M'
    ) as `total_revenue(before_promo)`,
    concat(
        round(sum(
            case
                when f.promo_type = '50% off' then f.base_price * 0.5 * f.`quantity_sold(after_promo)`
                when f.promo_type = '25% off' then f.base_price * 0.75 * f.`quantity_sold(after_promo)`
                when f.promo_type = 'bogof' then f.base_price * 0.5 * f.`quantity_sold(after_promo)` * 2
                when f.promo_type = '500 cashback' then (f.base_price - 500) * f.`quantity_sold(after_promo)`
                else f.base_price * 0.67 * f.`quantity_sold(after_promo)`
            end
        ) / 1000000, 2
    ), 'M'
    ) as `total_revenue(after_promo)`
from
    fact_events f
join 
    dim_campaigns c
on 
    f.campaign_id = c.campaign_id
group by
    c.campaign_name;

  
  #request 4 Incremental Sold Quantity (ISU%) for each category and ranking during the Diwali campaign.
  with ctel as (
	select
		category,
		concat(round(sum(
		case
			when promo_type = 'BOGOF' then `quantity_sold(after_promo)` * 2 - `quantity_sold(before_promo)`
			else `quantity_sold(after_promo)` - `quantity_sold(before_promo)`
		end
        )/sum(`quantity_sold(before_promo)`) * 100, 2), '%') as ISU_percent
	from
		fact_events f
	join
		dim_products p
	on
		f.product_code= p.product_code
	join
		dim_campaigns c
	on
		f.campaign_id = c.campaign_id	
	where
		c.campaign_name = 'DIWALI'
	group by
		p.category
)
	select
		category,
		ISU_percent,
		rank() over (order by isu_percent desc) as ISU_rank
	from
		ctel
	order by
		ISU_percent desc;
        
        
        
  # request 5 Top five products ranked by IR% overall 
  with cte1 as (select 
    p.product_name, 
    p.category,
CONCAT(ROUND(((
				SUM(
                    CASE 
                        WHEN f.promo_type = '50% off' THEN f.base_price * 0.5 * f.`quantity_sold(after_promo)`
                        WHEN f.promo_type = '25% off' THEN f.base_price * 0.75 * f.`quantity_sold(after_promo)`
                        WHEN f.promo_type = 'bogof' THEN f.base_price * 0.5 * f.`quantity_sold(after_promo)` * 2
                        WHEN f.promo_type = '500 cashback' THEN (f.base_price - 500) * f.`quantity_sold(after_promo)`
                        ELSE f.base_price * 0.67 * f.`quantity_sold(after_promo)`
                    END
                ) - SUM(f.base_price * f.`quantity_sold(before_promo)`)
            ) / SUM(f.base_price * f.`quantity_sold(before_promo)`) * 100
        ),
        2
    ),
    '%'
) AS IR_percentage

from
    fact_events f
join 
    dim_products p
on 
    f.product_code = p.product_code
group by
	p.product_name)    
select 
	product_name, 
    category, 
    IR_percentage,
    rank() over (order by IR_percentage desc) as IR_rank
from 
    cte1
order by 
    IR_percentage desc
limit 5