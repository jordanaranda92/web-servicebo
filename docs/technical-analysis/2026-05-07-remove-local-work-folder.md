# Technical Analysis: Eliminar carpeta de trabajo local y migrar a Google Drive

- **Fecha:** 2026-05-07
- **Identificador:** remove-local-work-folder
- **Fuente:** docs/functional-analysis/2026-05-07-remove-local-work-folder.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Eliminar toda la infraestructura de "carpeta de trabajo local"
(`WorkFolderConfig`, `WorkFolderCubit`, `WorkFolderState`, `WorkFolderSection`,
métodos de repositorio/datasource) y redirigir las tres features consumidoras
(`orders_today`, `orders_history`, `home/dashboard`) para que obtengan y operen
archivos Excel a través de la API de Google Drive en lugar del sistema de
archivos local (`dart:io`).

- **Áreas impactadas:** `settings` (eliminación), `orders_today` (reescritura de
  repositorio y datasource), `orders_history` (reescritura de repositorio),
  `home/dashboard` (reescritura de repositorio y cubit), módulos DI, i18n,
  tests.
- **Riesgo general estimado:** **alto** — se toca la fuente de datos de las tres
  features principales de la app; requiere un datasource remoto nuevo para
  leer/escribir archivos Excel en Drive.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC/Cubit, GetIt para DI y fpdart para
`Either<Failure, T>`.

### Patrón actual de acceso a archivos Excel

```
Presentation (page)
  → lee workFolderPath desde SettingsRepository.getWorkFolder()
  → pasa workFolderPath como parámetro en cada evento/acción
    → BLoC/Cubit → UseCase(workFolderPath, ...) → Repository(workFolderPath, ...)
      → ExcelLocalDataSource (dart:io File/Directory)
```

Todas las operaciones construyen rutas locales tipo
`$workFolderPath/historico/YYYY-MM-DD.xlsx` y `$workFolderPath/plantilla.xlsx`
usando `Platform.pathSeparator`.

### Datasource local de Excel

`ExcelLocalDataSource` / `ExcelLocalDataSourceImpl` (en
`orders_today/data/datasources/local/`) opera con `dart:io File` y el paquete
`excel` para decodificar/codificar `.xlsx`. Este datasource es el corazón de la
lectura/escritura de archivos y se reutiliza en `orders_history` y
`home/dashboard`.

### Integración Google Drive existente

- `GoogleAuthService` — gestiona OAuth 2.0 y tokens.
- `GoogleDriveRemoteDataSource` — lista carpetas y hojas de cálculo en Drive.
- `SettingsRepositoryImpl` — conecta Drive, verifica estructura de carpeta
  (`historico/`, `plantillas/`, `interno/`), persiste configuración
  (`GoogleDriveConfig` con `folderId`, `historicoFolderId`,
  `plantillasFolderId`, `internoFolderId`).
- El datasource remoto actual **no tiene** operaciones de descarga/subida de
  contenido de archivos ni copia de archivos.

### Restricciones

- Domain layer no puede depender de `dart:io` ni infraestructura (Clean
  Architecture).
- Los repositorios actuales reciben `String workFolderPath` como parámetro en
  domain — este parámetro debe reemplazarse.
- `file_picker` se usa en `WorkFolderCubit.pickFolder()` y en
  `_OrdersTodayContentState._saveAsNewExcel()` (para `FilePicker.saveFile()`).
  Solo la segunda subsiste tras la eliminación de WorkFolder.

### Dependencias

- `googleapis` / `googleapis_auth` (ya en pubspec)
- `excel` (ya en pubspec — para parseo de `.xlsx`)
- `file_picker` — se mantiene para `saveAsNewExcel` en `orders_today`.

## 3) Objetivo técnico

- **Eliminar** toda la capa de WorkFolder: entity, cubit, state, widget, métodos
  de repositorio/datasource, i18n, registros DI.
- **Sustituir** `String workFolderPath` por la configuración de Google Drive
  (`GoogleDriveConfig` → IDs de carpetas en Drive) en los contratos de
  repositorios, use cases, BLoCs/Cubits y páginas de `orders_today`,
  `orders_history` y `home/dashboard`.
- **Crear** un datasource remoto de Excel en Drive (`ExcelDriveDataSource`) que
  descargue, suba, copie y liste archivos `.xlsx` usando la API de Google Drive.
- **Mantener** `ExcelLocalDataSource` como utilidad de parseo de bytes Excel,
  pero desacoplarla de `dart:io` en la medida de lo posible, o crear un servicio
  complementario que convierta bytes ↔ `OrderSheet`.
- **Resultado:** la app trabaja exclusivamente con Google Drive como
  almacenamiento de archivos Excel.

## 4) Diseño técnico de la solución

### Enfoque propuesto

**Estrategia "Drive-first con parseo local"**: los archivos `.xlsx` se descargan
de Drive como bytes, se parsean en memoria con el paquete `excel`, y al guardar
se codifican a bytes y se suben a Drive. Esto reutiliza la lógica de parseo
existente sin reescribirla.

Se introduce una nueva capa de abstracción: un datasource remoto de Excel que
encapsula las operaciones de Drive (descargar archivo, subir archivo, copiar
archivo, listar archivos). Los repositorios pasan de recibir `workFolderPath` a
recibir los IDs de carpeta de Drive necesarios.

### Componentes / módulos / servicios afectados

#### A. Nuevo datasource: `ExcelDriveDataSource`

Responsabilidad: operaciones CRUD de archivos `.xlsx` en Google Drive.

```
Contrato (abstract):
- Future<Uint8List?> downloadFile(String fileId)
- Future<Uint8List?> downloadFileByName(String folderId, String fileName)
- Future<String> uploadFile(String folderId, String fileName, Uint8List bytes)
- Future<String> updateFile(String fileId, Uint8List bytes)
- Future<String> copyFile(String sourceFileId, String destFolderId, String destName)
- Future<List<DriveFileInfo>> listFiles(String folderId, {String? nameFilter})
- Future<bool> fileExistsByName(String folderId, String fileName)
```

Ubicación:
`lib/features/orders_today/data/datasources/remote/excel_drive_data_source.dart`
(contrato) y `excel_drive_data_source_impl.dart` (implementación con DriveApi).

#### B. Refactor de `ExcelLocalDataSource` → servicio de parseo

El `ExcelLocalDataSource` actual mezcla I/O de disco con parseo de Excel. Se
necesitan dos opciones:

**Opción recomendada**: crear métodos de parseo que acepten `Uint8List` (bytes)
en vez de `String filePath`:

```
- OrderSheet parseExcelBytes(Uint8List bytes)
- Uint8List encodeOrderSheet(OrderSheet sheet, Uint8List templateBytes)
- List<String> parseHeadersFromBytes(Uint8List bytes)
```

Esto permite reutilizar la lógica de parseo existente sin depender de `dart:io`.
`ExcelLocalDataSource` puede mantenerse para el caso de `saveAsNewExcel` (que
sigue escribiendo a disco local) o se puede refactorizar para que reciba bytes y
el caller gestione la escritura.

**Alternativa mínima**: mantener `ExcelLocalDataSource` con I/O para uso local
residual (`saveAsNewExcel`) y añadir un `ExcelParserService` independiente para
parseo de bytes.

#### C. Cambios en contratos de domain

Todos los repositorios y use cases dejan de recibir `String workFolderPath`. En
su lugar:

- **`OrdersTodayRepository`**: los métodos pasan a no recibir `workFolderPath`.
  El repositorio obtiene internamente los IDs de carpeta desde
  `SettingsRepository` (inyectado) o se le pasan como dependencia de
  constructor.
- **`OrdersHistoryRepository`**: igual.
- **`DashboardRepository`**: igual.

**Diseño recomendado**: el repositorio impl recibe los IDs de Drive como
dependencia inyectada a través de
`SettingsRepository`/`SettingsLocalDataSource`, consultándolos internamente. Los
contratos de domain quedan limpios de detalles de infraestructura.

#### D. Cambios en páginas (presentation)

Las páginas ya no necesitan leer `workFolderPath` con `setState`. En su lugar
verifican la configuración de Google Drive:

- Si `GoogleDriveConfig.isConnected == true` → proceden a cargar datos.
- Si no → muestran estado "Configura Google Drive".

Los eventos de BLoC ya no llevan `workFolderPath`.

### Contratos e interfaces (cambios clave)

**`OrdersTodayRepository` (domain)** — nuevo contrato:

```dart
abstract class OrdersTodayRepository {
  Future<Either<Failure, OrderSheet?>> getTodayOrders(DateTime date);
  Future<Either<Failure, OrderSheet>> createTodayFile(DateTime date);
  Future<Either<Failure, OrderSheet>> updateFileStructure(DateTime date);
  Future<Either<Failure, OrderSheet>> updateCellValue(DateTime date, String clientName, String product, num value);
  Future<Either<Failure, OrderSheet>> renameClient(DateTime date, String oldName, String newName);
  Future<Either<Failure, OrderSheet>> addRow(DateTime date, String clientName);
  Future<Either<Failure, OrderSheet>> deleteRows(DateTime date, Set<String> clientNames);
  Future<Either<Failure, Unit>> saveAsNewExcel(DateTime date, String destinationPath);
  Future<Either<Failure, OrderSheet>> saveOrders(DateTime date, OrderSheet orderSheet);
}
```

**`OrdersHistoryRepository` (domain)** — nuevo contrato:

```dart
abstract class OrdersHistoryRepository {
  Future<Either<Failure, List<DateTime>>> getAvailableDates();
  Future<Either<Failure, OrderSheet>> getHistoryOrders(DateTime date);
}
```

**`DashboardRepository` (domain)** — nuevo contrato:

```dart
abstract class DashboardRepository {
  Future<Either<Failure, DashboardStats>> getStats(DateTime today);
}
```

### Flujo de datos (nuevo)

```
Page
  → verifica GoogleDriveConfig.isConnected (via BLoC/Cubit o directamente)
  → emite evento al BLoC (sin workFolderPath)
    → UseCase(date, ...) → Repository
      → obtiene historicoFolderId, plantillasFolderId de SettingsLocalDataSource (inyectado)
      → ExcelDriveDataSource.downloadFileByName(historicoFolderId, "YYYY-MM-DD.xlsx")
        → bytes → ExcelParserService.parseExcelBytes(bytes) → OrderSheet
      → para escritura: ExcelParserService.encodeOrderSheet(...) → bytes
        → ExcelDriveDataSource.uploadFile(historicoFolderId, "YYYY-MM-DD.xlsx", bytes)
```

### Gestión de errores y validaciones

- **Drive no configurado**: `ConfigNotFoundFailure` (ya existe en
  `failure.dart`).
- **Archivo no encontrado en Drive**: retornar `Right(null)` (consistente con el
  comportamiento actual de `getTodayOrders`).
- **Error de autenticación/token expirado**: `AuthExpiredFailure` o
  `AuthFailure`.
- **Error de red**: `NetworkFailure`.
- **Error de API de Drive**: `ServerFailure`.
- **Error de parseo de Excel**: `EntityMappingFailure` (sin cambios).
- **Error de escritura a disco local** (solo `saveAsNewExcel`):
  `FileSystemFailure` (sin cambios).

### Consideraciones de compatibilidad o migración

- Los usuarios que tenían `workFolderPath` en SharedPreferences seguirán
  teniéndolo almacenado, pero la app lo ignorará. No se necesita migración de
  datos en SharedPreferences.
- La estructura de carpetas en Drive (`historico/`, `plantillas/`, `interno/`)
  ya se valida durante la configuración de Google Drive (en
  `verifyDriveFolder`).
- Los archivos de plantilla en Drive están en `plantillas/` (con nombre
  `plantilla_vN`), no `plantilla.xlsx` como en local → ajustar la lógica de
  búsqueda de plantilla.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                                   | Propósito                                                              |
| ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `lib/features/orders_today/data/datasources/remote/excel_drive_data_source.dart`            | Contrato del datasource remoto de Excel en Drive                       |
| `lib/features/orders_today/data/datasources/remote/excel_drive_data_source_impl.dart`       | Implementación con DriveApi: descargar, subir, copiar, listar archivos |
| `lib/core/services/excel_parser_service.dart`                                               | Contrato para parseo de bytes Excel → OrderSheet y viceversa           |
| `lib/core/services/excel_parser_service_impl.dart`                                          | Implementación basada en lógica existente de ExcelLocalDataSourceImpl  |
| `test/features/orders_today/data/datasources/remote/excel_drive_data_source_impl_test.dart` | Tests del nuevo datasource remoto                                      |

### Artefactos a modificar

| Artefacto                                                                           | Cambio esperado                                                                                                                                 |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/domain/repositories/orders_today_repository.dart`        | Eliminar `workFolderPath` de todos los métodos                                                                                                  |
| `lib/features/orders_today/domain/usecases/get_today_orders.dart`                   | Eliminar `workFolderPath` de params                                                                                                             |
| `lib/features/orders_today/domain/usecases/create_today_file.dart`                  | Eliminar `workFolderPath` de params                                                                                                             |
| `lib/features/orders_today/domain/usecases/update_file_structure.dart`              | Eliminar `workFolderPath` de params                                                                                                             |
| `lib/features/orders_today/domain/usecases/save_orders.dart`                        | Eliminar `workFolderPath` de params                                                                                                             |
| `lib/features/orders_today/domain/usecases/save_as_new_excel.dart`                  | Eliminar `workFolderPath` de params (mantener `destinationPath` para escritura local)                                                           |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`     | Reescribir: inyectar `ExcelDriveDataSource`, `ExcelParserService`, `SettingsLocalDataSource`; operar contra Drive en lugar de disco             |
| `lib/features/orders_today/presentation/bloc/orders_today_event.dart`               | Eliminar `workFolderPath` de todos los eventos                                                                                                  |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`                | Adaptar handlers a eventos sin `workFolderPath`                                                                                                 |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`               | Reemplazar lectura de `getWorkFolder()` por `getGoogleDriveConfig()`; adaptar estado vacío a "Drive no configurado"; eliminar `_workFolderPath` |
| `lib/features/orders_history/domain/repositories/orders_history_repository.dart`    | Eliminar `workFolderPath` de métodos                                                                                                            |
| `lib/features/orders_history/domain/usecases/get_available_dates.dart`              | Eliminar `workFolderPath` de params                                                                                                             |
| `lib/features/orders_history/domain/usecases/get_history_orders.dart`               | Eliminar `workFolderPath` de params                                                                                                             |
| `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart` | Reescribir: usar `ExcelDriveDataSource` + `ExcelParserService`; listar archivos de `historicoFolderId` en Drive                                 |
| `lib/features/orders_history/presentation/bloc/orders_history_event.dart`           | Eliminar `workFolderPath` de eventos                                                                                                            |
| `lib/features/orders_history/presentation/bloc/orders_history_bloc.dart`            | Adaptar handlers                                                                                                                                |
| `lib/features/orders_history/presentation/pages/orders_history_page.dart`           | Reemplazar lectura de `getWorkFolder()` por `getGoogleDriveConfig()`                                                                            |
| `lib/features/home/domain/repositories/dashboard_repository.dart`                   | Eliminar `workFolderPath` de `getStats`                                                                                                         |
| `lib/features/home/domain/usecases/get_dashboard_stats.dart`                        | Eliminar `workFolderPath` de params                                                                                                             |
| `lib/features/home/data/repositories/dashboard_repository_impl.dart`                | Reescribir: usar Drive para leer archivos Excel                                                                                                 |
| `lib/features/home/presentation/bloc/dashboard_cubit.dart`                          | Cambiar validación de `getWorkFolder()` por `getGoogleDriveConfig().isConnected`                                                                |
| `lib/features/settings/domain/repositories/settings_repository.dart`                | Eliminar métodos `getWorkFolder`, `saveWorkFolder`, `clearWorkFolder`                                                                           |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`             | Eliminar implementaciones de WorkFolder                                                                                                         |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`      | Eliminar métodos de WorkFolder (`getWorkFolderPath`, `saveWorkFolderPath`, `clearWorkFolderPath`)                                               |
| `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart` | Eliminar implementaciones de WorkFolder                                                                                                         |
| `lib/features/settings/presentation/pages/settings_page.dart`                       | Eliminar `WorkFolderSection` y `WorkFolderCubit` del `MultiBlocProvider`                                                                        |
| `lib/app/di/modules/settings_module.dart`                                           | Eliminar registro de `WorkFolderCubit`                                                                                                          |
| `lib/app/di/modules/orders_today_module.dart`                                       | Registrar `ExcelDriveDataSource`, `ExcelParserService`; actualizar constructor de `OrdersTodayRepositoryImpl`                                   |
| `lib/app/di/modules/orders_history_module.dart`                                     | Actualizar constructor de `OrdersHistoryRepositoryImpl`                                                                                         |
| `lib/app/di/modules/home_module.dart`                                               | Actualizar constructor de `DashboardRepositoryImpl`                                                                                             |
| `lib/app/localization/l10n/app_es.arb`                                              | Eliminar claves `settingsWorkFolder*` (~12 claves)                                                                                              |
| `test/features/settings/presentation/bloc/work_folder_cubit_test.dart`              | Eliminar completamente                                                                                                                          |
| `test/features/settings/data/repositories/settings_repository_impl_test.dart`       | Eliminar tests de WorkFolder; actualizar constructor mock                                                                                       |
| `test/features/home/data/repositories/dashboard_repository_impl_test.dart`          | Adaptar a nuevo contrato sin `workFolderPath`                                                                                                   |
| `test/features/orders_history/**`                                                   | Adaptar tests existentes                                                                                                                        |

### Artefactos a retirar o reemplazar

| Artefacto                                                              | Motivo                                    |
| ---------------------------------------------------------------------- | ----------------------------------------- |
| `lib/features/settings/domain/entities/work_folder_config.dart`        | Ya no se necesita entity de carpeta local |
| `lib/features/settings/presentation/bloc/work_folder_cubit.dart`       | Eliminación de funcionalidad              |
| `lib/features/settings/presentation/bloc/work_folder_state.dart`       | Eliminación de funcionalidad              |
| `lib/features/settings/presentation/widgets/work_folder_section.dart`  | Eliminación del widget de UI              |
| `test/features/settings/presentation/bloc/work_folder_cubit_test.dart` | Tests del artefacto eliminado             |

## 6) Estrategia de implementación

### Fase 1 — Infraestructura base (sin romper nada existente)

1. **Paso 1:** Crear `ExcelParserService` (contrato + implementación) extrayendo
   la lógica de parseo de `ExcelLocalDataSourceImpl` para que opere con
   `Uint8List` en lugar de rutas de archivo.
2. **Paso 2:** Crear `ExcelDriveDataSource` (contrato + implementación) con
   operaciones de Drive: `downloadFileByName`, `uploadFile`, `updateFile`,
   `copyFile`, `listFiles`, `fileExistsByName`.
3. **Paso 3:** Registrar ambos servicios nuevos en el módulo DI de
   `orders_today`.

### Fase 2 — Migrar `orders_today` a Drive

4. **Paso 4:** Actualizar contrato `OrdersTodayRepository` — eliminar
   `workFolderPath` de todos los métodos.
5. **Paso 5:** Actualizar todos los use cases de `orders_today` — eliminar
   `workFolderPath` de params.
6. **Paso 6:** Reescribir `OrdersTodayRepositoryImpl` — inyectar
   `ExcelDriveDataSource`, `ExcelParserService`, `SettingsLocalDataSource`;
   obtener `historicoFolderId` y `plantillasFolderId` internamente; operar
   contra Drive.
7. **Paso 7:** Actualizar eventos de `OrdersTodayBloc` — eliminar
   `workFolderPath`.
8. **Paso 8:** Actualizar `OrdersTodayBloc` — adaptar handlers.
9. **Paso 9:** Actualizar `OrdersTodayPage` — reemplazar validación de
   `getWorkFolder()` por `getGoogleDriveConfig()`, eliminar `_workFolderPath`,
   adaptar estado vacío.

### Fase 3 — Migrar `orders_history` a Drive

10. **Paso 10:** Actualizar contrato `OrdersHistoryRepository` — eliminar
    `workFolderPath`.
11. **Paso 11:** Actualizar use cases de `orders_history`.
12. **Paso 12:** Reescribir `OrdersHistoryRepositoryImpl` — listar archivos de
    `historicoFolderId` en Drive, descargar y parsear.
13. **Paso 13:** Actualizar eventos y bloc de `orders_history`.
14. **Paso 14:** Actualizar `OrdersHistoryPage`.

### Fase 4 — Migrar `home/dashboard` a Drive

15. **Paso 15:** Actualizar contrato `DashboardRepository` — eliminar
    `workFolderPath`.
16. **Paso 16:** Actualizar `GetDashboardStats` use case.
17. **Paso 17:** Reescribir `DashboardRepositoryImpl` — leer archivos de Drive.
18. **Paso 18:** Actualizar `DashboardCubit` — reemplazar `getWorkFolder()` por
    `getGoogleDriveConfig()`.

### Fase 5 — Eliminar WorkFolder y limpieza

19. **Paso 19:** Eliminar `WorkFolderCubit`, `WorkFolderState`,
    `WorkFolderSection`, `WorkFolderConfig`.
20. **Paso 20:** Eliminar métodos de WorkFolder de `SettingsRepository`,
    `SettingsRepositoryImpl`, `SettingsLocalDataSource`,
    `SettingsLocalDataSourceImpl`.
21. **Paso 21:** Actualizar `SettingsPage` — eliminar `WorkFolderSection` y su
    `BlocProvider`.
22. **Paso 22:** Eliminar registro de `WorkFolderCubit` de
    `settings_module.dart`.
23. **Paso 23:** Eliminar claves i18n `settingsWorkFolder*` de `app_es.arb` y
    regenerar.
24. **Paso 24:** Evaluar si `ExcelLocalDataSource`/`ExcelLocalDataSourceImpl`
    todavía se usa (para `saveAsNewExcel` que escribe a disco local). Si no,
    eliminar. Si sí, mantener solo para ese caso.

### Fase 6 — Tests

25. **Paso 25:** Eliminar `work_folder_cubit_test.dart`.
26. **Paso 26:** Actualizar `settings_repository_impl_test.dart` — quitar tests
    de WorkFolder, actualizar constructor.
27. **Paso 27:** Crear tests para `ExcelDriveDataSource`.
28. **Paso 28:** Actualizar/crear tests para `OrdersTodayRepositoryImpl`,
    `OrdersHistoryRepositoryImpl`, `DashboardRepositoryImpl` con mocks de
    `ExcelDriveDataSource` y `ExcelParserService`.
29. **Paso 29:** Actualizar tests de blocs/cubits afectados.
30. **Paso 30:** Ejecutar `dart analyze` y `flutter test` — verificar 0 issues.

### Orden recomendado

Fase 1 → 2 → 3 → 4 → 5 → 6 (secuencial, cada fase depende de la anterior).

### Dependencias entre pasos

- Fases 2, 3 y 4 dependen de Fase 1 (infraestructura base).
- Fase 5 depende de Fases 2, 3 y 4 (no se puede eliminar WorkFolder hasta que
  nadie lo consuma).
- Fase 6 puede ir parcialmente en paralelo con cada fase (tests de cada módulo
  al finalizarlo).

### Puntos delicados

- **Plantilla en Drive**: la plantilla en local se llama `plantilla.xlsx`; en
  Drive se almacena en la subcarpeta `plantillas/` con nombre `plantilla_vN`. La
  lógica de búsqueda de plantilla debe ajustarse para buscar el archivo correcto
  en Drive (probablemente el más reciente con prefijo `plantilla_v`).
- **Concurrencia en `saveOrders`**: al guardar pedidos, se descarga → parsea →
  modifica → codifica → sube. Si otro usuario modifica el archivo entre la
  descarga y la subida, los cambios se sobreescriben. Esto ya era un riesgo con
  Drive File Stream pero se hace más explícito.
- **Rendimiento del Dashboard**: actualmente lee muchos archivos (hoy + ayer + 7
  días de semana + 7 de semana pasada + N días de mes + N de mes anterior). Con
  Drive, cada lectura es una llamada HTTP. Se debe paralelizar con `Future.wait`
  y considerar un límite de archivos.
- **`saveAsNewExcel` y `file_picker`**: esta funcionalidad escribe a disco local
  seleccionando ruta con `FilePicker.saveFile()`. Se mantiene porque es un
  "exportar a disco" explícito por el usuario. El flujo cambia: leer bytes de
  Drive → usuario elige ruta local → escribir bytes a disco.
- **`OrderSheet.filePath`**: actualmente almacena la ruta local. Con Drive,
  puede almacenar el `fileId` de Drive o eliminarse si no se usa en la UI.

## 7) Estrategia de validación

### Verificaciones automáticas

- `dart analyze` → 0 issues en todos los archivos afectados.
- `flutter test` → todos los tests pasan (existentes actualizados + nuevos).
- No quedan referencias a `WorkFolderConfig`, `WorkFolderCubit`,
  `WorkFolderState`, `workFolderPath` en `lib/`.

### Verificaciones manuales

- Con Google Drive configurado: abrir Pedidos de hoy → verificar carga desde
  Drive.
- Crear archivo del día (copiar plantilla desde Drive) → verificar que aparece
  en Drive.
- Editar celda → guardar → refrescar → verificar persistencia.
- Abrir Historial → verificar listado de fechas desde Drive.
- Seleccionar fecha en historial → verificar carga de pedidos.
- Abrir Dashboard → verificar carga de estadísticas.
- Sin Google Drive configurado → verificar que todas las pantallas muestran el
  estado "Configura Google Drive".
- Exportar como nuevo Excel → verificar que escribe correctamente a disco local.
- Pantalla de Ajustes → verificar que no aparece "Carpeta de trabajo".

### Escenarios de prueba

| Escenario                                                   | Resultado esperado                                  |
| ----------------------------------------------------------- | --------------------------------------------------- |
| Drive conectado, carpeta con `historico/` y archivo del día | Carga pedidos correctamente                         |
| Drive conectado, archivo del día no existe                  | Muestra estado vacío con botón "Crear"              |
| Drive conectado, plantilla no encontrada                    | Error claro                                         |
| Drive no conectado                                          | Estado "Configura Google Drive" con botón a Ajustes |
| Token expirado y no refreshable                             | Estado de reconexión necesaria                      |
| Sin conexión a internet                                     | Error de red con opción de reintentar               |
| Exportar como nuevo Excel a disco                           | Archivo .xlsx escrito correctamente                 |

### Tipos de prueba recomendables

- Tests unitarios: ExcelDriveDataSource, ExcelParserService, repositorios
  refactorizados, blocs/cubits.
- Tests de integración (manual): flujo completo end-to-end con Google Drive
  real.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                          | Probabilidad | Impacto | Mitigación                                                                     |
| ----------------------------------------------- | ------------ | ------- | ------------------------------------------------------------------------------ |
| Latencia de red degrada UX vs lectura local     | Alta         | Medio   | Indicadores de carga claros; paralelizar lecturas en Dashboard                 |
| Límite de cuota de API de Google Drive          | Baja         | Alto    | Batch reads, caché en memoria para sesión                                      |
| Conflicto de concurrencia al guardar            | Media        | Medio   | Documentar limitación; considerar timestamps o ETags en futuro                 |
| Archivos grandes en Drive (muchos pedidos)      | Baja         | Bajo    | Streaming de descarga si es necesario                                          |
| Nombre de plantilla diferente en Drive vs local | Alta         | Medio   | Ajustar lógica de búsqueda de plantilla a convención de Drive (`plantilla_vN`) |

### Impacto potencial

- **Funcional**: las tres features principales de la app cambian de fuente de
  datos. Un error en el datasource de Drive bloquea la operación completa de la
  app.
- **Rendimiento**: se introduce latencia de red en cada operación. El Dashboard
  es especialmente sensible (múltiples lecturas).
- **UX**: usuarios que solo usaban carpeta local tendrán que configurar Google
  Drive obligatoriamente.

### Plan de rollback

- Toda la funcionalidad de WorkFolder se elimina en la Fase 5 (la última fase de
  código productivo). Si se detectan problemas antes de esa fase, el rollback es
  revertir los commits de las fases con problemas.
- Si el rollback es necesario post-merge, se restauran los archivos eliminados
  desde git history.
- Recomendación: hacer el desarrollo en una branch independiente y validar
  completamente antes de merge.

## 9) Suposiciones

- **S-01**: la estructura de carpetas en Drive (`historico/`, `plantillas/`,
  `interno/`) se valida durante la configuración y se asume presente.
- **S-02**: el nombre de la plantilla en Drive sigue el patrón `plantilla_vN`
  (según lógica existente en `verifyDriveFolder`).
- **S-03**: los archivos en `historico/` siguen la convención `YYYY-MM-DD.xlsx`
  tanto en local como en Drive.
- **S-04**: la API de Google Drive permite subir/actualizar archivos con
  permisos de escritura (el scope actual `driveReadonlyScope` puede ser
  **insuficiente** — ver PA-01).
- **S-05**: no se requiere caché offline en esta iteración.
- **S-06**: `saveAsNewExcel` (exportar a disco) se mantiene como funcionalidad
  independiente.

## 10) Preguntas abiertas

- **PA-01 (CRÍTICA)**: El scope actual de OAuth es
  `drive.DriveApi.driveReadonlyScope`. Para subir/actualizar archivos se
  necesita un scope de escritura (e.g. `drive.DriveApi.driveFileScope` o
  `drive.DriveApi.driveScope`). ¿Se puede ampliar el scope sin re-autenticar?
  Probablemente se requerirá re-autenticación la primera vez tras el cambio de
  scopes.
- **PA-02**: ¿La plantilla en Drive es un archivo `.xlsx` nativo o un Google
  Sheet? Si es Google Sheet, la descarga requiere exportar como `.xlsx`
  (`files.export` en lugar de `files.get` con `alt=media`). El check actual en
  `verifyDriveFolder` busca spreadsheets que incluyen mime type
  `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` (xlsx
  nativo), lo cual sugiere que son `.xlsx`.
- **PA-03**: ¿Se debe mostrar algún indicador de "última sincronización" o
  "guardado en Drive" en la UI de pedidos del día?
- **PA-04**: ¿La columna `lastModified` de `OrderSheet` se obtiene del metadata
  del archivo en Drive (`modifiedTime`)?

## 11) Notas para implementación

- **Scope de OAuth**: verificar y ampliar scopes si es necesario. Si se cambian
  scopes, los usuarios existentes deberán re-autenticarse.
- **No romper `saveAsNewExcel`**: esta funcionalidad sigue escribiendo a disco
  local. El flujo será: descargar bytes de Drive → usuario selecciona ruta con
  `FilePicker.saveFile()` → escribir bytes a disco. Mantener
  `ExcelLocalDataSource` para este caso o extraer un método simple de escritura.
- **`OrderSheet.filePath`**: este campo almacenaba la ruta local. Considerar
  reemplazarlo por `fileId` (String del ID de Drive) o hacer el campo nullable y
  solo popularlo cuando sea relevante.
- **Paralelización en Dashboard**: usar `Future.wait` para descargar múltiples
  archivos en paralelo. El Dashboard actual ya usa `Future.wait` con reads
  locales; replicar el patrón con reads de Drive.
- **Convención de nombres de archivos en Drive**: mantener `YYYY-MM-DD.xlsx` en
  `historico/`. Para la plantilla, buscar el archivo más reciente con prefijo
  `plantilla_v` en `plantillas/`.
- **Sequence sugerida**: implementar Fase 1 completa y verificar con un test
  manual antes de proceder con las fases 2-4. La Fase 5 (eliminación) solo al
  final cuando todo funcione.
- **No eliminar `ExcelLocalDataSourceImpl` prematuramente**: se usa en
  `saveAsNewExcel`. Evaluar al final si puede simplificarse o reemplazarse.
- **Estado: Listo para implementación**
