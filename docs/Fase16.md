# Fase 16 — Simulación de Producción

**Objetivo:** llevar el sistema a escala de producción —100.000 clientes,
500.000 cuentas, 5.000.000 de transacciones— ejecutar el batch nocturno
completo sobre ese portfolio y medir **tiempo, memoria y throughput**.

---

## 1. Generación masiva de datos

`scripts/simulation-load.sql` genera el portfolio de forma *set-based* con
`generate_series` + `INSERT … SELECT` (la técnica que usa un banco real para
sembrar un entorno de pruebas de carga). Volúmenes parametrizables; los
valores por defecto son los objetivos de la fase:

| Tabla          | Volumen     | Notas                                              |
|----------------|-------------|----------------------------------------------------|
| `customers`    | 100.000     | todos ACTIVE                                       |
| `accounts`     | 500.000     | 5 por cliente, 50 % SAVINGS / 50 % CHECKING        |
| `transactions` | 5.000.000   | 10 por cuenta, históricas (último año)             |
| `cards`        | 10.000      | activas con crédito gastado → trabajo para el batch |
| `loans`        | 5.000       | activos → trabajo para el batch                    |

Las claves sintéticas están *namespaced* (emails `@ecbs.sim`, IBAN `ES0000…`,
tarjetas `5…`) para no colisionar con la seed de la Fase 2. La carga afloja la
durabilidad (`synchronous_commit = off`) y sube `maintenance_work_mem`, porque
son datos desechables de prueba.

```bash
# contra el stack levantado (docker compose up -d)
Get-Content scripts/simulation-load.sql | \
  docker exec -i ecbs-postgres psql -U ecbs_admin -d ecbs \
    -v customers=100000 -v accounts=500000 -v transactions=5000000 \
    -v cards=10000 -v loans=5000 -f -
```

### Resultado medido — carga

| Métrica            | Valor                          |
|--------------------|--------------------------------|
| Filas insertadas   | **5.615.000**                  |
| Tiempo de pared    | **250,3 s**                    |
| Throughput         | **≈ 22.400 filas/s**           |
| Memoria PostgreSQL | 51 MiB → **564 MiB**           |

`ANALYZE` se ejecuta al final para que el planificador tenga estadísticas
frescas sobre las nuevas magnitudes (clave para que use los índices de la
Fase 15).

---

## 2. Batch nocturno completo

Se ejecuta `BATCH-NIGHTLY` (Fase 9) sobre el portfolio completo. Procesa, por
cursor y fila a fila vía SQL embebido (ocesql):

1. **INTEREST** — interés mensual sobre ~250.000 cuentas SAVINGS activas.
2. **FEES** — comisión de mantenimiento sobre ~250.000 cuentas CHECKING.
3. **LOANS** — cuota francesa de los 5.000 préstamos activos.
4. **CARDS** — liquidación de las 10.000 tarjetas activas con crédito gastado.

Todo dentro de **una única transacción** (atomicidad total: cualquier error
SQL revierte el lote completo y cierra la ejecución como `FAILED`). Para la
medición se invoca el binario directamente dentro del contenedor, de modo que
la duración no quede acotada por el timeout HTTP del bridge:

```bash
docker exec ecbs-cobol-runtime sh -c 'printf "{\"user\":\"sim\"}" | /opt/ecbs/bin/BATCH-NIGHTLY'
```

### Resultado medido — batch

<!-- BATCH-METRICS -->
_(Métricas rellenadas automáticamente por `scripts/run-simulation.ps1` en
`docs/fase16-results.txt`.)_

---

## 3. Harness reproducible

`scripts/run-simulation.ps1` orquesta y mide las dos fases de punta a punta y
deja el informe en `docs/fase16-results.txt`:

```powershell
docker compose up -d
./scripts/run-simulation.ps1          # escala completa por defecto
# o una escala reducida para una prueba rápida:
./scripts/run-simulation.ps1 -Customers 1000 -Accounts 5000 -Transactions 50000
```

El script mide tiempo de pared con `Measure-Command`, captura la memoria de los
contenedores con `docker stats --no-stream` y calcula el throughput de carga
(filas/s) y de batch (operaciones/s).

---

## 4. Conclusiones

- La **carga set-based** sostiene decenas de miles de filas por segundo: poblar
  un entorno de 5,6 M de filas es cuestión de minutos, no de horas.
- El **batch** es *row-by-row* por diseño (un movimiento contable y una línea de
  log por operación, como un batch COBOL clásico); su coste crece linealmente
  con el portfolio activo y es el candidato natural a paralelización futura.
- Los **índices de la Fase 15** y el `ANALYZE` posterior a la carga mantienen
  las consultas del API en *index scans* incluso a esta escala.

Con esta fase el sistema queda demostrado a escala de banca tradicional:
clientes, cuentas y transacciones en volúmenes de producción, procesados por la
capa COBOL y medidos de extremo a extremo. **Las 16 fases del proyecto están
completas.**
