```
    Завдання 4. Домашня робота



Завдання 1. Setup і typed-схема Olist

У першій секції notebook встановіть залежності, запустіть pgserver, перевірте підключення та отримайте файли Olist з Kaggle або з курсового архіву.

%pip install -q pgserver psycopg2-binary sqlalchemy pandas kagglehub

import os
import pandas as pd
import pgserver
from sqlalchemy import create_engine, text

pg = pgserver.get_server('/tmp/hw5_pg', cleanup_mode='stop')
engine = create_engine(pg.get_uri(), future=True)

with engine.connect() as conn:
    print(conn.execute(text('SELECT version()')).scalar_one())



Якщо використовується KaggleHub, у Colab має бути налаштований доступ до Kaggle. Якщо курс надає архів із CSV, розпакуйте його у data/olist/ і вкажіть це у README.

# Варіант A: якщо Kaggle credentials налаштовані
import kagglehub

dataset_dir = kagglehub.dataset_download('olistbr/brazilian-ecommerce')
print(dataset_dir)

# Варіант B: якщо CSV вже лежать у репозиторії або course archive
# dataset_dir = '/content/goit-rdb-hw-05/data/olist'



Завантажте CSV у raw-таблиці. Raw-таблиці потрібні лише як проміжний шар: вони відображають вихідні CSV і не замінюють typed-схему з constraints.

files = {
    'olist_customers_raw': 'olist_customers_dataset.csv',
    'olist_orders_raw': 'olist_orders_dataset.csv',
    'olist_order_items_raw': 'olist_order_items_dataset.csv',
    'olist_products_raw': 'olist_products_dataset.csv',
    'olist_sellers_raw': 'olist_sellers_dataset.csv',
}

for table_name, file_name in files.items():
    path = os.path.join(dataset_dir, file_name)
    df = pd.read_csv(path)
    df.to_sql(table_name, engine, if_exists='replace', index=False, chunksize=10_000)
    print(table_name, df.shape)



Після raw-завантаження створіть typed-таблиці. Саме typed-таблиці використовуються в усіх наступних завданнях.

DROP TABLE IF EXISTS olist_order_items CASCADE;
DROP TABLE IF EXISTS olist_orders      CASCADE;
DROP TABLE IF EXISTS olist_customers   CASCADE;
DROP TABLE IF EXISTS olist_products    CASCADE;
DROP TABLE IF EXISTS olist_sellers     CASCADE;

CREATE TABLE olist_customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_city            TEXT,
    customer_state           CHAR(2) NOT NULL
);

CREATE TABLE olist_orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT NOT NULL REFERENCES olist_customers(customer_id),
    order_status                  TEXT NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    CHECK (order_status IN (
        'created', 'approved', 'invoiced', 'processing',
        'shipped', 'delivered', 'unavailable', 'canceled'
    ))
);

CREATE TABLE olist_products (
    product_id                 TEXT PRIMARY KEY,
    product_category_name      TEXT,
    product_name_length        INTEGER CHECK (product_name_length IS NULL OR product_name_length >= 0),
    product_description_length INTEGER CHECK (product_description_length IS NULL OR product_description_length >= 0),
    product_photos_qty         INTEGER CHECK (product_photos_qty IS NULL OR product_photos_qty >= 0),
    product_weight_g           INTEGER CHECK (product_weight_g IS NULL OR product_weight_g >= 0),
    product_length_cm          INTEGER CHECK (product_length_cm IS NULL OR product_length_cm >= 0),
    product_height_cm          INTEGER CHECK (product_height_cm IS NULL OR product_height_cm >= 0),
    product_width_cm           INTEGER CHECK (product_width_cm IS NULL OR product_width_cm >= 0)
);

CREATE TABLE olist_sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city            TEXT,
    seller_state           CHAR(2) NOT NULL
);

CREATE TABLE olist_order_items (
    order_id            TEXT NOT NULL REFERENCES olist_orders(order_id),
    order_item_id       INTEGER NOT NULL,
    product_id          TEXT REFERENCES olist_products(product_id),
    seller_id           TEXT REFERENCES olist_sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12, 2) CHECK (price IS NULL OR price >= 0),
    freight_value       NUMERIC(12, 2) CHECK (freight_value IS NULL OR freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);



Перенесіть дані з raw-таблиць у typed-таблиці через INSERT ... SELECT. Нижче наведено шаблон; адаптуйте лише якщо ваша копія CSV має інші назви колонок.

INSERT INTO olist_customers
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix::INTEGER,
    customer_city,
    customer_state::CHAR(2)
FROM olist_customers_raw;

INSERT INTO olist_orders
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::TIMESTAMP,
    order_approved_at::TIMESTAMP,
    order_delivered_carrier_date::TIMESTAMP,
    order_delivered_customer_date::TIMESTAMP,
    order_estimated_delivery_date::TIMESTAMP
FROM olist_orders_raw;

INSERT INTO olist_products
SELECT
    product_id,
    product_category_name,
    product_name_lenght::INTEGER,
    product_description_lenght::INTEGER,
    product_photos_qty::INTEGER,
    product_weight_g::INTEGER,
    product_length_cm::INTEGER,
    product_height_cm::INTEGER,
    product_width_cm::INTEGER
FROM olist_products_raw;

INSERT INTO olist_sellers
SELECT
    seller_id,
    seller_zip_code_prefix::INTEGER,
    seller_city,
    seller_state::CHAR(2)
FROM olist_sellers_raw;

INSERT INTO olist_order_items
SELECT
    order_id,
    order_item_id::INTEGER,
    product_id,
    seller_id,
    shipping_limit_date::TIMESTAMP,
    price::NUMERIC(12, 2),
    freight_value::NUMERIC(12, 2)
FROM olist_order_items_raw;



Важливо. У файлі Olist назви product_name_lenght і product_description_lenght написані саме з помилкою lenght. У typed-схемі використовуйте нормалізовані назви product_name_length і product_description_length, але в SELECT із raw-таблиці звертайтеся до фактичних назв із CSV.



Додайте smoke-test кількості рядків. Якщо typed-таблиця має менше рядків, ніж raw-таблиця, поясніть причину.

SELECT 'customers' AS table_name, COUNT(*) AS n_rows FROM olist_customers
UNION ALL SELECT 'orders', COUNT(*) FROM olist_orders
UNION ALL SELECT 'order_items', COUNT(*) FROM olist_order_items
UNION ALL SELECT 'products', COUNT(*) FROM olist_products
UNION ALL SELECT 'sellers', COUNT(*) FROM olist_sellers
ORDER BY table_name;



Stub-schema fallback

Якщо немає можливості завантажити Olist, використайте наведений нижче DDL+seed. Stub-схема містить 30 customers, 50 orders і 100 order_items. Цього достатньо, щоб виконати всі CTE, recursive CTE, MV і EXPLAIN-завдання.



У цьому випадку всі наступні завдання (CTE, recursive CTE, Materialized View та EXPLAIN) виконуються на stub-схемі без будь-яких додаткових змін у коді.

DROP TABLE IF EXISTS olist_order_items CASCADE;
DROP TABLE IF EXISTS olist_orders      CASCADE;
DROP TABLE IF EXISTS olist_customers   CASCADE;
DROP TABLE IF EXISTS olist_products    CASCADE;
DROP TABLE IF EXISTS olist_sellers     CASCADE;

CREATE TABLE olist_customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_state           CHAR(2) NOT NULL,
    customer_city            TEXT
);

CREATE TABLE olist_orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT NOT NULL REFERENCES olist_customers(customer_id),
    order_status                  TEXT NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    CHECK (order_status IN (
        'created', 'approved', 'invoiced', 'processing',
        'shipped', 'delivered', 'unavailable', 'canceled'
    ))
);

CREATE TABLE olist_products (
    product_id                 TEXT PRIMARY KEY,
    product_category_name      TEXT,
    product_name_length        INTEGER CHECK (product_name_length IS NULL OR product_name_length >= 0),
    product_description_length INTEGER CHECK (product_description_length IS NULL OR product_description_length >= 0),
    product_photos_qty         INTEGER CHECK (product_photos_qty IS NULL OR product_photos_qty >= 0),
    product_weight_g           INTEGER CHECK (product_weight_g IS NULL OR product_weight_g >= 0),
    product_length_cm          INTEGER CHECK (product_length_cm IS NULL OR product_length_cm >= 0),
    product_height_cm          INTEGER CHECK (product_height_cm IS NULL OR product_height_cm >= 0),
    product_width_cm           INTEGER CHECK (product_width_cm IS NULL OR product_width_cm >= 0)
);

CREATE TABLE olist_sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city            TEXT,
    seller_state           CHAR(2) NOT NULL
);

CREATE TABLE olist_order_items (
    order_id            TEXT NOT NULL REFERENCES olist_orders(order_id),
    order_item_id       INTEGER NOT NULL,
    product_id          TEXT REFERENCES olist_products(product_id),
    seller_id           TEXT REFERENCES olist_sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12, 2) CHECK (price IS NULL OR price >= 0),
    freight_value       NUMERIC(12, 2) CHECK (freight_value IS NULL OR freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);

INSERT INTO olist_sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state)
VALUES
    ('s_01', 10001, 'Sao Paulo', 'SP'),
    ('s_02', 20001, 'Rio de Janeiro', 'RJ'),
    ('s_03', 30001, 'Belo Horizonte', 'MG');

INSERT INTO olist_products (
    product_id, product_category_name,
    product_name_length, product_description_length,
    product_photos_qty, product_weight_g,
    product_length_cm, product_height_cm, product_width_cm
)
VALUES
    ('p_01', 'electronics', 10, 100, 2,  800, 20, 10, 15),
    ('p_02', 'electronics', 12, 120, 3, 1200, 25, 12, 18),
    ('p_03', 'home',        8,  90, 1, 1500, 30, 20, 25),
    ('p_04', 'home',        9,  80, 2,  700, 18, 10, 14),
    ('p_05', 'fashion',     7,  60, 1,  300, 10,  5,  8),
    ('p_06', 'beauty',      6,  50, 1,  200,  8,  4,  6),
    ('p_07', 'sport',       9,  70, 2,  900, 20, 15, 16);

INSERT INTO olist_customers (
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_state, customer_city
)
SELECT
    'c_' || LPAD(n::TEXT, 3, '0'),
    'u_' || LPAD(((n - 1) % 25 + 1)::TEXT, 3, '0'),
    10000 + n,
    (ARRAY['SP', 'RJ', 'MG', 'BA', 'PR'])[(n % 5) + 1],
    'City' || (n % 10)
FROM generate_series(1, 30) AS n;

INSERT INTO olist_orders (
    order_id, customer_id, order_status,
    order_purchase_timestamp, order_approved_at,
    order_delivered_carrier_date, order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    'o_' || LPAD(n::TEXT, 3, '0'),
    'c_' || LPAD(((n % 30) + 1)::TEXT, 3, '0'),
    (ARRAY['delivered', 'delivered', 'delivered', 'canceled', 'shipped'])[(n % 5) + 1],
    TIMESTAMP '2024-01-01 00:00:00' + (n * INTERVAL '7 days'),
    TIMESTAMP '2024-01-01 00:00:00' + (n * INTERVAL '7 days') + INTERVAL '1 day',
    TIMESTAMP '2024-01-01 00:00:00' + (n * INTERVAL '7 days') + INTERVAL '3 days',
    TIMESTAMP '2024-01-01 00:00:00' + (n * INTERVAL '7 days') + INTERVAL '8 days',
    TIMESTAMP '2024-01-01 00:00:00' + (n * INTERVAL '7 days') + INTERVAL '10 days'
FROM generate_series(1, 50) AS n;

INSERT INTO olist_order_items (
    order_id, order_item_id, product_id, seller_id,
    shipping_limit_date, price, freight_value
)
SELECT
    'o_' || LPAD(((n - 1) % 50 + 1)::TEXT, 3, '0'),
    ((n - 1) / 50) + 1,
    'p_0' || ((n % 7) + 1),
    's_0' || ((n % 3) + 1),
    TIMESTAMP '2024-01-01 00:00:00' + (n * INTERVAL '7 days') + INTERVAL '5 days',
    (n % 200 + 10)::NUMERIC(12, 2),
    (n % 30 + 5)::NUMERIC(12, 2)
FROM generate_series(1, 100) AS n;



Зверніть увагу. Stub-схема свідомо мінімальна й детермінована: вона не використовує RANDOM(), тому результати після Restart & Run All залишаються стабільними. На ній EXPLAIN-плани будуть простішими, ніж на реальному Olist, і це нормально для навчальної цілі.



Завдання 2. CTE-chain pipeline з ≥5 stages

Побудуйте feature engineering pipeline через CTE-chain із щонайменше п’яти named stages. Кожен stage має мати короткий коментар у форматі -- Stage N: ... і виконувати одну логічну трансформацію.



Обов’язкові derived features:

RFM-features per customer: recency_days, frequency, monetary;
cohort_quarter: DATE_TRUNC('quarter', first_order_date)::DATE;
avg_order_value_30d: rolling 30-day AVG order_total per customer;
cancellation_rate per customer;
preferred_category per customer: top-1 product category за category revenue.
Зверніть увагу. Для recency_days використовуйте reference_date, обчислену з самого датасету, наприклад MAX(order_purchase_timestamp)::date + 1. Не використовуйте CURRENT_DATE як єдину reference date для історичного датасету: тоді результат змінюватиметься з кожним днем і буде менш відтворюваним.



Шаблон pipeline:

WITH
reference_date AS (
    -- Stage 0: stable reference date for historical dataset
    SELECT (MAX(order_purchase_timestamp)::DATE + 1) AS as_of_date
    FROM olist_orders
),
stage1_orders_total AS (
    -- Stage 1: orders + order_total + status
    SELECT
        o.customer_id,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp AS order_ts,
        o.order_purchase_timestamp::DATE AS order_date,
        COALESCE(SUM(
            COALESCE(oi.price, 0) + COALESCE(oi.freight_value, 0)
        ), 0)::NUMERIC(12, 2) AS order_total
    FROM olist_orders AS o
    LEFT JOIN olist_order_items AS oi
        ON oi.order_id = o.order_id
    GROUP BY
        o.customer_id,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp
),
stage2_rfm AS (
    -- Stage 2: RFM features per customer
    SELECT
        s.customer_id,
        (rd.as_of_date - MAX(s.order_date))::INTEGER AS recency_days,
        COUNT(*) AS frequency,
        SUM(s.order_total)::NUMERIC(12, 2) AS monetary,
        MIN(s.order_date) AS first_order_date
    FROM stage1_orders_total AS s
    CROSS JOIN reference_date AS rd
    GROUP BY s.customer_id, rd.as_of_date
),
stage3_cohort AS (
    -- Stage 3: cohort quarter from first order date
    SELECT
        r.*,
        DATE_TRUNC('quarter', r.first_order_date)::DATE AS cohort_quarter
    FROM stage2_rfm AS r
),
stage4_rolling_aov AS (
    -- Stage 4: rolling 30-day average order value per customer
    SELECT
        s.customer_id,
        s.order_id,
        s.order_ts,
        s.order_total,
        AVG(s.order_total) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.order_ts
            RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
        )::NUMERIC(12, 2) AS avg_order_value_30d,
        ROW_NUMBER() OVER (
            PARTITION BY s.customer_id
            ORDER BY s.order_ts DESC, s.order_id DESC
        ) AS rn_recent
    FROM stage1_orders_total AS s
),
stage5_cancel_rate AS (
    -- Stage 5: cancellation rate per customer
    SELECT
        customer_id,
        AVG(
            CASE WHEN order_status = 'canceled' THEN 1.0 ELSE 0.0 END
        )::NUMERIC(6, 4) AS cancellation_rate
    FROM stage1_orders_total
    GROUP BY customer_id
),
stage6_category_revenue AS (
    -- Stage 6: revenue by customer and product category
    SELECT
        o.customer_id,
        COALESCE(p.product_category_name, '(unknown)') AS product_category_name,
        SUM(
            COALESCE(oi.price, 0) + COALESCE(oi.freight_value, 0)
        )::NUMERIC(12, 2) AS category_revenue
    FROM olist_orders AS o
    JOIN olist_order_items AS oi
        ON oi.order_id = o.order_id
    LEFT JOIN olist_products AS p
        ON p.product_id = oi.product_id
    GROUP BY o.customer_id, COALESCE(p.product_category_name, '(unknown)')
),
stage7_preferred_category AS (
    -- Stage 7: preferred category per customer via top-1 ranking
    SELECT
        customer_id,
        product_category_name,
        category_revenue
    FROM (
        SELECT
            cr.*,
            ROW_NUMBER() OVER (
                PARTITION BY cr.customer_id
                ORDER BY cr.category_revenue DESC, cr.product_category_name
            ) AS rn
        FROM stage6_category_revenue AS cr
    ) AS ranked
    WHERE rn = 1
)
SELECT
    c.customer_id,
    c.customer_state,
    COALESCE(coh.recency_days, 9999) AS recency_days,
    COALESCE(coh.frequency, 0) AS frequency,
    COALESCE(coh.monetary, 0)::NUMERIC(12, 2) AS monetary,
    coh.first_order_date,
    coh.cohort_quarter,
    COALESCE(aov.avg_order_value_30d, 0)::NUMERIC(12, 2) AS avg_order_value_30d_recent,
    COALESCE(cancel.cancellation_rate, 0)::NUMERIC(6, 4) AS cancellation_rate,
    COALESCE(pc.product_category_name, '(none)') AS preferred_category,
    COALESCE(pc.category_revenue, 0)::NUMERIC(12, 2) AS preferred_category_revenue
FROM olist_customers AS c
LEFT JOIN stage3_cohort AS coh
    ON coh.customer_id = c.customer_id
LEFT JOIN stage4_rolling_aov AS aov
    ON aov.customer_id = c.customer_id
   AND aov.rn_recent = 1
LEFT JOIN stage5_cancel_rate AS cancel
    ON cancel.customer_id = c.customer_id
LEFT JOIN stage7_preferred_category AS pc
    ON pc.customer_id = c.customer_id
ORDER BY monetary DESC NULLS LAST, c.customer_id
LIMIT 20;



Важливо

Не зливайте всі обчислення в один CTE. Для цього завдання важливі не тільки фінальні колонки, а й структура pipeline: named stages, single responsibility і можливість окремо перевірити логіку кожного етапу.


Завдання 3. Recursive CTE для referral chain

Olist не містить referral-таблиці. Створіть синтетичну hw5_referrals — пари referrer_customer_id → referred_customer_id — і використайте recursive CTE, щоб обчислити depth і path у referral-tree.

DROP TABLE IF EXISTS hw5_referrals CASCADE;

CREATE TABLE hw5_referrals (
    referrer_customer_id TEXT NOT NULL REFERENCES olist_customers(customer_id),
    referred_customer_id TEXT NOT NULL REFERENCES olist_customers(customer_id),
    referred_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (referred_customer_id),
    CHECK (referrer_customer_id <> referred_customer_id)
);

WITH ordered_customers AS (
    SELECT
        customer_id,
        ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
    FROM olist_customers
    ORDER BY customer_id
    LIMIT 10
)
INSERT INTO hw5_referrals (referrer_customer_id, referred_customer_id)
SELECT
    prev.customer_id AS referrer_customer_id,
    nxt.customer_id AS referred_customer_id
FROM ordered_customers AS prev
JOIN ordered_customers AS nxt
    ON nxt.rn = prev.rn + 1
ON CONFLICT (referred_customer_id) DO NOTHING;

SELECT *
FROM hw5_referrals
ORDER BY referrer_customer_id, referred_customer_id;



Тепер побудуйте recursive CTE. У запиті має бути anchor part, recursive part, path, depth і захист від циклів через масив відвіданих customer_id та depth guard.

WITH RECURSIVE referral_depth AS (
    -- ANCHOR: root customers, які не були referred іншими customers
    SELECT
        c.customer_id,
        1 AS depth,
        ARRAY[c.customer_id]::TEXT[] AS path_ids,
        c.customer_id::TEXT AS path_text
    FROM olist_customers AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM hw5_referrals AS r
        WHERE r.referred_customer_id = c.customer_id
    )

    UNION ALL

    -- RECURSIVE: перейти від referrer до його referred customers
    SELECT
        r.referred_customer_id AS customer_id,
        rd.depth + 1 AS depth,
        rd.path_ids || r.referred_customer_id AS path_ids,
        rd.path_text || ' -> ' || r.referred_customer_id AS path_text
    FROM hw5_referrals AS r
    JOIN referral_depth AS rd
        ON rd.customer_id = r.referrer_customer_id
    WHERE NOT r.referred_customer_id = ANY(rd.path_ids)
      AND rd.depth < 50
)
SELECT
    depth,
    COUNT(*) AS n_customers,
    MAX(path_text) AS sample_path
FROM referral_depth
GROUP BY depth
ORDER BY depth;



Зверніть увагу. Anchor part має використовувати NOT EXISTS, а не NOT IN. Це узгоджується з Misconception Lab теми 5: NOT IN може дати неправильний результат, якщо підзапит містить NULL. Навіть якщо зараз referred_customer_id має NOT NULL, NOT EXISTS краще передає anti-join семантику.



 Важливо

У Reflection обов’язково поясніть, що станеться при циклі A → B → A. Для production-варіанта достатньо описати два захисти: масив path_ids із перевіркою NOT next_id = ANY(path_ids) і depth guard, наприклад rd.depth < 50. Можна також згадати PostgreSQL CYCLE-clause.


Завдання 4. Materialized View з CONCURRENT REFRESH

Оберніть повний результат CTE-pipeline з Завдання 2 у Materialized View. MV має містити ті самі ключові features, а не скорочену версію pipeline. Після створення MV додайте UNIQUE INDEX на customer_id і виконайте REFRESH MATERIALIZED VIEW CONCURRENTLY.

DROP MATERIALIZED VIEW IF EXISTS mv_olist_customer_features CASCADE;

CREATE MATERIALIZED VIEW mv_olist_customer_features AS
WITH
reference_date AS (
    SELECT (MAX(order_purchase_timestamp)::DATE + 1) AS as_of_date
    FROM olist_orders
),
stage1_orders_total AS (
    SELECT
        o.customer_id,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp AS order_ts,
        o.order_purchase_timestamp::DATE AS order_date,
        COALESCE(SUM(
            COALESCE(oi.price, 0) + COALESCE(oi.freight_value, 0)
        ), 0)::NUMERIC(12, 2) AS order_total
    FROM olist_orders AS o
    LEFT JOIN olist_order_items AS oi
        ON oi.order_id = o.order_id
    GROUP BY
        o.customer_id,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp
),
stage2_rfm AS (
    SELECT
        s.customer_id,
        (rd.as_of_date - MAX(s.order_date))::INTEGER AS recency_days,
        COUNT(*) AS frequency,
        SUM(s.order_total)::NUMERIC(12, 2) AS monetary,
        MIN(s.order_date) AS first_order_date
    FROM stage1_orders_total AS s
    CROSS JOIN reference_date AS rd
    GROUP BY s.customer_id, rd.as_of_date
),
stage3_cohort AS (
    SELECT
        r.*,
        DATE_TRUNC('quarter', r.first_order_date)::DATE AS cohort_quarter
    FROM stage2_rfm AS r
),
stage4_rolling_aov AS (
    SELECT
        s.customer_id,
        s.order_id,
        s.order_ts,
        s.order_total,
        AVG(s.order_total) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.order_ts
            RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
        )::NUMERIC(12, 2) AS avg_order_value_30d,
        ROW_NUMBER() OVER (
            PARTITION BY s.customer_id
            ORDER BY s.order_ts DESC, s.order_id DESC
        ) AS rn_recent
    FROM stage1_orders_total AS s
),
stage5_cancel_rate AS (
    SELECT
        customer_id,
        AVG(
            CASE WHEN order_status = 'canceled' THEN 1.0 ELSE 0.0 END
        )::NUMERIC(6, 4) AS cancellation_rate
    FROM stage1_orders_total
    GROUP BY customer_id
),
stage6_category_revenue AS (
    SELECT
        o.customer_id,
        COALESCE(p.product_category_name, '(unknown)') AS product_category_name,
        SUM(
            COALESCE(oi.price, 0) + COALESCE(oi.freight_value, 0)
        )::NUMERIC(12, 2) AS category_revenue
    FROM olist_orders AS o
    JOIN olist_order_items AS oi
        ON oi.order_id = o.order_id
    LEFT JOIN olist_products AS p
        ON p.product_id = oi.product_id
    GROUP BY o.customer_id, COALESCE(p.product_category_name, '(unknown)')
),
stage7_preferred_category AS (
    SELECT
        customer_id,
        product_category_name,
        category_revenue
    FROM (
        SELECT
            cr.*,
            ROW_NUMBER() OVER (
                PARTITION BY cr.customer_id
                ORDER BY cr.category_revenue DESC, cr.product_category_name
            ) AS rn
        FROM stage6_category_revenue AS cr
    ) AS ranked
    WHERE rn = 1
)
SELECT
    c.customer_id,
    c.customer_state,
    COALESCE(coh.recency_days, 9999) AS recency_days,
    COALESCE(coh.frequency, 0) AS frequency,
    COALESCE(coh.monetary, 0)::NUMERIC(12, 2) AS monetary,
    coh.first_order_date,
    coh.cohort_quarter,
    COALESCE(aov.avg_order_value_30d, 0)::NUMERIC(12, 2) AS avg_order_value_30d_recent,
    COALESCE(cancel.cancellation_rate, 0)::NUMERIC(6, 4) AS cancellation_rate,
    COALESCE(pc.product_category_name, '(none)') AS preferred_category,
    COALESCE(pc.category_revenue, 0)::NUMERIC(12, 2) AS preferred_category_revenue
FROM olist_customers AS c
LEFT JOIN stage3_cohort AS coh
    ON coh.customer_id = c.customer_id
LEFT JOIN stage4_rolling_aov AS aov
    ON aov.customer_id = c.customer_id
   AND aov.rn_recent = 1
LEFT JOIN stage5_cancel_rate AS cancel
    ON cancel.customer_id = c.customer_id
LEFT JOIN stage7_preferred_category AS pc
    ON pc.customer_id = c.customer_id;

CREATE UNIQUE INDEX idx_mv_olist_customer_features_customer_id
    ON mv_olist_customer_features (customer_id);



Перевірте MV:

SELECT COUNT(*) AS n_rows
FROM mv_olist_customer_features;

SELECT *
FROM mv_olist_customer_features
ORDER BY monetary DESC NULLS LAST, customer_id
LIMIT 5;



Виконайте concurrent refresh. Запускайте цю команду окремою SQL-клітинкою після створення UNIQUE INDEX.

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_olist_customer_features;



Важливо. Якщо REFRESH CONCURRENTLY впав із помилкою про відсутність відповідного UNIQUE INDEX, перевірте, що індекс справді UNIQUE, створений саме на колонках MV, не є partial index і покриває всі рядки. Звичайний неунікальний індекс для цієї команди недостатній.



Завдання 5. EXPLAIN ANALYZE + Reflection

Запустіть EXPLAIN (ANALYZE, BUFFERS) на двох сценаріях: повне переобчислення CTE-pipeline і lookup із Materialized View. Збережіть обидва output у notebook.



1. EXPLAIN на повному CTE-pipeline

EXPLAIN (ANALYZE, BUFFERS)
WITH
reference_date AS (
    SELECT (MAX(order_purchase_timestamp)::DATE + 1) AS as_of_date
    FROM olist_orders
),
stage1_orders_total AS (
    SELECT
        o.customer_id,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp AS order_ts,
        o.order_purchase_timestamp::DATE AS order_date,
        COALESCE(SUM(
            COALESCE(oi.price, 0) + COALESCE(oi.freight_value, 0)
        ), 0)::NUMERIC(12, 2) AS order_total
    FROM olist_orders AS o
    LEFT JOIN olist_order_items AS oi
        ON oi.order_id = o.order_id
    GROUP BY
        o.customer_id,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp
),
stage2_rfm AS (
    SELECT
        s.customer_id,
        (rd.as_of_date - MAX(s.order_date))::INTEGER AS recency_days,
        COUNT(*) AS frequency,
        SUM(s.order_total)::NUMERIC(12, 2) AS monetary,
        MIN(s.order_date) AS first_order_date
    FROM stage1_orders_total AS s
    CROSS JOIN reference_date AS rd
    GROUP BY s.customer_id, rd.as_of_date
)
SELECT *
FROM stage2_rfm
ORDER BY monetary DESC NULLS LAST
LIMIT 10;



2. EXPLAIN на lookup із MV

Для lookup за customer_id має допомагати UNIQUE INDEX.

EXPLAIN (ANALYZE, BUFFERS)
WITH target_customer AS (
    SELECT customer_id
    FROM olist_customers
    ORDER BY customer_id
    LIMIT 1
)
SELECT mv.*
FROM mv_olist_customer_features AS mv
JOIN target_customer AS t
    ON t.customer_id = mv.customer_id;



Додатково можна порівняти top-N читання з MV. Якщо хочете оптимізувати саме цей сценарій, додайте окремий індекс на monetary.

CREATE INDEX IF NOT EXISTS idx_mv_olist_customer_features_monetary
    ON mv_olist_customer_features (monetary DESC);

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM mv_olist_customer_features
ORDER BY monetary DESC NULLS LAST
LIMIT 10;



Reflection

Напишіть Reflection обсягом приблизно 250–300 слів.

Дайте відповіді на запитання:

Який feature з pipeline найдорожчий у обчисленні за EXPLAIN ANALYZE? Чому: JOIN, GROUP BY, window function, Sort або Hash Aggregate?
Чи варто кешувати цей feature через Materialized View? Який refresh-cycle ви б обрали: щогодини, щодоби, on-demand?
У якому use case звичайний VIEW був би правильнішим вибором, ніж MV?
Як recursive CTE забезпечує termination? Що станеться, якщо referral graph містить цикл A → B → A?
Який trade-off важливіший у цьому pipeline: freshness, latency, recompute-cost чи storage-cost?
Зверніть увагу. Reflection має бути конкретною. Не достатньо написати «MV швидша». Потрібно послатися на фактичний EXPLAIN output: які операції видно в плані, який запит виконується довше, де з’являються Hash Aggregate, Sort, Seq Scan або Index Scan.





Підсумки

У цьому домашньому завданні ви побудуєте повний pipeline підготовки ознак для задач Data Science та Machine Learning.



☝️
У процесі роботи ви:

створите typed-схему поверх сирих даних;
реалізуєте feature engineering через CTE-chain;
побудуєте customer-level ознаки для ML-моделі;
використаєте recursive CTE для роботи з графовими структурами;
створите Materialized View для кешування результатів;
порівняєте різні підходи до виконання запитів через EXPLAIN ANALYZE;
навчитеся оцінювати компроміси між швидкістю, актуальністю даних та вартістю обчислень.
Саме так виглядає підготовка ознак у реальних Data Engineering та ML-проєктах — від сирих даних до готового набору features для моделі.
```