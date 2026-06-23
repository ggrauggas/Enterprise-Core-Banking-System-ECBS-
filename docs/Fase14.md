# Fase 14 — Testing

**Objetivo:** dotar al sistema de una batería de pruebas automatizadas en
sus cuatro capas (backend, frontend, COBOL e integración end-to-end), con
cobertura medida y un umbral mínimo del **80 %**, e integrarlo todo en un
pipeline de CI/CD que se ejecuta en cada `push` y `pull request`.

---

## 1. Visión general

| Capa                 | Framework / herramienta    | Ubicación                    | Comando                                           |
|----------------------|----------------------------|------------------------------|---------------------------------------------------|
| Backend (unit + API) | JUnit 5 + MockMvc + JaCoCo | `backend/src/test/java`      | `cd backend && mvn verify`                        |
| Frontend (unit)      | Vitest + Testing Library   | `frontend/src/**/*.test.tsx` | `cd frontend && npm test`                         |
| COBOL (módulos)      | Drivers COBOL `TEST-*.cbl` | `cobol/src/tests`            | `sh scripts/run-cobol-tests.sh`                   |
| Integración / API    | Bash + curl                | `tests/smoke-api.sh`         | `docker compose up -d && bash tests/smoke-api.sh` |

Todo se orquesta en GitHub Actions (`.github/workflows/ci.yml`).

---

## 2. Backend — JUnit + MockMvc + JaCoCo

### Qué se prueba

- **`BankingService`** (unit, con `CobolBridgeClient` mockeado): interpretación
  del *envelope* de resultado COBOL, mapeo de cada código de error `Exxx` al
  `HttpStatus` correcto, fallos del bridge → `502`, construcción del payload
  con el usuario auditor.
- **Controladores REST** (slices `@WebMvcTest`, repositorios y `BankingService`
  mockeados) para `customers`, `accounts`, `transactions`, `cards`, `loans`,
  `audit`, `reports` y `system`: códigos HTTP de éxito (200/201), filtros de
  consulta, validación de entrada (`400 VALIDATION`), 404 de entidades
  inexistentes y propagación de errores de negocio (409/422) desde COBOL.
- **`ApiExceptionHandler`** (unit): el cuerpo de problema JSON
  (`timestamp/status/errorCode/message/details`) para errores de bridge,
  validación y excepciones inesperadas.
- **`CobolBridgeClient`** (unit): round-trip JSON real contra un
  `com.sun.net.httpserver.HttpServer` en proceso — verifica el enrutado
  `POST /run/{program}` y el parseo de la respuesta, sin necesitar el
  contenedor `cobol-runtime`.
- **Entidades JPA** (`ModelEntitiesTest`): accesores y *callbacks*
  `@PrePersist`/`@PreUpdate` (invocados por reflexión, como haría JPA).

### Gate de cobertura

El plugin **JaCoCo** está enlazado a las fases `test` (informe) y `verify`
(comprobación). La regla exige **≥ 80 % de líneas** sobre el *bundle*; si baja,
`mvn verify` falla. Se excluyen la clase de arranque y las configuraciones
estáticas (`OpenApiConfig`, `WebConfig`) por no contener lógica de negocio.

```
Tests run: 79, Failures: 0, Errors: 0
All coverage checks have been met.
Cobertura real de líneas: ~96 %
```

El informe HTML queda en `backend/target/site/jacoco/index.html`.

---

## 3. Frontend — Vitest + Testing Library

Se añadió **Vitest** (entorno `jsdom`), **@testing-library/react** y
**@vitest/coverage-v8**. Configuración en `vite.config.ts` (bloque `test`) y
*setup* global en `src/test/setup.ts` (matchers `jest-dom` + `cleanup`).

Pruebas:

- `api/client.test.ts` — `eur()` (formato monetario) y `errMsg()`
  (normalización de errores de la API, con y sin código de negocio).
- `ui/StatusChip.test.tsx` — etiqueta y color por estado, *fallback* para
  estados desconocidos.
- `ui/PageHeader.test.tsx` — título, subtítulo y acción opcional.
- `ui/Toast.test.tsx` — el contexto `useToast` muestra el Snackbar al dispararse.
- `pages/Dashboard.test.tsx` — render de KPIs con `axios` mockeado y rama de
  error.

La cobertura se exige por carpeta (`vite.config.ts > test.coverage.thresholds`)
sobre los módulos con lógica real (`src/api`, `src/ui`), que quedan al 100 %.
Las páginas CRUD restantes son contenedores presentacionales y se validan de
extremo a extremo con el smoke test de integración.

```
Test Files  5 passed (5)
     Tests  16 passed (16)
```

---

## 4. COBOL — drivers de prueba de los módulos

Se prueban los **módulos puros** (sin SQL embebido), que encapsulan la lógica
de negocio reutilizable. Cada driver define la estructura `LINKAGE` del módulo,
lo invoca con `CALL`, comprueba resultado y estado, imprime `PASS`/`FAIL` y
devuelve `RETURN-CODE` = nº de aserciones fallidas.

| Driver               | Módulo        | Casos                                                                 |
|----------------------|---------------|-----------------------------------------------------------------------|
| `TEST-MONEY.cbl`     | `MONEY_UTILS` | suma, resta, resta negativa (`NF`), interés mensual, cuota francesa, operación desconocida (`VE`) |
| `TEST-VALIDATION.cbl`| `VALIDATION`  | email válido/ inválido, email con espacio, teléfono válido / con letras / corto, `NOT-BLANK` |
| `TEST-DATEUTILS.cbl` | `DATE_UTILS`  | validación de fecha (bisiesto), 29-feb no bisiesto, mes inválido, `ADD-MONTHS` con *clamping*, `DAYS-BETWEEN` |
| `TEST-IBAN.cbl`      | `IBAN_UTILS`  | `BUILD` + `VALIDATE` (round trip mod 97-10), rechazo de dígitos de control alterados, operación desconocida |

El runner `scripts/run-cobol-tests.sh` compila los módulos como librerías
dinámicas (`.so`), compila los drivers como ejecutables, fija
`COB_LIBRARY_PATH` para que `CALL` resuelva los módulos, ejecuta cada driver y
agrega los fallos (sale `1` si alguno falla). Requiere `gnucobol3`
(en CI se instala con `apt-get`).

---

## 5. Integración — smoke test del stack completo

`tests/smoke-api.sh` ejerce la cadena **API REST → bridge → COBOL →
PostgreSQL** contra un stack real (`docker compose up -d`):

1. Espera a que el backend esté *healthy* (`/actuator/health`).
2. `system/info` y `system/model-stats`.
3. Ciclo de cliente: alta (`201`), consulta, rechazo de email duplicado
   (`409`, regla de COBOL).
4. Apertura de cuenta + depósito (`201`) y retiro sin fondos (`422`).
5. Reporte de banco y consulta de auditoría del cliente creado.
6. Rechazos de validación: cuerpo inválido (`400`) y entidad inexistente (`404`).

Falla al primer aserto incorrecto. Es el job final del pipeline, dependiente de
que las otras tres capas pasen.

---

## 6. CI/CD — GitHub Actions

`.github/workflows/ci.yml` define cuatro jobs:

| Job           | Runner        | Acción                                                        |
|---------------|---------------|---------------------------------------------------------------|
| `backend`     | ubuntu + JDK17| `mvn -B verify` (tests + gate JaCoCo) y sube el informe       |
| `frontend`    | ubuntu + Node22| `npm ci`, `npm run build` (type-check) y `npm run test:coverage` |
| `cobol`       | ubuntu        | instala `gnucobol3` y corre `scripts/run-cobol-tests.sh`      |
| `integration` | ubuntu        | `docker compose up --build -d` + `tests/smoke-api.sh` + teardown |

Los tres primeros corren en paralelo; `integration` espera a que pasen.

---

## 7. Cómo ejecutar todo en local

```bash
# Backend (tests + cobertura con gate)
cd backend && mvn verify

# Frontend (tests + cobertura)
cd ../frontend && npm install && npm test

# COBOL (necesita gnucobol3)
cd .. && sh scripts/run-cobol-tests.sh

# Integración end-to-end (necesita Docker)
docker compose up --build -d
bash tests/smoke-api.sh
docker compose down -v
```

---

## 8. Resultado

- **79** tests de backend, gate de cobertura **80 %** (real ~96 %).
- **16** tests de frontend, lógica crítica al 100 %.
- **4** drivers COBOL cubriendo los módulos de negocio reutilizables.
- **1** smoke test de integración recorriendo la cadena completa.
- Pipeline de **CI/CD** que ejecuta las cuatro capas en cada cambio.

Con esto el sistema cumple los objetivos de *Testing automatizado* y *CI/CD*
del proyecto. Siguiente: **Fase 15 — Optimización empresarial**.
