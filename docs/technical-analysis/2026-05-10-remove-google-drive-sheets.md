# Technical Analysis: Eliminar integración con Google Drive y Google Sheets

- **Fecha:** 2026-05-10
- **Identificador:** remove-google-drive-sheets
- **Fuente:** docs/functional-analysis/2026-05-10-remove-google-drive-sheets.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Eliminación total de toda la integración con Google Drive y Google Sheets:
  servicios OAuth, datasources, entidades, cubits, widgets, cadenas i18n,
  dependencias de paquetes, credenciales y registros DI.
- Refactorización de componentes compartidos (`SettingsRepository`,
  `DashboardCubit`, `OrdersHistoryPage`, etc.) para eliminar únicamente la parte
  de Drive sin romper funcionalidad existente de Firestore/FD.
- Áreas impactadas: `core/services`, `core/data/datasources`, `core/error`,
  `features/settings`, `features/orders_today`, `features/orders_history`,
  `features/home`, `app/di`, `app/config`, `app/localization`.
- Riesgo general: **medio** — la eliminación es amplia (~30 archivos) pero
  mecánica; el principal riesgo es olvidar alguna referencia que impida
  compilar.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt, fpdart.
- Cada feature tiene `data/`, `domain/`, `presentation/`.
- DI modular en `lib/app/di/modules/`.

### Módulos afectados

- **`core/services/`** — `GoogleAuthService` + impl (OAuth 2.0 con
  `googleapis_auth`)
- **`core/data/datasources/`** — `GoogleSheetsDataSource` + impl (wrapper
  genérico de Sheets API)
- **`core/error/failure.dart`** — `PrerequisiteFailure.googleDriveMissing`,
  `AuthCancelledFailure`, `AuthFailure`, `AuthExpiredFailure`
- **`features/settings/`** — DataSources remotos/locales, repository, entidades
  de dominio, cubit, states, widgets de Drive
- **`features/orders_today/`** — `OrdersSheetDataSource`,
  `ExcelDriveDataSource` + impls, `OrderSheetData` DTO, campo `spreadsheetId` en
  `OrderSheet`
- **`features/orders_history/`** — Repository que lee de Drive, page con chequeo
  de Drive
- **`features/home/`** — `DashboardRepositoryImpl` (lee de Drive),
  `DashboardCubit` (chequea Drive), `DashboardNoFolder` widget,
  `SpreadsheetPickerDialog`
- **`app/di/modules/`** — Registros de GoogleAuthService,
  GoogleDriveRemoteDataSource, GoogleDriveCubit, ExcelDriveDataSource,
  OrdersSheetDataSource
- **`app/config/`** — `googleOAuthClientId`, `googleOAuthClientSecret`,
  `modifiedTimePollInterval`
- **`app/localization/`** — ~60+ claves i18n de Drive/Sheets en `.arb`

### Dependencias externas

- `googleapis: ^14.0.0` — API client para Drive/Sheets
- `googleapis_auth: ^2.0.0` — OAuth 2.0 flow
- `url_launcher` — usado SOLO por `GoogleAuthServiceImpl` para abrir OAuth
  consent; verificar si hay otros usos antes de eliminar

### Restricciones

- `SettingsRepository` y `SettingsLocalDataSource` son compartidos con
  FacturaDirecta y otras funcionalidades (page size, user name). Solo se
  eliminan los métodos de Drive.
- `OrdersTodayRepositoryImpl` ya usa Firestore exclusivamente — ya no depende de
  los datasources de Drive/Sheets.
- `OrdersHistoryRepositoryImpl` y `DashboardRepositoryImpl` dependen de
  `ExcelDriveDataSource`. Confirmado que los datos ya están en Firestore, por lo
  que estas dependencias se eliminan y los repos se reconectarán a Firestore
  (fuera de este scope) o quedarán como stubs si ya lo están.

## 3) Objetivo técnico

- **Qué debe cambiar:** Eliminar todo el grafo de dependencias de Google
  Drive/Sheets — desde paquetes hasta UI.
- **Resultado técnico:** Compilación limpia sin ninguna referencia a
  `googleapis`, `googleapis_auth`, `GoogleDrive`, `GoogleSheet`, `GoogleAuth`,
  `spreadsheetId`, ni credenciales OAuth.
- **Limitaciones:** No se implementa funcionalidad de reemplazo; se asume que
  Firestore ya cubre los casos de uso. No se modifica la lógica de Firestore
  existente.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Eliminación en capas, de más profundo a más superficial:

1. **Dependencias (pubspec)** — quitar `googleapis`, `googleapis_auth`. Evaluar
   `url_launcher`.
2. **Core services** — eliminar archivos completos de `GoogleAuthService`.
3. **Core datasources** — eliminar archivos completos de
   `GoogleSheetsDataSource`.
4. **Core error** — refactorizar `failure.dart`: quitar `googleDriveMissing` de
   `PrerequisiteFailure`, eliminar `AuthCancelledFailure`, `AuthFailure`,
   `AuthExpiredFailure`.
5. **Feature settings/data** — eliminar datasources remotos de Drive,
   refactorizar local datasource y repository.
6. **Feature settings/domain** — eliminar entidades de Drive y refactorizar
   `SettingsRepository`.
7. **Feature settings/presentation** — eliminar cubit, states, widgets de Drive;
   refactorizar `SettingsPage`.
8. **Feature orders_today/data** — eliminar datasources de Drive/Sheets,
   eliminar DTO `OrderSheetData`, quitar `spreadsheetId`/`modifiedTime` de
   `OrderSheet`.
9. **Feature orders_history** — refactorizar repository y page para eliminar
   dependencias de Drive.
10. **Feature home** — refactorizar `DashboardCubit`, eliminar
    `DashboardNoFolder` state/widget, eliminar `SpreadsheetPickerDialog`.
11. **DI modules** — limpiar registros en `settings_module`,
    `orders_today_module`, `orders_history_module`, `home_module`.
12. **App config** — quitar campos OAuth y `modifiedTimePollInterval`.
13. **i18n** — quitar claves del `.arb` fuente, regenerar archivos.
14. **Tests** — actualizar/eliminar tests afectados.

### Componentes / módulos / servicios afectados

Detallados en la sección 5 (Impacto por artefactos).

### Contratos e interfaces

**Interfaces que se eliminan completamente:**

- `GoogleAuthService` (abstract class)
- `GoogleSheetsDataSource` (abstract class)
- `GoogleDriveRemoteDataSource` (abstract class + `DriveFileInfo`)
- `OrdersSheetDataSource` (abstract class)
- `ExcelDriveDataSource` (abstract class)

**Interfaces que se refactorizan (quitar métodos de Drive):**

`SettingsRepository` — queda:

```dart
abstract class SettingsRepository {
  // FacturaDirecta
  Future<Either<Failure, FacturaDirectaConfig?>> getFacturaDirectaConfig();
  Future<Either<Failure, Unit>> saveFacturaDirectaConfig(FacturaDirectaConfig config);
  Future<Either<Failure, Unit>> clearFacturaDirectaConfig();
  Future<Either<Failure, bool>> verifyFacturaDirectaConnection(FacturaDirectaConfig config);
  // Page size
  int getPageSize();
  Future<Either<Failure, Unit>> savePageSize(int size);
  // User identity
  String getUserName();
  Future<Either<Failure, Unit>> saveUserName(String name);
}
```

`SettingsLocalDataSource` — queda:

```dart
abstract class SettingsLocalDataSource {
  // FacturaDirecta
  String? getFacturaDirectaCompanyId();
  Future<String?> getFacturaDirectaApiToken();
  Future<void> saveFacturaDirectaConfig({required String companyId, required String apiToken});
  Future<void> clearFacturaDirectaConfig();
  // Page size
  int getPageSize();
  Future<void> savePageSize(int size);
  // User identity
  String? getUserName();
  Future<void> saveUserName(String name);
}
```

**Entidad `OrderSheet` — quitar campos:**

- `spreadsheetId` (String?)
- `modifiedTime` (DateTime?)
- Quitar de constructor, `copyWith`, `props`

**Entidad `PrerequisiteFailure` — quitar `googleDriveMissing`:**

```dart
class PrerequisiteFailure extends Failure {
  final bool facturaDirectaMissing;
  PrerequisiteFailure({this.facturaDirectaMissing = false});
  @override
  List<Object> get props => [facturaDirectaMissing];
}
```

### Flujo de datos o de control

No se diseñan flujos nuevos. Se eliminan los flujos existentes de:

- OAuth sign-in → Drive API → Sheets API
- Settings: connect Drive → pick folder → verify → save config
- Dashboard/History: check drive config → read Excel from Drive → parse

### Gestión de errores y validaciones

- `AuthCancelledFailure`, `AuthFailure`, `AuthExpiredFailure`: se eliminan. Solo
  los usaba `GoogleAuthServiceImpl` y `GoogleDriveCubit`.
- `PrerequisiteFailure.googleDriveMissing`: se elimina el campo; la clase se
  simplifica a un solo campo (`facturaDirectaMissing`).

### Consideraciones de compatibilidad o migración

- No se necesita migración de datos. Las credenciales OAuth huérfanas en
  SharedPreferences/SecureStorage quedarán inactivas sin impacto.
- `url_launcher` se usa **solo** en `GoogleAuthServiceImpl`. Si no hay otros
  usos en el proyecto, la dependencia se puede eliminar. Si hay otros usos, se
  mantiene.

## 5) Impacto por artefactos

### Artefactos a eliminar (archivos completos)

| Artefacto                                                                                 | Propósito                                      |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `lib/core/services/google_auth_service.dart`                                              | Interfaz OAuth Google                          |
| `lib/core/services/google_auth_service_impl.dart`                                         | Implementación OAuth Google                    |
| `lib/core/data/datasources/google_sheets_data_source.dart`                                | Interfaz Sheets API wrapper                    |
| `lib/core/data/datasources/google_sheets_data_source_impl.dart`                           | Implementación Sheets API wrapper              |
| `lib/features/settings/data/datasources/remote/google_drive_remote_data_source.dart`      | Interfaz Drive datasource + `DriveFileInfo`    |
| `lib/features/settings/data/datasources/remote/google_drive_remote_data_source_impl.dart` | Implementación Drive datasource                |
| `lib/features/settings/domain/entities/google_drive_config.dart`                          | Entidad `GoogleDriveConfig`                    |
| `lib/features/settings/domain/entities/drive_folder.dart`                                 | Entidad `DriveFolder`                          |
| `lib/features/settings/domain/entities/drive_folder_content.dart`                         | Entidad `DriveFolderContent`                   |
| `lib/features/settings/presentation/bloc/google_drive_cubit.dart`                         | Cubit de Google Drive                          |
| `lib/features/settings/presentation/bloc/google_drive_state.dart`                         | Estados del cubit de Drive                     |
| `lib/features/settings/presentation/widgets/google_drive_section.dart`                    | Widget sección Drive en Settings               |
| `lib/features/settings/presentation/widgets/drive_folder_picker.dart`                     | Widget picker de carpetas Drive                |
| `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source.dart`         | Interfaz Sheets datasource de pedidos          |
| `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source_impl.dart`    | Implementación (~540 líneas)                   |
| `lib/features/orders_today/data/datasources/remote/excel_drive_data_source.dart`          | Interfaz Excel/Drive datasource                |
| `lib/features/orders_today/data/datasources/remote/excel_drive_data_source_impl.dart`     | Implementación Excel/Drive                     |
| `lib/features/orders_today/data/dto/order_sheet_data.dart`                                | DTO de datos de hoja (referencia Google Sheet) |
| `lib/features/home/presentation/widgets/spreadsheet_picker_dialog.dart`                   | Widget picker de spreadsheets                  |
| `lib/features/home/presentation/widgets/dashboard_no_folder.dart`                         | Widget "no folder" del dashboard               |

### Artefactos a modificar

| Artefacto                                                                                 | Cambio esperado                                                                                                                                                                                                                                                                                                                      |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `pubspec.yaml`                                                                            | Eliminar `googleapis`, `googleapis_auth`. Evaluar `url_launcher`.                                                                                                                                                                                                                                                                    |
| `lib/core/error/failure.dart`                                                             | Quitar `googleDriveMissing` de `PrerequisiteFailure`. Eliminar `AuthCancelledFailure`, `AuthFailure`, `AuthExpiredFailure`.                                                                                                                                                                                                          |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`            | Quitar todos los métodos `getGoogleDrive*`, `saveGoogleDrive*`, `clearGoogleDrive*`.                                                                                                                                                                                                                                                 |
| `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`       | Quitar constantes `_googleDrive*Key`, implementaciones de métodos Drive, sección "Google Drive" y "Google Drive - subfolder IDs".                                                                                                                                                                                                    |
| `lib/features/settings/domain/repositories/settings_repository.dart`                      | Quitar métodos `getGoogleDriveConfig`, `saveGoogleDriveConfig`, `clearGoogleDriveConfig`, `connectGoogleDrive`, `listDriveFolders`, `verifyDriveFolder`, `selectDriveFolder`. Quitar imports de entidades de Drive.                                                                                                                  |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`                   | Quitar imports de `googleapis`, `google_auth_service`, entidades de Drive, `google_drive_remote_data_source`. Quitar campos `_googleDriveDataSource`, `_authService`, `_appConfig` del constructor. Quitar todas las implementaciones de métodos de Drive (~180 líneas). Ajustar constructor del DI.                                 |
| `lib/features/settings/presentation/pages/settings_page.dart`                             | Quitar import/BlocProvider de `GoogleDriveCubit`, quitar `GoogleDriveSection()` del layout.                                                                                                                                                                                                                                          |
| `lib/features/orders_today/domain/entities/order_sheet.dart`                              | Quitar campos `spreadsheetId` y `modifiedTime`, quitar de constructor, `copyWith`, `props`.                                                                                                                                                                                                                                          |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`           | Quitar asignación de `spreadsheetId: doc.date` y `modifiedTime: doc.lastModifiedAt` en `_buildOrderSheet`.                                                                                                                                                                                                                           |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`                        | Quitar referencia a `widget.orderSheet.modifiedTime` y lógica de formateo de `modifiedTime`.                                                                                                                                                                                                                                         |
| `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart`       | Quitar dependencia de `ExcelDriveDataSource`, `SettingsLocalDataSource`, `_historicoFolderId`, `_ensureConfigured`. Toda la implementación actual lee de Drive → debe vaciarse o redirigir a Firestore (fuera de scope: dejar como stub que retorna error si no se ha migrado aún).                                                  |
| `lib/features/orders_history/presentation/pages/orders_history_page.dart`                 | Quitar lógica `_isDriveConfigured`, `_loadDriveConfig()`, import de `SettingsRepository`, bloque condicional de "no folder".                                                                                                                                                                                                         |
| `lib/features/home/data/repositories/dashboard_repository_impl.dart`                      | Quitar dependencia de `ExcelDriveDataSource`, `SettingsLocalDataSource` (Drive), `_historicoFolderId`. Toda la implementación actual lee de Drive → debe vaciarse o redirigir a Firestore.                                                                                                                                           |
| `lib/features/home/presentation/bloc/dashboard_cubit.dart`                                | Quitar chequeo `getGoogleDriveConfig()` y la emisión de `DashboardNoFolder`. Quitar dependencia de `SettingsRepository` si solo se usaba para Drive.                                                                                                                                                                                 |
| `lib/features/home/presentation/bloc/dashboard_state.dart`                                | Quitar clase `DashboardNoFolder`.                                                                                                                                                                                                                                                                                                    |
| `lib/features/home/presentation/pages/home_page.dart`                                     | Quitar import de `dashboard_no_folder.dart`, quitar case `DashboardNoFolder()` del switch.                                                                                                                                                                                                                                           |
| `lib/app/di/modules/settings_module.dart`                                                 | Quitar imports y registros de `GoogleAuthService`, `GoogleAuthServiceImpl`, `GoogleDriveRemoteDataSource`, `GoogleDriveRemoteDataSourceImpl`, `GoogleDriveCubit`. Ajustar parámetros del constructor de `SettingsRepositoryImpl` (de 6 a 3: `sl(), sl(), sl()`).                                                                     |
| `lib/app/di/modules/orders_today_module.dart`                                             | Quitar imports y registros de `ExcelDriveDataSource`, `ExcelDriveDataSourceImpl`, `OrdersSheetDataSource`, `OrdersSheetDataSourceImpl`. Quitar comentario "legacy Sheets".                                                                                                                                                           |
| `lib/app/di/modules/orders_history_module.dart`                                           | Ajustar parámetros del constructor de `OrdersHistoryRepositoryImpl` (quitar las dependencias de Drive).                                                                                                                                                                                                                              |
| `lib/app/di/modules/home_module.dart`                                                     | Ajustar parámetros del constructor de `DashboardRepositoryImpl` (quitar dependencias de Drive). Ajustar constructor de `DashboardCubit` si se quita `settingsRepository`.                                                                                                                                                            |
| `lib/app/config/app_config.dart`                                                          | Quitar `googleOAuthClientId`, `googleOAuthClientSecret`, `modifiedTimePollInterval`.                                                                                                                                                                                                                                                 |
| `lib/app/config/environments/local_config.dart`                                           | Quitar overrides de `googleOAuthClientId`, `googleOAuthClientSecret`, `modifiedTimePollInterval`.                                                                                                                                                                                                                                    |
| `lib/app/config/environments/pro_config.dart`                                             | Quitar overrides de `googleOAuthClientId`, `googleOAuthClientSecret`, `modifiedTimePollInterval`.                                                                                                                                                                                                                                    |
| `lib/app/localization/l10n/app_es.arb`                                                    | Quitar todas las claves `settingsGoogleDrive*` (~50+), `spreadsheetPicker*` (4), `clientsConfigMissingGoogleDrive` (1), `ordersTodayExportSpreadsheet` (1), `ordersTodaySourceSpreadsheet*` (2), `dashboardNoFolderTitle` (1), `dashboardNoFolderMessage` (1), `ordersHistoryNoFolderTitle` (1), `ordersHistoryNoFolderMessage` (1). |
| `test/features/settings/data/repositories/settings_repository_impl_test.dart`             | Quitar mocks de `GoogleDriveRemoteDataSource`, `GoogleAuthService`. Ajustar constructor de `SettingsRepositoryImpl` en setUp.                                                                                                                                                                                                        |
| `test/features/home/presentation/bloc/dashboard_cubit_test.dart`                          | Quitar import de `GoogleDriveConfig`. Refactorizar tests que mockean `getGoogleDriveConfig()` — reemplazar lógica de chequeo de Drive.                                                                                                                                                                                               |
| `test/features/orders_history/data/repositories/orders_history_repository_impl_test.dart` | Quitar mock de `ExcelDriveDataSource`, import de `google_drive_remote_data_source`. Ajustar constructor y tests que dependen de Drive.                                                                                                                                                                                               |
| `test/features/home/data/repositories/dashboard_repository_impl_test.dart`                | Quitar mock de `ExcelDriveDataSource`, ajustar constructor y tests que dependen de `getGoogleDriveHistoricoFolderId`.                                                                                                                                                                                                                |

### Artefactos a retirar o reemplazar

| Artefacto                                                                | Motivo                                                                                     |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| Archivos generados `app_localizations.dart`, `app_localizations_es.dart` | Se regeneran con `flutter gen-l10n` después de editar el `.arb`. No se editan manualmente. |

## 6) Estrategia de implementación

### Pasos ordenados

1. **Eliminar dependencias de `pubspec.yaml`**
   - Quitar `googleapis: ^14.0.0`, `googleapis_auth: ^2.0.0`.
   - Verificar si `url_launcher` tiene otros usos; si no, quitarlo.
   - Ejecutar `flutter pub get`.

2. **Eliminar archivos de core**
   - Eliminar `lib/core/services/google_auth_service.dart`
   - Eliminar `lib/core/services/google_auth_service_impl.dart`
   - Eliminar `lib/core/data/datasources/google_sheets_data_source.dart`
   - Eliminar `lib/core/data/datasources/google_sheets_data_source_impl.dart`
   - Refactorizar `lib/core/error/failure.dart`

3. **Eliminar archivos de feature settings (data + domain)**
   - Eliminar datasources remotos de Drive (2 archivos)
   - Eliminar entidades de dominio (3 archivos)
   - Refactorizar `settings_local_data_source.dart` + impl
   - Refactorizar `settings_repository.dart` + impl

4. **Eliminar archivos de feature settings (presentation)**
   - Eliminar cubit + state (2 archivos)
   - Eliminar widgets (2 archivos)
   - Refactorizar `settings_page.dart`

5. **Eliminar archivos de feature orders_today**
   - Eliminar datasources de Drive/Sheets (4 archivos)
   - Eliminar DTO `order_sheet_data.dart`
   - Refactorizar `order_sheet.dart` (quitar `spreadsheetId`, `modifiedTime`)
   - Refactorizar `orders_today_repository_impl.dart`
   - Refactorizar `orders_table.dart`

6. **Refactorizar feature orders_history**
   - Refactorizar `orders_history_repository_impl.dart` (quitar deps de Drive)
   - Refactorizar `orders_history_page.dart` (quitar chequeo de Drive)

7. **Refactorizar feature home**
   - Eliminar `spreadsheet_picker_dialog.dart`
   - Eliminar `dashboard_no_folder.dart`
   - Refactorizar `dashboard_cubit.dart` (quitar chequeo de Drive)
   - Refactorizar `dashboard_state.dart` (quitar `DashboardNoFolder`)
   - Refactorizar `home_page.dart` (quitar case `DashboardNoFolder`)
   - Refactorizar `dashboard_repository_impl.dart` (quitar deps de Drive)

8. **Limpiar DI modules**
   - `settings_module.dart` — quitar registros de Google
   - `orders_today_module.dart` — quitar registros de Excel/Sheets
   - `orders_history_module.dart` — ajustar constructor
   - `home_module.dart` — ajustar constructores

9. **Limpiar app config**
   - `app_config.dart` — quitar campos OAuth y polling
   - `local_config.dart` — quitar implementaciones
   - `pro_config.dart` — quitar implementaciones

10. **Limpiar i18n**
    - Editar `app_es.arb` — quitar todas las claves de Drive/Sheets/NoFolder
    - Ejecutar `flutter gen-l10n`

11. **Actualizar tests**
    - `settings_repository_impl_test.dart`
    - `dashboard_cubit_test.dart`
    - `orders_history_repository_impl_test.dart`
    - `dashboard_repository_impl_test.dart`

12. **Verificación**
    - `flutter pub get`
    - `flutter analyze`
    - `flutter test`
    - `flutter build macos` (compilación)

### Orden recomendado

Bottom-up: dependencias → core → data → domain → presentation → DI → config →
i18n → tests → verificación.

### Dependencias entre pasos

- Paso 1 (pubspec) debe ir primero para que los imports de `googleapis` fallen
  de forma controlada al eliminar archivos.
- Pasos 2-4 (core + settings) deben completarse antes de 5-7 (features
  dependientes), porque los features importan core.
- Paso 8 (DI) debe ir después de eliminar los archivos que registra.
- Paso 10 (i18n) es independiente y puede ir en cualquier momento.
- Paso 11 (tests) debe ir después de todos los cambios en `lib/`.

### Puntos delicados

- **`SettingsRepositoryImpl` constructor**: actualmente recibe 6 parámetros
  positionales. Al quitar `_googleDriveDataSource`, `_authService` y
  `_appConfig`, queda con 3. Todos los puntos del DI que lo instancian deben
  ajustarse.
- **`DashboardCubit.load()`**: actualmente chequea `getGoogleDriveConfig()`
  antes de cargar stats. Al eliminar esta lógica, se eliminan también los stats
  de pedidos del dashboard. El cubit queda simplificado.
- **`OrdersHistoryRepositoryImpl`**: actualmente depende 100% de
  `ExcelDriveDataSource`. Queda como stub retornando error hasta tarea posterior
  de Firestore.
- **`DashboardRepositoryImpl`**: mismo caso. Se eliminan los stats de pedidos
  del dashboard. Queda como stub.
- **`orders_table.dart`**: referencia `modifiedTime` para mostrar la última
  modificación. Se elimina esa sección de la UI.
- **Cadenas i18n de "no folder"**: `dashboardNoFolderTitle`,
  `dashboardNoFolderMessage`, `ordersHistoryNoFolderTitle`,
  `ordersHistoryNoFolderMessage` se usan en widgets que se eliminan. Las cadenas
  deben quitarse del `.arb`.
- **`url_launcher`**: solo se usa en `GoogleAuthServiceImpl`. Si se confirma que
  no hay otros usos, eliminar del `pubspec.yaml`. Si hay otros usos (ej. abrir
  URLs externas desde la app), mantener.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze` — sin errores ni warnings nuevos
- `flutter test` — todos los tests restantes pasan
- `grep -r "googleapis\|GoogleDrive\|GoogleSheet\|GoogleAuth\|google_drive\|google_sheets\|google_auth\|spreadsheetId" lib/`
  — sin resultados
- `grep -r "googleapis\|GoogleDrive\|GoogleSheet\|GoogleAuth" test/` — sin
  resultados

### Verificación manual

- Abrir la página de Settings y verificar que no aparece la sección de Google
  Drive
- Verificar que el dashboard carga directamente (sin chequeo de "no folder")
- Verificar que la página de historial no muestra el estado "no configurado" de
  Drive

### Escenarios a cubrir

- Compilación limpia en la plataforma objetivo (macOS)
- La app inicia y navega sin crashear
- Settings muestra solo FacturaDirecta y User Identity
- Dashboard carga stats sin chequear Drive
- Historial de pedidos no muestra pantalla de "Drive no configurado"

### Tipo de pruebas recomendables

- Tests unitarios existentes (actualizados) para `SettingsRepositoryImpl`,
  `DashboardCubit`
- Smoke test manual de navegación

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                          | Probabilidad | Impacto | Mitigación                                                                            |
| ------------------------------------------------------------------------------- | ------------ | ------- | ------------------------------------------------------------------------------------- |
| Referencia olvidada que impide compilar                                         | Media        | Alto    | grep exhaustivo post-cambio + `flutter analyze`                                       |
| `OrdersHistoryRepositoryImpl` queda sin implementación funcional                | Alta         | Medio   | Queda como stub retornando error. Tarea posterior: conectar a Firestore               |
| `DashboardRepositoryImpl` queda sin implementación funcional (stats de pedidos) | Alta         | Medio   | Se eliminan los stats de pedidos del dashboard. Tarea posterior: conectar a Firestore |
| Tests que fallan por mocks de Drive                                             | Media        | Bajo    | Actualizar o eliminar en paso 11                                                      |
| Campo `modifiedTime` eliminado de UI de `orders_table.dart`                     | Baja         | Bajo    | Se elimina por completo. La UI de "última actualización" desaparece                   |

### Impacto potencial

- La funcionalidad de leer Excel desde Drive para `orders_history` y `dashboard`
  dejará de funcionar. Se asume que ya se usa Firestore.
- Se eliminan credenciales OAuth hardcodeadas (mejora de seguridad).
- Se reducen ~2 dependencias pesadas del build.

### Mitigación

- Verificación exhaustiva con grep + analyze + test.
- Los repos de history/dashboard se pueden dejar retornando
  `Left(ConfigNotFoundFailure())` temporalmente si la migración Firestore no
  cubre esos repos aún.

### Plan de rollback

- Git revert del commit/PR completo. Al ser una eliminación pura (sin
  migraciones de datos ni cambios de esquema), el rollback es limpio y sin
  efectos secundarios.

## 9) Suposiciones

- ~~Supuesto~~ → **Confirmado:** Los datos de pedidos del dashboard se eliminan
  temporalmente; history/dashboard quedarán como stubs hasta migración
  Firestore.
- `url_launcher` no se usa fuera de `GoogleAuthServiceImpl` (a verificar en
  implementación).
- ~~Supuesto~~ → **Confirmado:** `modifiedTime` se elimina por completo de
  `OrderSheet` junto con `spreadsheetId`.
- Los archivos `.arb` generados (`app_localizations.dart`,
  `app_localizations_es.dart`) se regeneran automáticamente con
  `flutter gen-l10n`.

## 10) Preguntas abiertas

Todas resueltas:

- ~~**PA-01:**~~ **Resuelto:** Se eliminan los datos de pedidos del dashboard
  (stats basados en Drive). `DashboardRepositoryImpl` y
  `OrdersHistoryRepositoryImpl` quedan como stubs temporales retornando error
  hasta que se conecten a Firestore en una tarea posterior.
- ~~**PA-02:**~~ **Resuelto:** `modifiedTime` se elimina por completo junto con
  `spreadsheetId`. No queda ninguna referencia a Google Sheets en el código.

## 11) Notas para implementación

- **Restricciones técnicas:** No romper la funcionalidad de FacturaDirecta ni de
  pedidos del día (Firestore). La página de Settings debe seguir mostrando las
  secciones de UserIdentity y FacturaDirecta correctamente.
- **Secuencia sugerida:** Bottom-up según paso 6. Implementar en un solo
  commit/PR grande pero con cambios agrupados lógicamente.
- **Consideraciones críticas:**
  - Al refactorizar `SettingsRepositoryImpl`, el constructor pasa de 6
    parámetros posicionales a 3. Esto impacta tanto el DI
    (`settings_module.dart`) como los tests.
  - Al eliminar `DashboardNoFolder` del sealed class `DashboardState`, asegurar
    que el switch del `home_page.dart` sigue siendo exhaustivo.
  - Los archivos de i18n generados (`app_localizations.dart`,
    `app_localizations_es.dart`) **no se editan manualmente**; se regeneran tras
    editar el `.arb`.
  - Tras eliminar `googleapis`, los archivos que hacen
    `import 'package:googleapis/...'` dejarán de compilar. Esto es esperado y se
    resuelve eliminando esos archivos en los pasos siguientes.
- **Estado: Listo para implementación**
