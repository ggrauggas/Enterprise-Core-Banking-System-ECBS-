# Fase 12 — API REST

**Objetivo:** exponer todo el sistema como una API REST en Spring Boot sobre la capa COBOL, con documentación OpenAPI/Swagger. El backend nunca ejecuta binarios COBOL: enruta cada operación de negocio al bridge HTTP (igual que un middleware enrutaría a transacciones CICS).

---

## 1. Arquitectura: lecturas JPA, escrituras COBOL

El backend aplica una separación tipo CQRS fiel al diseño del proyecto:

- **Lecturas** (GET de listados y detalle): se sirven del **modelo de lectura JPA** (repositorios sobre las tablas), rápido y directo.
- **Escrituras y operaciones de negocio** (alta/baja/modificación, depósitos, transferencias, tarjetas, préstamos): se despachan al **bridge COBOL**, que es el dueño de las reglas, la atomicidad y la auditoría.

```
HTTP REST  ->  Controllers  ->  BankingService  ->  CobolBridgeClient
                    │                                      │
              Repositorios JPA (lecturas)            bridge -> COBOL -> PostgreSQL
```

## 2. Componentes nuevos

```
cobol/BankingService.java     Despacha al bridge e interpreta el envelope COBOL
cobol/BridgeException.java     Error de negocio con su código ECBS y HTTP status
common/ApiExceptionHandler     @RestControllerAdvice -> cuerpo de problema JSON
common/OpenApiConfig           Metadatos OpenAPI (Swagger)
common/WebConfig               CORS para el frontend (Fase 13)
<dominio>/XxxController.java   7 controladores REST
```

## 3. Endpoints (`/api/v1`)

| Recurso | Endpoints |
|---|---|
| `customers` | GET list (`?status`), GET `{id}`, POST, PUT `{id}`, DELETE `{id}` |
| `accounts` | GET list (`?customerId,?status`), GET `{id}`, GET `{id}/transactions`, POST, POST `{id}/close` |
| `transactions` | GET (`?accountId`), POST `/deposits`, `/withdrawals`, `/transfers` |
| `cards` | GET list, GET `{id}`, POST, POST `{id}/block`, `/unblock`, `/purchases`, `/refunds` |
| `loans` | GET list, GET `{id}`, GET `{id}/schedule`, POST `/simulate`, POST, POST `{id}/approve`, `{id}/reject` |
| `audit` | GET (filtros combinables), GET `/stats` |
| `reports` | GET `/bank`, GET `/customers/{id}`, GET `/accounts/{id}` |
| `system` | GET `/model-stats`, GET `/info` |

En total **35 operaciones** sobre 29 rutas, todas en `/v3/api-docs`.

## 4. Mapeo de errores COBOL → HTTP

`BankingService` interpreta el envelope que devuelven los programas COBOL
(`{"status":"ERROR","errorCode":"Exxx","message":"..."}`) y lanza un
`BridgeException` con el HTTP status adecuado:

| Códigos ECBS | HTTP |
|---|---|
| E001/E002/E011/E012/E013/E015/E018 (validación) | 400 |
| E004 (no encontrado) | 404 |
| E003/E007/E014/E016/E017/E019/E020/E022 (conflicto de estado) | 409 |
| E005/E008/E009/E021 (regla de negocio) | 422 |
| E010 y otros (interno) | 500 |

`ApiExceptionHandler` produce un cuerpo uniforme `{timestamp, status, errorCode, message, details?}`. La validación de Spring (`@NotBlank`, `@Positive`…) se aplica antes y devuelve 400 con detalle de campos.

## 5. Documentación OpenAPI / Swagger

- Spec: `http://localhost:8080/v3/api-docs`
- Swagger UI: `http://localhost:8080/swagger-ui.html`

Cada controlador lleva `@Tag` y cada endpoint `@Operation`; las peticiones usan records con anotaciones de validación, que springdoc traduce a esquemas.

## 6. Incidencia resuelta: cuerpo *chunked*

`RestClient` (cliente HTTP del JDK) envía el cuerpo POST con
`Transfer-Encoding: chunked` y **sin** `Content-Length`. El bridge leía el
cuerpo por `Content-Length`, así que recibía 0 bytes y COBOL veía `{}`
(primer error: `E011 firstName`). Diagnóstico con un log temporal del bridge:

```
[bridge-debug] CL=None TE=chunked bodylen=0 body=b''      <- backend
[bridge-debug] CL=105  TE=None    bodylen=105 body=b'{...}' <- curl
```

Solución (en el bridge, que es nuestro y debe ser robusto): `_read_request_body()`
detecta `Transfer-Encoding: chunked` y decodifica los *chunks* (tamaño en hex +
CRLF) hasta el chunk 0; si no, lee por `Content-Length` como antes.

## 7. Cómo ejecutar y verificar

```bash
docker compose up -d --build postgres cobol-runtime backend

# lecturas (JPA)
curl http://localhost:8080/api/v1/customers
# alta (COBOL CUST-CREATE)
curl -X POST http://localhost:8080/api/v1/customers -H 'Content-Type: application/json' \
  -H 'X-ECBS-User: api' \
  -d '{"firstName":"Pau","lastName":"Vidal","birthDate":"1991-08-20","email":"pau@example.com","phone":"+34611222333"}'
# transferencia (COBOL TXN-TRANSFER)
curl -X POST http://localhost:8080/api/v1/transactions/transfers -H 'Content-Type: application/json' \
  -d '{"fromAccountId":1,"toAccountId":3,"amount":200}'
# documentación
open http://localhost:8080/swagger-ui.html
```

Resultado real de la verificación de extremo a extremo (HTTP → backend → bridge → COBOL → PostgreSQL):

| Prueba | Resultado |
|---|---|
| GET `/customers` (oculta DELETED) / GET `/customers/999` | lista de 5 / `404` |
| POST `/customers` (alta) | cliente 9 creado, `ACTIVE` |
| POST email inválido / campo vacío | `400 E001` / `400 VALIDATION` (campo) |
| POST `/accounts` | cuenta 9, IBAN generado |
| Depósito / transferencia | saldos actualizados, txns 31/32/33 |
| Retiro sin fondos | `422 E005` |
| Emisión tarjeta / bloqueo / compra con bloqueada | card 5 / `BLOCKED` / `422 E008` |
| Simulación / solicitud / aprobación con desembolso préstamo | cuota OK / `REQUESTED` / `ACTIVE` |
| Baja lógica de cliente | `DELETED` |
| Auditoría (filtro + stats) | 39 entradas, desglose por entidad |
| Reporte de banco | totales correctos |
| Swagger UI / `/v3/api-docs` | `200`, 29 rutas / 35 operaciones |

## 8. Resultado de la fase

- ✅ API REST completa sobre los 5 dominios + auditoría + reportes
- ✅ Lecturas por JPA, escrituras por la capa COBOL (el backend no ejecuta binarios)
- ✅ Mapeo fiel de los 22 códigos de error ECBS a HTTP 400/404/409/422/500
- ✅ Validación de entrada (Bean Validation) y cuerpo de problema uniforme
- ✅ Documentación OpenAPI 3 + Swagger UI
- ✅ Bridge robusto ante cuerpos chunked

**Siguiente fase:** Fase 13 — Frontend React (dashboard, clientes, cuentas, transacciones, tarjetas, préstamos y visor de auditoría) consumiendo esta API.
