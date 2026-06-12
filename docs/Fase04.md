# Fase 4 — Gestión de Clientes

**Objetivo:** implementar el primer dominio de negocio completo en COBOL: alta, baja lógica, modificación y consulta de clientes, con validaciones (email, teléfono, duplicados), SQL embebido contra PostgreSQL y registro de auditoría en `audit_logs`.

Es la primera fase en la que COBOL habla directamente con la base de datos: los programas se precompilan con **ocesql** (Open-COBOL-ESQL) y ejecutan `EXEC SQL` real contra PostgreSQL.

---

## 1. Nuevos programas y módulos

```
cobol/src/modules/JSON_UTILS.cbl      Parser JSON plano (módulo común)
cobol/src/programs/CUST-CREATE.cbl    Alta de cliente
cobol/src/programs/CUST-UPDATE.cbl    Modificación de cliente
cobol/src/programs/CUST-DELETE.cbl    Baja lógica de cliente
cobol/src/programs/CUST-INQUIRY.cbl   Consulta individual y listado
```

Todos siguen el mismo esqueleto, el patrón clásico de un programa online de mainframe:

```
ACCEPT (stdin) → PARSE-INPUT → VALIDATE → DB-CONNECT
   → operación SQL → WRITE-AUDIT → COMMIT/ROLLBACK → JSON a stdout
```

El bridge HTTP de la Fase 1 no cambió: `POST /run/<PROGRAMA>` sigue pasando el body JSON por stdin y devolviendo el stdout parseado.

## 2. Módulo `JSON_UTILS` — `CALL 'JSON_UTILS' USING JU-PARAMS`

Los programas reciben el payload como una línea JSON por stdin, y GnuCOBOL 3 no trae `JSON PARSE`. Este módulo extrae el valor de una clave de primer nivel de un objeto JSON plano:

- Localiza el patrón `"clave"`, salta blancos y `:` y lee el valor.
- Soporta valores string (con escapes `\"` y `\\`) y valores desnudos (números, booleanos).
- Devuelve `JU-FOUND` `'Y'/'N'` y el valor en `JU-VALUE` (rellenado con espacios).

Es deliberadamente simple (no maneja objetos anidados ni arrays): suficiente para los payloads del bridge, igual que una rutina de mapeo de un monitor transaccional.

## 3. Catálogo de errores ampliado (`ERROR_HANDLER`)

La fase añade 4 códigos al catálogo central (que pasa de 10 a 14 entradas):

| Código | Texto | Uso en esta fase |
|---|---|---|
| `E011` | MANDATORY FIELD MISSING | falta `firstName`, `lastName` o `customerId` |
| `E012` | INVALID DATE | `birthDate` no es una fecha de calendario |
| `E013` | CUSTOMER MUST BE AN ADULT | edad < 18 según `DATE_UTILS CALC-AGE` |
| `E014` | INVALID STATUS TRANSITION | operar sobre un cliente `DELETED` |

Los ya existentes `E001` (email), `E002` (teléfono), `E003` (duplicado), `E004` (no encontrado) y `E010` (error interno/SQL) completan el mapa de errores del dominio.

## 4. Los cuatro programas

### `CUST-CREATE` — alta

```bash
curl -X POST http://localhost:9090/run/CUST-CREATE -d '{
  "firstName":"Nora","lastName":"Salas Marti",
  "birthDate":"1990-05-17","email":"nora.salas@example.com",
  "phone":"+34600123987","user":"operator1"}'
```

Validaciones en orden: `firstName`/`lastName` no vacíos (E011), email con formato (E001), teléfono 9–15 dígitos (E002), fecha real (E012), mayoría de edad (E013) y email no duplicado con `SELECT COUNT(*)` (E003). Inserta con `status='ACTIVE'`, recupera el id generado (el email es `UNIQUE`) y audita la operación `CREATE` con el registro nuevo como JSONB. Respuesta: `{"status":"OK","customerId":6,"email":"..."}`.

### `CUST-UPDATE` — modificación

```bash
curl -X POST http://localhost:9090/run/CUST-UPDATE -d '{
  "customerId":6,"email":"nuevo@example.com","user":"operator2"}'
```

Semántica de *merge*: solo cambian los campos presentes y no vacíos (`firstName`, `lastName`, `email`, `phone`); el resto conserva el valor actual leído de la BD. Si no se aporta ningún campo → E011. Cliente inexistente → E004; cliente `DELETED` → E014; email duplicado en **otro** cliente (`customer_id <> :id`) → E003. Audita `UPDATE` con valor antiguo **y** nuevo. El trigger `trg_customers_updated_at` de la Fase 2 actualiza `updated_at` solo.

### `CUST-DELETE` — baja lógica

```bash
curl -X POST http://localhost:9090/run/CUST-DELETE -d '{"customerId":6,"user":"operator2"}'
```

Nunca borra la fila: `UPDATE customers SET status='DELETED'`, preservando el histórico (cuentas, transacciones, auditoría). Repetir la baja → E014 `CUSTOMER ALREADY DELETED`. Audita `DELETE` con la transición de estado.

### `CUST-INQUIRY` — consulta

Dos modos según el payload:

| Payload | Resultado |
|---|---|
| `{"customerId":3}` | ficha completa (incluye `createdAt`/`updatedAt`) |
| `{}` | listado (máx. 100, excluye `DELETED`), con `count` |
| `{"statusFilter":"INACTIVE"}` | listado filtrado por estado (`DELETED` los hace visibles) |

El listado usa un **cursor SQL** (`DECLARE CUSTCUR CURSOR` / `OPEN` / `FETCH` / `CLOSE`). Las consultas no se auditan (son de solo lectura), solo se registran vía LOGGER.

## 5. Detalles técnicos del SQL embebido

- **Conexión por programa**: el paragraph `DB-CONNECT` lee `ECBS_DB_*` del entorno (`ACCEPT ... FROM ENVIRONMENT`), monta `ecbs@postgres:5432` y ejecuta `EXEC SQL CONNECT :user IDENTIFIED BY :pass USING :conn`. ocesql abre la transacción implícitamente; al final el programa hace `COMMIT WORK` (éxito) o `ROLLBACK WORK` (cualquier error) y `DISCONNECT ALL` — la operación es atómica: o se escriben cliente **y** auditoría, o nada.
- **Variables host inline**: ocesql no expande `COPY`, así que las variables usadas en `EXEC SQL` se declaran en el propio programa (los copybooks de la Fase 3 siguen siendo el contrato para los módulos sin SQL).
- **`TRIM(TRAILING FROM :HV)`**: los `PIC X(n)` viajan con relleno de espacios; se recortan en el lado SQL en cada INSERT/UPDATE/WHERE.
- **Auditoría JSONB**: el JSON de old/new se construye con `STRING` y se inserta con `CAST(... AS JSONB)`.
- **Errores SQL**: cualquier `SQLCODE` inesperado pasa por `SQL-ERROR-PARA`, que adjunta `SQLCODE` y `SQLERRMC` al error E010 y rueda la transacción atrás.

## 6. Incidencias resueltas durante la fase

| Incidencia | Causa | Solución |
|---|---|---|
| `sqlca.cbl: No such file or directory` | ocesql traduce `INCLUDE SQLCA` a `COPY "sqlca.cbl"`, que vive en el repo de Open-COBOL-ESQL | El Dockerfile conserva `sqlca.cbl` en `/usr/local/share/ocesql/copy` y `compile-cobol.sh` añade ese `-I` a los fuentes con SQL |
| `:MI is not defined in the working-storage` | ocesql interpreta los `:` del literal `TO_CHAR(...,'HH24:MI:SS')` como variables host | Usar `SUBSTR(CAST(created_at AS VARCHAR),1,19)`, sin dos puntos en el SQL |
| `module 'OCESQLConnect' not found` en ejecución | el `CALL` COBOL es dinámico, el enlazador descarta `libocesql` por `--as-needed` | `ENV COB_PRE_LOAD=/usr/local/lib/libocesql.so` en el Dockerfile |

## 7. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime
docker compose up -d postgres cobol-runtime

# Programas disponibles (deben aparecer los 4 CUST-*)
curl http://localhost:9090/programs

# Ciclo de vida completo
curl -X POST http://localhost:9090/run/CUST-CREATE  -d '{"firstName":"Nora","lastName":"Salas Marti","birthDate":"1990-05-17","email":"nora.salas@example.com","phone":"+34600123987","user":"operator1"}'
curl -X POST http://localhost:9090/run/CUST-INQUIRY -d '{"customerId":6}'
curl -X POST http://localhost:9090/run/CUST-UPDATE  -d '{"customerId":6,"phone":"+34699888777"}'
curl -X POST http://localhost:9090/run/CUST-DELETE  -d '{"customerId":6}'
curl -X POST http://localhost:9090/run/CUST-INQUIRY -d '{}'

# Rastro de auditoría
docker exec ecbs-postgres psql -U ecbs_admin -d ecbs \
  -c "SELECT username, operation, entity_id, old_value, new_value FROM audit_logs ORDER BY audit_id;"
```

Resultado real de la verificación (resumen):

| Prueba | Resultado |
|---|---|
| Alta válida | `{"status":"OK","customerId":6}` + audit `CREATE` |
| Email duplicado / inválido | `E003` / `E001` |
| Teléfono inválido | `E002` |
| Fecha inválida (`1990-02-30`) / menor de edad | `E012` / `E013` |
| Campo obligatorio ausente | `E011` |
| Update con merge + auditoría old/new | OK, `updated_at` refrescado por trigger |
| Update a email de otro cliente | `E003` |
| Baja lógica, segunda baja, update sobre borrado | OK / `E014` / `E014` |
| Listado excluye `DELETED`; filtros `INACTIVE`/`DELETED` | OK (`count` correcto) |
| Cliente inexistente | `E004` |
| Regresión `FRAMEWORK-TEST` | `status OK` |

## 8. Resultado de la fase

- ✅ 4 programas COBOL online con SQL embebido (primer dominio de negocio completo)
- ✅ Módulo común `JSON_UTILS` para los payloads del bridge
- ✅ Validaciones de email, teléfono, fecha, mayoría de edad y duplicados
- ✅ Baja lógica que preserva el histórico
- ✅ Auditoría JSONB (usuario, operación, entidad, valor anterior/nuevo) en cada escritura
- ✅ Transacciones atómicas (COMMIT/ROLLBACK) y catálogo de errores ampliado a 14 códigos

**Siguiente fase:** Fase 5 — Gestión de Cuentas (apertura, cierre y consulta de cuentas corrientes/ahorro, regla de saldo no negativo, auditoría).
