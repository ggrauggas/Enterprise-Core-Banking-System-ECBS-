# Fase 1 — Fundación del Proyecto

**Objetivo:** crear toda la estructura inicial del Enterprise Core Banking System (ECBS): carpetas, contenedores Docker, PostgreSQL, backend Spring Boot, frontend React y el runtime GnuCOBOL con su bridge HTTP.

---

## 1. Decisiones de arquitectura

Antes de escribir código se fijaron dos decisiones estructurales:

1. **Integración COBOL ↔ backend mediante bridge HTTP.** El contenedor `cobol-runtime` expone un pequeño servicio HTTP (`cobol/bridge/server.py`, solo librería estándar de Python) que recibe peticiones del backend y ejecuta los programas COBOL compilados. Este bridge juega el papel que un monitor transaccional (CICS/IMS) jugaría en un mainframe real: el backend nunca ejecuta binarios directamente, solo despacha "transacciones" por nombre de programa.
2. **SQL embebido con ocesql.** Los programas COBOL que acceden a PostgreSQL usarán `EXEC SQL` precompilado con [Open-COBOL-ESQL (ocesql)](https://github.com/opensourcecobol/Open-COBOL-ESQL), que ya queda instalado en la imagen desde esta fase.

La cadena completa queda así:

```
Frontend (React) → Backend (Spring Boot) → Bridge HTTP → Programa COBOL → PostgreSQL
```

## 2. Estructura de carpetas creada

```
/frontend     SPA React (TypeScript, Vite, Material UI)
/backend      API REST Spring Boot (Java 17, Maven)
/cobol        Programas COBOL online (src/) + bridge HTTP (bridge/) + Dockerfile
/copybooks    Estructuras COBOL compartidas (.cpy) — se llenan en Fase 3
/batch        Batch nocturno — se implementa en Fase 9
/database     Scripts SQL de inicialización (database/init/)
/docs         Documentación por fase (este archivo)
/tests        Tests de integración transversales — Fase 14
/scripts      Utilidades: compile-cobol.sh, dev-up.ps1
```

## 3. Docker Compose

`docker-compose.yml` define los 4 contenedores exigidos por el proyecto, con *healthchecks* encadenados (`postgres` → `cobol-runtime` → `backend` → `frontend`) para que el arranque respete las dependencias:

| Servicio        | Imagen                              | Puerto host | Healthcheck                       |
|-----------------|-------------------------------------|-------------|-----------------------------------|
| `postgres`      | `postgres:16-alpine`                | 5432        | `pg_isready`                      |
| `cobol-runtime` | build propio (`cobol/Dockerfile`)   | 9090        | `GET /health` del bridge          |
| `backend`       | build propio (`backend/Dockerfile`) | 8080        | `GET /actuator/health`            |
| `frontend`      | build propio (`frontend/Dockerfile`)| 3000        | —                                 |

Credenciales de desarrollo: base de datos `ecbs`, usuario `ecbs_admin`, contraseña `ecbs_secret` (variables de entorno del compose; en producción irían en un gestor de secretos).

## 4. PostgreSQL

- Los scripts de `database/init/` se montan en `/docker-entrypoint-initdb.d`, por lo que PostgreSQL los ejecuta automáticamente al crear el volumen por primera vez.
- `001_bootstrap.sql` crea la extensión `pgcrypto` y una tabla marcador `system_bootstrap` para poder verificar la inicialización. Las tablas de dominio (customers, accounts, …) llegan en la Fase 2.

> Para reinicializar la base de datos desde cero: `docker compose down -v` (borra el volumen `postgres-data`) y `docker compose up -d`.

## 5. Runtime COBOL (`cobol-runtime`)

`cobol/Dockerfile` (contexto de build = raíz del repo, para poder copiar también `/copybooks` y `/scripts`):

1. Parte de `debian:bookworm-slim` e instala **GnuCOBOL 3** (`gnucobol3`), la toolchain C (gcc, make, autotools, `pkg-config`) y `libpq-dev`.
2. Clona y compila **ocesql** desde GitHub (precompilador de SQL embebido para PostgreSQL).
3. Copia `copybooks/`, `cobol/src/` y `cobol/bridge/`.
4. Ejecuta `scripts/compile-cobol.sh`, que compila cada `*.cbl` de `src/` a binario en `/opt/ecbs/bin`. Si el fuente contiene `EXEC SQL`, primero lo pasa por `ocesql` y enlaza con `-locesql`; si no, compila directo con `cobc -x`.
5. Arranca el bridge: `python3 /opt/ecbs/bridge/server.py`.

### El bridge HTTP

| Método | Ruta             | Función                                                        |
|--------|------------------|----------------------------------------------------------------|
| GET    | `/health`        | Liveness + número de programas disponibles                      |
| GET    | `/programs`      | Lista de programas COBOL ejecutables                            |
| POST   | `/run/<PROGRAMA>`| Ejecuta el binario; el body JSON se pasa por stdin y el stdout se devuelve (parseado como JSON si es posible) |

Convención ECBS: **todo programa online lee JSON por stdin y escribe JSON por stdout**. El bridge valida el nombre del programa (regex `^[A-Z][A-Z0-9-]{0,30}$` y existencia en `/opt/ecbs/bin`) para impedir ejecuciones arbitrarias.

### Programa de humo `HELLO.cbl`

Primer programa COBOL del sistema (formato fijo, GnuCOBOL). Imprime un JSON con `status`, `message` y un timestamp obtenido con `FUNCTION CURRENT-DATE`. Sirve para probar toda la cadena.

## 6. Backend (Spring Boot 3, Java 17)

- `backend/pom.xml`: Spring Boot 3.3.5 con `spring-boot-starter-web`, `actuator` y `test`. (JPA/PostgreSQL se añaden en la Fase 2, cuando exista el modelo.)
- `com.ecbs.cobol.CobolBridgeClient`: cliente `RestClient` hacia el bridge; URL configurable vía `ECBS_COBOL_BRIDGE_URL` (en compose apunta a `http://cobol-runtime:9090`).
- `com.ecbs.system.SystemController`: expone `GET /api/v1/system/info`, que consulta la salud del bridge **y ejecuta el programa COBOL `HELLO`**, demostrando la cadena completa.
- `backend/Dockerfile`: build multi-stage (Maven → JRE 17 alpine) con capa de dependencias cacheada (`dependency:go-offline`).

## 7. Frontend (React + TypeScript + Vite + Material UI)

- Proyecto Vite con React 18, MUI 5 y axios.
- `src/App.tsx`: página de estado que llama a `/api/v1/system/info` y muestra tres tarjetas: estado del backend, estado del bridge COBOL y respuesta del programa `HELLO`.
- En desarrollo local, `vite.config.ts` proxya `/api` → `http://localhost:8080`; en Docker, nginx (`frontend/nginx.conf`) sirve la SPA y proxya `/api/` → `http://backend:8080`.
- `frontend/Dockerfile`: build multi-stage (node 22 → nginx 1.27).

## 8. Otros archivos

- `.gitattributes`: fuerza fin de línea LF en `*.sh`, `*.py`, `*.cbl`, `*.cpy`, `*.sql`, Dockerfiles… para que los archivos funcionen dentro de los contenedores Linux aunque el desarrollo sea en Windows.
- `.gitignore` ampliado (target de Maven, node_modules, binarios COBOL…).
- `.dockerignore` raíz + por servicio para acelerar los builds.
- `README.md` inicial con arquitectura, puertos, instrucciones y tabla de estado de fases.

## 9. Cómo ejecutar y verificar

```bash
# Construir y arrancar todo
docker compose up --build -d

# Ver estado de los contenedores (todos deben quedar healthy)
docker compose ps
```

Verificaciones manuales:

1. **Bridge COBOL** — `http://localhost:9090/health` → `{"status":"UP","service":"cobol-bridge","programCount":1}`
2. **Programa COBOL** — `POST http://localhost:9090/run/HELLO` → JSON con `"message":"ECBS COBOL runtime ready"` y `exitCode: 0`
3. **Backend** — `http://localhost:8080/api/v1/system/info` → incluye `cobolBridge.status = "UP"` y la respuesta de `HELLO`
4. **Frontend** — `http://localhost:3000` → dashboard con las tres tarjetas en verde
5. **PostgreSQL** — `docker exec ecbs-postgres psql -U ecbs_admin -d ecbs -c "SELECT * FROM system_bootstrap;"`

Para parar todo: `docker compose down` (añadir `-v` para borrar también los datos).

## 10. Incidencias resueltas durante la fase

| Incidencia | Causa | Solución |
|------------|-------|----------|
| `configure: error: libpq-fe.h is required` al compilar ocesql | El `configure` de ocesql localiza libpq mediante `pkg-config`, que no estaba en la imagen | Añadir `pkg-config` al `apt-get install` de `cobol/Dockerfile` |
| `TS2580: Cannot find name 'process'` en el build del frontend | `vite.config.ts` usa `process.env` y faltaban los tipos de Node | Añadir `@types/node` a devDependencies y `"types": ["node"]` en `tsconfig.node.json` |

## 11. Resultado de la fase

- ✅ Estructura completa de 9 carpetas
- ✅ 4 contenedores orquestados con Docker Compose y healthchecks
- ✅ PostgreSQL 16 inicializado con script de bootstrap
- ✅ Backend Spring Boot con cliente del bridge y endpoint de sistema
- ✅ Frontend React + MUI con página de estado
- ✅ GnuCOBOL 3 + ocesql instalados; primer programa COBOL (`HELLO`) compilado y ejecutable vía HTTP
- ✅ README inicial

**Siguiente fase:** Fase 2 — Modelo Bancario (tablas PostgreSQL y entidades: clientes, cuentas, transacciones, tarjetas y préstamos).
