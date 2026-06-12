# Fase 7 — Sistema de Tarjetas

**Objetivo:** ciclo de vida completo de tarjetas de crédito: emisión con número generado (Luhn), bloqueo/desbloqueo, compras y devoluciones controlando límite y crédito disponible.

---

## 1. Nuevos programas y módulos

```
cobol/src/modules/CARD_UTILS.cbl       Numeración de tarjetas (Luhn mod 10)
cobol/src/programs/CARD-ISSUE.cbl      Emisión
cobol/src/programs/CARD-BLOCK.cbl      Bloqueo
cobol/src/programs/CARD-UNBLOCK.cbl    Desbloqueo
cobol/src/programs/CARD-PURCHASE.cbl   Compra
cobol/src/programs/CARD-REFUND.cbl     Devolución
cobol/src/programs/CARD-INQUIRY.cbl    Consulta individual y listados
```

## 2. Módulo `CARD_UTILS` — `CALL 'CARD_UTILS' USING CU-PARAMS`

- `GENERATE`: número de 16 dígitos determinista a partir del id de tarjeta: BIN `4539` + `0` + id a 10 dígitos + **dígito de control Luhn (mod 10)** calculado en COBOL (doblado de posiciones pares desde la derecha, resta de 9 si > 9). Único (el id va incrustado) y verificable con cualquier validador estándar.
- `VALIDATE`: re-verifica los 16 dígitos (suma Luhn ≡ 0 mod 10).

## 3. Catálogo de errores ampliado (`ERROR_HANDLER`, 19 → 21)

| Código | Texto | Uso |
|---|---|---|
| `E020` | CARD IS CANCELLED | operar sobre tarjeta cancelada |
| `E021` | REFUND EXCEEDS CREDIT LIMIT | devolución que dejaría `available > limit` |

Se reutilizan `E008` (tarjeta bloqueada, del catálogo original), `E009` (límite de crédito excedido), `E004`, `E007`, `E011`, `E014` y `E018`.

## 4. Los seis programas

### `CARD-ISSUE` — emisión
`{"accountId":1,"creditLimit":2000,"user":"operator1"}` → cuenta existente (E004) y `ACTIVE` (E007), límite > 0 (E018). Toma el id de `cards_card_id_seq`, genera el número con `CARD_UTILS` y emite con `available_credit = credit_limit` y estado `ACTIVE`. Audita `CREATE`/`CARD`.

### `CARD-BLOCK` / `CARD-UNBLOCK`
Transiciones de estado estrictas: solo `ACTIVE → BLOCKED` y `BLOCKED → ACTIVE`. Bloquear una bloqueada o desbloquear una activa → `E014`; tarjeta `CANCELLED` → `E020`. Auditan `BLOCK`/`UNBLOCK` con la transición.

### `CARD-PURCHASE` — compra
`{"cardId":4,"amount":250.75,"description":"Supermarket","user":"pos1"}`. Tarjeta existente (E004), `ACTIVE` (E008 bloqueada / E020 cancelada), importe > 0 (E018) y `available_credit >= amount` calculado en SQL (E009 con el disponible real). Atómico: descuenta crédito + fila `CARD_PURCHASE` en `transactions` (sobre la cuenta vinculada) + auditoría con disponible antes/después.

### `CARD-REFUND` — devolución
Regla espejo: `available_credit + amount <= credit_limit` (solo se puede devolver lo gastado), si no → `E021` con disponible y límite en el mensaje. Fila `CARD_REFUND` + auditoría.

### `CARD-INQUIRY` — consulta
`{"cardId":4}` detalle con el IBAN de la cuenta (JOIN); `{}` listado; `{"accountId":1}` por cuenta; `{"statusFilter":"BLOCKED"}` por estado (combinables). Solo lectura.

## 5. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime && docker compose up -d postgres cobol-runtime

curl -X POST http://localhost:9090/run/CARD-ISSUE    -d '{"accountId":1,"creditLimit":2000,"user":"operator1"}'
curl -X POST http://localhost:9090/run/CARD-PURCHASE -d '{"cardId":4,"amount":250.75,"user":"pos1"}'
curl -X POST http://localhost:9090/run/CARD-REFUND   -d '{"cardId":2,"amount":100,"user":"pos1"}'
curl -X POST http://localhost:9090/run/CARD-BLOCK    -d '{"cardId":4,"user":"fraud-dept"}'
curl -X POST http://localhost:9090/run/CARD-UNBLOCK  -d '{"cardId":4,"user":"fraud-dept"}'
curl -X POST http://localhost:9090/run/CARD-INQUIRY  -d '{"cardId":4}'
```

Resultado real de la verificación:

| Prueba | Resultado |
|---|---|
| Emisión en cuenta 1, límite 2000 | tarjeta 4, número `4539000000000044` **Luhn-válido** (verificado con implementación Python externa) |
| Emisión: cuenta inexistente / cerrada / límite negativo | `E004` / `E007` / `E018` |
| Compra 250.75 (tarjeta 4) | disponible 1749.25, txn 13 `CARD_PURCHASE` en cuenta 1 |
| Compra 5000 con disponible 900 | `E009 AVAILABLE 900.00` |
| Compra con tarjeta bloqueada | `E008` |
| Devolución 100 (tarjeta 2: 900 → 1000) | OK, txn 14 `CARD_REFUND` |
| Devolución 9999 (disponible 1000, límite 1500) | `E021 AVAILABLE 1000.00 LIMIT 1500.00` |
| Bloqueo → compra → re-bloqueo → desbloqueo → re-desbloqueo | OK / `E008` / `E014` / OK / `E014` |
| Tarjeta `CANCELLED` (forzada vía psql) | `E020` |
| Consulta con IBAN, por cuenta, filtro BLOCKED | OK |
| Auditoría: `CREATE`, `CARD_PURCHASE`, `CARD_REFUND`, `BLOCK`, `UNBLOCK` | OK (usuarios `operator1`/`pos1`/`fraud-dept`) |
| Regresión `FRAMEWORK-TEST` | `status OK` |

## 6. Resultado de la fase

- ✅ Emisión con número de tarjeta Luhn-válido generado en COBOL
- ✅ Máquina de estados estricta ACTIVE/BLOCKED/CANCELLED con E008/E014/E020
- ✅ Control de límite y crédito disponible en compras (E009) y devoluciones (E021)
- ✅ Compras y devoluciones como movimientos `CARD_PURCHASE`/`CARD_REFUND` en `transactions`
- ✅ Auditoría completa de todas las operaciones; catálogo en 21 códigos

**Siguiente fase:** Fase 8 — Sistema de Préstamos (simulador con método francés, solicitud, aprobación/rechazo y calendario de amortización).
