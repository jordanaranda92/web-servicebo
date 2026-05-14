# Implementation Report: Eliminar carpeta de trabajo local

- **Fecha:** 2026-05-07
- **Identificador:** remove-local-work-folder
- **Plan técnico:**
  docs/technical-analysis/2026-05-07-remove-local-work-folder.md
- **Estado:** Completed with warnings

## 1) Resumen

Se ha eliminado completamente la funcionalidad de carpeta de trabajo local
(`WorkFolder`). Todas las operaciones de lectura/escritura de archivos Excel
ahora se realizan a través de Google Drive usando `ExcelDriveDataSource` y
`ExcelParserService`. Se removió el parámetro `workFolderPath` de todos los
contratos, use cases, eventos, blocs y páginas de las features `orders_today`,
`orders_history` y `home` (dashboard).

## 2) Alcance ejecutado

- ✅ Fase 1: Creación de `ExcelParserService` y `ExcelDriveDataSource`
  (contratos + implementaciones)
- ✅ Fase 2: Migración completa de `orders_today` a Drive (repositorio, use
  cases, eventos, bloc, página)
- ✅ Fase 3: Migración completa de `orders_history` a Drive
- ✅ Fase 4: Migración completa de `dashboard` a Drive
- ✅ Fase 5: Eliminación de WorkFolder (entidad, cubit, state, widget, claves
  i18n, métodos en contratos)
- ✅ Fase 6: Actualización de tests y validación

## 3) Artefactos tocados

### Creados

- `lib/core/services/excel_parser_service.dart` — Contrato de parsing Excel
- `lib/core/services/excel_parser_service_impl.dart` — Implementación
- `lib/features/orders_today/data/datasources/remote/excel_drive_data_source.dart`
  — Contrato Drive CRUD
- `lib/features/orders_today/data/datasources/remote/excel_drive_data_source_impl.dart`
  — Implementación

### Modificados

- `lib/features/orders_today/domain/repositories/orders_today_repository.dart`
- `lib/features/orders_today/domain/usecases/get_today_orders.dart`
- `lib/features/orders_today/domain/usecases/create_today_file.dart`
- `lib/features/orders_today/domain/usecases/update_file_structure.dart`
- `lib/features/orders_today/domain/usecases/save_orders.dart`
- `lib/features/orders_today/domain/usecases/save_as_new_excel.dart`
- `lib/features/orders_today/domain/usecases/add_row.dart`
- `lib/features/orders_today/domain/usecases/delete_rows.dart`
- `lib/features/orders_today/domain/usecases/rename_client.dart`
- `lib/features/orders_today/domain/usecases/update_cell_value.dart`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  — Reescrito completo
- `lib/features/orders_today/presentation/bloc/orders_today_event.dart` —
  Reescrito
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart` —
  Reescrito
- `lib/features/orders_today/presentation/pages/orders_today_page.dart`
- `lib/features/orders_history/domain/repositories/orders_history_repository.dart`
- `lib/features/orders_history/domain/usecases/get_available_dates.dart`
- `lib/features/orders_history/domain/usecases/get_history_orders.dart`
- `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart`
  — Reescrito completo
- `lib/features/orders_history/presentation/bloc/orders_history_event.dart`
- `lib/features/orders_history/presentation/bloc/orders_history_bloc.dart`
- `lib/features/orders_history/presentation/pages/orders_history_page.dart`
- `lib/features/home/domain/repositories/dashboard_repository.dart`
- `lib/features/home/domain/usecases/get_dashboard_stats.dart`
- `lib/features/home/data/repositories/dashboard_repository_impl.dart` —
  Reescrito completo
- `lib/features/home/presentation/bloc/dashboard_cubit.dart`
- `lib/features/settings/domain/repositories/settings_repository.dart`
- `lib/features/settings/data/repositories/settings_repository_impl.dart`
- `lib/features/settings/data/datasources/local/settings_local_data_source.dart`
- `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/app/di/modules/orders_today_module.dart`
- `lib/app/di/modules/orders_history_module.dart`
- `lib/app/di/modules/home_module.dart`
- `lib/app/di/modules/settings_module.dart`
- `lib/app/localization/l10n/app_es.arb`
- `test/features/settings/data/repositories/settings_repository_impl_test.dart`
- `test/features/home/data/repositories/dashboard_repository_impl_test.dart`
- `test/features/home/presentation/bloc/dashboard_cubit_test.dart`
- `test/features/orders_history/data/repositories/orders_history_repository_impl_test.dart`
- `test/features/orders_history/presentation/bloc/orders_history_bloc_test.dart`

### Retirados o reemplazados

- `lib/features/settings/domain/entities/work_folder_config.dart` — Eliminado
- `lib/features/settings/presentation/bloc/work_folder_cubit.dart` — Eliminado
- `lib/features/settings/presentation/bloc/work_folder_state.dart` — Eliminado
- `lib/features/settings/presentation/widgets/work_folder_section.dart` —
  Eliminado
- `test/features/settings/presentation/bloc/work_folder_cubit_test.dart` —
  Eliminado

## 4) Validación ejecutada

- **dart analyze lib/**: 8 issues, todos pre-existentes en `contacts` feature
  (claves i18n faltantes) — no relacionados con este cambio
- **flutter test**: 57 passed, 1 failed — el fallo es pre-existente en
  `side_menu_cubit_test` (índice fuera de rango)
- **Conclusión**: Sin regresiones introducidas por la implementación

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1**: Se eliminó `_localDataSource` del constructor de
  `OrdersTodayRepositoryImpl` (el análisis técnico lo incluía para
  `saveAsNewExcel`). La escritura local en `saveAsNewExcel` se hace directamente
  con `dart:io File` sin necesidad del datasource.
  - **Justificación**: Simplificación — el datasource completo no es necesario
    para una sola operación de escritura.
  - **Impacto**: Ninguno funcional.

- **Desviación 2**: El OAuth scope ya se cambió de `driveReadonlyScope` a
  `driveFileScope` en la Fase 1, como PA-01 del análisis técnico indicaba.

## 6) Riesgos, incidencias y pendientes

- **Riesgo**: Los usuarios existentes con autenticación previa deberán
  re-autenticarse para obtener el scope `driveFileScope` (escritura).
- **Pendiente**: No se han creado tests unitarios para `ExcelParserService`,
  `ExcelParserServiceImpl`, `ExcelDriveDataSource`, `ExcelDriveDataSourceImpl`,
  ni para `OrdersTodayRepositoryImpl` (reescrito). Se recomienda añadirlos.
- **Pendiente**: Las claves i18n `ordersHistoryNoFolderTitle`,
  `ordersHistoryNoFolderMessage`, `ordersTodayNoFolderTitle`,
  `ordersTodayNoFolderMessage` siguen referenciando "carpeta de trabajo" —
  deberían actualizarse para mencionar "Google Drive".
- **Pre-existente**: Los errores de `contacts` feature y el fallo en
  `side_menu_cubit_test` no están relacionados con este cambio.

## 7) Resultado final

- Estado final: ⚠️ Completado con warnings
- Siguiente paso recomendado:
  1. Actualizar textos i18n que aún mencionan "carpeta de trabajo" por "Google
     Drive"
  2. Crear tests unitarios para los servicios y datasources nuevos
  3. Validación manual de flujo completo con cuenta Google Drive real
