-- 日付ディメンション（2020年〜今日+5年）
-- 元の Databricks 版は spark.sql の sequence()+explode() で日付範囲を生成していたが、
-- Snowflake には同等機能が無いため GENERATOR + SEQ4() によるデイトスパインで代替する。
-- rowcount は 2020-01-01 起点で「今日+5年」を十分カバーできるよう余裕を持たせている
-- （約60年分）。dbt実行日が進んでも generator 側の上限に達しないための安全マージン。
with bounds as (

    select
        to_date('2020-01-01')            as start_date,
        dateadd(year, 5, current_date()) as end_date

),

date_spine as (

    select
        dateadd(day, seq4(), bounds.start_date) as date_key,
        bounds.end_date                          as end_date
    from table(generator(rowcount => 25000))
    cross join bounds

),

filtered as (

    select date_key
    from date_spine
    where date_key <= end_date

),

final as (

    select
        date_key,
        year(date_key)  as year,
        month(date_key) as month,
        day(date_key)   as day,

        -- 会計年度（4月始まり）
        case
            when month(date_key) >= 4 then year(date_key)
            else year(date_key) - 1
        end as fiscal_year,

        -- 会計四半期（4月始まり: 4-6月=Q1, 7-9月=Q2, 10-12月=Q3, 1-3月=Q4）
        case
            when month(date_key) between 4 and 6 then 1
            when month(date_key) between 7 and 9 then 2
            when month(date_key) between 10 and 12 then 3
            else 4
        end as quarter,

        dayofweek(date_key) as day_of_week,

        case dayname(date_key)
            when 'Sun' then 'Sunday'
            when 'Mon' then 'Monday'
            when 'Tue' then 'Tuesday'
            when 'Wed' then 'Wednesday'
            when 'Thu' then 'Thursday'
            when 'Fri' then 'Friday'
            when 'Sat' then 'Saturday'
        end as day_name,

        case month(date_key)
            when 1 then 'January'
            when 2 then 'February'
            when 3 then 'March'
            when 4 then 'April'
            when 5 then 'May'
            when 6 then 'June'
            when 7 then 'July'
            when 8 then 'August'
            when 9 then 'September'
            when 10 then 'October'
            when 11 then 'November'
            when 12 then 'December'
        end as month_name,

        to_char(date_key, 'YYYY-MM') as year_month,

        -- year_quarter も会計年度基準
        (case
            when month(date_key) >= 4 then year(date_key)
            else year(date_key) - 1
        end)::varchar || '-Q' || (case
            when month(date_key) between 4 and 6 then 1
            when month(date_key) between 7 and 9 then 2
            when month(date_key) between 10 and 12 then 3
            else 4
        end)::varchar as year_quarter,

        dayname(date_key) in ('Sat', 'Sun') as is_weekend

    from filtered

)

select * from final
