# Technical Analysis: Pedidos de hoy — Google Sheets con creación automática

- **Fecha:** 2026-05-07
- **Identificador:** orders-today
- **Fuente:** docs/functional-analysis/2026-05-07-orders-today.md (v3)
- **Estado:** Ready for implementation

## 1) Resumen técnico

Rediseñar la feature `orders_today` para operar íntegramente con Google Sheets
API en lugar de archivos `.xlsx` parseados localmente. Los cambios principales
son:

1. **Nuevo datasource nativo de Google Sheets** que lee/escribe directamente
   celdas, fórmulas y formato condicional vía la API de Sheets, reemplazando el
   flujo actual de descargar → parsear `.xlsx` → subir `.xlsx`.
2. **Transposición del modelo de dominio**: la entidad `OrderSheet` pasa de
   `products` en columnas + `rows` por cliente, a `products` en filas +
   `clients` en columnas.
3. **Creación inteligente del sheet del día**: copiar plantilla versionada
   (`plantilla_vX`, mayor X) + escribir fecha, clientes activos, productos
   activos, fórmulas (PEDIDOS = SUM, QUEDAN = STOCKS − PEDIDOS) y formato
   condicional (QUEDAN: rojo/verde).
4. **Auto-refresh por polling**: consultar `modifiedTime` del archivo vía Drive
   API periódicamente (~30s); recargar datos si ha cambiado.

**Áreas impactadas:** `orders_today` (data, domain, presentation),
`core/services`, `app/di`.

**Riesgo general estimado:** Medio — el cambio de datasource es significativo
pero la arquitectura Clean Architecture actual aísla bien las capas; el dominio
y la presentación se adaptan sin romper contratos externos.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC, GetIt (DI), fpdart (`Either`).

### Estructura actual de `orders_today`

```
orders_today/
├── data/
│   ├── datasources/
│   │   ├── local/       → ExcelLocalDataSource (lee/escribe .xlsx local)
│   │   └── remote/      → ExcelDriveDataSource (sube/descarga .xlsx a Drive)
│   └── repositories/    → OrdersTodayRepositoryImpl
├── domain/
│   ├── entities/        → OrderSheet, OrderRow, VersionCheckResult
│   ├── repositories/    → OrdersTodayRepository (contrato)
│   └── usecases/        → GetTodayOrders, CreateTodayFile, UpdateFileStructure,
│                          SaveOrders, SaveAsNewExcel, UpdateCellValue,
│                          RenameClient, AddRow, DeleteRows
└── presentation/
    ├── bloc/            → OrdersTodayBloc + events + states
    ├── pages/           → OrdersTodayPage, OrdersViewPage
    └── widgets/         → OrdersTable, OrdersToolbar, OrdersEmptyState,
                           OrdersErrorState, OrdersFooter, VersionWarningBanner
```

### Flujo actual de datos

1. `OrdersTodayRepositoryImpl` usa `ExcelDriveDataSource` para descargar el
   `.xlsx` del día de Drive como `Uint8List`.
2. Pasa los bytes al `ExcelParserService` (basado en paquete `excel`) que
   produce un `OrderSheet` con `products` (cabeceras) y `rows` (lista de
   `OrderRow` con `clientName` + `quantities`).
3. Las operaciones de escritura (actualizar celda, renombrar cliente, etc.)
   siguen el mismo patrón: descargar → parsear → modificar en memoria →
   re-encodificar → subir.

### Modelo de dominio actual (transpuesto respecto al nuevo requisito)

- `OrderSheet`: `products: List<String>` (cabeceras de columna) +
  `rows: List<OrderRow>` (una por cliente).
- `OrderRow`: `clientName: String` + `quantities: Map<String, num>`.

En la nueva estructura, los ejes se invierten: productos en filas, clientes en
columnas. El modelo debe reflejar esto.

### Dependencias relevantes

- `googleapis: ^14.0.0` → incluye `SheetsApi`, `DriveApi`.
- `googleapis_auth: ^2.0.0` → autenticación OAuth.
- `excel: ^4.0.6` → parseo local de `.xlsx` (dejará de usarse para esta
  feature).
- `GoogleAuthService` → provee `AutoRefreshingAuthClient`.
- `SettingsLocalDataSource` → provee IDs de subcarpetas de Drive
  (`historicoFolderId`, `plantillasFolderId`, `internoFolderId`).
- Features `clients` y `products` → entidades `Client` y `Product` con campos
  `isActive`, `orderInNewOrders`. **No tienen campo `showInNewOrders`** (ver
  Suposiciones).

### Restricciones

- No se deben introducir dependencias nuevas; `googleapis` ya incluye
  `SheetsApi`.
- El paquete `excel` se mantiene en `pubspec.yaml` (otras features pueden
  usarlo), pero esta feature dejará de depender de él.
- El `ExcelParserService` (core) no debe eliminarse; otras features lo consumen.
  Pero `orders_today` dejará de usarlo.

## 3) Objetivo técnico

- Reemplazar el flujo de datos de `orders_today` (descargar/subir `.xlsx` +
  parseo local) por lectura/escritura directa vía Google Sheets API.
- Transponer el modelo de dominio: productos en filas, clientes en columnas.
- Implementar la creación del sheet del día: copia de plantilla versionada +
  escritura de fecha, clientes, productos, fórmulas y formato condicional.
- Implementar auto-refresh por polling de `modifiedTime`.
- Mantener compatibilidad con el contrato BLoC → UI (adaptar states/events sin
  romper el flujo de navegación existente).

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear un **nuevo datasource** `OrdersSheetDataSource` que opere directamente con
la Google Sheets API (`SheetsApi`) para leer/escribir celdas, fórmulas y formato
condicional, y con Drive API (`DriveApi`) para copiar plantillas y consultar
`modifiedTime`. Este datasource reemplaza la combinación actual
`ExcelDriveDataSource` + `ExcelParserService` en el repositorio de
`orders_today`.

### Componentes / módulos / servicios afectados

| Componente                             | Tipo de cambio                                                        |
| -------------------------------------- | --------------------------------------------------------------------- |
| `OrderSheet` (entity)                  | Rediseño: transponer ejes                                             |
| `OrderRow` (entity)                    | Eliminar o renombrar a `ProductRow`                                   |
| `VersionCheckResult` (entity)          | Sin cambios inmediatos                                                |
| `OrdersTodayRepository` (contrato)     | Adaptar firma de métodos: simplificar                                 |
| `OrdersTodayRepositoryImpl`            | Reescribir: usar nuevo datasource                                     |
| `ExcelDriveDataSource`                 | Dejar de usar en esta feature (no eliminar)                           |
| `ExcelParserService`                   | Dejar de usar en esta feature (no eliminar)                           |
| **Nuevo:** `OrdersSheetDataSource`     | Crear: operaciones Sheets API                                         |
| **Nuevo:** `OrdersSheetDataSourceImpl` | Crear: implementación                                                 |
| `GetTodayOrders` (use case)            | Adaptar params si cambia contrato                                     |
| `CreateTodayFile` (use case)           | Adaptar: ya no es simple copia                                        |
| Use cases de edición                   | Evaluar: fuera de alcance funcional pero pueden mantenerse            |
| `OrdersTodayBloc`                      | Adaptar: nuevo evento auto-refresh, quitar eventos de edición local   |
| `OrdersTodayEvent`                     | Añadir `OrdersTodayAutoRefreshTriggered`; eliminar eventos de edición |
| `OrdersTodayState`                     | Simplificar: quitar `hasUnsavedChanges`                               |
| `OrdersTodayPage`                      | Adaptar: integrar timer de polling                                    |
| `OrdersTable` (widget)                 | Rediseñar: transponer ejes (productos en filas, clientes en columnas) |
| `orders_today_module.dart` (DI)        | Actualizar registros                                                  |

### Contratos e interfaces

#### Nuevo datasource: `OrdersSheetDataSource`

```dart
abstract class OrdersSheetDataSource {
  /// Lee todos los datos del sheet del día.
  /// Retorna null si el sheet no existe en historico/.
  Future<OrderSheetData?> readTodaySheet(String historicoFolderId, String date);

  /// Copia la plantilla de mayor versión y escribe fecha, clientes,
  /// productos, fórmulas y formato condicional.
  /// Retorna el spreadsheetId del nuevo sheet.
  Future<String> createTodaySheet({
    required String plantillasFolderId,
    required String historicoFolderId,
    required String date,
    required String formattedDate,
    required List<String> clientNames,
    required List<String> productNames,
  });

  /// Consulta el modifiedTime de un archivo en Drive.
  Future<DateTime?> getFileModifiedTime(String fileId);

  /// Busca el fileId del sheet del día en historico/.
  Future<String?> findTodaySheetId(String historicoFolderId, String date);
}
```

Donde `OrderSheetData` es un DTO de la capa data (no una entity):

```dart
class OrderSheetData {
  final String spreadsheetId;
  final String date;
  final List<String> clientNames;
  final List<String> productNames;
  final List<List<num>> quantities; // [productIdx][clientIdx]
  final List<num> pedidos;   // por producto
  final List<num> stocks;    // por producto
  final List<num> quedan;    // por producto
  final List<int> clientOrders; // números de orden (fila 2)
  final DateTime? modifiedTime;
}
```

#### Entity `OrderSheet` (dominio) — rediseño

```dart
class OrderSheet extends Equatable {
  final String date;
  final List<String> clients;         // nombres de clientes (columnas)
  final List<String> products;        // nombres de productos (filas)
  final List<List<num>> quantities;   // [productIdx][clientIdx]
  final List<num> pedidos;            // sumatorio por producto
  final List<num> stocks;             // stock por producto
  final List<num> quedan;             // stock - pedidos
  final List<int> clientOrders;       // número de orden por cliente
  final String? spreadsheetId;
  final DateTime? modifiedTime;
}
```

La entity `OrderRow` deja de ser necesaria (se puede eliminar o deprecar).

#### Repositorio (contrato simplificado)

```dart
abstract class OrdersTodayRepository {
  Future<Either<Failure, OrderSheet?>> getTodayOrders(DateTime date);
  Future<Either<Failure, OrderSheet>> createTodaySheet(DateTime date);
  Future<Either<Failure, DateTime?>> getSheetModifiedTime(DateTime date);
}
```

Los métodos de edición (`updateCellValue`, `renameClient`, `addRow`,
`deleteRows`, `saveOrders`, `saveAsNewExcel`, `updateFileStructure`) se eliminan
del contrato: quedan fuera de alcance funcional (la edición se realiza
directamente en Google Sheets por los operadores). Si se quieren preservar para
uso futuro, pueden mantenerse pero no se implementan ni se conectan al BLoC en
esta iteración.

### Flujo de datos o de control

#### Flujo 1: Carga del sheet del día

```
UI (OrdersTodayPage)
  → BLoC: OrdersTodayLoadRequested
    → UseCase: GetTodayOrders(date)
      → Repository: getTodayOrders(date)
        → OrdersSheetDataSource.findTodaySheetId(historicoFolderId, "YYYY-MM-DD")
        → Si null → return Right(null) → BLoC emite OrdersTodayNoFile
        → Si existe → OrdersSheetDataSource.readTodaySheet(...)
          → SheetsApi.spreadsheets.values.get(spreadsheetId, rango)
          → Parsear filas/columnas → OrderSheetData (DTO)
          → Mapear a OrderSheet (entity)
          → Drive API: files.get para obtener modifiedTime
        → return Right(OrderSheet) → BLoC emite OrdersTodayLoaded
```

#### Flujo 2: Creación del sheet del día

```
UI: botón "Crear pedido de hoy"
  → BLoC: OrdersTodayCreateFileRequested
    → UseCase: CreateTodayFile(date)
      → Repository: createTodaySheet(date)
        → Leer clientes activos: ClientsRepository o acceso directo a
          spreadsheet configuracion (hoja clientes)
        → Leer productos activos: ProductsRepository o acceso directo a
          spreadsheet configuracion (hoja productos)
        → OrdersSheetDataSource.createTodaySheet(...)
          → Drive API: listFiles(plantillasFolderId, namePrefix: "plantilla_v")
            → parsear versión numérica, seleccionar max
          → Drive API: files.copy(templateId, historicoFolderId, "YYYY-MM-DD")
          → Sheets API: spreadsheets.values.update(...)
            → A3: fecha formateada
            → Fila 2: [1, 2, 3, ...]
            → Fila 3: [fecha, cliente1, cliente2, ..., PEDIDOS, STOCKS, QUEDAN]
            → Columna A (filas 4+): [producto1, producto2, ...]
            → Celdas de datos: 0
            → Columna PEDIDOS: fórmulas =SUM(B4:X4)
            → Columna QUEDAN: fórmulas =H4-G4 (STOCKS-PEDIDOS)
          → Sheets API: spreadsheets.batchUpdate(...)
            → addConditionalFormatRule para columna QUEDAN:
              - BooleanRule: si valor < 0 → texto rojo
              - BooleanRule: si valor >= 0 → texto verde
        → Leer datos del sheet recién creado → OrderSheet
        → return Right(OrderSheet)
```

#### Flujo 3: Auto-refresh por polling

```
OrdersTodayPage (StatefulWidget)
  → initState: si estado es Loaded, iniciar Timer.periodic(30s)
  → cada tick:
    → BLoC: OrdersTodayCheckModifiedRequested(currentModifiedTime)
      → Repository: getSheetModifiedTime(date)
        → OrdersSheetDataSource.getFileModifiedTime(spreadsheetId)
          → Drive API: files.get(fileId, $fields: "modifiedTime")
      → Si modifiedTime > currentModifiedTime:
        → BLoC: emitir recarga automática (dispatch OrdersTodayRefreshRequested)
      → Si igual: no hacer nada
  → dispose / salir de pantalla: cancelar Timer
  → onResume (WidgetsBindingObserver): reanudar Timer si estaba en Loaded
  → onPause: cancelar Timer
```

### Gestión de errores y validaciones

| Escenario                              | Failure                 | Comportamiento UI                                                       |
| -------------------------------------- | ----------------------- | ----------------------------------------------------------------------- |
| Google Drive no configurado            | `ConfigNotFoundFailure` | Estado error: "Configura Google Drive en Ajustes"                       |
| Plantilla no encontrada                | `FileSystemFailure`     | Estado error: "No se encontró plantilla"                                |
| Spreadsheet configuración no accesible | `ServerFailure`         | Error: "No se pudo acceder a datos de configuración"                    |
| Error de red / API Google              | `ServerFailure`         | Error descriptivo + botón reintentar                                    |
| Token expirado no renovable            | `AuthExpiredFailure`    | Derivar a re-autenticación                                              |
| Sheet del día con formato inválido     | `EntityMappingFailure`  | Error: "Formato de hoja inválido"                                       |
| Polling falla silenciosamente          | —                       | Log warning, no mostrar error al usuario, reintentar en el próximo tick |

### Consideraciones de compatibilidad o migración

- **`ExcelDriveDataSource` y `ExcelParserService`** siguen existiendo en el
  proyecto. Solo se desconectan de `orders_today`. Otras features (ej:
  `orders_history`) pueden seguir usándolos.
- **`ExcelLocalDataSource`**: ya no se registra en el DI de `orders_today` si no
  la usa nadie más. Verificar antes de eliminar.
- **Métodos de edición en el repositorio**: se eliminan del contrato y del BLoC.
  Si en el futuro se necesita edición desde la app, se re-añadirían con la API
  de Sheets (no con el flujo `.xlsx`).
- **Use cases obsoletos**: `UpdateCellValue`, `RenameClient`, `AddRow`,
  `DeleteRows`, `SaveOrders`, `SaveAsNewExcel`, `UpdateFileStructure` → eliminar
  o marcar como deprecated.
- **`OrdersTable` widget**: la transposición de ejes requiere un rediseño
  significativo del widget. Los productos pasan a ser filas y los clientes
  columnas. Las columnas de selección (checkboxes) y edición in-line ya no
  aplican (se elimina la edición desde la app).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                              | Propósito                                       |
| -------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source.dart`      | Contrato del nuevo datasource Google Sheets API |
| `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source_impl.dart` | Implementación con `SheetsApi` + `DriveApi`     |
| `lib/features/orders_today/data/dto/order_sheet_data.dart`                             | DTO para datos crudos del sheet                 |

### Artefactos a modificar

| Artefacto                                                                       | Cambio esperado                                                                                                                                                                  |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/domain/entities/order_sheet.dart`                    | Transponer modelo: productos en filas, clientes en columnas; añadir campos `pedidos`, `stocks`, `quedan`, `clientOrders`; renombrar `filePath` a `spreadsheetId`                 |
| `lib/features/orders_today/domain/repositories/orders_today_repository.dart`    | Simplificar: dejar `getTodayOrders`, cambiar `createTodayFile` a `createTodaySheet`, añadir `getSheetModifiedTime`; eliminar métodos de edición                                  |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart` | Reescribir: usar `OrdersSheetDataSource` en vez de `ExcelDriveDataSource` + `ExcelParserService`; inyectar repositorios/datasources de clientes y productos para creación        |
| `lib/features/orders_today/domain/usecases/create_today_file.dart`              | Adaptar a nuevo contrato del repositorio                                                                                                                                         |
| `lib/features/orders_today/domain/usecases/get_today_orders.dart`               | Sin cambios funcionales; el retorno ya es `Either<Failure, OrderSheet?>`                                                                                                         |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`            | Eliminar handlers de edición; añadir handler de auto-refresh check; simplificar                                                                                                  |
| `lib/features/orders_today/presentation/bloc/orders_today_event.dart`           | Eliminar eventos de edición; añadir `OrdersTodayCheckModifiedRequested`                                                                                                          |
| `lib/features/orders_today/presentation/bloc/orders_today_state.dart`           | Eliminar `hasUnsavedChanges`; añadir `OrdersTodayErrorType.driveNotConfigured`, `OrdersTodayErrorType.configNotAvailable`                                                        |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`           | Integrar `Timer.periodic` para polling; eliminar lógica de unsaved changes guard; eliminar `save_as_new_excel`                                                                   |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`              | Rediseñar: productos en filas (columna A fija), clientes en columnas (fila header fija); eliminar checkboxes y edición inline; añadir columnas Pedidos/Stocks/Quedan con estilos |
| `lib/features/orders_today/presentation/widgets/orders_toolbar.dart`            | Simplificar: quitar botones de edición (guardar, añadir fila, eliminar filas); mantener recarga y búsqueda                                                                       |
| `lib/features/orders_today/presentation/widgets/orders_footer.dart`             | Adaptar o eliminar si ya no aplica                                                                                                                                               |
| `lib/app/di/modules/orders_today_module.dart`                                   | Registrar `OrdersSheetDataSource`; eliminar registro de `ExcelLocalDataSource` si no es usada por otra feature; actualizar registros de use cases y BLoC                         |

### Artefactos a retirar o reemplazar

| Artefacto                                                                            | Motivo                                              |
| ------------------------------------------------------------------------------------ | --------------------------------------------------- |
| `lib/features/orders_today/domain/entities/order_row.dart`                           | Modelo transpuesto; ya no se usan filas por cliente |
| `lib/features/orders_today/domain/usecases/update_cell_value.dart`                   | Edición desde app fuera de alcance                  |
| `lib/features/orders_today/domain/usecases/rename_client.dart`                       | Edición desde app fuera de alcance                  |
| `lib/features/orders_today/domain/usecases/add_row.dart`                             | Edición desde app fuera de alcance                  |
| `lib/features/orders_today/domain/usecases/delete_rows.dart`                         | Edición desde app fuera de alcance                  |
| `lib/features/orders_today/domain/usecases/save_orders.dart`                         | Edición desde app fuera de alcance                  |
| `lib/features/orders_today/domain/usecases/save_as_new_excel.dart`                   | Edición desde app fuera de alcance                  |
| `lib/features/orders_today/domain/usecases/update_file_structure.dart`               | Versionado fuera de alcance en esta iteración       |
| `lib/features/orders_today/domain/entities/version_check_result.dart`                | Versionado fuera de alcance                         |
| `lib/features/orders_today/presentation/widgets/version_warning_banner.dart`         | Versionado fuera de alcance                         |
| `lib/features/orders_today/presentation/pages/orders_view_page.dart`                 | Multi-window view ya no aplica sin edición          |
| `lib/features/orders_today/data/datasources/local/excel_local_data_source.dart`      | Ya no se usa desde `orders_today`                   |
| `lib/features/orders_today/data/datasources/local/excel_local_data_source_impl.dart` | Ya no se usa desde `orders_today`                   |

> **Nota:** No eliminar `ExcelDriveDataSource` ni `ExcelParserService` de
> `core/services/` — pueden ser usados por otras features.

## 6) Estrategia de implementación

### Paso 1: Crear DTO y nuevo datasource

1. Crear `OrderSheetData` (DTO).
2. Crear contrato `OrdersSheetDataSource`.
3. Implementar `OrdersSheetDataSourceImpl`:
   - `findTodaySheetId`: usar `DriveApi.files.list` con query por nombre +
     carpeta.
   - `readTodaySheet`: usar `SheetsApi.spreadsheets.values.get` para leer rango
     completo; parsear estructura (fila 2 = órdenes, fila 3 = clientes, col A
     desde fila 4 = productos, celdas = cantidades, últimas 3 cols =
     pedidos/stocks/quedan).
   - `createTodaySheet`: copiar plantilla (Drive API) + escribir datos (Sheets
     API `values.batchUpdate` con `valueInputOption: USER_ENTERED` para
     fórmulas) + crear formato condicional (Sheets API
     `spreadsheets.batchUpdate` con `AddConditionalFormatRuleRequest`).
   - `getFileModifiedTime`: usar `DriveApi.files.get` con
     `$fields:
     modifiedTime`.

### Paso 2: Rediseñar entidad de dominio

1. Modificar `OrderSheet`: nuevos campos (`clients`, `quantities` como
   `List<List<num>>`, `pedidos`, `stocks`, `quedan`, `clientOrders`,
   `spreadsheetId`).
2. Eliminar `OrderRow`.
3. Eliminar `VersionCheckResult`.

### Paso 3: Simplificar contrato del repositorio

1. Reducir `OrdersTodayRepository` a 3 métodos: `getTodayOrders`,
   `createTodaySheet`, `getSheetModifiedTime`.
2. Eliminar use cases obsoletos.

### Paso 4: Reescribir repositorio impl

1. Reemplazar dependencias: `OrdersSheetDataSource` en lugar de
   `ExcelDriveDataSource` + `ExcelParserService`.
2. Para `createTodaySheet`: obtener clientes y productos activos. Opciones:
   - **Opción A (recomendada):** Inyectar el datasource de Google Sheets de
     `settings` para leer directamente las hojas `clientes` y `productos` del
     spreadsheet `configuracion`. Esto evita crear una dependencia circular
     entre features.
   - **Opción B:** Inyectar `ClientsRepository` y `ProductsRepository`. Más
     limpio semánticamente pero introduce dependencia entre features.
   - **Decisión sugerida:** Opción A — crear un datasource compartido en core o
     reutilizar un servicio de lectura de Google Sheets que pueda leer rangos
     arbitrarios de cualquier spreadsheet.
3. Mapear DTO a entity.

### Paso 5: Adaptar BLoC y eventos/estados

1. Eliminar eventos de edición del BLoC.
2. Añadir evento `OrdersTodayCheckModifiedRequested`.
3. Eliminar `hasUnsavedChanges` del estado.
4. Implementar handler para check de `modifiedTime`.

### Paso 6: Rediseñar presentación

1. Integrar `Timer.periodic` en `OrdersTodayPage` para polling.
2. Rediseñar `OrdersTable`: transponer ejes, eliminar edición inline,
   implementar cabeceras fijas (columna A + fila header), añadir columnas
   resumen con estilos.
3. Simplificar `OrdersToolbar`.
4. Eliminar widgets obsoletos (`VersionWarningBanner`, `OrdersViewPage`,
   `OrdersFooter` si no aplica).

### Paso 7: Actualizar DI

1. Registrar `OrdersSheetDataSource` / `OrdersSheetDataSourceImpl`.
2. Actualizar constructor de `OrdersTodayRepositoryImpl`.
3. Eliminar registros de use cases obsoletos.
4. Actualizar constructor de `OrdersTodayBloc`.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (el DTO alimenta el mapeo a entity).
- Paso 3 depende de Paso 2 (contrato usa las entities nuevas).
- Paso 4 depende de Paso 1 + 3.
- Paso 5 depende de Paso 3 (use cases).
- Paso 6 depende de Paso 2 + 5 (entity + BLoC).
- Paso 7 depende de todos los anteriores.

### Puntos delicados

- **Selección de plantilla**: el sort actual
  `files.sort((a, b) =>
  b.name.compareTo(a.name))` usa orden lexicográfico, lo
  cual falla si hay más de 9 versiones (`v10` < `v2` lexicográficamente). Se
  debe parsear el número de versión como entero y ordenar numéricamente.
- **Fórmulas**: las fórmulas deben escribirse con
  `valueInputOption:
  USER_ENTERED` para que Google Sheets las interprete. Si
  se usa `RAW`, se almacenan como texto literal.
- **Formato condicional**: requiere `spreadsheets.batchUpdate` con requests de
  tipo `AddConditionalFormatRuleRequest`. El rango debe calcularse dinámicamente
  según el número de productos.
- **Obtención de clientes/productos activos**: no existe un campo
  `showInNewOrders` en las entidades `Client` ni `Product` actualmente. Si la
  hoja de `configuracion` tiene esta columna, el datasource que lea los datos
  debe filtrar directamente desde los datos crudos del sheet. Alternativa:
  añadir el campo a las entidades en la iteración correspondiente
  (`clients-data-enrichment` / `products-google-sheet-source`).
- **Fecha en español**: usar `DateFormat("EEEE, d MMMM", "es")` con `intl` y
  convertir a mayúsculas (`toUpperCase()`).
- **Subcarpeta `historico/`**: si no existe en Drive, debe crearse antes de
  copiar la plantilla. Verificar con `DriveApi.files.list` o manejar error al
  copiar.

## 7) Estrategia de validación

### Tests unitarios

- **`OrdersSheetDataSourceImpl`**: mockear `SheetsApi` y `DriveApi`; verificar
  que `readTodaySheet` parsea correctamente la estructura del sheet; verificar
  que `createTodaySheet` llama las APIs en el orden correcto con los parámetros
  esperados (fórmulas, formato condicional).
- **`OrdersTodayRepositoryImpl`**: mockear `OrdersSheetDataSource`; verificar
  mapeo DTO → entity; verificar gestión de errores (null sheet, server error,
  config not found).
- **`OrdersTodayBloc`**: mockear use cases; verificar transiciones de estado:
  Initial → Loading → Loaded/NoFile/Error; verificar auto-refresh trigger.
- **`OrderSheet` entity**: verificar `Equatable` props.

### Tests de widget

- **`OrdersTable`**: verificar renderizado con datos mock (productos en filas,
  clientes en columnas); verificar scroll horizontal/vertical; verificar
  cabeceras fijas.
- **`OrdersTodayPage`**: verificar que muestra estado vacío cuando Drive no
  configurado; verificar que muestra botón "Crear pedido" cuando no hay sheet.

### Verificación manual

- Crear un sheet del día real desde la app y verificar en Google Sheets que:
  - La fecha en A3 es correcta.
  - Los clientes aparecen en el orden correcto.
  - Los productos aparecen en el orden correcto.
  - Las fórmulas de PEDIDOS (SUM) funcionan.
  - La fórmula QUEDAN (STOCKS - PEDIDOS) funciona.
  - El formato condicional de QUEDAN funciona (rojo/verde).
- Modificar una celda directamente en Google Sheets y verificar que la app
  detecta el cambio vía polling y recarga los datos.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                         | Probabilidad | Impacto |
| ------------------------------------------------------------------------------ | ------------ | ------- |
| Cuota de API de Google Sheets/Drive excedida en entornos con polling frecuente | Baja         | Medio   |
| Latencia de red en lecturas del sheet (especialmente sheets grandes)           | Media        | Bajo    |
| Campo `showInNewOrders` no existe aún en entidades Client/Product              | Alta         | Medio   |
| Formato condicional complejo vía API es frágil ante cambios de estructura      | Baja         | Bajo    |

### Impacto potencial

- La pantalla "Pedidos de hoy" deja de funcionar con archivos `.xlsx` locales.
  Esto es intencional pero debe coordinarse con la eliminación del modo local.
- Los use cases de edición se eliminan; si algún test o módulo los referencia,
  fallará la compilación.

### Mitigación

- **Cuota API**: el polling de `modifiedTime` es una llamada `files.get` muy
  ligera (no lee contenido). El intervalo de 30s es conservador. Se puede
  aumentar si es necesario.
- **`showInNewOrders`**: si el campo no se ha añadido a las entidades cuando se
  implementa esta feature, el datasource puede filtrar directamente de los datos
  crudos del sheet `configuracion`, leyendo la columna "Mostrar en nuevos
  pedidos" manualmente. Esto es aceptable como solución temporal.
- **Formato condicional**: encapsular la lógica de creación de reglas en un
  helper que calcule rangos dinámicamente.

### Plan de rollback

- Los archivos fuente actuales se preservan en el historial de Git.
- Si es necesario revertir, basta con restaurar el commit anterior; no hay
  migraciones de datos ni cambios destructivos en almacenamiento.
- El `ExcelDriveDataSource` y `ExcelParserService` no se eliminan del proyecto,
  facilitando la reversión.

## 9) Suposiciones

- **S-01:** Las features `clients-data-enrichment` y
  `products-google-sheet-source` se implementan antes o en paralelo. Si no, se
  accederá directamente al spreadsheet `configuracion` para leer clientes y
  productos activos, sin pasar por los repositorios de esas features.
- **S-02:** El campo "Mostrar en nuevos pedidos" existe en la hoja del
  spreadsheet `configuracion`. Si no existe en las entidades de dominio, se
  filtra directamente desde los datos crudos.
- **S-03:** La cuenta de Google autenticada tiene permisos de lectura y
  escritura sobre los spreadsheets en el Drive configurado.
- **S-04:** El spreadsheet `configuracion` y sus hojas `clientes`/`productos` ya
  existen y tienen la estructura esperada (cabeceras en fila 1 o 3 según los
  DTOs existentes).
- **S-05:** La plantilla en `plantillas/` puede ser un Google Sheet nativo o un
  `.xlsx` subido. `Drive API files.copy` funciona en ambos casos y produce un
  Google Sheet nativo como resultado.
- **S-06:** El intervalo de polling de 30 segundos es aceptable para el usuario.

## 10) Preguntas abiertas

- **PA-01:** ¿Se deben implementar las features `clients-data-enrichment` y
  `products-google-sheet-source` antes de esta? Si no, ¿cómo se prefiere acceder
  a los datos de clientes/productos activos (datasource directo vs.
  repositorio)?
- **PA-02:** ¿Se elimina definitivamente la dependencia de
  `ExcelLocalDataSource` del módulo DI de `orders_today`, o se mantiene por si
  se necesita un modo offline en el futuro?

## 11) Notas para implementación

- Respetar Clean Architecture: el nuevo `OrdersSheetDataSource` pertenece a
  `data/datasources/remote/`. No debe haber imports de `googleapis` en domain ni
  presentation.
- Usar `Either<Failure, T>` en todos los retornos del repositorio.
- Las fórmulas de Google Sheets usan el formato del locale del spreadsheet.
  Verificar si el spreadsheet está en español (separador `;` en fórmulas) o
  inglés (separador `,`). Recomendación: crear el sheet con locale `en_US` para
  usar `,` o detectar el locale del spreadsheet copiado.
- El `Timer.periodic` para polling debe declararse en el `State` del widget, no
  en el BLoC, para poder cancelarlo en `dispose`. El BLoC solo procesa el evento
  y decide si emitir recarga.
- Considerar usar `WidgetsBindingObserver` para detectar `AppLifecycleState` y
  pausar/reanudar el polling (aunque en desktop el ciclo de vida es diferente;
  evaluar si basta con el `dispose` del widget).
- La lógica de parseo de versión de plantilla debe extraerse del sort
  lexicográfico actual a un `RegExp(r'plantilla_v(\d+)')` con parse de `int`.
- Para las cabeceras fijas en la tabla, considerar `Table` con
  `ScrollController` sincronizados o un paquete como `linked_scroll_controller`
  (ya que `DataTable` no soporta freeze nativamente). Alternativamente, usar dos
  `SingleChildScrollView` coordinados.
- Secuencia sugerida: implementar primero el datasource + repo + BLoC (sin UI),
  validar con tests unitarios, y luego adaptar la presentación.
- **Estado: Listo para implementación**
