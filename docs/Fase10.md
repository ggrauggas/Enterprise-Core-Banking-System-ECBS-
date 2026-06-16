# Fase 10 — Motor de Auditoría

**Objetivo:** completar el motor de auditoría empresarial. El lado de **escritura** ya estaba operativo desde la Fase 4 (cada operación de negocio inserta en `audit_logs` usuario, fecha, operación, entidad y valores anterior/nuevo); esta fase añade el lado de **consulta**: un visor con filtros avanzados y un agregador de estadísticas.

---

## 1. El rastro de auditoría ya existente

A lo largo de las fases 4–9, toda escritura deja su entrada en `audit_logs`. Tras la verificación, el rastro contiene 28 entradas que cubren los cinco dominios:

| entity_type | Operaciones registradas |
|---|---|
| `CUSTOMER` | CREATE, UPDATE, DELETE |
| `ACCOUNT` | CREATE, CLOSE, DEPOSIT, WITHDRAWAL, TRANSFER |
| `CARD` | CREATE, BLOCK, UNBLOCK, CARD_PURCHASE, CARD_REFUND |
| `LOAN` | REQUEST, APPROVE, REJECT |
| `BATCH` | BATCH_INTEREST, BATCH_FEES, BATCH_LOANS, BATCH_CARDS |

Cada fila guarda `old_value`/`new_value` como **JSONB**, lo que permite reconstruir el antes y el después de cada cambio (requisito "todo cambio debe quedar auditado").

## 2. Nuevos programas

```
cobol/src/programs/AUDIT-INQUIRY.cbl   Visor con filtros avanzados
cobol/src/programs/AUDIT-STATS.cbl     Estadísticas agregadas
```

### `AUDIT-INQUIRY` — visor con filtros

Todos los filtros son opcionales y **combinables libremente**; cada uno se activa con un flag `0/1` en el WHERE (el patrón `(:flag = 1 OR columna = :valor)` que ya usaban las consultas de cuentas y tarjetas):

```bash
curl -X POST http://localhost:9090/run/AUDIT-INQUIRY -d '{
  "entityType":"ACCOUNT","entityId":1,
  "username":"teller1","operation":"TRANSFER",
  "dateFrom":"2026-06-01","dateTo":"2026-06-12","limit":50}'
```

| Filtro | Efecto |
|---|---|
| `entityType` | tipo de entidad (normalizado a mayúsculas) |
| `entityId` | id concreto dentro del tipo |
| `username` | autor de la operación |
| `operation` | tipo de operación |
| `dateFrom` / `dateTo` | rango inclusivo de fechas (`event_time >= from` y `< to + 1 día`); ambas se validan con `DATE_UTILS` → `E012` si no son fechas reales |
| `limit` | tope de filas (default 100, máx. 200) |

Devuelve las entradas **más recientes primero** (`ORDER BY audit_id DESC`), con `oldValue`/`newValue` emitidos como **JSON crudo** (objeto o `null`) usando `COALESCE(CAST(... AS VARCHAR), 'null')`, de modo que el JSON del visor anida directamente el JSONB almacenado sin doble escapado.

### `AUDIT-STATS` — estadísticas

`{}` sin parámetros. Devuelve totales y desgloses para alimentar el dashboard de auditoría del frontend (Fase 13):

- `totalEntries`, `distinctUsers`, `firstEvent`, `lastEvent` (una sola consulta de agregación).
- `byEntity`: recuento por tipo de entidad (`GROUP BY entity_type ORDER BY COUNT(*) DESC`).
- `byOperation`: recuento por operación (top 25).

## 3. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime && docker compose up -d postgres cobol-runtime

curl -X POST http://localhost:9090/run/AUDIT-INQUIRY -d '{"entityType":"CUSTOMER"}'
curl -X POST http://localhost:9090/run/AUDIT-INQUIRY -d '{"username":"risk-dept"}'
curl -X POST http://localhost:9090/run/AUDIT-INQUIRY -d '{"operation":"TRANSFER"}'
curl -X POST http://localhost:9090/run/AUDIT-STATS   -d '{}'
```

Resultado real de la verificación (rastro de 28 entradas):

| Prueba | Resultado |
|---|---|
| Sin filtros (`limit:5`) | las 5 más recientes (los 4 steps del batch run 2 + uno del run 1) |
| `entityType=CUSTOMER` | 3 entradas: DELETE, UPDATE, CREATE |
| `entityType=ACCOUNT` + `entityId=1` | 3 entradas: TRANSFER, WITHDRAWAL, DEPOSIT |
| `username=risk-dept` | 3 entradas: APPROVE(2), APPROVE(4), REJECT(3) |
| `operation=TRANSFER` | old/new con los saldos de ambas cuentas en JSON anidado |
| Rango `2026-06-12`..`2026-06-12` | 28 (todas dentro del día) |
| Fecha inválida `2026-13-99` | `E012 INVALID DATE - dateFrom` |
| `AUDIT-STATS` | total 28, 9 usuarios distintos, ventana temporal correcta; byEntity `BATCH:8 ACCOUNT:6 LOAN:6 CARD:5 CUSTOMER:3`; byOperation `CREATE:4 REQUEST:3 APPROVE:2 ...` |

## 4. Resultado de la fase

- ✅ Lado de escritura ya completo desde Fase 4: usuario, fecha, operación, entidad y valores antes/después en JSONB
- ✅ `AUDIT-INQUIRY`: visor con 7 filtros combinables y validación de fechas
- ✅ `oldValue`/`newValue` como JSON crudo reutilizable por el frontend
- ✅ `AUDIT-STATS`: agregados (totales, por entidad, por operación) para el dashboard
- ✅ Cobertura del rastro verificada en los 5 dominios de negocio + batch

**Siguiente fase:** Fase 11 — Reporting (extracto de cliente, movimientos de cuenta, totales del banco; exportación CSV y PDF).
