# Fase 3 — Framework COBOL

**Objetivo:** crear la infraestructura COBOL común sobre la que se construirán todos los programas de negocio: los 6 copybooks del modelo y los 5 módulos reutilizables (validación, errores, logging, fechas y dinero).

---

## 1. Reorganización de `cobol/src`

A partir de esta fase los fuentes COBOL se separan en dos categorías con tratamiento de compilación distinto:

```
cobol/src/programs/   Ejecutables (cobc -x) expuestos por el bridge HTTP
cobol/src/modules/    Módulos compartidos (cobc -m → .so) invocados con CALL
```

- `scripts/compile-cobol.sh` compila primero los módulos como librerías dinámicas (`.so`) y después los programas.
- La variable `COB_LIBRARY_PATH=/opt/ecbs/bin` (definida en el Dockerfile) permite que el runtime de GnuCOBOL resuelva los `CALL 'MODULO'` en tiempo de ejecución, igual que haría un gestor de carga en un mainframe.
- El bridge excluye los `.so` de la lista de programas ejecutables.

## 2. Copybooks (`/copybooks`)

Seis copybooks que reflejan 1:1 las tablas de la Fase 2. Son el "contrato de datos" entre programas (equivalente a los DTOs del backend):

| Copybook | Registro | Detalles |
|---|---|---|
| `CUSTOMER.cpy` | `CUSTOMER-REC` | campos + niveles 88 `CUST-ACTIVE`/`INACTIVE`/`DELETED` |
| `ACCOUNT.cpy` | `ACCOUNT-REC` | saldo `S9(13)V99 COMP-3`, 88s de tipo y estado |
| `TRANSACTION.cpy` | `TRANSACTION-REC` | 10 condiciones 88 para los tipos de movimiento |
| `CARD.cpy` | `CARD-REC` | límite y disponible en COMP-3, 88s de estado |
| `LOAN.cpy` | `LOAN-REC` | importe, tipo de interés, meses, 88s del ciclo de vida |
| `AUDIT.cpy` | `AUDIT-REC` | usuario, operación, entidad, valores antiguo/nuevo |

Convenciones: importes monetarios siempre `PIC S9(13)V99 COMP-3` (empaquetado decimal, sin errores de coma flotante); fechas como texto ISO `X(10)`; estados alineados con los CHECK de PostgreSQL.

## 3. Módulos comunes (`cobol/src/modules/`)

Todos siguen el mismo patrón: un bloque de parámetros en `LINKAGE SECTION`, código de retorno de 2 caracteres (`'00'` = OK) y `GOBACK`.

### `VALIDATION.cbl` — `CALL 'VALIDATION' USING VAL-PARAMS`

Operaciones: `EMAIL`, `PHONE`, `NOT-BLANK`. Devuelve `VAL-RC` (`00`/`VE`) y `VAL-MESSAGE` con el motivo exacto. El email se valida carácter a carácter (un solo `@`, punto en el dominio, sin espacios, sin punto final); el teléfono admite `+` inicial y exige 9–15 dígitos.

> Nota: el campo se llama `VAL-RC` y no `VAL-STATUS` porque `VAL-STATUS` es **palabra reservada** en GnuCOBOL (cláusula VALIDATE).

### `ERROR_HANDLER.cbl` — `CALL 'ERROR_HANDLER' USING EH-PARAMS`

Catálogo central de 10 códigos de error de negocio (`E001` email inválido … `E010` error interno) definido como tabla `REDEFINES`/`OCCURS`. Resuelve el código a texto, construye el mensaje estándar `[CODIGO] TEXTO - CONTEXTO`, lo registra vía LOGGER con el nivel correspondiente a la severidad (`I`/`W`/`E`) y lo devuelve al llamador.

### `LOGGER.cbl` — `CALL 'LOGGER' USING LOG-PARAMS`

Logging central con formato `[timestamp] [NIVEL] [COMPONENTE] mensaje`:

- **Archivo**: append a `ECBS_LOG_FILE` (default `/opt/ecbs/logs/ecbs.log`), con `SELECT OPTIONAL` + `OPEN EXTEND` (crea el archivo si no existe).
- **stderr** (`DISPLAY UPON SYSERR`): así el bridge lo captura en el campo `stderr` de la respuesta sin contaminar el JSON de stdout.

### `DATE_UTILS.cbl` — `CALL 'DATE_UTILS' USING DU-PARAMS`

Fechas ISO `YYYY-MM-DD`. Operaciones: `CURRENT-TS` (timestamp actual), `VALIDATE` (fecha de calendario real, vía `INTEGER-OF-DATE`), `CALC-AGE` (edad exacta teniendo en cuenta si ya pasó el cumpleaños), `ADD-MONTHS` (con ajuste de fin de mes: 31-ene + 1 mes → 28-feb) y `DAYS-BETWEEN`.

### `MONEY_UTILS.cbl` — `CALL 'MONEY_UTILS' USING MU-PARAMS`

Aritmética monetaria en COMP-3: `ADD`, `SUBTRACT` (devuelve `NF` si el resultado sería negativo — la regla de oro de la Fase 5), `FORMAT` (cadena legible), `MONTHLY-INT` (interés mensual simple) y **`FRENCH-PMT`**: cuota constante del método francés `A = P·i·f/(f−1)` con `f=(1+i)^n`, que usará el simulador de préstamos de la Fase 8.

## 4. Programa de verificación `FRAMEWORK-TEST`

`cobol/src/programs/FRAMEWORK-TEST.cbl` ejercita los 5 módulos y el copybook `CUSTOMER` (vía `COPY CUSTOMER`) y emite los resultados como JSON. Ejecutable desde el bridge:

```bash
curl -X POST http://localhost:9090/run/FRAMEWORK-TEST -d '{}'
```

Resultado real de la verificación:

```json
{
  "emailOk": "00", "emailBad": "VE",
  "emailBadMsg": "EMAIL MUST CONTAIN EXACTLY ONE @",
  "phoneOk": "00", "dateValid": "00", "dateInvalid": "VE",
  "age": 41, "addMonths": "2026-02-28", "daysBetween": 161,
  "moneyAdd": "300.75", "frenchPayment": "229.21",
  "errorMessage": "[E005] INSUFFICIENT FUNDS - ACCOUNT 3",
  "copybookEmail": "maria.garcia@example.com", "status": "OK"
}
```

(La cuota francesa de 12.000 € al 5,50 % a 60 meses = **229,21 €/mes**, verificable con cualquier calculadora de amortización.)

## 5. Incidencias resueltas durante la fase

| Incidencia | Causa | Solución |
|---|---|---|
| `'VAL-STATUS' is a reserved word` | GnuCOBOL reserva `VAL-STATUS` (cláusula VALIDATE del estándar) | Renombrar el campo a `VAL-RC` |
| LOGGER no escribía el archivo (file status `05` y luego `41`) | `05` ("archivo opcional creado") es un código de éxito y se trataba como error, dejando el archivo sin cerrar | Aceptar `00` y `05` como apertura válida |
| Líneas > columna 72 en la tabla de errores | Formato fijo COBOL | Partir cada entrada en dos FILLER (código + texto) |

## 6. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime
docker compose up -d cobol-runtime

# Lista de programas (los .so no aparecen: no son ejecutables directos)
curl http://localhost:9090/programs

# Test integral del framework
curl -X POST http://localhost:9090/run/FRAMEWORK-TEST -d '{}'

# Ver el log generado por LOGGER
docker exec ecbs-cobol-runtime cat /opt/ecbs/logs/ecbs.log
```

## 7. Resultado de la fase

- ✅ 6 copybooks alineados con el esquema PostgreSQL
- ✅ 5 módulos comunes compilados como librerías dinámicas invocables con `CALL`
- ✅ Pipeline de compilación con dos modos (programas/módulos) y soporte ocesql ya preparado
- ✅ Logging centralizado a archivo + stderr
- ✅ `FRAMEWORK-TEST` validando todo el framework de extremo a extremo vía HTTP

**Siguiente fase:** Fase 4 — Gestión de Clientes (alta, baja lógica, modificación y consulta con SQL embebido desde COBOL, validaciones y auditoría).
