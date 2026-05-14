# Implementation Report: Contadores de Albaranes y Facturas en el Dashboard

- **Fecha:** 2026-05-08
- **Identificador:** dashboard-fd-counters
- **Plan técnico:** docs/technical-analysis/2026-05-08-dashboard-fd-counters.md
- **Estado:** Completed

## 1) Resumen

Se han implementado dos nuevos contadores ("Albaranes hoy" y "Facturas hoy") en
la sección "Resumen del día" del dashboard. Los contadores se obtienen de
FacturaDirecta de forma independiente al dashboard local, con gestión de estados
(loading, sin configurar, error, cargado). Las cards son interactivas y navegan
a las vistas correspondientes al pulsarlas.

## 2) Alcance ejecutado

- Creación del `FdCountersCubit` y `FdCountersState` con 5 estados sealed.
- Registro del cubit como factory en el módulo DI de home.
- Ampliación del widget `StatCard` con parámetro `onTap` opcional.
- Integración en `home_page.dart` con `MultiBlocProvider`, ciclo de vida
  completo (init, dispose, recarga al volver al home) y renderizado de las 2
  cards de FD en el grid de stats.
- Corrección del `_kSettingsIndex` de 7 a 8 para reflejar el índice real de
  Settings en el menú.
- Adición de 4 claves i18n al ARB.
- Validación con `flutter gen-l10n` y `flutter analyze`: 0 errores, 0 warnings.

## 3) Artefactos tocados

### Creados

- `lib/features/home/presentation/bloc/fd_counters_state.dart`
- `lib/features/home/presentation/bloc/fd_counters_cubit.dart`

### Modificados

- `lib/features/home/presentation/widgets/stat_card.dart` — añadido parámetro
  `VoidCallback? onTap`, envuelve en `Material`+`InkWell` cuando onTap no es
  null.
- `lib/features/home/presentation/pages/home_page.dart` — imports de
  `FdCountersCubit`/`FdCountersState`, constantes `_kDeliveryNotesIndex` y
  `_kInvoicesIndex`, instanciación/cierre de `_fdCubit`, `MultiBlocProvider`,
  método `_buildFdCounterCards`, corrección de `_kSettingsIndex` a 8.
- `lib/app/di/modules/home_module.dart` — import y registro de `FdCountersCubit`
  como `registerFactory`.
- `lib/app/localization/l10n/app_es.arb` — 4 claves nuevas:
  `dashboardDeliveryNotes`, `dashboardInvoices`, `dashboardFdNotConfigured`,
  `dashboardFdError`.

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- `flutter gen-l10n`: exitoso, sin errores.
- `flutter analyze lib/features/home/ lib/app/di/modules/home_module.dart`: **0
  issues found**.
- Corrección intermedia: el primer intento usaba `Future.wait` que perdía la
  información de tipo (`Equatable` en vez de `DeliveryNote`/`Invoice`).
  Corregido usando llamadas secuenciales que preservan los tipos.

## 5) Desviaciones respecto al análisis técnico

- **Llamadas secuenciales en vez de `Future.wait`:** El análisis técnico sugería
  llamar en paralelo con `Future.wait`. Dart pierde los tipos específicos al
  combinar `Either<Failure, List<DeliveryNote>>` y
  `Either<Failure, List<Invoice>>` en un solo `Future.wait` (resuelve a
  `Equatable`). Se optó por llamadas secuenciales (`await` independientes) que
  preservan los tipos. Impacto: latencia ligeramente mayor (secuencial vs
  paralelo), pero correctitud de tipos. Alternativa futura: usar variables
  tipadas explícitas con `Future.wait` y cast.
- **`_kSettingsIndex` corregido de 7 a 8:** El análisis técnico mantenía el
  valor 7 del código existente, pero el menú real ya tiene 9 ítems (0-8) con
  Settings en índice 8. El valor previo (7) era incorrecto y se ha corregido.
  Impacto: corrección de un bug latente.

## 6) Riesgos, incidencias y pendientes

- **Riesgo bajo:** Si el formato de fecha de la API de FD incluye hora
  (`"2026-05-08T10:30:00"`), el filtro `startsWith(todayStr)` lo maneja
  correctamente.
- **Pendiente:** Tests unitarios para `FdCountersCubit` (no incluidos en el
  alcance de este paso de implementación).
- **Pendiente:** Validación manual en entorno real con FacturaDirecta
  configurada para confirmar que los contadores se muestran correctamente.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en la aplicación y,
  opcionalmente, creación de tests unitarios para `FdCountersCubit`.
