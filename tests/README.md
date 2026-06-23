# Tests

Estrategia de testing del sistema (**Fase 14**). Las pruebas viven junto
a cada componente y se orquestan en CI (`.github/workflows/ci.yml`).

| Capa                 | Framework                  | Ubicación                    | Cómo ejecutar                                     |
|----------------------|----------------------------|------------------------------|---------------------------------------------------|
| Backend (unit + API) | JUnit 5 + MockMvc + JaCoCo | `backend/src/test/java`      | `cd backend && mvn verify`                        |
| Frontend (unit)      | Vitest + Testing Library   | `frontend/src/**/*.test.tsx` | `cd frontend && npm test`                         |
| COBOL (módulos)      | Drivers COBOL              | `cobol/src/tests/TEST-*.cbl` | `sh scripts/run-cobol-tests.sh`                   |
| Integración / API    | Bash + curl                | `tests/smoke-api.sh`         | `docker compose up -d && bash tests/smoke-api.sh` |

## Cobertura

- **Backend**: gate JaCoCo al **80 % de líneas** sobre el bundle
  (`mvn verify` falla si baja). Cobertura real ≈ 96 %.
- **Frontend**: umbrales por carpeta sobre la lógica con valor
  (`src/api`, `src/ui`) en `vite.config.ts`.
- **COBOL**: cada driver `TEST-*.cbl` devuelve `RETURN-CODE` = número de
  aserciones fallidas; el runner agrega y falla si alguna no pasa.

El smoke test de integración (`smoke-api.sh`) recorre la cadena completa
backend → bridge → COBOL → PostgreSQL contra un stack real levantado con
Docker Compose.
