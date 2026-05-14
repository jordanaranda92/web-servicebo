# Implementation Report: Eliminar pedidos/Drive del Dashboard

- **Fecha:** 2026-05-11
- **Identificador:** remove-dashboard-orders
- **Fuente:** Continuación de
  docs/implementation-reports/2026-05-10-remove-google-drive-sheets.md
- **Estado:** Completed

## 1) Resumen

Se eliminó toda la infraestructura de pedidos/Google Drive del dashboard. La
causa raíz era que `DashboardCubit` seguía registrado en DI e invocado desde
`home_page.dart`, provocando el warning
`[WARNING] Dashboard: Drive backend removed, returning empty stats`. Se removió
el cubit, su repositorio stub, el use case, las entidades, el widget de error,
las claves i18n huérfanas y los tests asociados.

## 2) Alcance ejecutado

- ✅ DashboardCubit eliminado del home_page.dart
- ✅ ComparisonCard limpiado de parámetros de pedidos (`ordersDiff`,
  `isLoadingOrders`)
- ✅ 7 ficheros de infraestructura eliminados
- ✅ DI limpiado en home_module.dart
- ✅ 2 ficheros de test eliminados
- ✅ 8 claves i18n huérfanas eliminadas del ARB + regeneración l10n

## 3) Artefactos tocados

### Creados

- (ninguno)

### Modificados

- `lib/features/home/presentation/pages/home_page.dart` — Removido
  DashboardCubit, stat card de pedidos, parámetros de orders en ComparisonCards
- `lib/features/home/presentation/widgets/comparison_card.dart` — Removidos
  `ordersDiff`, `isLoadingOrders`, fila de métrica de pedidos
- `lib/app/di/modules/home_module.dart` — Removidas registraciones de
  DashboardRepository, GetDashboardStats, DashboardCubit
- `lib/app/localization/l10n/app_es.arb` — Removidas 8 claves huérfanas
  (dashboardClients, dashboardErrorTitle, dashboardErrorMessage,
  dashboardRetry + sus @-metadata)
- `lib/app/localization/l10n/app_localizations.dart` — Regenerado
- `lib/app/localization/l10n/app_localizations_es.dart` — Regenerado

### Retirados o reemplazados

- `lib/features/home/presentation/bloc/dashboard_cubit.dart`
- `lib/features/home/presentation/bloc/dashboard_state.dart`
- `lib/features/home/data/repositories/dashboard_repository_impl.dart`
- `lib/features/home/domain/repositories/dashboard_repository.dart`
- `lib/features/home/domain/usecases/get_dashboard_stats.dart`
- `lib/features/home/domain/entities/dashboard_stats.dart`
- `lib/features/home/presentation/widgets/dashboard_error.dart`
- `test/features/home/presentation/bloc/dashboard_cubit_test.dart`
- `test/features/home/data/repositories/dashboard_repository_impl_test.dart`

## 4) Validación ejecutada

| Validación           | Resultado                 |
| -------------------- | ------------------------- |
| `dart analyze lib/`  | ✅ No issues found        |
| `dart analyze test/` | ✅ No issues found        |
| `flutter test`       | ✅ 35 tests passed        |
| `flutter gen-l10n`   | ✅ Regenerado sin errores |

## 5) Desviaciones respecto al análisis técnico

No había análisis técnico formal para esta iteración. La implementación original
(2026-05-10) dejó el stub `DashboardRepositoryImpl` y el `DashboardCubit`
activos en DI y UI. Esta sesión completa la eliminación que quedó pendiente.

## 6) Riesgos, incidencias y pendientes

- Sin riesgos detectados
- Sin incidencias durante la implementación
- La clave i18n `dashboardClientsLabel` se verificó que ya fue eliminada en la
  sesión anterior

## 7) Resultado final

- Estado final: ✅ Completado
- El warning `[WARNING] Dashboard: Drive backend removed, returning empty stats`
  ya no aparecerá
- El dashboard muestra únicamente las métricas de FacturaDirecta (facturas y
  total facturado)
- Siguiente paso recomendado: validación manual en app
