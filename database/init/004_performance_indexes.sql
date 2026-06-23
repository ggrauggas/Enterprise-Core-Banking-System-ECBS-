-- ECBS performance indexes (Fase 15 - Optimización Empresarial).
-- These indexes back the query patterns actually issued by the API read
-- model and the COBOL programs: status filters, audit-trail lookups by
-- user/operation, foreign-key joins and the batch ordering. They turn the
-- in-memory filtering done before this phase into index-backed scans.

-- customers: list endpoints filter by status (findByStatus / findByStatusNot).
CREATE INDEX IF NOT EXISTS idx_customers_status ON customers (status);

-- accounts: list filtered by status, optionally also by customer.
CREATE INDEX IF NOT EXISTS idx_accounts_status ON accounts (status);
CREATE INDEX IF NOT EXISTS idx_accounts_customer_status
    ON accounts (customer_id, status);

-- cards: list filtered by status, optionally also by account.
CREATE INDEX IF NOT EXISTS idx_cards_status ON cards (status);
CREATE INDEX IF NOT EXISTS idx_cards_account_status
    ON cards (account_id, status);

-- loans: list filtered by status, optionally also by customer.
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans (status);
CREATE INDEX IF NOT EXISTS idx_loans_customer_status
    ON loans (customer_id, status);

-- transactions: the second leg of a transfer references related_account_id;
-- index it so reverse lookups and FK checks do not scan the whole table.
CREATE INDEX IF NOT EXISTS idx_transactions_related
    ON transactions (related_account_id)
    WHERE related_account_id IS NOT NULL;

-- audit_logs: the AUDIT-INQUIRY viewer combines filters by user and by
-- operation on top of the existing entity/time indexes (Fase 10).
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs (username);
CREATE INDEX IF NOT EXISTS idx_audit_operation ON audit_logs (operation);

-- batch_runs: the dashboard lists runs newest-first and by run date.
CREATE INDEX IF NOT EXISTS idx_batch_runs_started ON batch_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_batch_runs_run_date ON batch_runs (run_date);

INSERT INTO system_bootstrap (component, version)
VALUES ('performance-indexes', 'fase-15');
