# Fase 15 — Optimización Empresarial

**Objetivo:** llevar el sistema de "funciona" a "aguanta carga real":
índices alineados con las consultas, eliminación del filtrado en memoria,
preparación para procesamiento masivo, y resiliencia (timeouts, reintentos
y recuperación ante fallos) en la integración con la capa COBOL.

---

## 1. Índices de rendimiento

Nueva migración `database/init/004_performance_indexes.sql`, alineada con
los patrones de consulta reales (no índices "por si acaso"):

| Tabla          | Índice                                   | Lo respalda                                  |
|----------------|------------------------------------------|----------------------------------------------|
| `customers`    | `idx_customers_status`                   | listado por estado (`findByStatus[Not]`)     |
| `accounts`     | `idx_accounts_status`, `idx_accounts_customer_status` | filtro por estado y por cliente+estado |
| `cards`        | `idx_cards_status`, `idx_cards_account_status` | filtro por estado y por cuenta+estado   |
| `loans`        | `idx_loans_status`, `idx_loans_customer_status` | filtro por estado y por cliente+estado  |
| `transactions` | `idx_transactions_related` (parcial)     | segunda pata de una transferencia            |
| `audit_logs`   | `idx_audit_user`, `idx_audit_operation`  | filtros del visor de auditoría (Fase 10)     |
| `batch_runs`   | `idx_batch_runs_started`, `idx_batch_runs_run_date` | listado de ejecuciones del batch     |

Verificado contra Postgres: `EXPLAIN SELECT * FROM accounts WHERE
status='ACTIVE'` →
`Index Scan using idx_accounts_status`.

---

## 2. Consultas optimizadas

Antes, los listados de cuentas, tarjetas y préstamos cargaban toda la tabla
(o todas las del cliente) y filtraban por estado en memoria con
`stream().filter(...)`. Ahora cada combinación de filtros baja a una
consulta indexada:

```java
if (customerId != null && status != null) return repo.findByCustomerIdAndStatus(customerId, status);
if (customerId != null)                    return repo.findByCustomerId(customerId);
if (status != null)                        return repo.findByStatus(status);
return repo.findAll();
```

Se añadieron los finders derivados `findByStatus` / `findByCustomerIdAndStatus`
(y equivalentes para tarjetas y préstamos) en los repositorios JPA. Resultado:
el trabajo de filtrado lo hace PostgreSQL sobre un índice, no la JVM sobre
listas completas.

---

## 3. Procesamiento masivo

Configuración en `application.yml` para sostener la carga del batch nocturno
y la API concurrente:

- **Pool HikariCP** dimensionado (`maximum-pool-size`, `minimum-idle`,
  `connection-timeout`, `idle-timeout`, `max-lifetime`). *Fast-fail* ante un
  pool saturado en lugar de bloquear hilos de petición indefinidamente.
- **Batching JDBC de Hibernate** (`batch_size: 50`, `order_inserts`,
  `order_updates`) para que las escrituras masivas del read model se agrupen
  en sentencias `INSERT`/`UPDATE` en bloque en vez de un viaje por fila.

El procesamiento masivo de negocio (intereses, cuotas, cargos) sigue siendo
*set-based* dentro de `BATCH-NIGHTLY` (Fase 9); aquí se optimiza el camino de
persistencia del backend.

---

## 4. Manejo de errores y recuperación ante fallos

### Cliente del bridge COBOL (`CobolBridgeClient`)

- **Timeouts acotados** de conexión y lectura (configurables vía
  `ecbs.cobol-bridge.connect-timeout-ms` / `read-timeout-ms`), para que un
  bridge colgado no agote los hilos del servidor.
- **Reintentos con backoff** ante fallos transitorios (conexión rechazada,
  *read timeout*, respuestas `5xx`): `max-retries` intentos con
  `retry-backoff-ms` de espera. Los errores no transitorios (`4xx`) se
  propagan de inmediato. Así un *hiccup* momentáneo del bridge (p. ej. mientras
  arranca) no se convierte en un error de petición.

### Health check del bridge (`BridgeHealthIndicator`)

Nuevo `HealthIndicator` de Actuator: `/actuator/health` agrega el estado del
bridge COBOL. Si la capa de negocio está caída, el health global pasa a
`DOWN` y un orquestador/balanceador puede reenrutar o reiniciar el backend.

```json
{"status":"UP","components":{
  "cobolBridge":{"status":"UP","details":{"programCount":30}},
  "db":{"status":"UP", ...}}}
```

Se exponen también `metrics` y `health` con detalle completo.

### Lanzador del batch (`batch/run-nightly.sh`)

Reescrito con **recuperación ante fallos**: reintenta el arranque con backoff
mientras el bridge no esté disponible, distingue un fallo de negocio (exit
code ≠ 0 del programa → no reintenta, sale `2`) de uno de infraestructura
(bridge inalcanzable → reintenta, sale `1` al agotar intentos). El planificador
puede así alertar y re-encolar con criterio.

---

## 5. Pruebas

La batería de la Fase 14 se amplió y sigue verde con el gate de cobertura:

- `CobolBridgeClientTest`: round-trip + **reintenta 5xx transitorios y luego
  tiene éxito**, y **propaga el error tras agotar los reintentos** (contando
  los intentos contra un servidor HTTP en proceso).
- `BridgeHealthIndicatorTest`: UP / DOWN por estado y DOWN ante excepción.
- Tests de listado por estado e índice (cuentas, tarjetas, préstamos) ajustados
  a las consultas combinadas.

```
Backend: Tests run: 87, Failures: 0, Errors: 0
All coverage checks have been met.   (gate 80%, real ~96%)
```

Verificación end-to-end con el stack Docker real:

- `/actuator/health` → `cobolBridge: UP, programCount: 30`.
- 11 índices de la Fase 15 presentes; `EXPLAIN` confirma su uso.
- `tests/smoke-api.sh` → 12/12 con las consultas optimizadas.

---

## 6. Resultado

| Área                    | Antes                          | Después                                    |
|-------------------------|--------------------------------|--------------------------------------------|
| Filtrado de listados    | en memoria (`stream().filter`) | consulta indexada en PostgreSQL            |
| Índices                 | claves y FKs básicas           | + estado, auditoría por usuario/operación, batch |
| Pool / persistencia     | por defecto                    | HikariCP dimensionado + batching JDBC      |
| Llamada a COBOL         | sin timeout ni reintentos      | timeouts + reintentos con backoff          |
| Observabilidad          | `health`, `info`              | + `metrics`, health del bridge COBOL       |
| Batch                   | un disparo, sin recuperación   | reintentos con backoff y exit codes claros |

Siguiente: **Fase 16 — Simulación de Producción** (carga masiva de datos y
medición de tiempo, memoria y throughput).
