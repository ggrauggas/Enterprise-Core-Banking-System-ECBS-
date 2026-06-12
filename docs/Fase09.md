# Fase 9 — Batch Nocturno

**Objetivo:** el módulo crítico del sistema: un proceso batch que recorre toda la cartera aplicando intereses, cargos, cuotas de préstamos y liquidación de tarjetas, con contabilización en `batch_runs` y generación de los archivos `BATCH_LOG`, `RUN_SUMMARY` y `AUDIT_REPORT`.

---

## 1. Nuevos componentes

```
cobol/src/programs/BATCH-NIGHTLY.cbl   Programa batch (4 job steps)
batch/run-nightly.sh                   Lanzador (rol de Control-M/cron)
```

El Dockerfile crea `/opt/ecbs/batch-output` y define `ECBS_BATCH_DIR`.

## 2. Los cuatro job steps

El programa procesa secuencialmente, con un cursor SQL por step (el patrón clásico de un job JCL con varios steps):

| Step | Población | Acción | Movimiento |
|---|---|---|---|
| 1 `INTEREST` | cuentas `SAVINGS` `ACTIVE` con saldo > 0 | interés mensual al 2,00 % anual (`MONEY_UTILS MONTHLY-INT`) | `INTEREST` |
| 2 `FEES` | cuentas `CHECKING` `ACTIVE` | comisión de mantenimiento 5,00 € — **solo si el saldo la cubre** (nunca deja saldo negativo; si no, skip contado) | `FEE` |
| 3 `LOANS` | préstamos `ACTIVE` | cuota francesa mensual (`FRENCH-PMT`) cargada a la cuenta `ACTIVE` **con más saldo** del titular; sin cuenta o sin fondos → skip contado | `LOAN_PAYMENT` |
| 4 `CARDS` | tarjetas `ACTIVE` con crédito dispuesto | liquidación: el dispuesto (`limit − available`) se carga a la cuenta vinculada y el crédito se restaura al límite; sin fondos → skip | `FEE` (`CARD n MONTHLY SETTLEMENT`) |

## 3. Contabilización y transaccionalidad

- **`batch_runs`**: al arrancar se inserta la fila `RUNNING` y se hace COMMIT inmediato (en su propia transacción, para que sobreviva a un rollback del trabajo). Al acabar se actualiza con `finished_at`, `SUCCESS`/`FAILED`, `processed_count`, `error_count` y un resumen textual.
- **Atomicidad**: los 4 steps corren dentro de **una** transacción de negocio; cualquier `SQLCODE` inesperado revierte todos los movimientos y el run se cierra como `FAILED`.
- **Auditoría**: una entrada `audit_logs` por step (`BATCH_INTEREST`, `BATCH_FEES`, `BATCH_LOANS`, `BATCH_CARDS`) con entidad `BATCH`, `entity_id` = run id y contadores en JSONB. La trazabilidad por cuenta la dan las filas de `transactions`.

## 4. Archivos generados (secuenciales LINE SEQUENTIAL)

En `ECBS_BATCH_DIR` (`/opt/ecbs/batch-output`):

| Archivo | Modo | Contenido |
|---|---|---|
| `BATCH_LOG.log` | `OPEN EXTEND` (append histórico) | una línea con timestamp por cada acción/skip: `[ts] RUN n INTEREST account 2 +15.17` |
| `RUN_SUMMARY.rpt` | `OPEN OUTPUT` (último run) | tabla de contadores por step + totales + estado |
| `AUDIT_REPORT.rpt` | `OPEN OUTPUT` (último run) | volcado de las entradas de auditoría del run (cursor sobre `audit_logs`) |

Es la primera fase que ejercita el manejo de **archivos secuenciales** COBOL (`FD`, `FILE STATUS`, `WRITE`) junto al SQL embebido.

## 5. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime && docker compose up -d postgres cobol-runtime

# por el bridge (o con el lanzador: ./batch/run-nightly.sh)
curl -X POST http://localhost:9090/run/BATCH-NIGHTLY -d '{"user":"scheduler"}'

docker exec ecbs-cobol-runtime cat /opt/ecbs/batch-output/RUN_SUMMARY.rpt
docker exec ecbs-cobol-runtime cat /opt/ecbs/batch-output/AUDIT_REPORT.rpt
docker exec ecbs-cobol-runtime tail -20 /opt/ecbs/batch-output/BATCH_LOG.log
docker exec ecbs-postgres psql -U ecbs_admin -d ecbs \
  -c "SELECT * FROM batch_runs ORDER BY batch_run_id;"
```

Resultado real de las dos ejecuciones de verificación:

**Run 1** — `SUCCESS`, processed 9, errors 0 (`interest=2 fees=3 loans=2 cards=2`). Verificación contable manual exacta:

| Cuenta | Antes | Movimientos | Después |
|---|---|---|---|
| 1 CHECKING | 1500.00 | −5.00 fee −250.75 settlement tarjeta 4 | **1244.25** ✓ |
| 2 SAVINGS | 9100.50 | +15.17 interés | **9115.67** ✓ |
| 3 CHECKING | 930.75 | −5.00 fee −229.21 préstamo 1 −500.00 settlement tarjeta 2 | **196.54** ✓ |
| 4 SAVINGS | 45000.00 | +75.00 interés −302.31 préstamo 2 | **44772.69** ✓ |
| 6 CHECKING | 780.25 | −5.00 fee | **775.25** ✓ |

Las tarjetas 2 y 4 quedaron con `available_credit = credit_limit` (liquidadas).

**Run 2** — `SUCCESS`, processed 6, errors 1: el préstamo 1 quedó `SKIPPED (INSUFFICIENT FUNDS)` porque la cuenta 3 ya no cubría la cuota (196.54 < 229.21) — el batch lo registra en log, summary (`LOANS 1 / 1`) y auditoría sin abortar el run, y `cards=0` porque no había crédito dispuesto. Comportamiento de reproceso correcto.

Regresión `FRAMEWORK-TEST`: `OK`.

## 6. Resultado de la fase

- ✅ Batch de 4 steps con cursores SQL y proceso masivo por cartera
- ✅ Regla de oro respetada: ningún cargo deja saldo negativo (skips contados, no errores fatales)
- ✅ `batch_runs` con ciclo RUNNING → SUCCESS/FAILED y contadores
- ✅ BATCH_LOG (append), RUN_SUMMARY y AUDIT_REPORT como archivos secuenciales COBOL
- ✅ Una transacción de negocio por run con rollback total ante error SQL
- ✅ Re-ejecutable: la segunda pasada liquidó solo lo pendiente

**Siguiente fase:** Fase 10 — Motor de Auditoría (consulta centralizada del rastro: usuario, fecha, operación, entidad, valores; visor con filtros).
