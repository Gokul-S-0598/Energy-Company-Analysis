use energy;
/* Top 5 Carbon Plants with highest average carbon emissions */

Select
    p.plant_name, p.location,
    sum(e.carbon_emission_kg)/sum(e.amount_kwh) as avg_carbon_emission_per_kwh
From energy_production e
Join production_plants p
on p.plant_id = e.production_plant_id
group by p.plant_name, p.location
order by avg_carbon_emission_per_kwh desc
limit 5;

/*  performance of various sustainability initiatives based on the energy savings achieved */
select initiative_name, start_date, end_date, energy_savings_kwh
from sustainability_initiatives
order by energy_savings_kwh desc
limit 3;

/*  distribution of energy production amounts*/
 Select
    production_id,
    production_plant_id,
    date,
    energy_type,
    amount_kwh,
    sum(amount_kwh) over(partition by energy_type) as total_energy_by_type
From energy_production;

/*  rank the energy production records based on the production amount within each energy type*/
select
    production_id,
    production_plant_id,
    date,
    energy_type,
    amount_kwh,
    rank() over(partition by energy_type order by amount_kwh desc) as rank_within_type
From energy_production;

 /*Cumulative energy consumption for each customer over time */
 
 Select
    consumption_id,
    customer_id,
    date,
    energy_type,
    amount_kwh,
    sum(amount_kwh) over( partition by customer_id order by date) as cumulative_consumption
From energy_consumption;

/* monthly changes in energy production for each plant to understand trends and fluctuations.*/

With Monthly_Production as (
    Select
        production_plant_id,
        Date_Format(date, '%Y-%m-01') as month,
        sum(amount_kwh) as current_month_production
    From energy_production
    Group by production_plant_id, Date_Format(date, '%Y-%m-01')
)
Select
    production_plant_id,
    month,
    current_month_production,
    lag(current_month_production) over(partition by production_plant_id order by month) as previous_month_production,
    lead(current_month_production) over(partition by production_plant_id order by month) as next_month_production
From Monthly_Production;

/* top 3 highest energy production records for each energy type */

With Ranked_production as (
	Select
		production_plant_id,
        energy_type,
		date,
        amount_kwh,
        row_number()over(partition by energy_type order by amount_kwh desc) as rn
	From energy_production)
Select
	production_plant_id,
	energy_type,
    date,
    amount_kwh
From Ranked_production
where rn <= 3
order by energy_type, rn;

/* rank the production plants based on their average monthly energy production */

Select
	production_plant_id,
    Date_Format(date, '%Y-%m') as month,
    avg(amount_kwh) as avg_monthly_production,
    rank()over(partition by date_format(date, '%Y-%m') order by avg(amount_kwh) desc) as ranking
From energy_production
Group by production_plant_id, Date_Format(date, '%Y-%m') 
Order by month, ranking asc;

/* rank the sustainability initiatives based on their total energy savings */

Select initiative_name, start_date, end_date, energy_savings_kwh,
	rank()over(order by energy_savings_kwh desc) as initiative_rank
From sustainability_initiatives;

/* Changes in energy production amounts between consecutive months for 
each plant to identify trends and fluctuations.*/

WITH monthly_production AS (
    SELECT
        production_plant_id,
        DATE_FORMAT(date, '%Y-%m') AS month,
        SUM(amount_kwh) AS current_month_production
    FROM energy_production
    GROUP BY production_plant_id, DATE_FORMAT(date, '%Y-%m')
)
SELECT
    production_plant_id,
    month,
    current_month_production,
    LAG(current_month_production) OVER (PARTITION BY production_plant_id ORDER BY month) AS previous_month_production,
    LEAD(current_month_production) OVER (PARTITION BY production_plant_id ORDER BY month) AS next_month_production
FROM monthly_production;

/* energy consumption patterns of customers throughout the year 2023 */

With Consumption_2023 as(
	Select 
		customer_id,
        amount_kwh,
        First_value(amount_kwh) over(partition by customer_id order by date) as first_consumption,
        last_value(amount_kwh) over(partition by customer_id order by date range between unbounded preceding
        and unbounded following) as last_consumption
	From energy_consumption
    where year(date) = 2023
)
Select
	customer_id,
    first_consumption,
    last_consumption
from 
	consumption_2023
group by customer_id,first_consumption,last_consumption
order by customer_id;

/* analyze the total and monthly energy consumption 
for each customer to identify high consumption patterns */

WITH Monthly_consumption AS 
( SELECT customer_id, DATE_FORMAT(date, '%Y-%m') AS month,
SUM(amount_kwh) AS monthly_consumption
FROM energy_consumption GROUP BY customer_id, month )

SELECT mc.customer_id, c.name, SUM(mc.monthly_consumption) AS total_consumption,
AVG(mc.monthly_consumption) AS avg_monthly_consumption
FROM Monthly_consumption mc JOIN customers c ON c.customer_id = mc.customer_id
GROUP BY mc.customer_id, c.name ORDER BY mc.customer_id;

/* production plants contributing the most to carbon emissions */
with cte as(
	select production_plant_id,
		avg(carbon_emission_kg) as avg_emissions,
		sum(carbon_emission_kg) as total_emissions
	from energy_production
    group by production_plant_id)
Select c.production_plant_id,
	p.plant_name,
	avg_emissions,
    total_emissions
from cte c
join production_plants p
on c.production_plant_id = p.plant_id
group by c.production_plant_id, p.plant_name
order by c.production_plant_id;

/* Identify the most effective Initiatives */

With Monthly_Savings as(
Select
initiative_id, 
initiative_name,
DATE_FORMAT(start_date, '%Y-%m') as Month,
energy_savings_kwh/timestampdiff(Month, start_date, end_date) as monthly_savings
From sustainability_initiatives
Where end_date is not null),
InitiativeSummary as (
Select
initiative_id,
initiative_name,
sum(monthly_savings) as total_savings,
avg(monthly_savings) as avg_monthly_savings
From 
Monthly_Savings
Group by
initiative_id, initiative_name)
Select
initiative_id,
initiative_name,
total_savings,
avg_monthly_savings
From InitiativeSummary
Order by initiative_id;