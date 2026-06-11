-- ECBS bootstrap script (Fase 1).
-- Domain tables (customers, accounts, ...) are created in Fase 2 migrations.
-- This script only prepares extensions and a bootstrap marker so the stack
-- can be smoke-tested end to end.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS system_bootstrap (
    id          SERIAL PRIMARY KEY,
    component   VARCHAR(64)  NOT NULL,
    version     VARCHAR(32)  NOT NULL,
    applied_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO system_bootstrap (component, version)
VALUES ('database', 'fase-01');
