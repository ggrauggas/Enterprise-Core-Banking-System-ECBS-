# Fase 2 — Modelo Bancario

**Objetivo:** implementar el modelo de datos completo del banco: las 7 tablas PostgreSQL del sistema y sus entidades JPA en el backend, organizadas por dominios.

---

## 1. Esquema PostgreSQL (`database/init/002_domain_schema.sql`)

Se crean las 7 tablas exigidas por el proyecto. Las reglas de negocio que la capa COBOL aplicará en fases posteriores se reflejan también como `CHECK constraints` en la base de datos (*defensa en profundidad*, como en un core bancario real).

### `customers`

| Columna | Tipo | Notas |
|---|---|---|
| `customer_id` | BIGSERIAL PK | |
| `first_name` / `last_name` | VARCHAR(50/80) | NOT NULL |
| `birth_date` | DATE | NOT NULL |
| `email` | VARCHAR(120) | **UNIQUE** (la validación de duplicados de la Fase 4 se apoya aquí) |
| `phone` | VARCHAR(20) | NOT NULL |
| `status` | VARCHAR(10) | `ACTIVE` / `INACTIVE` / `DELETED` — la baja es **lógica** (Fase 4) |
| `created_at` / `updated_at` | TIMESTAMPTZ | `updated_at` se mantiene con un trigger `touch_updated_at()` |

### `accounts`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id` | BIGSERIAL PK | |
| `iban` | VARCHAR(34) | UNIQUE |
| `customer_id` | BIGINT FK → customers | indexado (`idx_accounts_customer`) |
| `balance` | NUMERIC(15,2) | **CHECK (balance >= 0)** — regla "sin saldo negativo" de la Fase 5 |
| `account_type` | VARCHAR(10) | `CHECKING` (corriente) / `SAVINGS` (ahorro) |
| `status` | VARCHAR(10) | `ACTIVE` / `CLOSED` (cierre de cuenta, Fase 5) |
| `created_at` | TIMESTAMPTZ | |

### `transactions`

| Columna | Tipo | Notas |
|---|---|---|
| `transaction_id` | BIGSERIAL PK | |
| `account_id` | BIGINT FK → accounts | índice compuesto `(account_id, timestamp)` |
| `transaction_type` | VARCHAR(15) | 10 tipos: DEPOSIT, WITHDRAWAL, TRANSFER_IN/OUT, CARD_PURCHASE/REFUND, INTEREST, FEE, LOAN_PAYMENT, LOAN_DISBURSE |
| `amount` | NUMERIC(15,2) | CHECK (> 0); el signo lo determina el tipo |
| `timestamp` | TIMESTAMPTZ | default `now()` |
| `description` | VARCHAR(200) | opcional |
| `related_account_id` | BIGINT FK | contrapartida en transferencias (Fase 6) |

### `cards`

| Columna | Tipo | Notas |
|---|---|---|
| `card_id` | BIGSERIAL PK | |
| `account_id` | BIGINT FK → accounts | indexado |
| `card_number` | VARCHAR(16) | UNIQUE |
| `credit_limit` | NUMERIC(15,2) | CHECK (>= 0) |
| `available_credit` | NUMERIC(15,2) | **CHECK (0 ≤ available_credit ≤ credit_limit)** (control de límite, Fase 7) |
| `status` | VARCHAR(10) | `ACTIVE` / `BLOCKED` / `CANCELLED` (bloqueo/desbloqueo, Fase 7) |

### `loans`

| Columna | Tipo | Notas |
|---|---|---|
| `loan_id` | BIGSERIAL PK | |
| `customer_id` | BIGINT FK → customers | indexado |
| `amount` | NUMERIC(15,2) | CHECK (> 0) |
| `interest_rate` | NUMERIC(5,2) | % nominal anual |
| `duration_months` | INTEGER | CHECK (> 0) |
| `status` | VARCHAR(10) | `REQUESTED` / `APPROVED` / `REJECTED` / `ACTIVE` / `PAID` / `DEFAULTED` (ciclo de vida, Fase 8) |

### `audit_logs` (motor de auditoría, Fase 10)

`audit_id`, `username`, `event_time`, `operation`, `entity_type`, `entity_id`, `old_value` **JSONB**, `new_value` **JSONB**. Índices por entidad y por fecha para el visor con filtros de la Fase 13.

### `batch_runs` (batch nocturno, Fase 9)

`batch_run_id`, `run_date`, `started_at`, `finished_at`, `status` (`RUNNING`/`SUCCESS`/`FAILED`), `processed_count`, `error_count`, `summary`.

## 2. Datos semilla (`database/init/003_seed_data.sql`)

Dataset pequeño y realista para poder probar todas las fases siguientes desde el primer momento: 5 clientes, 6 cuentas (una cerrada), 8 transacciones, 3 tarjetas (una bloqueada) y 2 préstamos (uno activo, uno solicitado). Tras cada bloque se ajusta la secuencia con `setval()` porque los IDs se insertan explícitos. La generación masiva (100k clientes…) llega en la Fase 16.

## 3. Entidades JPA (diseño orientado a dominios)

El backend se organiza **por dominios**, no por capas técnicas: cada dominio tiene su paquete con entidad + repositorio:

```
com.ecbs.customer     Customer, CustomerRepository
com.ecbs.account      Account, AccountRepository
com.ecbs.transaction  Transaction, TransactionRepository
com.ecbs.card         Card, CardRepository
com.ecbs.loan         Loan, LoanRepository
com.ecbs.audit        AuditLog, AuditLogRepository
com.ecbs.batch        BatchRun, BatchRunRepository
```

Decisiones técnicas:

- Los estados se modelan como **enums anidados** (`Customer.Status`, `Account.Type`, …) con `@Enumerated(EnumType.STRING)`, alineados 1:1 con los CHECK de la base de datos.
- Importes con `BigDecimal` ↔ `NUMERIC(15,2)` (nunca `double` para dinero).
- Los JSONB de auditoría se mapean con `@JdbcTypeCode(SqlTypes.JSON)`.
- Las FKs se mapean como `Long` (no relaciones `@ManyToOne`): el dueño de la integridad referencial es la base de datos y la capa COBOL; el backend actúa como capa fina.
- `spring.jpa.hibernate.ddl-auto: validate` — **el esquema lo gobiernan los scripts SQL**, Hibernate solo verifica que el mapeo coincide. Esto detecta desalineaciones modelo↔DB en el arranque.
- `open-in-view: false` (buena práctica en APIs REST).

## 4. Configuración

- `backend/pom.xml`: añadidos `spring-boot-starter-data-jpa` y el driver `postgresql`.
- `application.yml`: datasource configurable por variables de entorno (`SPRING_DATASOURCE_URL`…), con default a `localhost:5432` para desarrollo fuera de Docker.
- `docker-compose.yml`: el backend recibe la URL JDBC (`jdbc:postgresql://postgres:5432/ecbs`) y declara dependencia explícita de `postgres` healthy.

## 5. Endpoint de verificación

`GET /api/v1/system/model-stats` devuelve el recuento de filas de las 7 tablas a través de los repositorios JPA, demostrando que el mapeo completo funciona:

```json
{ "customers": 5, "accounts": 6, "transactions": 8, "cards": 3, "loans": 2, "auditLogs": 0, "batchRuns": 0 }
```

## 6. Cómo ejecutar y verificar

> ⚠️ Los scripts de `database/init/` solo se ejecutan al **crear** el volumen de PostgreSQL. Si la base de datos ya existía: `docker compose down -v` antes de levantar.

```bash
docker compose down -v
docker compose build backend
docker compose up -d
```

Verificaciones:

1. `docker exec ecbs-postgres psql -U ecbs_admin -d ecbs -c "\dt"` → las 8 tablas (7 de dominio + `system_bootstrap`)
2. `http://localhost:8080/api/v1/system/model-stats` → recuentos del seed
3. El backend arranca sin errores de `ddl-auto: validate` (modelo alineado con el esquema)

## 7. Resultado de la fase

- ✅ 7 tablas de dominio con constraints, índices y trigger de `updated_at`
- ✅ Datos semilla coherentes para desarrollo
- ✅ 7 entidades JPA + 7 repositorios Spring Data organizados por dominio
- ✅ Backend conectado a PostgreSQL con validación de esquema en el arranque
- ✅ Endpoint `model-stats` verificando el mapeo completo

**Siguiente fase:** Fase 3 — Framework COBOL (copybooks `CUSTOMER.cpy`, `ACCOUNT.cpy`, … y módulos comunes `VALIDATION`, `ERROR_HANDLER`, `LOGGER`, `DATE_UTILS`, `MONEY_UTILS`).
