```
Завдання 4. Узагальнені табличні вирази (CTE), Materialized View
Вітаємо у домашньому завданні теми 5!

У цій темі ви працювали з підзапитами, CTE, CTE-chain підходом до SQL-пайплайнів, рекурсивними CTE, Materialized View та базовим аналізом плану виконання через EXPLAIN ANALYZE. У домашньому завданні ви застосуєте ці інструменти для побудови customer-level ознак на багатотабличному e-commerce-датасеті Olist.



Головна мета роботи — не просто написати один великий SQL-запит, а побудувати відтворюваний feature engineering pipeline: отримати дані, створити контрольовану typed-схему, розбити трансформацію на зрозумілі CTE-етапи, реалізувати recursive CTE, матеріалізувати фінальні ознаки та порівняти вартість обчислення через EXPLAIN.



У результаті виконання завдання ви навчитеся:

завантажувати пов’язані таблиці Olist у PostgreSQL і створювати typed-схему поверх raw-шару;
будувати CTE-chain із щонайменше п’яти named stages у стилі аналітичних SQL/dbt-пайплайнів;
створювати customer-level features: RFM, cohort quarter, rolling AOV, cancellation rate і preferred category;
використовувати window functions у CTE-ланцюжку без втрати деталізації рядків;
писати recursive CTE з anchor part, recursive part, termination condition і захистом від циклів;
створювати Materialized View для feature caching і виконувати REFRESH MATERIALIZED VIEW CONCURRENTLY;
порівнювати повне переобчислення pipeline з читанням із MV через EXPLAIN (ANALYZE, BUFFERS);
пояснювати компроміс між freshness, latency, recompute-cost і storage-cost для ML-feature serving.


 ☝ Важливо. Основне правило цього ДЗ: усі SQL-клітинки мають бути відтворюваними. Notebook повинен виконуватися після Restart & Run All без ручного виправлення таблиць, шляхів, constraints або проміжних об’єктів.


Що потрібно знати перед виконанням

Із огляду дисципліни вам знадобляться:

запуск PostgreSQL через pgserver у Google Colab;
робота з notebook;
структура репозиторію;
базове завантаження CSV-даних.
Із тем 3–4 вам знадобляться:

SELECT, WHERE, GROUP BY, HAVING, ORDER BY, LIMIT;
JOIN та anti-join;
NULLhandling і NOT EXISTS;
window functions на базовому рівні;
CREATE TABLE, constraints, DML і DDL.
Із теми 5 вам знадобляться:

scalar, IN, EXISTS і correlated subqueries;
CTE та CTE chains;
recursive CTE з anchor і recursive parts;
VIEW vs Materialized View;
REFRESH MATERIALIZED VIEW CONCURRENTLY;
EXPLAIN (ANALYZE, BUFFERS).




Хід роботи

У цьому домашньому завданні ви побудуєте повний pipeline підготовки ознак для ML-моделі:

Завантажите Olist або використаєте stub-схему.
Створите контрольовану typed-схему даних.
Побудуєте feature engineering pipeline через CTE-chain.
Реалізуєте recursive CTE для роботи з графовою структурою.
Матеріалізуєте результати через Materialized View.
Порівняєте різні способи виконання запитів через EXPLAIN ANALYZE.
Підготуєте Reflection щодо архітектурних рішень і компромісів між швидкістю, вартістю обчислень та актуальністю даних.


Опис домашнього завдання

Уявіть, що ви працюєте Data Engineer або ML Engineer у продуктовій компанії.

Вам потрібно підготувати customer-level feature store для подальшого навчання моделей прогнозування поведінки клієнтів. Для цього необхідно побудувати відтворюваний SQL-pipeline, реалізувати складні трансформації через CTE, створити механізм кешування ознак через Materialized View та оцінити вартість обчислень.

Саме такі задачі ви виконаєте в межах цього домашнього завдання.



Усі наступні завдання виконуються на одному датасеті — Olist Brazilian E-commerce Dataset. Він дозволяє відпрацювати не лише окремі SQL-конструкції, а й побудову повноцінного feature engineering pipeline на багатотабличній реляційній схемі.



Для домашнього завдання використовується Olist Brazilian E-commerce Public Dataset — багатотабличний набір даних про приблизно 100 тис. замовлень на бразильській e-commerce-платформі Olist за 2016–2018 роки. У цьому ДЗ потрібні таблиці customers, orders, order_items, products і sellers.

Джерело: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Таблиця	Призначення	Ключ у typed-схемі
olist_customers	Клієнти: customer_id, customer_unique_id, city/state/zip.	customer_id
olist_orders	Замовлення: статус і часові мітки.	order_id
olist_order_items	Позиції замовлення: товар, продавець, ціна, freight.	(order_id, order_item_id)
olist_products	Товари й категорії.	product_id
olist_sellers	Продавці: city/state/zip.	seller_id


Зверніть увагу. Olist не має referral-таблиці. Для recursive CTE у Завданні 3 потрібно синтетично створити hw5_referrals — таблицю пар referrer_customer_id → referred_customer_id. Це навчальна імітація referral-графа, а не реальна колонка датасету Olist.



Перед здачею переконайтеся, що:

Notebook виконується після Restart & Run All без помилок.
Завантажено Olist або використано stub-schema fallback.
Створено typed-схему з усіма необхідними таблицями.
CTE-chain містить щонайменше 5 named stages.
Реалізовано всі обов’язкові derived features.
Recursive CTE має захист від циклів.
Створено Materialized View та UNIQUE INDEX.
REFRESH MATERIALIZED VIEW CONCURRENTLY виконується без помилок.
У notebook присутні обидва EXPLAIN-плани.
Reflection відповідає на всі запитання.


Підготовка та завантаження домашнього завдання

Створіть публічний репозиторій goit-rdb-hw-05.
Виконайте роботу в Google Colab notebook.
Додайте README.md з джерелом датасету, способом отримання файлів, описом raw/typed-шару та короткою інструкцією запуску.
Переконайтеся, що notebook виконується від початку до кінця після Restart & Run All.
Збережіть notebook разом із output клітинок.
Створіть архів ДЗ5_ПІБ.zip і завантажте його в LMS.
Додайте в LMS посилання на репозиторій та архів.


Якщо в курсовому репозиторії є notebooks/hw_t5_template.ipynb, використайте його як основу.

Для службових таблиць ДЗ використовуйте префікс hw5_, а для typed-таблиць Olist — префікс olist_.



Формат здачі:

публічний репозиторій goit-rdb-hw-05;
notebook у форматі .ipynb з output клітинок;
README.md із джерелом даних, способом отримання файлів, описом CTE-stages і короткою інструкцією запуску;
архів ДЗ5_ПІБ.zip у LMS;
CSV-файли у папці data/, якщо вони вкладаються у ліміт репозиторію;
якщо CSV не вкладаються у ліміт репозиторію — стабільне посилання або інструкція отримання через Kaggle / course archive.




Формат оцінювання

Загальна оцінка за домашнє завдання — 100 балів.

Етап	Що оцінюється	Бали
1. Setup і typed-schema Olist	Працююче підключення доpgserver; 5 таблиць Olist або stub-schema; typed-таблиці з ключами й базовими constraints	0–15
2. CTE-chain pipeline	Щонайменше 5 named stages; кожен stage має single responsibility; присутні 5 обов’язкових derived features	0–35
3. Recursive CTE	Anchor + recursive parts; termination condition; захист від циклів або depth-guard; осмислений depth/path результат	0–15
4. Materialized View	CREATE MATERIALIZED VIEW на основі повного feature pipeline; UNIQUE INDEX; REFRESH CONCURRENTLYбез помилок	0–20
5. EXPLAIN + Reflection	EXPLAIN (ANALYZE, BUFFERS)для full pipeline і MV-lookup; Reflection 250–300 слів проcost, caching і freshness	0–15


Бали зменшуються пропорційно до помилок або відсутніх артефактів відповідно до критеріїв прийняття нижче.



Зверніть увагу! 

Для успішного виконання роботи важливо реалізувати всі ключові етапи: CTE-chain, recursive CTE, Materialized View та аналіз планів виконання через EXPLAIN.


Критерії прийняття

Робота відповідає вимогам, якщо виконано всі наведені нижче умови.

У LMS додано посилання на публічний репозиторій goit-rdb-hw-05 та архів ДЗ5_ПІБ.zip.
Notebook виконується після Restart & Run All без ручного виправлення шляхів або SQL.
Перша секція запускає pgserver і показує версію PostgreSQL.
Olist-дані отримано з Kaggle або курсового архіву відтворюваним способом, або використано stub-schema fallback.
Створено raw-шар і typed-схему або одразу використано повну stub-схему з constraints.
CTE-chain містить щонайменше 5 named stages із коментарями.
У CTE-chain присутні RFM, cohort_quarter, rolling AOV 30d, cancellation_rate і preferred_category.
Recency рахується від стабільної reference_date, а не неконтрольовано від поточної дати без пояснення.
Recursive CTE має anchor part, recursive part, depth/path результат і termination-захист.
Anchor recursive CTE використовує NOT EXISTS або інший NULL-safe anti-join, а не небезпечний NOT IN.
Materialized View створено через CREATE MATERIALIZED VIEW на основі повного feature pipeline.
Для MV створено UNIQUE INDEX на customer_id.
REFRESH MATERIALIZED VIEW CONCURRENTLY виконується без помилок.
Є EXPLAIN (ANALYZE, BUFFERS) для full pipeline і для MV lookup.
Reflection відповідає на питання про cost, MV, refresh-cycle, recursive CTE termination і trade-offs.


Робота приймається, якщо загальна оцінка становить не менше 60 балів зі 100 і одночасно наявні:

працездатне підключення до pgserver;
CTE-chain із щонайменше 5 named stages;
усі 5 обов’язкових derived features;
recursive CTE з валідним termination-захистом;
Materialized View з UNIQUE INDEX;
успішний REFRESH MATERIALIZED VIEW CONCURRENTLY.
```