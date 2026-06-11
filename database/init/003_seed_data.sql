-- ECBS seed data (Fase 2). Small, realistic development dataset so every
-- later phase can be smoke-tested immediately. Mass data generation for
-- production simulation happens in Fase 16.

INSERT INTO customers (customer_id, first_name, last_name, birth_date, email, phone, status) VALUES
    (1, 'Maria',  'Garcia Lopez',     '1985-03-12', 'maria.garcia@example.com',  '+34600111222', 'ACTIVE'),
    (2, 'Jordi',  'Puig Serra',       '1978-11-02', 'jordi.puig@example.com',    '+34600333444', 'ACTIVE'),
    (3, 'Lucia',  'Fernandez Ruiz',   '1992-07-25', 'lucia.fernandez@example.com', '+34600555666', 'ACTIVE'),
    (4, 'Carlos', 'Martinez Gil',     '1969-01-30', 'carlos.martinez@example.com', '+34600777888', 'ACTIVE'),
    (5, 'Anna',   'Roca Vidal',       '2000-09-14', 'anna.roca@example.com',     '+34600999000', 'INACTIVE');

SELECT setval('customers_customer_id_seq', (SELECT max(customer_id) FROM customers));

INSERT INTO accounts (account_id, iban, customer_id, balance, account_type, status) VALUES
    (1, 'ES9121000418450200051332', 1, 2500.00, 'CHECKING', 'ACTIVE'),
    (2, 'ES7921000813610123456789', 1, 9100.50, 'SAVINGS',  'ACTIVE'),
    (3, 'ES6621000418401234567891', 2,  430.75, 'CHECKING', 'ACTIVE'),
    (4, 'ES1021002222330123456733', 3, 15000.00,'SAVINGS',  'ACTIVE'),
    (5, 'ES4321001111220198765432', 4,    0.00, 'CHECKING', 'CLOSED'),
    (6, 'ES2521003333440187654321', 4,  780.25, 'CHECKING', 'ACTIVE');

SELECT setval('accounts_account_id_seq', (SELECT max(account_id) FROM accounts));

INSERT INTO transactions (account_id, transaction_type, amount, "timestamp", description) VALUES
    (1, 'DEPOSIT',     3000.00, now() - interval '30 days', 'Initial deposit'),
    (1, 'WITHDRAWAL',   500.00, now() - interval '12 days', 'ATM withdrawal'),
    (2, 'DEPOSIT',     9000.00, now() - interval '60 days', 'Savings opening'),
    (2, 'INTEREST',     100.50, now() - interval '1 day',   'Monthly interest'),
    (3, 'DEPOSIT',      500.00, now() - interval '20 days', 'Payroll'),
    (3, 'FEE',           69.25, now() - interval '2 days',  'Maintenance fee'),
    (4, 'DEPOSIT',    15000.00, now() - interval '90 days', 'Term deposit'),
    (6, 'DEPOSIT',      780.25, now() - interval '5 days',  'Cash deposit');

INSERT INTO cards (card_id, account_id, card_number, credit_limit, available_credit, status) VALUES
    (1, 1, '4539148803436467', 3000.00, 3000.00, 'ACTIVE'),
    (2, 3, '4716461583322103', 1500.00,  900.00, 'ACTIVE'),
    (3, 6, '4929804463622139', 1000.00, 1000.00, 'BLOCKED');

SELECT setval('cards_card_id_seq', (SELECT max(card_id) FROM cards));

INSERT INTO loans (loan_id, customer_id, amount, interest_rate, duration_months, status) VALUES
    (1, 2, 12000.00, 5.50, 60, 'ACTIVE'),
    (2, 3, 30000.00, 3.90, 120, 'REQUESTED');

SELECT setval('loans_loan_id_seq', (SELECT max(loan_id) FROM loans));

INSERT INTO system_bootstrap (component, version)
VALUES ('seed-data', 'fase-02');
