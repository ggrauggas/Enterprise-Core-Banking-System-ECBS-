# Fase 13 — Frontend React

**Objetivo:** un dashboard web profesional (React + TypeScript + Vite + Material UI) que consume la API REST de la Fase 12 y cubre todos los dominios del banco: panel de KPIs, clientes, cuentas, transacciones, tarjetas, préstamos y visor de auditoría.

---

## 1. Stack y estructura

```
frontend/src/
  main.tsx              ThemeProvider + ToastProvider + BrowserRouter
  App.tsx               Layout (AppBar + Drawer de navegación) + rutas
  api/client.ts         Instancia axios (/api/v1), formato EUR, normalización de errores
  api/types.ts          Interfaces TypeScript de las entidades y reportes
  ui/Toast.tsx          Contexto de notificaciones (Snackbar global)
  ui/StatusChip.tsx     Chip de estado con color por estado de negocio
  pages/
    Dashboard.tsx       KPIs + actividad auditada
    Customers.tsx       Tabla + alta/edición/baja (diálogos)
    Accounts.tsx        Tabla + apertura/cierre + movimientos
    Transactions.tsx    Depósito / retiro / transferencia + consulta de movimientos
    Cards.tsx           Tabla + emisión + bloqueo/desbloqueo + compra/devolución
    Loans.tsx           Simulador + solicitud + aprobación/rechazo + cuadro de amortización
    Audit.tsx           Filtros avanzados + tabla + estadísticas
```

Se añadió `react-router-dom` para el enrutado SPA. La navegación es un `Drawer` permanente con resaltado de la ruta activa.

## 2. Patrones de UI

- **Axios centralizado** (`api/client.ts`): baseURL `/api/v1`, cabecera `X-ECBS-User: web-ui`, y `errMsg()` que extrae el mensaje del cuerpo de problema de la API (`errorCode: mensaje`) — así los errores de negocio de COBOL (E001…E022) llegan legibles al usuario.
- **Toasts globales** vía contexto (`useToast`): cada operación confirma éxito o muestra el error de la API.
- **Diálogos** para altas y operaciones (cliente, cuenta, tarjeta, préstamo).
- **`StatusChip`** colorea los estados (ACTIVE verde, BLOCKED ámbar, CANCELLED/REJECTED rojo, etc.).
- **Formato monetario** español (`Intl.NumberFormat` EUR).

## 3. Pantallas

| Pantalla | Funciones |
|---|---|
| **Dashboard** | KPIs (clientes, cuentas, depósitos, préstamos, tarjetas) desde `/reports/bank`; desglose de auditoría desde `/audit/stats` |
| **Clientes** | tabla, alta (diálogo), edición, baja lógica |
| **Cuentas** | tabla con saldo, apertura (selección de cliente y tipo), cierre, diálogo de movimientos |
| **Transacciones** | pestañas depósito/retiro/transferencia con selección de cuenta, y consulta de historial |
| **Tarjetas** | tabla, emisión, bloqueo/desbloqueo, compra y devolución |
| **Préstamos** | simulador (método francés) con cuadro de amortización, solicitud, aprobación con desembolso opcional, rechazo con motivo |
| **Auditoría** | filtros combinables (entidad, id, usuario, operación, fechas), tabla con valores antiguo/nuevo en JSON, panel de estadísticas |

## 4. Despliegue

El frontend se construye con Vite (`tsc -b && vite build`, TypeScript estricto) y se sirve con **nginx**, que también hace de proxy de `/api/` hacia el contenedor `backend`. En desarrollo, el proxy lo hace Vite (`vite.config.ts`).

```
Navegador  ->  nginx (SPA + proxy /api)  ->  backend  ->  bridge COBOL  ->  PostgreSQL
```

## 5. Cómo ejecutar y verificar

```bash
docker compose up -d --build          # levanta los 4 contenedores
# Frontend:  http://localhost:3000
# Swagger:   http://localhost:8080/swagger-ui.html
```

Resultado real de la verificación (stack completo en marcha):

| Prueba | Resultado |
|---|---|
| Build del frontend (TypeScript estricto) | `✓ built in 3.05s`, sin errores |
| SPA servida por nginx (`/`) | `HTTP 200`, assets `/assets/index-*.js` |
| Enrutado SPA (`/customers` recargado) | `HTTP 200` (fallback a `index.html`) |
| Proxy de lectura `/api/v1/reports/bank` | datos reales (6 clientes activos, depósitos) |
| Escritura a través del proxy (alta cliente) | cliente 10 creado, `ACTIVE` |
| Error de negocio a través del proxy (email duplicado) | `HTTP 409` |
| 4 contenedores | `postgres`, `cobol-runtime`, `backend`, `frontend` arriba |

> Nota: la verificación se hizo vía HTTP (SPA, assets, proxy de lecturas/escrituras y errores). La comprobación visual de los componentes React requiere abrir `http://localhost:3000` en un navegador.

## 6. Resultado de la fase

- ✅ Dashboard profesional con 7 secciones cubriendo todos los dominios
- ✅ React + TypeScript estricto + Vite + Material UI, enrutado SPA
- ✅ Consume la API REST; errores de negocio COBOL mostrados de forma legible
- ✅ Servido por nginx con proxy a la API; build reproducible en Docker
- ✅ Stack completo (4 contenedores) operativo de extremo a extremo

**Siguiente fase:** Fase 14 — Testing (unit, integración, batch, API y frontend) con objetivo de cobertura superior al 80%.
