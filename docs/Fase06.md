# Fase 6 — Motor Transaccional

**Objetivo:** el corazón operativo del banco: depósitos, retiros con validación de fondos y transferencias **atómicas** entre cuentas, con doble apunte en `transactions` y auditoría completa de saldos antes/después.

Sigue el patrón online de las fases 4–5 (stdin JSON → validar → SQL embebido → auditar → COMMIT/ROLLBACK → stdout JSON).

---

## 1. Nuevos programas

```
cobol/src/programs/TXN-DEPOSIT.cbl    Depósito (incrementa saldo)
cobol/src/programs/TXN-WITHDRAW.cbl   Retiro (valida fondos)
cobol/src/programs/TXN-TRANSFER.cbl   Transferencia atómica
cobol/src/programs/TXN-INQUIRY.cbl    Historial de movimientos
```

## 2. Catálogo de errores ampliado (`ERROR_HANDLER`, 17 → 19)

| Código | Texto | Uso |
|---|---|---|
| `E018` | INVALID AMOUNT | importe ausente del dominio (`<= 0` o no numérico) |
| `E019` | SAME ACCOUNT TRANSFER | origen y destino son la misma cuenta |

Se reutilizan `E004` (cuenta inexistente), `E005` (fondos insuficientes, con el saldo real en el contexto), `E007` (cuenta cerrada) y `E011` (campo obligatorio).

## 3. Los cuatro programas

### `TXN-DEPOSIT` — depósito

```bash
curl -X POST http://localhost:9090/run/TXN-DEPOSIT \
  -d '{"accountId":1,"amount":500.50,"description":"Cash deposit","user":"teller1"}'
# {"status":"OK","transactionId":9,"accountId":1,"amount":500.50,"newBalance":3000.50}
```

Cuenta existente (E004) y `ACTIVE` (E007), importe > 0 (E018). En una única transacción de BD: `UPDATE balance = balance + :amt` + fila `DEPOSIT` en `transactions` + entrada de auditoría.

### `TXN-WITHDRAW` — retiro

Las mismas reglas más la **validación de fondos**: el `SELECT` de la cuenta calcula en SQL `CASE WHEN balance >= :amt THEN 1 ELSE 0 END`; si no alcanza → `E005 INSUFFICIENT FUNDS - BALANCE x`. El `CHECK (balance >= 0)` de la Fase 2 queda como última línea de defensa. Fila `WITHDRAWAL` + auditoría.

### `TXN-TRANSFER` — transferencia atómica

```bash
curl -X POST http://localhost:9090/run/TXN-TRANSFER \
  -d '{"fromAccountId":1,"toAccountId":3,"amount":500,"description":"Rent","user":"teller2"}'
# {"status":"OK","transferOutId":11,"transferInId":12,...,"fromNewBalance":1500.00,"toNewBalance":930.75}
```

Validaciones en orden: origen ≠ destino (E019) → importe > 0 (E018) → origen existe (E004 `ORIGIN ACCOUNT n`) y `ACTIVE` (E007) y con fondos (E005) → destino existe (E004 `DESTINATION ACCOUNT n`) y `ACTIVE` (E007).

La operación es **doble apunte clásico** dentro de una sola transacción PostgreSQL:

1. débito en origen (`balance - :amt`)
2. crédito en destino (`balance + :amt`)
3. fila `TRANSFER_OUT` en origen con `related_account_id` = destino
4. fila `TRANSFER_IN` en destino con `related_account_id` = origen
5. auditoría con los saldos de **ambas** cuentas antes y después

ocesql abre la transacción implícitamente en el CONNECT y el programa solo hace `COMMIT WORK` si los 5 pasos devolvieron `SQLCODE = 0`; cualquier fallo intermedio ejecuta `ROLLBACK WORK` y no queda ningún apunte a medias. Es la misma semántica que tendría el programa bajo un monitor CICS con syncpoint.

### `TXN-INQUIRY` — historial

| Payload | Resultado |
|---|---|
| `{"accountId":1}` | últimos 100 movimientos, los más recientes primero |
| `{"accountId":1,"typeFilter":"DEPOSIT"}` | filtrado por tipo |

Cursor SQL sobre `transactions`; cada fila devuelve id, tipo, importe, timestamp, descripción y cuenta relacionada (0 si no aplica). Solo lectura: no audita.

## 4. Detalles técnicos

- **Importes**: viajan del JSON a un host var `PIC S9(13)V99 COMP-3` vía `FUNCTION NUMVAL`; los saldos vuelven como `CAST(balance AS VARCHAR)` y se emiten como números JSON.
- **Id de transacción**: tras cada INSERT se recupera con `currval('transactions_transaction_id_seq')` dentro de la misma sesión.
- **`description`**: opcional; se inserta con `NULLIF(TRIM(...), '')` para almacenar NULL si viene vacía.
- **Columna `timestamp`**: es palabra clave SQL; se referencia calificada (`t.timestamp`), que PostgreSQL acepta sin comillas y ocesql no confunde.

## 5. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime && docker compose up -d postgres cobol-runtime

curl -X POST http://localhost:9090/run/TXN-DEPOSIT  -d '{"accountId":1,"amount":500.50,"user":"teller1"}'
curl -X POST http://localhost:9090/run/TXN-WITHDRAW -d '{"accountId":1,"amount":1000.50,"user":"teller1"}'
curl -X POST http://localhost:9090/run/TXN-TRANSFER -d '{"fromAccountId":1,"toAccountId":3,"amount":500,"user":"teller2"}'
curl -X POST http://localhost:9090/run/TXN-INQUIRY  -d '{"accountId":1}'

# Doble apunte y auditoría
docker exec ecbs-postgres psql -U ecbs_admin -d ecbs -c \
  "SELECT transaction_id, account_id, transaction_type, amount, related_account_id
     FROM transactions ORDER BY transaction_id DESC LIMIT 4;"
docker exec ecbs-postgres psql -U ecbs_admin -d ecbs -c \
  "SELECT username, operation, entity_id, old_value, new_value
     FROM audit_logs WHERE operation IN ('DEPOSIT','WITHDRAWAL','TRANSFER');"
```

Resultado real de la verificación (cuenta 1 partía de 2500.00, cuenta 3 de 430.75):

| Prueba | Resultado |
|---|---|
| Depósito 500.50 en cuenta 1 | saldo 3000.50, txn 9, audit `DEPOSIT` |
| Depósito en cuenta cerrada / importe negativo / sin importe | `E007` / `E018` / `E011` |
| Retiro 1000.50 | saldo 2000.00, txn 10 |
| Retiro 99999 | `E005 BALANCE 2000.00` |
| Transferencia 500 de 1 → 3 | saldos 1500.00 / 930.75, txns 11 (`TRANSFER_OUT`, rel 3) y 12 (`TRANSFER_IN`, rel 1) |
| Misma cuenta / sin fondos / destino cerrado / destino inexistente | `E019` / `E005` / `E007` / `E004` |
| Historial cuenta 1 | 5 movimientos (semilla + nuevos), filtro por tipo OK |
| Auditoría con saldos antes/después de ambas cuentas | OK |
| Regresión `FRAMEWORK-TEST` | `status OK` |

La consistencia contable cuadra: 2500.00 + 500.50 − 1000.50 − 500.00 = **1500.00** (cuenta 1) y 430.75 + 500.00 = **930.75** (cuenta 3).

## 6. Resultado de la fase

- ✅ Depósitos y retiros con validación de fondos en SQL (E005 con saldo real)
- ✅ Transferencias atómicas con doble apunte `TRANSFER_OUT`/`TRANSFER_IN` enlazado por `related_account_id`
- ✅ Un solo COMMIT por operación; cualquier fallo intermedio hace ROLLBACK total
- ✅ Auditoría completa con saldos antes/después (en transferencias, de las dos cuentas)
- ✅ Historial de movimientos con filtro por tipo; catálogo de errores en 19 códigos

**Siguiente fase:** Fase 7 — Sistema de Tarjetas (emisión, bloqueo/desbloqueo, compras y devoluciones controlando límite y crédito disponible).
