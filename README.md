# ДЗ5 — CTE, recursive CTE і Materialized View на Olist

Тема 5, GoIT «Реляційні бази даних». Робота виконана в одному Colab-сумісному notebook:
[`HW5.ipynb`](HW5.ipynb) — із виконаними клітинками й збереженими output.

## Датасет

**Olist Brazilian E-commerce Public Dataset** — близько 100 тис. замовлень бразильського
e-commerce-майданчика Olist за 2016–2018 роки. У цьому ДЗ використано **5 пов'язаних таблиць**:
клієнти, замовлення, позиції замовлень, товари, продавці.

| | |
|---|---|
| Оригінал на Kaggle | https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce |
| Публічне дзеркало тих самих CSV | https://huggingface.co/datasets/bulutttt/olist-raw-data |
| Ліцензія | CC BY-NC-SA 4.0 |

## Спосіб отримання файлів

Notebook пробує три джерела за пріоритетом, перше доступне виграє.

1. **KaggleHub** — `kagglehub.dataset_download('olistbr/brazilian-ecommerce')`. Використовується
   лише якщо креденшели справді налаштовані (`KAGGLE_USERNAME`/`KAGGLE_KEY` або
   `~/.kaggle/kaggle.json`). Перевірка обовʼязкова: без токена `kagglehub` намагається запитати
   креденшели інтерактивно, а це зависання при *Restart & Run All*.
2. **Локальна папка `data/olist/`** — 5 файлів `*.csv.gz`, які лежать у цьому репозиторії
   (19 МБ; без стиснення це було б 46 МБ).
3. **Дзеркало HuggingFace** — якщо репозиторій клоновано без даних, файли завантажуються в
   `data/olist/` і надалі беруться звідти.

Якщо не спрацювало жодне джерело, notebook вмикає **stub-схему** з умови ДЗ (3 продавці,
7 товарів, 30 клієнтів, 50 замовлень, 100 позицій) і виконується до кінця без єдиної правки SQL:
stub наповнює **ті самі** `olist_*_raw` таблиці, тому точка розгалуження в ноутбуці одна.

Усі джерела дають ідентичні файли: у дзеркалі збережено навіть оригінальну описку в назвах
колонок `product_name_lenght` / `product_description_lenght`.

## Використані таблиці й кількість рядків

| CSV | Рядків | Typed-таблиця | Ключ |
|---|---|---|---|
| `olist_customers_dataset.csv` | 99 441 | `olist_customers` | `customer_id` |
| `olist_orders_dataset.csv` | 99 441 | `olist_orders` | `order_id` |
| `olist_order_items_dataset.csv` | 112 650 | `olist_order_items` | `(order_id, order_item_id)` |
| `olist_products_dataset.csv` | 32 951 | `olist_products` | `product_id` |
| `olist_sellers_dataset.csv` | 3 095 | `olist_sellers` | `seller_id` |

**Жоден рядок не втрачено** при переході raw → typed (`diff = 0` для всіх пʼяти таблиць): усі
посилання датасету цілі, тому `FOREIGN KEY` не мали чого блокувати.

## Шари

**Raw-рівень** (`olist_*_raw`, 5 таблиць) дзеркалить CSV як є, з типами, які виводить `pandas`,
і з оригінальними назвами колонок. Завантаження — через `COPY ... FROM STDIN`
(`psycopg2.cursor.copy_expert`), а не `DataFrame.to_sql`: `to_sql` шле рядки по одному й на
112 тис. позицій займає хвилини замість секунд.

**Typed-схема** (`olist_customers`, `olist_orders`, `olist_order_items`, `olist_products`,
`olist_sellers`) — контракт даних: **5 `PRIMARY KEY`** (у `olist_order_items` складений),
**4 `FOREIGN KEY`**, **10 `CHECK`** (список статусів замовлення, невідʼємні ціни, вага й
габарити). Типи приводяться явним `INSERT ... SELECT`, там же нормалізуються назви колонок
(`lenght` → `length`).

**Службові обʼєкти ДЗ** мають префікс `hw5_` (`hw5_referrals`), typed-таблиці Olist — `olist_`.

## CTE-chain: stages pipeline

`v_olist_customer_features` — звичайний `VIEW` із повним pipeline; `mv_olist_customer_features` —
той самий SQL, матеріалізований. Вісім named stages, у кожного одна відповідальність:

| Stage | Що робить | Обовʼязкова ознака |
|---|---|---|
| `reference_date` | `MAX(order_purchase_timestamp)::DATE + 1` | стабільна база для recency |
| `stage1_orders_total` | зводить позиції до замовлення: `price + freight_value` | — |
| `stage2_rfm` | `recency_days`, `frequency`, `monetary`, `first_order_date` | **RFM** |
| `stage3_cohort` | `DATE_TRUNC('quarter', first_order_date)::DATE` | **cohort_quarter** |
| `stage4_rolling_aov` | `AVG(...) OVER (... RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW)` + `ROW_NUMBER()` | **avg_order_value_30d** |
| `stage5_cancel_rate` | частка `order_status = 'canceled'` | **cancellation_rate** |
| `stage6_category_revenue` | виручка клієнт × категорія товару | — |
| `stage7_preferred_category` | top-1 категорія за виручкою, нічия — за назвою | **preferred_category** |

Фінальний `SELECT` починається з `olist_customers` і зʼєднується через `LEFT JOIN`, щоб клієнти
без замовлень не зникали з feature store, а отримували явні заглушки (`recency_days = 9999`,
`frequency = 0`, `preferred_category = '(none)'`).

Опорна дата для recency береться **з датасету** (`MAX(order_purchase_timestamp)::DATE + 1 =
2018-10-18`), а не з `CURRENT_DATE` — інакше `recency_days` змінювався б щодня.

**Про грануляність ключа (розділ 2.1 ноутбука).** Ключ feature store — `customer_id`, як
вимагає умова. Але в Olist `customer_id` видається на кожне замовлення: **99 441**
`customer_id` відповідають лише **96 096** реальним покупцям (`customer_unique_id`), максимум
замовлень на `customer_id` — **1**, на покупця — **17**, повторних покупців **2 997**. Тому на
цьому ключі `frequency ≡ 1`, а 30-денне вікно rolling AOV завжди містить один рядок. У ноутбуці
це задокументовано окремим запитом, а window-функція додатково продемонстрована на покупці з
найдовшою історією, де у вікно потрапляє до 4 замовлень.

## Recursive CTE

Olist не містить referral-таблиці, тому `hw5_referrals` — **навчальна імітація** referral-графа.
Сід детермінований: бінарне дерево на 15 клієнтах (14 ребер) плюс **навмисний замкнений цикл**
`A → B → C → A` на трьох інших (`PRIMARY KEY (referred_customer_id)` цьому не перешкоджає).
`referred_at` — фіксована константа, а не `NOW()`.

Обхід має anchor через `NOT EXISTS` (не `NOT IN`: з `NULL` у підзапиті `NOT IN` дав би порожній
anchor), recursive part, `depth`, `path_ids TEXT[]` і `path_text`. Два незалежні запобіжники:

- `NOT (next_id = ANY (path_ids))` — коректність: обхід не входить туди, де вже був;
- `rd.depth < 50` — гарантія завершення навіть при помилці в першій умові.

Результат: дерево глибиною **4** (1 → 2 → 4 → 8), **14** вузлів під коренями. Окремо показано
обидва боки захисту: обхід, запущений **усередині** циклу, спиняється на `depth = 3` (видно
вузол, на якому його заблоковано), а перевірка охоплення ловить протилежний випадок — цикл без
кореня у звіт не потрапляє зовсім, бо `NOT EXISTS`-anchor не має з чого його почати.

## Materialized View і refresh

`mv_olist_customer_features` створено з **повного** pipeline (не скороченого) — автоперевірка
порівнює MV з live-`VIEW` через `EXCEPT` в обидва боки, обидва дають 0 рядків.

- `UNIQUE INDEX idx_mv_olist_customer_features_customer_id` — не оптимізація, а **умова роботи**
  `REFRESH ... CONCURRENTLY`: без унікального й повного (не partial) індексу PostgreSQL
  неблокуючий refresh не зробить.
- `REFRESH MATERIALIZED VIEW CONCURRENTLY` виконується окремим зʼєднанням з
  `isolation_level='AUTOCOMMIT'`, бо команда не працює в транзакційному блоці, а JupySQL виконує
  кожну клітинку саме в транзакції.
- Розмір: **22 MB** кешу проти **46 MB** вихідних `olist_orders` + `olist_order_items`.
- Тривалість: блокуючий `REFRESH` — **2.62 с**, `CONCURRENTLY` — **3.14 с** (+20 % за те, що
  читачі не блокуються).
- Freshness продемонстровано ідемпотентно: `INSERT` probe-замовлення → MV ще віддає старе
  значення, live-`VIEW` — нове → `REFRESH CONCURRENTLY` вирівнює → probe прибрано, refresh
  повертає початковий стан.

## EXPLAIN (ANALYZE, BUFFERS)

Чотири сценарії читання **одного й того самого** набору ознак (із збереженого прогону):

| Сценарій | Execution | Буфери | Проти pipeline |
|---|---|---|---|
| повне переобчислення CTE-pipeline | 1951.2 мс | 140 469 | 1x |
| top-10 з MV без індексу (`top-N heapsort` + `Parallel Seq Scan`) | 19.5 мс | 8 556 | 100x |
| lookup за `customer_id` (`Index Scan` по UNIQUE INDEX) | 0.127 мс | 30 | 15 364x |
| top-10 з MV з індексом `(monetary DESC NULLS LAST)` | 0.038 мс | 43 | 51 349x |

Найдорожчий вузол повного плану — не `JOIN`, а `Sort` під window-функцією
`stage4_rolling_aov`: `Sort Method: external merge  Disk: 9440kB`, далі два `WindowAgg` —
520.9 → **724.9 мс**. Таймінги між прогонами трохи змінюються, порядки — ні.

Повний Reflection (≈280 слів) — у розділі 5.5 ноутбука.

## Як запустити

**У Colab.** Усі залежності ставить перша клітинка, PostgreSQL 16 піднімається вбудованим
`pgserver` (без Docker), дані беруться з репозиторію або дзеркала. Далі
**Runtime → Restart session → Run all**.

**Локально.**

```bash
py -3.12 -m venv .venv && . .venv/Scripts/activate   # Linux/macOS: . .venv/bin/activate
pip install pgserver psycopg2-binary "sqlalchemy>=2.0" pandas jupysql kagglehub tzdata jupyter
jupyter lab HW5.ipynb                                 # далі Restart & Run All
```

> **Потрібен Python 3.12.** `pgserver` 0.1.4 має колеса лише до `cp312` включно — на Python 3.13
> `pip install pgserver` завершується помилкою «No matching distribution found».

> **Windows.** Колесо `pgserver` для Windows не містить `share/postgresql/timezone`, тому сервер
> стартує з `TimeZone=GMT`, а `SET TIME ZONE 'UTC'` падає. Notebook лагодить це сам: функція
> `ensure_pg_timezone_files()` копіює `site-packages/tzdata/zoneinfo` у
> `site-packages/pgserver/pginstall/share/postgresql/timezone`. У Colab/Linux вона нічого не
> робить.

> **SQLAlchemy 2.1.** Починаючи з цієї версії `postgresql://` віддається драйверу `psycopg` (v3),
> тому в `create_engine` URI явно переписується на `postgresql+psycopg2://` — саме цей драйвер
> надає `cursor.copy_expert()` для `COPY`.

Відтворюваність: усі DDL починаються з `DROP ... IF EXISTS`, `reference_date` береться з даних,
у синтетичних даних немає `RANDOM()` і `NOW()`, probe-рядок freshness-демо прибирається. Фінальна
клітинка — 8 блоків `assert`, які падають, якщо будь-який артефакт ДЗ відсутній або MV
розійшлася з pipeline.

## Структура репозиторію

| Шлях | Що це |
|---|---|
| `HW5.ipynb` | notebook із виконаними клітинками й усіма висновками |
| `README.md` | цей файл |
| `data/olist/*.csv.gz` | 5 таблиць Olist, gzip, 19 МБ |
| `task.md`, `task_details.md` | умова завдання |

## Структура notebook

| Розділ | Зміст |
|---|---|
| 1 | `pgserver`, отримання Olist, raw-рівень через `COPY`, typed-схема, smoke-тести |
| 2 | CTE-chain із 8 named stages, грануляність ключа, перевірки кожного stage |
| 3 | `hw5_referrals`, recursive CTE, два запобіжники від циклів |
| 4 | `MATERIALIZED VIEW`, `UNIQUE INDEX`, `REFRESH CONCURRENTLY`, демонстрація staleness |
| 5 | чотири `EXPLAIN (ANALYZE, BUFFERS)`, зведення таймінгів, Reflection |
| — | автоперевірки та підсумки |
