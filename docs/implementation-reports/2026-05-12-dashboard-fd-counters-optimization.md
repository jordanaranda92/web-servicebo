# Implementation Report: Optimización de consultas de facturas en el Dashboard

- **Fecha:** 2026-05-12
- **Identificador:** dashboard-fd-counters-optimization
- **Plan técnico:**
  docs/technical-analysis/2026-05-12-dashboard-fd-counters-optimization.md
- **Estado:** Completed (v2 — hotfix post-validación manual)

## 1) Resumen

Se ha implementado la optimización de consultas de facturas en el dashboard. El
`FdCountersCubit` ya no descarga 500 facturas sin filtro; ahora realiza 2
peticiones paralelas filtradas por rango de fechas (mes actual y mes anterior
equivalente) utilizando el nuevo use case `GetInvoicesByDateRange`.

**v2 — Hotfix (2026-05-12):** Tras validación manual se detectaron 2 bugs:

1. La API de FD devolvía HTTP 400 porque `limit=5000` excede el máximo permitido
   (500). Corregido a `limit=500`.
2. Overflow de 6px en las cards del dashboard cuando se muestra el estado de
   error/no configurado (subtitle). Corregido reemplazando `Spacer()` por
   `Flexible(child: SizedBox.shrink())` en `StatCard`.

## 2) Alcance ejecutado

- Todas las partes del plan técnico se han implementado completamente.
- Se han ejecutado los 7 pasos definidos: datasource → repository → use case →
  DI invoices → cubit → DI home → tests.
- No ha quedado ninguna parte sin completar.

## 3) Artefactos tocados

### Creados

- `lib/features/invoices/domain/usecases/get_invoices_by_date_range.dart` — Use
  case con `DateRangeParams(minDate, maxDate)`.
- `test/features/home/presentation/bloc/fd_counters_cubit_test.dart` — 6 tests
  unitarios para el cubit refactorizado.

### Modificados

- `lib/core/data/datasources/factura_directa_api_data_source.dart` — Añadido
  método abstracto `getInvoicesByDateRange`.
- `lib/core/data/datasources/factura_directa_api_data_source_impl.dart` —
  Implementación de `getInvoicesByDateRange` con query params `minDate`,
  `maxDate`, `related=state`, `limit=500`.
- `lib/features/invoices/domain/repositories/invoices_repository.dart` — Añadido
  método abstracto `getInvoicesByDateRange`.
- `lib/features/invoices/data/repositories/invoices_repository_impl.dart` —
  Implementación de `getInvoicesByDateRange`.
- `lib/features/home/presentation/bloc/fd_counters_cubit.dart` — Cambiada
  dependencia de `GetInvoices` a `GetInvoicesByDateRange`. Refactorizado
  `load()` para calcular rangos y hacer 2 llamadas paralelas con `Future.wait`.
  Eliminada duplicación de cálculo de rangos.
- `lib/app/di/modules/invoices_module.dart` — Registrado
  `GetInvoicesByDateRange(sl())`.
- `lib/app/di/modules/home_module.dart` — Actualizada inyección del cubit:
  `getInvoicesByDateRange: sl()`.
- `lib/features/home/presentation/widgets/stat_card.dart` — Reemplazado
  `Spacer()` por `Flexible(child: SizedBox.shrink())` para evitar overflow
  cuando se muestra subtitle (estado error/no configurado).

### Retirados o reemplazados

- Ninguno. `GetInvoices` se mantiene intacto para `InvoicesPage`.

## 4) Validación ejecutada

### Automática

- **Errores de compilación:** 0 errores en los 8 archivos afectados.
- **Tests nuevos del cubit (6 tests):** Todos pasan.
  - Estado inicial es `FdCountersInitial`.
  - Emite `[Loading, Loaded]` con contadores correctos al recibir datos.
  - Emite `[Loading, Error]` si la primera llamada falla.
  - Emite `[Loading, Error]` si la segunda llamada falla.
  - Emite `[Loading, Loaded]` con contadores a 0 si no hay facturas.
  - Verifica que se hacen exactamente 2 llamadas al use case.
- **Suite completa (28 tests):** Todos pasan. 22 preexistentes + 6 nuevos. Sin
  regresiones. (Revalidado tras hotfix v2: 28 tests OK.)

### Manual pendiente

- Verificar en la app que el dashboard muestra contadores y comparativas
  correctamente (ahora con `limit=500` y sin overflow en cards).

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** El parámetro `limit` en `getInvoicesByDateRange` se definió
  inicialmente como `5000` (siguiendo el análisis técnico que usaba ese valor
  como margen). Sin embargo, la OpenAPI de FD especifica un máximo de 500 para
  el parámetro `limit`. Corregido a `500`.
  - **Justificación:** Restricción de la API no documentada en el análisis
    técnico.
  - **Impacto:** Bajo. Para el dashboard (contadores de 1-2 meses), 500 facturas
    es más que suficiente. Si alguna empresa emite >500 facturas/mes, los
    contadores serían aproximados.

- **Desviación 2:** Se modificó `stat_card.dart` (no previsto en el plan
  técnico) para corregir overflow visual en cards con subtitle.
  - **Justificación:** Bug de layout descubierto durante validación manual.
  - **Impacto:** Ninguno funcional. Mejora visual en estados error/no
    configurado.

## 6) Riesgos, incidencias y pendientes

- **Incidencia resuelta (v2):** FD API devolvía 400 por `limit=5000`. Causa
  raíz: la OpenAPI especifica máximo 500. Resuelto cambiando a 500.
- **Incidencia resuelta (v2):** Overflow de ~6px en `StatCard` con subtitle.
  Causa raíz: `Spacer()` (FlexFit.tight) no toleraba contenido más alto que el
  constraint. Resuelto con `Flexible(child: SizedBox.shrink())` (FlexFit.loose).
- **Riesgo menor vigente:** Si una empresa emite >500 facturas en un mes, los
  contadores del dashboard serían aproximados (capped a 500). Impacto bajo para
  el uso actual de la app.
- **Pendiente:** Validación manual en la app con datos reales.

## 7) Resultado final

- Estado final: ✅ Completado (v2 — tras hotfix)
- Siguiente paso recomendado: validación manual en la app.
