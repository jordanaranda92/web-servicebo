# Functional Analysis: Eliminar integración con Google Drive y Google Sheets

- **Fecha:** 2026-05-10
- **Identificador:** remove-google-drive-sheets
- **Estado:** Ready for technical analysis

## 1) Resumen

Eliminar por completo toda la integración con Google Drive y Google Sheets del
proyecto Servicebo. Esto incluye la autenticación OAuth con Google, los
datasources que acceden a Drive/Sheets API, los widgets de configuración de
Drive en Settings, las entidades de dominio relacionadas, las dependencias de
paquetes (`googleapis`, `googleapis_auth`), las cadenas de i18n, y cualquier
lógica de negocio que dependa de estas APIs.

## 2) Contexto y objetivo

- **Qué se solicita:** Eliminación total de toda funcionalidad, código,
  configuración y dependencias relacionadas con Google Drive y Google Sheets.
- **Qué problema resuelve:** La aplicación ha migrado (o está migrando) sus
  fuentes de datos a Firestore. Las integraciones con Google Drive/Sheets son
  código legacy que ya no se necesita, incrementa la superficie de
  mantenimiento, añade dependencias pesadas y expone credenciales OAuth
  innecesarias.
- **Resultado funcional esperado:** La aplicación compila correctamente sin
  ninguna referencia a Google Drive ni Google Sheets. No existen datasources,
  repositorios, widgets, cubits, entidades, DTOs ni cadenas de localización
  relacionados con estas APIs. Las dependencias `googleapis` y `googleapis_auth`
  se eliminan del `pubspec.yaml`.

## 3) Alcance

### En alcance

- **Core — Servicio de autenticación Google:**
  - `lib/core/services/google_auth_service.dart` (interfaz)
  - `lib/core/services/google_auth_service_impl.dart` (implementación OAuth)
- **Core — DataSource Google Sheets genérico:**
  - `lib/core/data/datasources/google_sheets_data_source.dart` (interfaz)
  - `lib/core/data/datasources/google_sheets_data_source_impl.dart`
    (implementación)
- **Core — Failure con campo `googleDriveMissing`:**
  - `lib/core/error/failure.dart` → `PrerequisiteFailure.googleDriveMissing`
- **Feature Settings — DataSources remotos de Drive:**
  - `lib/features/settings/data/datasources/remote/google_drive_remote_data_source.dart`
    (interfaz + `DriveFileInfo`)
  - `lib/features/settings/data/datasources/remote/google_drive_remote_data_source_impl.dart`
    (implementación)
- **Feature Settings — DataSource local (campos de Drive):**
  - `lib/features/settings/data/datasources/local/settings_local_data_source.dart`
    — métodos `getGoogleDrive*`, `saveGoogleDrive*`, `clearGoogleDrive*`
  - `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`
    — implementación de los mismos
- **Feature Settings — Repository (operaciones de Drive):**
  - `lib/features/settings/domain/repositories/settings_repository.dart` —
    métodos `getGoogleDriveConfig`, `saveGoogleDriveConfig`,
    `clearGoogleDriveConfig`, `connectGoogleDrive`, `listDriveFolders`,
    `verifyDriveFolder`, `selectDriveFolder`
  - `lib/features/settings/data/repositories/settings_repository_impl.dart` —
    implementación + imports de `googleapis`
- **Feature Settings — Entidades de dominio:**
  - `lib/features/settings/domain/entities/google_drive_config.dart`
  - `lib/features/settings/domain/entities/drive_folder.dart`
  - `lib/features/settings/domain/entities/drive_folder_content.dart`
- **Feature Settings — Cubit/State de Google Drive:**
  - `lib/features/settings/presentation/bloc/google_drive_cubit.dart`
  - `lib/features/settings/presentation/bloc/google_drive_state.dart`
- **Feature Settings — Widgets de UI:**
  - `lib/features/settings/presentation/widgets/google_drive_section.dart`
  - `lib/features/settings/presentation/widgets/drive_folder_picker.dart`
- **Feature Orders Today — DataSources remotos de Drive/Sheets:**
  - `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source.dart`
    (interfaz)
  - `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source_impl.dart`
    (implementación ~540 líneas)
  - `lib/features/orders_today/data/datasources/remote/excel_drive_data_source.dart`
    (interfaz)
  - `lib/features/orders_today/data/datasources/remote/excel_drive_data_source_impl.dart`
    (implementación)
- **Feature Orders Today — DTO:**
  - `lib/features/orders_today/data/dto/order_sheet_data.dart` — referencia a
    "Google Sheet" en comentario y campo `spreadsheetId`
- **Feature Orders Today — Entidad de dominio:**
  - `lib/features/orders_today/domain/entities/order_sheet.dart` — campo
    `spreadsheetId` ("Spreadsheet ID in Google Drive")
- **Feature Orders History:**
  - `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart`
    — dependencia de `ExcelDriveDataSource` y
    `getGoogleDriveHistoricoFolderId()`
  - `lib/features/orders_history/presentation/pages/orders_history_page.dart` —
    lógica `_isDriveConfigured` / `getGoogleDriveConfig()`
- **Feature Home — Dashboard:**
  - `lib/features/home/data/repositories/dashboard_repository_impl.dart` —
    dependencia de `ExcelDriveDataSource` y `getGoogleDriveHistoricoFolderId()`
  - `lib/features/home/presentation/bloc/dashboard_cubit.dart` —
    `getGoogleDriveConfig()`
  - `lib/features/home/presentation/widgets/spreadsheet_picker_dialog.dart` —
    widget completo de Drive
- **DI Modules:**
  - `lib/app/di/modules/settings_module.dart` — registros de
    `GoogleAuthService`, `GoogleDriveRemoteDataSource`, `GoogleDriveCubit`
  - `lib/app/di/modules/orders_today_module.dart` — registros de
    `ExcelDriveDataSource`, `OrdersSheetDataSource`
- **App Config:**
  - `lib/app/config/app_config.dart` — `googleOAuthClientId`,
    `googleOAuthClientSecret`
  - `lib/app/config/environments/local_config.dart` — valores de OAuth
  - `lib/app/config/environments/pro_config.dart` — valores de OAuth
- **Localización (i18n):**
  - `lib/app/localization/l10n/app_es.arb` — todas las claves
    `settingsGoogleDrive*`, `spreadsheetPicker*`,
    `clientsConfigMissingGoogleDrive`, `ordersTodayExportSpreadsheet`,
    `ordersTodaySourceSpreadsheet*`
  - `lib/app/localization/l10n/app_localizations.dart` — getters generados
    correspondientes
  - `lib/app/localization/l10n/app_localizations_es.dart` — implementaciones
    generadas correspondientes
- **Dependencias (pubspec.yaml):**
  - `googleapis: ^14.0.0`
  - `googleapis_auth: ^2.0.0`
- **Tests:**
  - `test/features/settings/data/repositories/settings_repository_impl_test.dart`
    — mocks de `GoogleDriveRemoteDataSource`, `GoogleAuthService`
  - `test/features/home/presentation/bloc/dashboard_cubit_test.dart` — mocks de
    `GoogleDriveConfig`
  - `test/features/orders_history/data/repositories/orders_history_repository_impl_test.dart`
    — mock de `getGoogleDriveHistoricoFolderId`
  - `test/features/home/data/repositories/dashboard_repository_impl_test.dart` —
    mock de `getGoogleDriveHistoricoFolderId`

### Fuera de alcance

- Migración de datos de Google Sheets a Firestore (se asume ya realizada o en
  curso por separado)
- Eliminación de Factura Directa (queda intacta)
- Refactorización de features que usan Firestore como fuente de datos (ya
  funcionales)
- Cambios en Firebase/Firestore
- Eliminación de la feature `orders_history` o `home/dashboard` en sí mismas:
  solo se eliminan sus dependencias de Drive

## 4) Actores implicados

| Actor                        | Impacto                                                                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Usuario final (operador)** | Pierde la sección "Google Drive" en Settings; pierde el picker de spreadsheets; pierde la exportación/importación desde hojas de cálculo de Drive |
| **Desarrollador**            | Reducción significativa de código y dependencias a mantener                                                                                       |
| **Sistema**                  | Eliminación de credenciales OAuth embebidas; reducción de tamaño de build                                                                         |

## 5) Requisitos funcionales

- **RF-01:** Eliminar toda la lógica de autenticación OAuth con Google (sign-in,
  sign-out, refresh de tokens, almacenamiento de credenciales).
- **RF-02:** Eliminar los datasources de Google Drive
  (`GoogleDriveRemoteDataSource`, `ExcelDriveDataSource`) y Google Sheets
  (`GoogleSheetsDataSource`, `OrdersSheetDataSource`) tanto interfaces como
  implementaciones.
- **RF-03:** Eliminar las entidades de dominio `GoogleDriveConfig`,
  `DriveFolder`, `DriveFolderContent`.
- **RF-04:** Eliminar el `GoogleDriveCubit` y sus estados (`GoogleDriveState` y
  subclases).
- **RF-05:** Eliminar los widgets `GoogleDriveSection`, `DriveFolderPicker` y
  `SpreadsheetPickerDialog`.
- **RF-06:** Eliminar todos los métodos de Google Drive del `SettingsRepository`
  (interfaz e implementación) y del `SettingsLocalDataSource`.
- **RF-07:** Eliminar el campo `googleDriveMissing` de `PrerequisiteFailure`.
- **RF-08:** Eliminar los campos `googleOAuthClientId` y
  `googleOAuthClientSecret` de `AppConfig` y sus implementaciones de entorno.
- **RF-09:** Eliminar las dependencias `googleapis` y `googleapis_auth` del
  `pubspec.yaml`.
- **RF-10:** Eliminar todas las cadenas de localización relacionadas
  (`settingsGoogleDrive*`, `spreadsheetPicker*`,
  `clientsConfigMissingGoogleDrive`, `ordersTodayExportSpreadsheet`,
  `ordersTodaySourceSpreadsheet*`) del archivo `.arb` y regenerar los archivos
  de localización.
- **RF-11:** Eliminar los registros de DI correspondientes en
  `settings_module.dart` y `orders_today_module.dart`.
- **RF-12:** Eliminar o refactorizar las dependencias de Drive en
  `OrdersHistoryRepositoryImpl`, `DashboardRepositoryImpl`, `DashboardCubit` y
  `OrdersHistoryPage`.
- **RF-13:** Eliminar el campo `spreadsheetId` de `OrderSheet` y
  `OrderSheetData` por completo.
- **RF-14:** Actualizar o eliminar los tests que mockean componentes de Google
  Drive/Sheets.
- **RF-15:** La aplicación debe compilar sin errores y los tests existentes (no
  relacionados con Drive) deben seguir pasando.

## 6) Criterios de aceptación

- **CA-01:** No existe ningún import de `googleapis`, `googleapis_auth` ni
  `google_sign_in` en el proyecto.
- **CA-02:** No existen archivos con nombre que contenga `google_drive`,
  `google_sheets`, `google_auth` en `lib/` ni `test/`.
- **CA-03:** `grep -r "GoogleDrive\|GoogleSheet\|GoogleAuth\|googleapis" lib/`
  no devuelve resultados.
- **CA-04:** El `pubspec.yaml` no contiene las dependencias `googleapis` ni
  `googleapis_auth`.
- **CA-05:** `flutter build macos` (o la plataforma objetivo) compila sin
  errores.
- **CA-06:** `flutter test` ejecuta sin fallos en los tests que quedan.
- **CA-07:** La página de Settings no muestra la sección de Google Drive.
- **CA-08:** El DI container (`GetIt`) no registra ningún servicio relacionado
  con Google Drive, Sheets u OAuth de Google.
- **CA-09:** Los archivos `.arb` no contienen claves `settingsGoogleDrive*` ni
  `spreadsheetPicker*`.
- **CA-10:** No existen credenciales OAuth de Google embebidas en el código
  fuente.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. Se identifican todos los archivos y fragmentos de código que referencian
   Google Drive o Google Sheets.
2. Se eliminan los archivos que son exclusivamente de Google Drive/Sheets
   (datasources, entidades, cubits, widgets, etc.).
3. Se refactorizan los archivos compartidos para remover solo las partes de
   Drive/Sheets (repositorios, DI, configs, failures, i18n, etc.).
4. Se actualizan los módulos DI para eliminar registros huérfanos.
5. Se eliminan las dependencias del `pubspec.yaml` y se ejecuta
   `flutter pub get`.
6. Se regeneran los archivos de localización (`flutter gen-l10n`).
7. Se verifica compilación y ejecución de tests.

### Flujos alternativos

- **FA-01:** ~~Si algún componente depende de `ExcelDriveDataSource` para
  funcionalidad que aún se usa~~ → **Resuelto:** los datos ya están en
  Firestore, se elimina la dependencia directamente.
- **FA-02:** ~~Si el campo `spreadsheetId` en `OrderSheet` se reutiliza como
  identificador genérico~~ → **Resuelto:** se elimina por completo.

### Estados especiales / excepciones

- **Estado vacío:** La sección de Settings tendrá menos opciones; la UI debe
  seguir consistente sin la sección de Google Drive.
- **Estado error:** No aplica — se elimina la fuente de errores de Google Drive.
- **Sin datos migrados:** Confirmado que los datos ya están en Firestore. No hay
  riesgo de rotura funcional.

## 8) Edge cases

- **EC-01:** Usuarios con credenciales OAuth almacenadas en
  `SharedPreferences`/`FlutterSecureStorage`. Las credenciales persistidas
  quedarán como datos huérfanos. No se requiere limpieza activa.
- **EC-02:** ~~El campo `spreadsheetId` de `OrderSheet`~~ → **Resuelto:** se
  elimina por completo junto con sus referencias.
- **EC-03:** Las cadenas i18n como `ordersTodayExportSpreadsheet` y
  `ordersTodaySourceSpreadsheet` pueden estar referenciadas en la UI de
  `orders_today`. Verificar si esos botones/opciones existen en la presentación
  y eliminarlos también.
- **EC-04:** El `SpreadsheetPickerDialog` en `home/presentation/widgets/` es un
  widget completo que puede tener referencias desde la página del dashboard o
  del home.
- **EC-05:** `PrerequisiteFailure` podría usarse solo con
  `facturaDirectaMissing` tras eliminar `googleDriveMissing`. Si queda con un
  solo campo, valorar si simplificar la clase.

## 9) Impacto funcional

- **Módulos afectados:**
  - `settings` — pierde sección completa de Google Drive (UI, bloc, data,
    domain)
  - `orders_today` — pierde datasources de Drive/Sheets (2 datasources + DTOs)
  - `orders_history` — pierde dependencia de `ExcelDriveDataSource` y chequeo de
    Drive
  - `home` — pierde `SpreadsheetPickerDialog`, chequeo de Drive en dashboard
  - `core` — pierde `GoogleAuthService`, `GoogleSheetsDataSource` y campo de
    failure
  - `app/di` — pierde registros de DI de Google
  - `app/config` — pierde credenciales OAuth
  - `app/localization` — pierde ~60+ cadenas de i18n
- **Impacto en usuario:** El usuario ya no podrá conectar Google Drive,
  seleccionar carpetas, exportar/importar hojas de cálculo desde Drive, ni ver
  el picker de spreadsheets. Toda la gestión de datos se hará desde Firestore.
- **Impacto en negocio:** Reducción de la dependencia de servicios de terceros
  (Google APIs); eliminación de credenciales OAuth embebidas en el código
  (mejora de seguridad).
- **Impacto en experiencia de usuario:** La página de Settings será más simple.
  Las funciones de exportar/importar desde Drive desaparecen.

## 10) Suposiciones

- **S-01:** ~~Supuesto~~ → **Confirmado:** Los datos ya están en Firestore. Las
  features `orders_today`, `orders_history` y `home/dashboard` funcionan sin
  Google Drive/Sheets.
- **S-02:** ~~Supuesto~~ → **Confirmado:** El campo `spreadsheetId` se elimina
  por completo.
- **S-03:** No hay otros workspace folders o proyectos dependientes de las APIs
  de Google eliminadas.
- **S-04:** ~~Supuesto~~ → **Confirmado:** No se requiere limpieza de
  credenciales OAuth huérfanas.

## 11) Preguntas abiertas

Todas resueltas:

- ~~**PA-01:**~~ **Resuelto:** El campo `spreadsheetId` se elimina por completo.
- ~~**PA-02:**~~ **Resuelto:** Los datos ya están en Firestore. Se eliminan las
  dependencias de Drive directamente.
- ~~**PA-03:**~~ **Resuelto:** No se requiere migración de credenciales
  almacenadas.

## 12) Notas para análisis técnico

- Hay **~30+ archivos** directamente afectados entre `lib/` y `test/`.
- Los archivos a **eliminar completamente** son aproximadamente 15 (datasources,
  entidades, cubits, widgets, DTOs específicos de Drive/Sheets).
- Los archivos a **refactorizar** (quitar solo la parte de Drive) son
  aproximadamente 15 (repositorios, DI modules, configs, failures, i18n, pages,
  tests).
- Las credenciales OAuth hardcodeadas en `local_config.dart` y `pro_config.dart`
  son un hallazgo de seguridad que se resuelve con esta eliminación.
- El orden de eliminación recomendado: (1) dependencias de pubspec, (2) core
  services, (3) data layer, (4) domain layer, (5) presentation layer, (6) DI,
  (7) config, (8) i18n, (9) tests, (10) verificación.
- Las cadenas de localización están en archivos `.arb` que se regeneran con
  `flutter gen-l10n`. Basta con editar el `.arb` fuente.
- **Estado: Listo para análisis técnico**
