-- bigquery-public-data.google_analytics_sample.ga_sessions_
-- Link instruction: https://docs.google.com/spreadsheets/d/1WnBJsZXj_4FDi2DyfLH1jkWtfTridO2icWbWCh7PLs8/edit#gid=0


-- Query 01: calculate total visit, pageview, transaction and revenue for Jan, Feb and March 2017 order by month
#standardSQL
select
    format_date('%Y%m', parse_date('%Y%m%d', date)) as month
    ,sum(totals.visits) as visit
    ,sum(totals.pageviews) as pageviews 
    ,sum( totals.transactions) as transaction
    ,(sum(totals.totalTransactionRevenue)/1000000) as revenue
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
Where date between '20170101' and '20170331'
group by month
order by month

-- Query 02: Bounce rate per traffic source in July 2017
#standardSQL
select 
  trafficSource.source
  , sum(totals.visits) as total_visit
  , sum(totals.bounces) as total_no_of_bounces
	, (sum(totals.bounces)/sum(totals.visits)) as bounce_rate
from `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
group by trafficSource.source

-- Query 3: Revenue by traffic source by week, by month in June 2017
#standardSQL
(
select 
  'month' as time_type
  , format_date('%Y%m' , parse_date('%Y%m%d',date)) as Time
  , trafficSource.source
  , sum(totals.totalTransactionRevenue) as Revenue
from `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`
group by trafficSource.source, time
)
union all
(
select 
  'week' as time_type
  , format_date('%Y%W' , parse_date('%Y%m%d',date)) as Time
  , trafficSource.source
  , sum(totals.totalTransactionRevenue) as Revenue
from `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`
group by trafficSource.source, time
)

--Query 04: Average number of product pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017. Note: totals.transactions >=1 for purchaser and totals.transactions is null for non-purchaser
#standardSQL
SELECT 
  format_date('%Y%m' , parse_date('%Y%m%d' , date)) as month
  , CASE
      WHEN totals.transactions >= 1 THEN 'purchase' 
      ELSE 'non_purchase'
    END as status
    , sum(totals.pageviews) / count(distinct fullVisitorId) as avg_pageviews
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` 
where date between '20170601' and '20170731'
group by status, month

-- Query 05: Average number of transactions per user that made a purchase in July 2017
#standardSQL
SELECT 
	format_date('%Y%m' , parse_date('%Y%m%d' , date)) as month
    , sum(totals.transactions) / count(distinct fullVisitorId) as avg_totals_transactions_per_user
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` 
where totals.transactions >= 1
group by month

-- Query 06: Average amount of money spent per session
#standardSQL
SELECT 
	format_date('%Y%m' , parse_date('%Y%m%d' , date)) as month
   , sum(totals.totalTransactionRevenue) / count(visitId) as avg_revenue_by_user_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` 
where totals.transactions is not null
group by month

-- Query 07: Products purchased by customers who purchased product A (Classic Ecommerce)
#standardSQL
with bang1 as 
(
select 
    fullVisitorId
from `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
	, UNNEST (hits) hits
	, UNNEST (hits.product) product
where product.v2ProductName  = "YouTube Men's Vintage Henley" and product.productRevenue is not null
)
select
  product.v2ProductName as other_pur_product
  , sum(product.productQuantity) as Quantity
from `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
	, UNNEST (hits) hits
	, UNNEST (hits.product) product
where fullVisitorId in (select fullVisitorId from bang1) 
	and product.v2ProductName  <> "YouTube Men's Vintage Henley" 
	and product.productRevenue is not null
group by other_pur_product
order by Quantity

--Query 08: Calculate cohort map from pageview to addtocart to purchase in last 3 month. For example, 100% pageview then 40% add_to_cart and 10% purchase.
#standardSQL
with views as 
(
	select format_date('%Y%m',parse_date('%Y%m%d', date)) as month
	, count(hits.eCommerceAction.action_type) as num_views
from `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
	, UNNEST(hits) hits
where date between '20170101' and '20170331' 
	and hits.eCommerceAction.action_type = '2'
group by month
)
, add_product as 
(
	select format_date('%Y%m',parse_date('%Y%m%d', date)) as month
	, count(hits.eCommerceAction.action_type) as num_add
from `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
	,	UNNEST(hits) hits
where date between '20170101' and '20170331' and hits.eCommerceAction.action_type = '3'
group by month
)
,purchase as 
(
	select format_date('%Y%m',parse_date('%Y%m%d', date)) as month
	, count(hits.eCommerceAction.action_type) as num_pur
from `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
	, UNNEST(hits) hits
where date between '20170101' and '20170331' 
	and hits.eCommerceAction.action_type = '6'
group by month
)
select 
	views.month
	, views.num_views
	, add_product.num_add 
	, purchase.num_pur
	, add_product.num_add/views.num_views as add_to_cart_rate
	, purchase.num_pur/views.num_views as purchase_rate
from views
inner join add_product on views.month = add_product.month
inner join purchase on add_product.month = purchase.month