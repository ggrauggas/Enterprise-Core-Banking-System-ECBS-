# Fase 11 — Reporting

**Objetivo:** generación de informes empresariales (extracto de cliente, movimientos de cuenta y totales del banco) con exportación a **CSV** y **PDF**. El PDF se genera directamente en COBOL mediante un módulo reutilizable con tabla de referencias cruzadas (xref) byte-exacta.

---

## 1. Nuevos componentes

```
cobol/src/modules/PDF-WRITER.cbl       Generador de PDF (módulo reutilizable)
cobol/src/programs/RPT-BANK.cbl        Totales del banco (JSON + CSV + PDF)
cobol/src/programs/RPT-CUSTOMER.cbl    Extracto completo de cliente (JSON)
cobol/src/programs/RPT-ACCOUNT.cbl     Movimientos de cuenta (JSON + CSV + PDF)
```

El Dockerfile crea `/opt/ecbs/reports` y define `ECBS_REPORT_DIR`.

## 2. Módulo `PDF-WRITER` — PDF nativo en COBOL

`CALL 'PDF-WRITER' USING PW-PARAMS` con un título y una tabla de líneas de texto produce un **PDF real de una página** (fuente Courier 9pt) que abre en cualquier visor estándar.

Lo relevante es que el PDF se construye respetando la estructura binaria del formato:

- Objetos `Catalog` / `Pages` / `Page` / `Contents` (stream de texto) / `Font`.
- **Offsets byte-exactos**: cada `WRITE` de un archivo `LINE SEQUENTIAL` emite el registro recortado más un `LF`; un contador acumulado (longitud recortada + 1) da el offset real de cada objeto, que se vuelca en la tabla `xref` y en `startxref`.
- Las entradas `xref` terminan en `CR` para que midan los 20 bytes estándar (terminador `CR LF`).
- El `/Length` del stream se calcula antes de escribirlo, sumando los bytes de las líneas de contenido.
- Escapado de `(`, `)` y `\` en el texto.

Verificación estructural del PDF generado (`statement_1.pdf`, 4431 bytes): cabecera `%PDF-1.4`, los **5 offsets del xref apuntan exactamente** a su objeto `N 0 obj`, `startxref` apunta a `xref` y termina en `%%EOF`.

## 3. Los tres informes

### `RPT-BANK` — totales del banco
`{}` → JSON con `totalCustomers`, `activeCustomers`, `totalAccounts`, `totalDeposits` (suma de saldos de cuentas activas), `activeLoans`, `totalLoanAmount`, `activeCards`. Exporta `bank_report.csv` y `bank_report.pdf`.

### `RPT-CUSTOMER` — extracto completo de cliente
`{"customerId":1}` → JSON con los datos personales, **todas** sus cuentas, tarjetas y préstamos, y un bloque `summary` (nº de cuentas/tarjetas/préstamos, saldo total, importe de préstamos activos). Cliente inexistente → `E004`.

### `RPT-ACCOUNT` — extracto de movimientos
`{"accountId":1}` (opcional `limit`, default 50, máx. 200) → JSON con cabecera de cuenta + titular (JOIN), movimientos (más recientes primero, con `direction` IN/OUT) y `totals` (inflow/outflow/recuento). Exporta `statement_<id>.csv` y `statement_<id>.pdf`.

> Nota de implementación: `ocesql` **no** admite subconsultas escalares en la lista del `SELECT`; los totales del banco y del cliente se obtienen con varias sentencias simples. Las agregaciones con `CASE ... END` dentro de `SUM()` (totales de cuenta) sí las admite.

## 4. Clasificación de movimientos (inflow/outflow)

| Dirección | Tipos |
|---|---|
| `IN` (+) | DEPOSIT, TRANSFER_IN, INTEREST, CARD_REFUND, LOAN_DISBURSE |
| `OUT` (−) | WITHDRAWAL, TRANSFER_OUT, CARD_PURCHASE, FEE, LOAN_PAYMENT |

## 5. Cómo ejecutar y verificar

```bash
docker compose build cobol-runtime && docker compose up -d postgres cobol-runtime

curl -X POST http://localhost:9090/run/RPT-BANK     -d '{}'
curl -X POST http://localhost:9090/run/RPT-CUSTOMER -d '{"customerId":1}'
curl -X POST http://localhost:9090/run/RPT-ACCOUNT  -d '{"accountId":1}'

docker exec ecbs-cobol-runtime cat /opt/ecbs/reports/statement_1.csv
docker cp ecbs-cobol-runtime:/opt/ecbs/reports/statement_1.pdf .
```

Resultado real de la verificación:

| Prueba | Resultado |
|---|---|
| `RPT-BANK` | 6 clientes (4 activos), 6 cuentas, depósitos 55.876,90 €, 2 préstamos activos (42.000 €), 3 tarjetas |
| `RPT-CUSTOMER` cliente 1 | 3 cuentas (saldo total 10.370,11 €), 2 tarjetas, 2 préstamos; resumen correcto |
| `RPT-CUSTOMER` inexistente | `E004` |
| `RPT-ACCOUNT` cuenta 1 | 9 movimientos, inflow 3.500,50 / outflow 2.512,00, JSON + CSV + PDF |
| CSV de la cuenta | cabecera + 9 filas con descripción entre comillas |
| PDF de la cuenta | 4431 bytes, xref byte-exacto verificado, abre en visor |

## 6. Resultado de la fase

- ✅ Tres informes: banco, cliente y cuenta
- ✅ Exportación CSV (archivos secuenciales) y PDF (módulo `PDF-WRITER` nativo en COBOL)
- ✅ PDF con xref byte-exacta verificada estructuralmente
- ✅ Totales del banco y clasificación inflow/outflow de movimientos
- ✅ 26 programas COBOL + 9 módulos

**Siguiente fase:** Fase 12 — API REST (Spring Boot): endpoints `/customers`, `/accounts`, `/transactions`, `/cards`, `/loans` sobre el bridge COBOL, con documentación OpenAPI/Swagger.
