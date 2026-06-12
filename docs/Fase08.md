# Fase 8 — Sistema de Préstamos

**Objetivo:** ciclo completo de préstamos: simulador con **método francés** y calendario de amortización, solicitud, aprobación (con desembolso opcional a cuenta) y rechazo.

---

## 1. Nuevos programas

```
cobol/src/programs/LOAN-SIMULATE.cbl   Simulador + calendario de pagos
cobol/src/programs/LOAN-REQUEST.cbl    Solicitud
cobol/src/programs/LOAN-APPROVE.cbl    Aprobación (± desembolso)
cobol/src/programs/LOAN-REJECT.cbl     Rechazo
cobol/src/programs/LOAN-INQUIRY.cbl    Consulta y seguimiento
```

Nuevo código de error: `E022 ACCOUNT NOT OWNED BY CUSTOMER` (catálogo en 22).

## 2. `LOAN-SIMULATE` — método francés y calendario

Dos modos:

```bash
# simulación libre (sin tocar la BD)
curl -X POST http://localhost:9090/run/LOAN-SIMULATE \
  -d '{"amount":12000,"interestRate":5.5,"durationMonths":60}'
# simulación de un préstamo almacenado
curl -X POST http://localhost:9090/run/LOAN-SIMULATE -d '{"loanId":2}'
```

- La cuota constante viene de `MONEY_UTILS FRENCH-PMT` (`A = P·i·f/(f−1)`, `f=(1+i)^n`), el módulo de la Fase 3.
- El calendario se genera mes a mes en COBOL con aritmética COMP-3: `interés = pendiente × tipo/1200` (redondeado), `capital = cuota − interés`, y la **última cuota liquida el pendiente exacto** para que el préstamo cierre en 0.00 (en el caso de prueba la cuota 60 es 229.47 en lugar de 229.21 por el ajuste de redondeos acumulados).
- Cada fila incluye `dueDate` calculada con `DATE_UTILS ADD-MONTHS` desde hoy (con ajuste de fin de mes).
- Caso borde tipo 0 %: cuota = importe/meses (la fórmula francesa dividiría por `f−1 = 0`).
- Límites: importe > 0, tipo ≥ 0, meses 1–600 (E018).

Salida: cabecera (importe, tipo, meses, cuota), array `schedule` (mes, fecha, cuota, interés, capital, pendiente) y totales (`totalPaid`, `totalInterest`).

## 3. Flujo de vida del préstamo

```
LOAN-REQUEST          LOAN-APPROVE                LOAN-REJECT
REQUESTED ──────────> APPROVED (sin desembolso)   REJECTED
            └───────> ACTIVE (con desembolso)
```

### `LOAN-REQUEST` — solicitud
`{"customerId":1,"amount":15000,"interestRate":4.75,"durationMonths":48,"user":"advisor1"}`. Cliente existente y `ACTIVE` (E004/E017), términos válidos (E018). Crea el préstamo `REQUESTED` y devuelve la **cuota mensual calculada** para que el solicitante la conozca de antemano; la cuota también queda en la auditoría.

### `LOAN-APPROVE` — aprobación
Solo sobre préstamos `REQUESTED` (E014 con el estado real en el contexto). Dos variantes:
- Sin `accountId`: `REQUESTED → APPROVED`.
- Con `accountId`: **aprobación + desembolso atómico**: la cuenta debe existir (E004), estar `ACTIVE` (E007) y **pertenecer al titular del préstamo** (`E022`). Abona el importe, escribe la fila `LOAN_DISBURSE` en `transactions` y deja el préstamo `ACTIVE`. Todo en una transacción: si la cuenta no es válida, nada cambia (verificado: tras un E022 el préstamo sigue `REQUESTED`).

### `LOAN-REJECT` — rechazo
`REQUESTED → REJECTED` (E014 si no). El motivo opcional (`reason`) queda en la auditoría.

### `LOAN-INQUIRY` — seguimiento
`{"loanId":2}` detalle con nombre del titular (JOIN); listados por `customerId` y/o `statusFilter`.

## 4. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime && docker compose up -d postgres cobol-runtime

curl -X POST http://localhost:9090/run/LOAN-SIMULATE -d '{"amount":12000,"interestRate":5.5,"durationMonths":60}'
curl -X POST http://localhost:9090/run/LOAN-REQUEST  -d '{"customerId":1,"amount":15000,"interestRate":4.75,"durationMonths":48,"user":"advisor1"}'
curl -X POST http://localhost:9090/run/LOAN-APPROVE  -d '{"loanId":2,"accountId":4,"user":"risk-dept"}'
curl -X POST http://localhost:9090/run/LOAN-REJECT   -d '{"loanId":3,"reason":"Insufficient income","user":"risk-dept"}'
curl -X POST http://localhost:9090/run/LOAN-INQUIRY  -d '{"customerId":3}'
```

Resultado real de la verificación:

| Prueba | Resultado |
|---|---|
| Simulación 12.000 € / 5,50 % / 60 m | cuota **229,21 €** (valor contrastado), 60 filas, pendiente final 0.00, última cuota ajustada 229.47 |
| Simulación del préstamo 2 (30.000 € / 3,90 % / 120 m) | cuota 302,31 €, 120 filas, cierre exacto |
| Tipo 0 % / meses > 600 / préstamo inexistente | cuota lineal 100.00 / `E018` / `E004` |
| Solicitud cliente 1 | préstamo 3 `REQUESTED`, cuota 343,74 € en respuesta y auditoría |
| Solicitud cliente INACTIVE | `E017` |
| Rechazo + segundo rechazo | OK / `E014 LOAN STATUS REJECTED` |
| Aprobación sin desembolso (préstamo 4) | `APPROVED` |
| Aprobación con desembolso (préstamo 2 → cuenta 4) | `ACTIVE`, saldo 15.000 → **45.000**, txn 15 `LOAN_DISBURSE` |
| Aprobar préstamo ya ACTIVE | `E014` |
| Desembolso a cuenta de otro cliente | `E022` y rollback (préstamo intacto) |
| Auditoría: `REQUEST`/`APPROVE`/`REJECT` con cuota, motivo y destino | OK |
| Regresión `FRAMEWORK-TEST` | `status OK` |

## 5. Resultado de la fase

- ✅ Simulador con método francés y calendario completo que cierra a 0.00 exacto
- ✅ Máquina de estados REQUESTED → APPROVED/ACTIVE/REJECTED con E014
- ✅ Desembolso atómico a cuenta del titular (E022 si no le pertenece) con `LOAN_DISBURSE`
- ✅ Cuota mensual informada en solicitud y auditoría
- ✅ Catálogo de errores en 22 códigos; 20 programas COBOL + 8 módulos en total

**Siguiente fase:** Fase 9 — Batch Nocturno (intereses, préstamos, cargos y tarjetas en proceso masivo, con BATCH_LOG, RUN_SUMMARY y AUDIT_REPORT).
