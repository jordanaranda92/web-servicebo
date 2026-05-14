# Implementation Report: Carga unificada y búsqueda multi-campo en pantalla de clientes

- **Fecha:** 2026-05-11
- **Identificador:** clients-unified-load-and-search
- **Plan técnico:**
  docs/technical-analysis/2026-05-11-clients-unified-load-and-search.md
- **Estado:** Completed

## 1) Resumen

Se implementó la carga unificada de la tabla de clientes y la búsqueda
multi-campo según el plan técnico. La tabla ahora espera a que tanto los datos
de Firestore como los NIF/CIF de la API de Factura Directa estén disponibles
antes de renderizarse. El buscador filtra por NIF/CIF, Nombre y Nombre Factura
Directa simultáneamente.

## 2) Alcance ejecutado

- Todas las partes del plan se implementaron completamente.
- No hay partes pendientes.

## 3) Artefactos tocados

### Creados

- Ninguno

### Modificados

- `lib/features/clients/presentation/bloc/clients_state.dart` — Añadido campo
  `fiscalIdsByUuid` a `ClientsLoaded` con valor por defecto vacío, incluido en
  `props`.
- `lib/features/clients/presentation/bloc/clients_cubit.dart` — Añadida
  dependencia `GetFdFiscalIds`; coordinación paralela stream+future con buffer;
  métodos `_loadFiscalIds()`, `reloadFiscalIds()`, `_emitLoaded()`; filtro
  multi-campo en `_applyFilter()`.
- `lib/features/clients/presentation/pages/clients_page.dart` — Eliminados
  `_getFdFiscalIds`, `_fiscalIdsByUuid`, `_loadFiscalIds()` y sus imports;
  `_buildRow` recibe `fiscalIdsByUuid` desde el state del BLoC; `_syncFromFd`
  llama a `reloadFiscalIds()` tras sync exitoso.
- `lib/app/di/modules/clients_module.dart` — Añadido 6.º parámetro `sl()` (que
  resuelve `GetFdFiscalIds`) al factory de `ClientsCubit`.

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- **Análisis estático (`dart analyze`):** 0 issues en los 4 archivos
  modificados.
- **Errores del IDE:** 0 errores en los 4 archivos.
- **Revisión manual del código:** Verificada la coherencia del flujo
  stream+future+buffer, degradación graceful ante fallo de fiscal IDs, y
  corrección del filtro multi-campo.

## 5) Desviaciones respecto al análisis técnico

- Ninguna. La implementación sigue exactamente el plan técnico.

## 6) Riesgos, incidencias y pendientes

- **Tests unitarios:** No existen tests previos para `ClientsCubit`
  (`test/features/clients/` está vacío). Se recomienda crear tests para cubrir
  los escenarios definidos en el análisis técnico: coordinación de carga,
  degradación graceful, filtrado multi-campo y recarga post-sync.
- **Validación manual:** Pendiente verificar en la app que el spinner se muestra
  hasta que ambas fuentes completen, que no hay "salto" visual y que la búsqueda
  funciona con los tres campos.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en la app + creación de tests
  unitarios para `ClientsCubit`
