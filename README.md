# Enterprise Core Banking System (ECBS)

Simulación de un sistema Core Banking empresarial desarrollado en **COBOL**, inspirado en arquitecturas bancarias reales. Incluye gestión de clientes, cuentas, transferencias, tarjetas, préstamos, procesamiento batch nocturno, auditoría completa, reporting financiero y una interfaz web moderna para operaciones y monitorización.

## Arquitectura

```
Frontend (React + TS + Vite + MUI)
        ↓ HTTP
Backend API (Java Spring Boot)
        ↓ HTTP (bridge, rol de monitor transaccional)
COBOL Business Layer (GnuCOBOL + ocesql)
        ↓ SQL embebido / archivos batch
PostgreSQL 16
```

Cada capa corre en su propio contenedor Docker:

| Contenedor      | Tecnología                     | Puerto |
|-----------------|--------------------------------|--------|
| `frontend`      | React + Vite servido por nginx | 3000   |
| `backend`       | Spring Boot 3 (Java 17)        | 8080   |
| `cobol-runtime` | GnuCOBOL 3 + ocesql + bridge   | 9090   |
| `postgres`      | PostgreSQL 16                  | 5432   |

## Estructura del repositorio

```
/frontend     SPA React (TypeScript, Vite, Material UI)
/backend      API REST Spring Boot
/cobol        Programas COBOL online + bridge HTTP
/copybooks    Estructuras de datos COBOL compartidas (.cpy)
/batch        Programas y scripts del batch nocturno
/database     Scripts SQL de inicialización y migraciones
/docs         Documentación por fase (FaseXX.md)
/tests        Tests de integración transversales
/scripts      Utilidades (compilación COBOL, arranque, etc.)
```

## Puesta en marcha

Requisitos: Docker Desktop (Compose v2).

```bash
docker compose up --build -d
```

Servicios:

- Frontend: <http://localhost:3000>
- API backend: <http://localhost:8080/api/v1/system/info>
- Bridge COBOL: <http://localhost:9090/health>
- PostgreSQL: `localhost:5432` (db `ecbs`, usuario `ecbs_admin`)

## Estado de las fases

| Fase | Descripción              | Estado |
|------|--------------------------|--------|
| 1    | Fundación del proyecto   | ✅     |
| 2    | Modelo bancario          | ✅     |
| 3    | Framework COBOL          | ✅     |
| 4    | Gestión de clientes      | ✅     |
| 5    | Gestión de cuentas       | ✅     |
| 6    | Motor transaccional      | ✅     |
| 7    | Sistema de tarjetas      | ✅     |
| 8    | Sistema de préstamos     | ⬜     |
| 9    | Batch nocturno           | ⬜     |
| 10   | Motor de auditoría       | ⬜     |
| 11   | Reporting                | ⬜     |
| 12   | API REST completa        | ⬜     |
| 13   | Frontend React completo  | ⬜     |
| 14   | Testing                  | ⬜     |
| 15   | Optimización empresarial | ⬜     |
| 16   | Simulación de producción | ⬜     |

La documentación detallada de cada fase está en [`/docs`](docs/).
