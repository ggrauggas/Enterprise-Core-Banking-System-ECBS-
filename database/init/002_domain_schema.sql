-- ECBS domain schema (Fase 2).
-- The seven core tables of the banking model. Business rules that the
-- COBOL layer must also enforce are mirrored here as CHECK constraints
-- (defense in depth, as in a real core banking database).

-- ---------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id  BIGSERIAL PRIMARY KEY,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(80)  NOT NULL,
    birth_date   DATE         NOT NULL,
    email        VARCHAR(120) NOT NULL UNIQUE,
    phone        VARCHAR(20)  NOT NULL,
    status       VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE'
                 CHECK (status IN ('ACTIVE', 'INACTIVE', 'DELETED')),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- accounts
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
    account_id   BIGSERIAL PRIMARY KEY,
    iban         VARCHAR(34)  NOT NULL UNIQUE,
    customer_id  BIGINT       NOT NULL REFERENCES customers (customer_id),
    balance      NUMERIC(15,2) NOT NULL DEFAULT 0
                 CHECK (balance >= 0),
    account_type VARCHAR(10)  NOT NULL
                 CHECK (account_type IN ('CHECKING', 'SAVINGS')),
    status       VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE'
                 CHECK (status IN ('ACTIVE', 'CLOSED')),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_accounts_customer ON accounts (customer_id);

-- ---------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id     BIGSERIAL PRIMARY KEY,
    account_id         BIGINT      NOT NULL REFERENCES accounts (account_id),
    transaction_type   VARCHAR(15) NOT NULL
                       CHECK (transaction_type IN
                              ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN',
                               'TRANSFER_OUT', 'CARD_PURCHASE', 'CARD_REFUND',
                               'INTEREST', 'FEE', 'LOAN_PAYMENT',
                               'LOAN_DISBURSE')),
    amount             NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    "timestamp"        TIMESTAMPTZ NOT NULL DEFAULT now(),
    description        VARCHAR(200),
    related_account_id BIGINT REFERENCES accounts (account_id)
);

CREATE INDEX idx_transactions_account ON transactions (account_id, "timestamp");

-- ---------------------------------------------------------------------
-- cards
-- ---------------------------------------------------------------------
CREATE TABLE cards (
    card_id          BIGSERIAL PRIMARY KEY,
    account_id       BIGINT        NOT NULL REFERENCES accounts (account_id),
    card_number      VARCHAR(16)   NOT NULL UNIQUE,
    credit_limit     NUMERIC(15,2) NOT NULL CHECK (credit_limit >= 0),
    available_credit NUMERIC(15,2) NOT NULL,
    status           VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE'
                     CHECK (status IN ('ACTIVE', 'BLOCKED', 'CANCELLED')),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CHECK (available_credit >= 0 AND available_credit <= credit_limit)
);

CREATE INDEX idx_cards_account ON cards (account_id);

-- ---------------------------------------------------------------------
-- loans
-- ---------------------------------------------------------------------
CREATE TABLE loans (
    loan_id         BIGSERIAL PRIMARY KEY,
    customer_id     BIGINT        NOT NULL REFERENCES customers (customer_id),
    amount          NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    interest_rate   NUMERIC(5,2)  NOT NULL CHECK (interest_rate >= 0),
    duration_months INTEGER       NOT NULL CHECK (duration_months > 0),
    status          VARCHAR(10)   NOT NULL DEFAULT 'REQUESTED'
                    CHECK (status IN ('REQUESTED', 'APPROVED', 'REJECTED',
                                      'ACTIVE', 'PAID', 'DEFAULTED')),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_loans_customer ON loans (customer_id);

-- ---------------------------------------------------------------------
-- audit_logs (populated by every business operation, Fase 10)
-- ---------------------------------------------------------------------
CREATE TABLE audit_logs (
    audit_id    BIGSERIAL PRIMARY KEY,
    username    VARCHAR(50)  NOT NULL,
    event_time  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    operation   VARCHAR(30)  NOT NULL,
    entity_type VARCHAR(30)  NOT NULL,
    entity_id   BIGINT,
    old_value   JSONB,
    new_value   JSONB
);

CREATE INDEX idx_audit_entity ON audit_logs (entity_type, entity_id);
CREATE INDEX idx_audit_time ON audit_logs (event_time);

-- ---------------------------------------------------------------------
-- batch_runs (nightly batch bookkeeping, Fase 9)
-- ---------------------------------------------------------------------
CREATE TABLE batch_runs (
    batch_run_id    BIGSERIAL PRIMARY KEY,
    run_date        DATE        NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    status          VARCHAR(10) NOT NULL DEFAULT 'RUNNING'
                    CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    processed_count INTEGER     NOT NULL DEFAULT 0,
    error_count     INTEGER     NOT NULL DEFAULT 0,
    summary         TEXT
);

-- ---------------------------------------------------------------------
-- updated_at maintenance for customers
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

INSERT INTO system_bootstrap (component, version)
VALUES ('domain-schema', 'fase-02');
