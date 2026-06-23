-- ECBS production-scale data generator (Fase 16).
--
-- Bulk-loads a synthetic portfolio using set-based generate_series inserts
-- (the way a real core-banking load test seeds its environment). Volumes are
-- parameterised; defaults are the production-simulation targets:
--     customers     100,000
--     accounts      500,000   (5 per customer)
--     transactions  5,000,000 (10 per account)
--     cards          10,000   (active, with spent credit -> batch step 4)
--     loans           5,000   (active -> batch step 3)
--
-- Override on the command line, e.g. a quick smoke load:
--     psql ... -v customers=1000 -v accounts=5000 -v transactions=50000 \
--              -v cards=200 -v loans=100 -f scripts/simulation-load.sql
--
-- Synthetic keys are namespaced (emails @ecbs.sim, IBAN 'ES0000…', card
-- numbers '5…') so they never collide with the Fase 2 seed data.

\set ON_ERROR_STOP on
\timing on

-- Guarded defaults: only set when not provided with -v.
\if :{?customers}
\else
  \set customers 100000
\endif
\if :{?accounts}
\else
  \set accounts 500000
\endif
\if :{?transactions}
\else
  \set transactions 5000000
\endif
\if :{?cards}
\else
  \set cards 10000
\endif
\if :{?loans}
\else
  \set loans 5000
\endif

-- Loosen durability for the load only (this is throwaway test data).
SET synchronous_commit = off;
SET maintenance_work_mem = '256MB';

\echo '== Generating customers =='
INSERT INTO customers (first_name, last_name, birth_date, email, phone, status)
SELECT 'First' || g,
       'Last' || g,
       DATE '1950-01-01' + ((g * 7) % 25000),
       'sim.' || g || '@ecbs.sim',
       '+34' || lpad((600000000 + g)::text, 9, '0'),
       'ACTIVE'
FROM generate_series(1, :customers) AS g;

\echo '== Generating accounts =='
INSERT INTO accounts (iban, customer_id, balance, account_type, status)
SELECT 'ES' || lpad(g::text, 22, '0'),
       ((g - 1) % :customers) + 1,
       round((100 + random() * 9900)::numeric, 2),
       CASE WHEN g % 2 = 0 THEN 'CHECKING' ELSE 'SAVINGS' END,
       'ACTIVE'
FROM generate_series(1, :accounts) AS g;

\echo '== Generating cards (active, with spent credit) =='
INSERT INTO cards (account_id, card_number, credit_limit, available_credit, status)
SELECT ((g - 1) % :accounts) + 1,
       '5' || lpad(g::text, 15, '0'),
       limit_amt,
       round((limit_amt * (0.30 + random() * 0.40))::numeric, 2),  -- 30-70% spent
       'ACTIVE'
FROM generate_series(1, :cards) AS g
CROSS JOIN LATERAL (SELECT round((500 + random() * 4500)::numeric, 2) AS limit_amt) c;

\echo '== Generating loans (active) =='
INSERT INTO loans (customer_id, amount, interest_rate, duration_months, status)
SELECT ((g - 1) % :customers) + 1,
       round((3000 + random() * 27000)::numeric, 2),
       round((2 + random() * 6)::numeric, 2),
       (ARRAY[12, 24, 36, 60, 120])[1 + (g % 5)],
       'ACTIVE'
FROM generate_series(1, :loans) AS g;

\echo '== Generating transactions (this is the big one) =='
INSERT INTO transactions (account_id, transaction_type, amount, "timestamp", description)
SELECT ((g - 1) % :accounts) + 1,
       (ARRAY['DEPOSIT', 'WITHDRAWAL', 'CARD_PURCHASE', 'INTEREST', 'FEE'])[1 + (g % 5)],
       round((1 + random() * 1000)::numeric, 2),
       now() - ((g % 365) || ' days')::interval,
       'sim txn ' || g
FROM generate_series(1, :transactions) AS g;

\echo '== Refreshing planner statistics =='
ANALYZE customers;
ANALYZE accounts;
ANALYZE cards;
ANALYZE loans;
ANALYZE transactions;

\echo '== Row counts =='
SELECT 'customers'    AS table, count(*) FROM customers
UNION ALL SELECT 'accounts',     count(*) FROM accounts
UNION ALL SELECT 'cards',        count(*) FROM cards
UNION ALL SELECT 'loans',        count(*) FROM loans
UNION ALL SELECT 'transactions', count(*) FROM transactions
ORDER BY 1;
