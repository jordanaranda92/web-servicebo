# Implementation Report: Eliminación completa de Albaranes

- **Fecha:** 2026-05-10
- **Identificador:** remove-delivery-notes
- **Plan técnico:** docs/technical-analysis/2026-05-10-remove-delivery-notes.md
- **Estado:** Completed

## 1) Resumen

Se ha eliminado por completo la funcionalidad de Albaranes (delivery notes) de
la aplicación Servicebo. Se eliminaron 10 archivos, se modificaron 15 archivos y
se regeneraron los archivos de localización. La aplicación compila sin errores,
los 58 tests existentes pasan y no quedan referencias residuales a delivery
notes en el código fuente.

## 2) Alcance ejecutado

- Feature `delivery_notes` eliminada completamente (9 archivos)
- Módulo DI eliminado y registro quitado de `injection.dart`
- 3 métodos de albaranes eliminados de `FacturaDirectaApiDataSource` (interfaz e
  impl)
- Método `_post` huérfano eliminado de la implementación del datasource
- `FdCountersCubit` y `FdCountersState` refactorizados sin dependencia de
  delivery notes
- `ComparisonCard` simplificada (sin fila de albaranes)
- `HomePage` reindexada y sin tarjeta de albaranes
- Menú lateral reducido de 9 a 8 ítems, separadores ajustados
- `SideMenuShell` reindexada (Facturas=6, Ajustes=7)
- `SideMenuCubit._maxIndex` de 8 a 7
- `OrdersTable`, `OrdersTableToolbar`, `OrdersTodayPage` sin callback
  `onGenerateDeliveryNotes`
- ~20 claves i18n eliminadas del ARB, localización regenerada

## 3) Artefactos tocados

### Creados

_Ninguno_

### Modificados

- `lib/app/di/injection.dart`
- `lib/app/di/modules/home_module.dart`
- `lib/core/data/datasources/factura_directa_api_data_source.dart`
- `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`
- `lib/features/home/presentation/bloc/side_menu_cubit.dart`
- `lib/features/home/presentation/bloc/fd_counters_cubit.dart`
- `lib/features/home/presentation/bloc/fd_counters_state.dart`
- `lib/features/home/presentation/pages/side_menu_shell.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/home/presentation/widgets/side_menu.dart`
- `lib/features/home/presentation/widgets/comparison_card.dart`
- `lib/features/orders_today/presentation/widgets/orders_table.dart`
- `lib/features/orders_today/presentation/widgets/orders_table_toolbar.dart`
- `lib/features/orders_today/presentation/pages/orders_today_page.dart`
- `lib/app/localization/l10n/app_es.arb`
- `lib/app/localization/l10n/app_localizations.dart` (regenerado)
- `lib/app/localization/l10n/app_localizations_es.dart` (regenerado)

### Retirados o reemplazados

- `lib/features/delivery_notes/` (carpeta completa — 9 archivos)
- `lib/app/di/modules/delivery_notes_module.dart`

## 4) Validación ejecutada

| Validación                                                   | Resultado                                                       |
| ------------------------------------------------------------ | --------------------------------------------------------------- |
| `flutter analyze`                                            | 2 `info` preexistentes (no relacionados). 0 errores, 0 warnings |
| `flutter test`                                               | 58 tests passed, 0 failures                                     |
| `flutter gen-l10n`                                           | Regeneración limpia                                             |
| `grep -ri "delivery_notes\|DeliveryNote\|deliveryNote" lib/` | 0 coincidencias                                                 |

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** Se eliminó el método privado `_post` de
  `FacturaDirectaApiDataSourceImpl` porque quedó sin uso tras eliminar
  `createDeliveryNote` (era su único consumidor). `flutter analyze` lo reportaba
  como `unused_element`.
- **Justificación:** Eliminar código muerto es coherente con el objetivo de
  limpieza.
- **Impacto:** Ninguno negativo. Si en el futuro se necesita un POST, se
  recreará.

## 6) Riesgos, incidencias y pendientes

- **Riesgos detectados:** Ninguno.
- **Incidencias:** Ninguna.
- **Pendientes:** Ninguno.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: verificación manual de la app (navegación de los 8
  ítems del menú, dashboard sin albaranes, toolbar de Pedidos Hoy sin "Generar
  albarán")
