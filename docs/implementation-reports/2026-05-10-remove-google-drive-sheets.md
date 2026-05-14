# Implementation Report: Eliminar integración Google Drive y Google Sheets

- **Fecha:** 2026-05-10
- **Identificador:** remove-google-drive-sheets
- **Plan técnico:**
  docs/technical-analysis/2026-05-10-remove-google-drive-sheets.md
- **Estado:** Completed

## 1) Resumen

- Se ha eliminado por completo toda integración con Google Drive y Google Sheets
  del proyecto
- Se han borrado 20 archivos, refactorizado ~25 archivos y eliminado 96 claves
  i18n
- Se han eliminado 3 dependencias de pubspec.yaml (googleapis, googleapis_auth,
  url_launcher)
- `dart analyze` pasa sin errores en lib/ y test/
- Los 39 tests pasan correctamente

## 2) Alcance ejecutado

- ✅ Eliminación de dependencias pubspec (googleapis, googleapis_auth,
  url_launcher)
- ✅ Eliminación de servicios core (GoogleAuthService, GoogleSheetsDataSource)
- ✅ Limpieza de failure.dart (googleDriveMissing, Auth*Failure)
- ✅ Eliminación de archivos settings/Drive (datasources, entities, cubit,
  widgets)
- ✅ Refactorización de settings (local datasource, repository, presentation)
- ✅ Eliminación de archivos orders_today/Drive (ExcelDrive, OrdersSheet,
  OrderSheetData)
- ✅ Limpieza de OrderSheet entity (spreadsheetId, modifiedTime)
- ✅ Limpieza de orders_table_footer (LastModifiedLabel)
- ✅ Conversión de OrdersHistoryRepositoryImpl a stub
- ✅ Conversión de DashboardRepositoryImpl a stub
- ✅ Limpieza de DashboardCubit (eliminación de SettingsRepository dependency y
  DashboardNoFolder)
- ✅ Limpieza de home_page (eliminación de DashboardNoFolder case)
- ✅ Limpieza de orders_history_page (eliminación de Drive config check)
- ✅ Limpieza de módulos DI (settings, orders_today, orders_history, home, core)
- ✅ Limpieza de AppConfig (googleOAuthClientId, googleOAuthClientSecret,
  modifiedTimePollInterval)
- ✅ Limpieza de i18n (96 claves eliminadas) + regeneración
- ✅ Actualización de tests (4 archivos)

## 3) Artefactos tocados

### Creados

- Ninguno

### Modificados

- `pubspec.yaml` — eliminadas 3 dependencias
- `lib/core/error/failure.dart` — eliminados googleDriveMissing, Auth*Failure
- `lib/features/settings/data/datasources/local/settings_local_data_source.dart`
- `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`
- `lib/features/settings/domain/repositories/settings_repository.dart`
- `lib/features/settings/data/repositories/settings_repository_impl.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/features/orders_today/domain/entities/order_sheet.dart`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
- `lib/features/orders_today/presentation/widgets/orders_table.dart`
- `lib/features/orders_today/presentation/widgets/orders_table_footer.dart`
- `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart`
  — convertido a stub
- `lib/features/orders_history/presentation/pages/orders_history_page.dart`
- `lib/features/home/data/repositories/dashboard_repository_impl.dart` —
  convertido a stub
- `lib/features/home/presentation/bloc/dashboard_cubit.dart`
- `lib/features/home/presentation/bloc/dashboard_state.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/app/di/modules/settings_module.dart`
- `lib/app/di/modules/orders_today_module.dart`
- `lib/app/di/modules/orders_history_module.dart`
- `lib/app/di/modules/home_module.dart`
- `lib/app/di/modules/core_module.dart`
- `lib/app/config/app_config.dart`
- `lib/app/config/environments/local_config.dart`
- `lib/app/config/environments/pro_config.dart`
- `lib/app/localization/l10n/app_es.arb` — 96 claves eliminadas
- `test/features/settings/data/repositories/settings_repository_impl_test.dart`
- `test/features/home/presentation/bloc/dashboard_cubit_test.dart`
- `test/features/orders_history/data/repositories/orders_history_repository_impl_test.dart`
- `test/features/home/data/repositories/dashboard_repository_impl_test.dart`

### Eliminados

- `lib/core/services/google_auth_service.dart`
- `lib/core/services/google_auth_service_impl.dart`
- `lib/core/data/datasources/google_sheets_data_source.dart`
- `lib/core/data/datasources/google_sheets_data_source_impl.dart`
- `lib/features/settings/data/datasources/remote/google_drive_remote_data_source.dart`
- `lib/features/settings/data/datasources/remote/google_drive_remote_data_source_impl.dart`
- `lib/features/settings/domain/entities/google_drive_config.dart`
- `lib/features/settings/domain/entities/drive_folder.dart`
- `lib/features/settings/domain/entities/drive_folder_content.dart`
- `lib/features/settings/presentation/bloc/google_drive_cubit.dart`
- `lib/features/settings/presentation/bloc/google_drive_state.dart`
- `lib/features/settings/presentation/widgets/google_drive_section.dart`
- `lib/features/settings/presentation/widgets/drive_folder_picker.dart`
- `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source.dart`
- `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source_impl.dart`
- `lib/features/orders_today/data/datasources/remote/excel_drive_data_source.dart`
- `lib/features/orders_today/data/datasources/remote/excel_drive_data_source_impl.dart`
- `lib/features/orders_today/data/dto/order_sheet_data.dart`
- `lib/features/home/presentation/widgets/spreadsheet_picker_dialog.dart`
- `lib/features/home/presentation/widgets/dashboard_no_folder.dart`

## 4) Validación ejecutada

- `dart analyze lib/` → No issues found
- `dart analyze test/` → No issues found
- `flutter test` → 39 tests passed
- `grep` exhaustivo de referencias residuales → limpio

## 5) Desviaciones respecto al análisis técnico

- **SettingsRepositoryImpl** mantiene 4 parámetros (`_localDataSource`,
  `_remoteDataSource`, `_logger`, `_appConfig`) en lugar de 3, porque
  `_appConfig` es necesario para `getFacturaDirectaConfig()`. El plan técnico
  indicaba 3 parámetros.
- **ExcelParserService** y su implementación quedan en `lib/core/services/` pero
  sin registro en DI ni uso activo. No se eliminaron porque podrían usarse en
  futura migración a Firestore.
- **`ordersHistoryGoToSettings`** — clave i18n conservada (sigue siendo usada
  por otros widgets de empty state).

## 6) Riesgos, incidencias y pendientes

- **TODO:** `OrdersHistoryRepositoryImpl` y `DashboardRepositoryImpl` son stubs
  que retornan empty/error. Necesitan implementación Firestore.
- **ExcelParserService** queda como código muerto — considerar eliminar cuando
  se confirme que no se necesita.
- Las credenciales OAuth (client ID/secret) que estaban en los config files de
  entorno han sido eliminadas.

## 7) Resultado final

- ✅ Completado
- Siguiente paso recomendado: implementar backends Firestore para Dashboard y
  OrdersHistory
