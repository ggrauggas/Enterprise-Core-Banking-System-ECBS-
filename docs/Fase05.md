# Fase 5 — Gestión de Cuentas

**Objetivo:** segundo dominio de negocio en COBOL: apertura, cierre y consulta de cuentas bancarias (corriente/ahorro), con generación de IBAN real, regla de saldo no negativo y auditoría.

Reutiliza íntegro el patrón online de la Fase 4 (stdin JSON → validar → SQL embebido → auditar → COMMIT/ROLLBACK → stdout JSON).

---

## 1. Nuevos programas y módulos

```
cobol/src/modules/IBAN_UTILS.cbl      Dígitos de control IBAN (módulo común)
cobol/src/programs/ACCT-OPEN.cbl      Apertura de cuenta
cobol/src/programs/ACCT-CLOSE.cbl     Cierre de cuenta
cobol/src/programs/ACCT-INQUIRY.cbl   Consulta individual y listados
```

## 2. Módulo `IBAN_UTILS` — `CALL 'IBAN_UTILS' USING IB-PARAMS`

Implementa el algoritmo **ISO 13616 (mod 97-10)** de los IBAN:

- `BUILD`: a partir del país (2 letras) y el BBAN, calcula los 2 dígitos de control y devuelve el IBAN completo. El mod-97 se calcula con resto acumulado dígito a dígito (las letras expanden a dos dígitos, A=10…Z=35), sin necesitar aritmética de 24+ cifras.
- `VALIDATE`: reordena el IBAN (BBAN + país + control) y verifica `mod 97 = 1`.

Los IBAN generados validan contra implementaciones externas del estándar (comprobado con una implementación Python independiente durante las pruebas).

## 3. Catálogo de errores ampliado (`ERROR_HANDLER`, 14 → 17)

| Código | Texto | Uso |
|---|---|---|
| `E015` | INVALID ACCOUNT TYPE | tipo distinto de `CHECKING`/`SAVINGS` |
| `E016` | ACCOUNT BALANCE NOT ZERO | intento de cerrar una cuenta con saldo |
| `E017` | CUSTOMER NOT ACTIVE | abrir cuenta a cliente `INACTIVE`/`DELETED` |

Se reutilizan `E004` (no encontrado), `E007` (cuenta ya cerrada, ya existía en el catálogo de la Fase 3) y `E011` (campo obligatorio).

## 4. Los tres programas

### `ACCT-OPEN` — apertura

```bash
curl -X POST http://localhost:9090/run/ACCT-OPEN \
  -d '{"customerId":1,"accountType":"CHECKING","user":"operator1"}'
# {"status":"OK","accountId":7,"iban":"ES1321000418000000000007",...}
```

Reglas:
- El titular debe existir (E004) y estar `ACTIVE` (E017 si `INACTIVE` o `DELETED`).
- `accountType` obligatorio, `CHECKING` o `SAVINGS` (E015); se acepta en minúsculas (se normaliza con `UPPER-CASE`).
- **Las cuentas siempre abren con saldo 0**: la financiación llega por el motor transaccional de la Fase 6. Junto al `CHECK (balance >= 0)` de la BD, esto garantiza la regla "no permitir saldo negativo".

Generación del IBAN: el programa toma el id de la secuencia **antes** del INSERT (`SELECT nextval('accounts_account_id_seq')`) para poder incrustarlo en el BBAN: entidad `2100` + oficina `0418` + DC interno `00` (simplificado) + número de cuenta = id a 10 dígitos. `IBAN_UTILS BUILD` añade los dígitos de control ES. Consumir el `nextval` mantiene la secuencia del `BIGSERIAL` coherente.

Audita `CREATE`/`ACCOUNT` con el registro nuevo en JSONB.

### `ACCT-CLOSE` — cierre

```bash
curl -X POST http://localhost:9090/run/ACCT-CLOSE -d '{"accountId":7,"user":"operator2"}'
```

Reglas en orden: cuenta existente (E004) → no cerrada ya (E007) → **saldo exactamente 0** (E016, el contexto incluye el saldo actual). Igual que la baja de clientes, es una operación lógica: `status='CLOSED'`, el histórico se conserva. La comparación de saldo se hace en SQL (`CASE WHEN balance = 0 THEN 1 ELSE 0 END`), evitando aritmética decimal en el lado COBOL. Audita `CLOSE`/`ACCOUNT` con la transición.

### `ACCT-INQUIRY` — consulta

| Payload | Resultado |
|---|---|
| `{"accountId":7}` | detalle completo con **nombre del titular** (`JOIN customers`) |
| `{}` | listado de todas las cuentas (máx. 100) |
| `{"customerId":1}` | cuentas de un cliente |
| `{"statusFilter":"CLOSED"}` | filtro por estado (combinable con `customerId`) |

El listado usa cursor SQL (`DECLARE ACCTCUR CURSOR`). El saldo viaja como `CAST(balance AS VARCHAR)` y se emite como número JSON (`"balance":2500.00`). Solo lectura: se registra vía LOGGER pero no se audita.

## 5. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime && docker compose up -d postgres cobol-runtime

curl -X POST http://localhost:9090/run/ACCT-OPEN    -d '{"customerId":1,"accountType":"CHECKING","user":"operator1"}'
curl -X POST http://localhost:9090/run/ACCT-INQUIRY -d '{"accountId":7}'
curl -X POST http://localhost:9090/run/ACCT-INQUIRY -d '{"customerId":1}'
curl -X POST http://localhost:9090/run/ACCT-CLOSE   -d '{"accountId":7}'

docker exec ecbs-postgres psql -U ecbs_admin -d ecbs \
  -c "SELECT username, operation, entity_id, new_value FROM audit_logs WHERE entity_type='ACCOUNT';"
```

Resultado real de la verificación (resumen):

| Prueba | Resultado |
|---|---|
| Apertura CHECKING (cliente 1) / SAVINGS (cliente 3) | cuentas 7 y 8, IBAN válido mod-97 (verificado externamente) |
| Tipo inválido (`PREMIUM`) | `E015` |
| Titular inexistente / INACTIVE / DELETED | `E004` / `E017` / `E017` |
| Detalle con titular (`Maria Garcia Lopez`), listados y filtros | OK (`count` correcto) |
| Cierre con saldo 0 | OK + audit `CLOSE` |
| Segundo cierre / cierre con saldo 2500.00 | `E007` / `E016 BALANCE 2500.00` |
| `accountId` ausente | `E011` |
| Auditoría: 2×`CREATE` + 1×`CLOSE` sobre `ACCOUNT` | OK |
| Regresión `FRAMEWORK-TEST` | `status OK` |

## 6. Resultado de la fase

- ✅ Apertura con IBAN ISO 13616 generado en COBOL (mod 97-10 propio)
- ✅ Cierre lógico solo con saldo cero (regla E016) y sin dobles cierres (E007)
- ✅ Consulta con JOIN al titular, listados por cliente y por estado
- ✅ Regla de saldo no negativo garantizada por diseño (apertura a 0 + CHECK en BD)
- ✅ Auditoría JSONB de apertura y cierre; catálogo de errores en 17 códigos

**Siguiente fase:** Fase 6 — Motor Transaccional (depósitos, retiros con validación de fondos y transferencias atómicas con auditoría completa).
