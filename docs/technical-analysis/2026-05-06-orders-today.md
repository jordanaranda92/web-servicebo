# Technical Analysis: Pedidos de hoy

- **Fecha:** 2026-05-06
- **Identificador:** orders-today
- **Fuente:** docs/functional-analysis/2026-05-06-orders-today.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- **Enfoque:** Construir las capas `domain/` y `data/` de la feature
  `orders_today` siguiendo Clean Architecture feature-first, reemplazar el
  placeholder de `presentation/` y añadir la dependencia `excel` para
  lectura/escritura de archivos `.xlsx`.
- **Áreas impactadas:** Feature `orders_today` (nueva lógica completa), módulo
  DI (`injection.dart`), i18n (nuevas claves ARB), `pubspec.yaml` (nueva
  dependencia).
- **Riesgo general estimado:** Bajo. La feature es autocontenida, no modifica
  otras features, y la lectura de ficheros locales es una operación directa en
  entornos desktop.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con capas `domain/`, `data/`,
  `presentation/`
- Estado gestionado con **BLoC/Cubit** (paquete `flutter_bloc`)
- DI con **GetIt** (módulos separados por feature en `lib/app/di/modules/`)
- Errores funcionales con **fpdart** (`Either<Failure, T>`)
- Excepciones técnicas con jerarquía `AppException` → capturadas en
  `RepositoryImpl` → convertidas a `Failure`
- Use cases extienden `UseCase<Type, Params>` de `lib/core/usecase/usecase.dart`

### Feature `orders_today` — estado actual

- Solo existe `presentation/pages/orders_today_page.dart` como placeholder
- No tiene capas `domain/` ni `data/`

### Feature `settings` — dependencia de lectura

- `SettingsRepository.getWorkFolder()` → `Either<Failure, WorkFolderConfig?>`
- `WorkFolderConfig` expone `path` (String) e `isValid` (bool)
- La ruta se persiste en `SharedPreferences` vía `SettingsLocalDataSourceImpl`
- El `WorkFolderCubit` ya está registrado como `registerFactory` en DI

### Infraestructura existente

- `Failure`: `NetworkFailure`, `ServerFailure`, `CacheFailure`,
  `EntityMappingFailure`, `InternalFailure`
- `AppException`: `ServerException`, `CacheException`, `NetworkException`,
  `NotFoundException`, `ParsingException`
- Widget `PageHeader` acepta `actions: List<Widget>` → se puede usar para el
  botón de recarga
- i18n: un único ARB (`app_es.arb`), generación automática con
  `flutter gen-l10n`
- Plataformas: macOS, Windows → `dart:io` disponible para operaciones de
  ficheros

### Dependencias actuales relevantes

- No hay ningún paquete de manipulación de Excel en `pubspec.yaml`

## 3) Objetivo técnico

- Crear la estructura completa de la feature `orders_today` (domain, data,
  presentation)
- Leer y parsear archivos `.xlsx` desde el sistema de ficheros local
- Crear archivos `.xlsx` copiando una plantilla
- Comparar cabeceras entre plantilla y archivo del día para detectar cambios de
  versión
- Actualizar la estructura de un archivo Excel existente según la plantilla
  actual
- Calcular totalizaciones (por fila y por columna) en la capa de presentación
- Presentar datos en tabla con scroll horizontal, estados de carga/error/vacío y
  banner de versión
- **Limitación:** No se editan datos del Excel desde la app (solo lectura +
  creación + reestructuración)

## 4) Diseño técnico de la solución

### Enfoque propuesto

La feature se estructura en 3 capas siguiendo los patrones existentes del
proyecto. La lógica de acceso a ficheros Excel se encapsula en un datasource
local. Se utilizan 3 use cases para las operaciones principales. El BLoC
gestiona los estados de la pantalla.

### Componentes / módulos / servicios afectados

| Componente                                    | Acción                                                    |
| --------------------------------------------- | --------------------------------------------------------- |
| `lib/features/orders_today/domain/`           | Crear (entities, repository contrato, use cases)          |
| `lib/features/orders_today/data/`             | Crear (datasource local, repository impl)                 |
| `lib/features/orders_today/presentation/`     | Modificar (reemplazar placeholder, añadir BLoC y widgets) |
| `lib/app/di/modules/orders_today_module.dart` | Crear (módulo DI)                                         |
| `lib/app/di/injection.dart`                   | Modificar (registrar módulo)                              |
| `lib/app/localization/l10n/app_es.arb`        | Modificar (nuevas claves i18n)                            |
| `pubspec.yaml`                                | Modificar (añadir dependencia `excel`)                    |
| `lib/core/error/failure.dart`                 | Modificar (añadir `FileSystemFailure`)                    |
| `lib/core/error/exceptions.dart`              | Modificar (añadir `FileSystemException`)                  |

### Entidades de dominio

```
OrderSheet
├── products: List<String>           // Cabeceras de productos (del Excel)
├── rows: List<OrderRow>             // Filas de datos
└── isOutdated: bool                 // Indica si la estructura difiere de la plantilla

OrderRow
├── clientName: String
└── quantities: Map<String, num>     // producto → cantidad

VersionCheckResult
├── isOutdated: bool
├── templateProducts: List<String>?  // Productos de la plantilla (null si no existe plantilla)
└── fileProducts: List<String>       // Productos del archivo actual
```

- `OrderSheet` y `OrderRow` son entities inmutables con `Equatable`
- `VersionCheckResult` es un value object de dominio para el resultado de la
  comparación

### Contratos e interfaces

**Repository (domain):**

```dart
abstract class OrdersTodayRepository {
  /// Lee el archivo del día. Devuelve null si no existe.
  Future<Either<Failure, OrderSheet?>> getTodayOrders(String workFolderPath, DateTime date);

  /// Crea el archivo del día copiando la plantilla.
  Future<Either<Failure, OrderSheet>> createTodayFile(String workFolderPath, DateTime date);

  /// Compara cabeceras del archivo del día con la plantilla.
  Future<Either<Failure, VersionCheckResult>> checkVersion(String workFolderPath, DateTime date);

  /// Actualiza la estructura del archivo del día según la plantilla.
  Future<Either<Failure, OrderSheet>> updateFileStructure(String workFolderPath, DateTime date);
}
```

**DataSource local:**

```dart
abstract class ExcelLocalDataSource {
  /// Lee y parsea un archivo Excel. Lanza FileSystemException/ParsingException.
  OrderSheet readExcel(String filePath);

  /// Copia un archivo a otra ruta. Crea directorios intermedios.
  void copyFile(String sourcePath, String destinationPath);

  /// Lee solo las cabeceras (primera fila) de un archivo Excel.
  List<String> readHeaders(String filePath);

  /// Reescribe el archivo aplicando la nueva estructura de cabeceras.
  OrderSheet updateStructure(String filePath, List<String> newHeaders);

  /// Verifica si un archivo existe.
  bool fileExists(String filePath);
}
```

### Use Cases

| Use Case              | Params                                            | Return                         | Responsabilidad                                              |
| --------------------- | ------------------------------------------------- | ------------------------------ | ------------------------------------------------------------ |
| `GetTodayOrders`      | `GetTodayOrdersParams(workFolderPath, date)`      | `Either<Failure, OrderSheet?>` | Obtener los pedidos del día (o null si no existe el archivo) |
| `CreateTodayFile`     | `CreateTodayFileParams(workFolderPath, date)`     | `Either<Failure, OrderSheet>`  | Crear archivo del día desde plantilla y devolver los datos   |
| `UpdateFileStructure` | `UpdateFileStructureParams(workFolderPath, date)` | `Either<Failure, OrderSheet>`  | Reestructurar el archivo del día según plantilla actual      |

Cada use case recibe las params necesarias y delega en el repository. No se
necesita un use case separado para `checkVersion` porque la comprobación se
realiza como parte del flujo de `GetTodayOrders` dentro del BLoC (se puede
invocar directamente el repository desde el use case `GetTodayOrders` añadiendo
la info de versión al resultado, o bien el BLoC coordina ambas llamadas).

**Decisión de diseño:** El BLoC invoca `GetTodayOrders` y luego, si hay datos,
invoca `repository.checkVersion()` vía un segundo use case o directamente. Para
mantener la simplicidad y dado que `checkVersion` es una operación ligera de
lectura, se opta por que `GetTodayOrders` devuelva el `OrderSheet` incluyendo el
flag `isOutdated` (el repository internamente compara las cabeceras al cargar el
archivo).

### Flujo de datos o de control

**Flujo de carga (evento `LoadOrders`):**

```
UI (evento) → BLoC → GetTodayOrders(usecase)
  → OrdersTodayRepositoryImpl
    → SettingsRepository.getWorkFolder() [obtener path] (*)
    → ExcelLocalDataSource.fileExists(historicoPath)
    → Si existe:
        → ExcelLocalDataSource.readExcel(historicoPath)
        → ExcelLocalDataSource.fileExists(plantillaPath)
        → Si plantilla existe: ExcelLocalDataSource.readHeaders(plantillaPath) → comparar → isOutdated
        → Si no existe: isOutdated = false
        → Return OrderSheet(isOutdated: ...)
    → Si no existe: Return null
  → BLoC emite estado (Loaded / NoFile / Error)
```

(*) **Nota sobre la obtención del `workFolderPath`:** El BLoC necesita la ruta
de la carpeta de trabajo. Hay dos opciones:

1. El BLoC recibe el path como parámetro del evento (la UI lo obtiene del
   `WorkFolderCubit`/estado global).
2. El use case depende de `SettingsRepository` para obtenerlo internamente.

**Decisión:** Opción 1 — el path se pasa como parámetro. Es más simple, evita
acoplar `orders_today` con el repository de `settings`, y la UI ya tiene acceso
al estado de la carpeta de trabajo.

**Flujo de creación (evento `CreateFile`):**

```
UI (evento) → BLoC → CreateTodayFile(usecase)
  → OrdersTodayRepositoryImpl
    → ExcelLocalDataSource.fileExists(plantillaPath) → si no: NotFoundException
    → ExcelLocalDataSource.copyFile(plantilla → historico/yyyy-MM-dd.xlsx)
    → ExcelLocalDataSource.readExcel(nuevoArchivo)
    → Return OrderSheet
  → BLoC emite Loaded
```

**Flujo de actualización de estructura (evento `UpdateStructure`):**

```
UI (evento) → BLoC → UpdateFileStructure(usecase)
  → OrdersTodayRepositoryImpl
    → ExcelLocalDataSource.readHeaders(plantillaPath) → nuevas cabeceras
    → ExcelLocalDataSource.updateStructure(historicoPath, nuevasCabeceras)
    → Return OrderSheet actualizado
  → BLoC emite Loaded(isOutdated: false)
```

### Gestión de errores y validaciones

| Situación                  | Exception (data layer)           | Failure (domain)            | Estado BLoC                          |
| -------------------------- | -------------------------------- | --------------------------- | ------------------------------------ |
| Carpeta no configurada     | — (detectado en UI)              | —                           | `OrdersTodayNoFolder`                |
| Archivo no encontrado      | — (no es error, es flujo normal) | —                           | `OrdersTodayNoFile`                  |
| Plantilla no encontrada    | `NotFoundException`              | `FileSystemFailure`         | `OrdersTodayError(templateNotFound)` |
| Error de lectura/escritura | `FileSystemException` (nueva)    | `FileSystemFailure` (nueva) | `OrdersTodayError(fileSystemError)`  |
| Excel con formato inválido | `ParsingException`               | `EntityMappingFailure`      | `OrdersTodayError(invalidFormat)`    |
| Permisos insuficientes     | `FileSystemException`            | `FileSystemFailure`         | `OrdersTodayError(permissionDenied)` |

**Nuevos tipos de error a crear:**

- `FileSystemException extends AppException` — para errores de I/O de ficheros
- `FileSystemFailure extends Failure` — failure correspondiente

### Consideraciones de compatibilidad o migración

- No hay migración de datos: la feature es nueva
- La dependencia `excel` (paquete pub.dev) es pura Dart, compatible con todas
  las plataformas del proyecto
- No se modifica la feature `settings` ni su API; solo se consume en lectura
- Los archivos Excel creados por la app son compatibles con Excel/LibreOffice
  estándar

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                            | Propósito                                               |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| `lib/features/orders_today/domain/entities/order_sheet.dart`                         | Entity principal con productos, filas y flag de versión |
| `lib/features/orders_today/domain/entities/order_row.dart`                           | Entity de fila individual (cliente + cantidades)        |
| `lib/features/orders_today/domain/entities/version_check_result.dart`                | Value object resultado de comparación de versiones      |
| `lib/features/orders_today/domain/repositories/orders_today_repository.dart`         | Contrato del repository                                 |
| `lib/features/orders_today/domain/usecases/get_today_orders.dart`                    | Use case: cargar pedidos del día                        |
| `lib/features/orders_today/domain/usecases/create_today_file.dart`                   | Use case: crear archivo desde plantilla                 |
| `lib/features/orders_today/domain/usecases/update_file_structure.dart`               | Use case: reestructurar archivo según plantilla         |
| `lib/features/orders_today/data/datasources/local/excel_local_data_source.dart`      | Contrato del datasource de Excel                        |
| `lib/features/orders_today/data/datasources/local/excel_local_data_source_impl.dart` | Implementación con paquete `excel` y `dart:io`          |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`      | Implementación del repository                           |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`                 | BLoC principal                                          |
| `lib/features/orders_today/presentation/bloc/orders_today_event.dart`                | Eventos del BLoC                                        |
| `lib/features/orders_today/presentation/bloc/orders_today_state.dart`                | Estados del BLoC                                        |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`                   | Widget tabla con scroll horizontal y totalizaciones     |
| `lib/features/orders_today/presentation/widgets/orders_empty_state.dart`             | Widget estado sin archivo                               |
| `lib/features/orders_today/presentation/widgets/orders_error_state.dart`             | Widget estado de error                                  |
| `lib/features/orders_today/presentation/widgets/version_warning_banner.dart`         | Banner de versión desactualizada                        |
| `lib/app/di/modules/orders_today_module.dart`                                        | Módulo DI de la feature                                 |

### Artefactos a modificar

| Artefacto                                                             | Cambio esperado                                                     |
| --------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart` | Reemplazar placeholder por integración con BLoC y widgets reales    |
| `lib/app/di/injection.dart`                                           | Importar y registrar `registerOrdersTodayModule(sl)`                |
| `lib/app/localization/l10n/app_es.arb`                                | Añadir ~15 claves i18n para la feature                              |
| `pubspec.yaml`                                                        | Añadir dependencia `excel: ^4.0.6` (o versión más reciente estable) |
| `lib/core/error/failure.dart`                                         | Añadir `FileSystemFailure`                                          |
| `lib/core/error/exceptions.dart`                                      | Añadir `FileSystemException`                                        |

### Artefactos a retirar o reemplazar

| Artefacto                                    | Motivo                                                                 |
| -------------------------------------------- | ---------------------------------------------------------------------- |
| Contenido actual de `orders_today_page.dart` | Se reemplaza el placeholder por la implementación real (mismo archivo) |

## 6) Estrategia de implementación

### Orden recomendado

1. **Paso 1 — Dependencias y errores base**
   - Añadir `excel` a `pubspec.yaml`
   - Añadir `FileSystemFailure` a `lib/core/error/failure.dart`
   - Añadir `FileSystemException` a `lib/core/error/exceptions.dart`

2. **Paso 2 — Capa domain**
   - Crear entities: `OrderSheet`, `OrderRow`, `VersionCheckResult`
   - Crear contrato: `OrdersTodayRepository`
   - Crear use cases: `GetTodayOrders`, `CreateTodayFile`, `UpdateFileStructure`

3. **Paso 3 — Capa data**
   - Crear contrato e implementación de `ExcelLocalDataSource`
   - Crear `OrdersTodayRepositoryImpl`

4. **Paso 4 — Capa presentation (BLoC)**
   - Crear eventos, estados y BLoC `OrdersTodayBloc`

5. **Paso 5 — Capa presentation (UI)**
   - Crear widgets: `OrdersTable`, `OrdersEmptyState`, `OrdersErrorState`,
     `VersionWarningBanner`
   - Reemplazar `OrdersTodayPage`

6. **Paso 6 — DI e i18n**
   - Crear `orders_today_module.dart`
   - Registrar en `injection.dart`
   - Añadir claves i18n a `app_es.arb`

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (necesita `FileSystemFailure`)
- Paso 3 depende de Paso 1 (necesita paquete `excel`) y Paso 2 (necesita
  entities y contrato)
- Paso 4 depende de Paso 2 (necesita use cases)
- Paso 5 depende de Paso 4 (necesita BLoC) y Paso 6 (necesita i18n)
- Paso 6 depende de Pasos 2-4 (necesita clases para registrar en DI)

### Puntos delicados

- **Lectura del Excel:** La primera fila debe interpretarse como cabecera
  (productos), y la primera columna de cada fila como nombre de cliente. Celdas
  vacías o con tipos inesperados deben manejarse defensivamente.
- **Escritura del Excel en `updateStructure`:** Se modifica un archivo
  existente; hay que leer → transformar en memoria → sobreescribir. Si falla a
  mitad, el archivo puede quedar corrupto. Considerar escribir a un archivo
  temporal y luego renombrar.
- **Comparación de cabeceras:** Debe ser sensible al orden (mismos productos en
  distinto orden = versión desactualizada).
- **Concurrencia de acceso al fichero:** Si el usuario modifica el Excel
  externamente mientras la app está abierta, la recarga debe funcionar sin
  problemas. No se requiere file locking, pero sí capturar errores de lectura.
- **Ruta de ficheros:** Construir las rutas con `path` separator del sistema
  (`Platform.pathSeparator` o usar `package:path`). Actualmente el proyecto no
  incluye `package:path`, pero se puede usar `dart:io` `Platform.pathSeparator`
  directamente.

## 7) Estrategia de validación

### Tests unitarios recomendados

| Capa                   | Qué testear                                                            | Herramientas                                         |
| ---------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------- |
| Domain (entities)      | Igualdad (`Equatable`), construcción                                   | `flutter_test`                                       |
| Domain (use cases)     | Delegación correcta al repository, paso de params                      | `mocktail`                                           |
| Data (repository impl) | Conversión Exception→Failure, flujos happy/error, llamada a datasource | `mocktail`                                           |
| Data (datasource)      | Lectura/escritura de Excel con ficheros de prueba                      | `flutter_test`, ficheros `.xlsx` en `test/fixtures/` |
| Presentation (BLoC)    | Transiciones de estado para cada evento, flujos completos              | `bloc_test`, `mocktail`                              |

### Escenarios clave a cubrir

- Carga exitosa con archivo existente y plantilla coincidente
- Carga exitosa con archivo existente y plantilla diferente (isOutdated = true)
- Carga sin archivo del día (return null → estado NoFile)
- Creación exitosa desde plantilla
- Creación con plantilla inexistente (error)
- Actualización de estructura exitosa
- Errores de I/O (permisos, archivo corrupto)
- Excel vacío (solo cabeceras sin filas)
- Excel con celdas vacías o valores no numéricos
- Cálculo correcto de totales por fila y columna

### Validación manual recomendada

- Probar con archivos Excel reales generados por Excel/LibreOffice
- Verificar scroll horizontal con muchas columnas de productos
- Verificar creación de subcarpeta `historico/` cuando no existe
- Probar sin carpeta de trabajo configurada
- Verificar actualización de estructura con productos añadidos y eliminados

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                         | Probabilidad | Impacto |
| -------------------------------------------------------------- | ------------ | ------- |
| Incompatibilidad del paquete `excel` con algún formato `.xlsx` | Baja         | Medio   |
| Corrupción de archivo durante `updateStructure`                | Baja         | Alto    |
| Rendimiento con archivos Excel muy grandes                     | Baja         | Bajo    |

### Impacto potencial

- La nueva dependencia `excel` incrementa ligeramente el tamaño del build
- No afecta a otras features (cambio autocontenido)
- Los cambios en `core/error/` son aditivos (nuevas clases, no modifican las
  existentes)

### Mitigación

- **Corrupción:** Escribir a archivo temporal y renombrar (`File.rename`) para
  operación atómica
- **Incompatibilidad:** Testear con archivos generados por Excel y LibreOffice;
  el paquete `excel` es maduro y ampliamente usado
- **Rendimiento:** Los archivos de pedidos diarios son típicamente pequeños
  (decenas de filas); no se prevé problema

### Plan de rollback

- Revertir el commit. Al ser una feature nueva sin dependencias entrantes, el
  rollback es limpio.
- La única modificación en código compartido (`core/error/`) son adiciones que
  no afectan al resto.

## 9) Suposiciones

- El paquete `excel` (pub.dev) es adecuado para lectura y escritura de archivos
  `.xlsx` en entornos desktop
- El primer sheet del archivo Excel contiene los datos; se ignoran sheets
  adicionales
- La primera fila del Excel es siempre la cabecera con los nombres de productos
  empezando por la columna de "Cliente"
- La app se ejecuta en entorno desktop con acceso completo al sistema de
  ficheros (`dart:io`)
- No se requiere `package:path` como dependencia adicional; `dart:io`
  `Platform.pathSeparator` es suficiente

## 10) Preguntas abiertas

- Ninguna. El análisis funcional está completo y no hay ambigüedades técnicas
  bloqueantes.

## 11) Notas para implementación

- **Respetar convenciones de naming:** archivos en `snake_case`, clases en
  `PascalCase`, use cases con verbo + objeto
- **i18n obligatorio:** Todos los textos visibles al usuario deben usar claves
  del ARB; no hardcodear strings
- **Design tokens:** Usar `Theme.of(context)` para colores y
  `AppSpacing`/`AppIconSizes` para dimensiones; no hardcodear valores
- **BLoC como `registerFactory`:** Siguiendo el patrón de `settings_module.dart`
- **DataSource y Repository como `registerLazySingleton`:** Siguiendo
  convenciones existentes
- **Eventos sealed + estados sealed:** Siguiendo el patrón de
  `folder-features.instructions.md`
- **Totalización en presentación:** Los totales por fila y columna se calculan
  en el widget o en el estado del BLoC al emitir, no en la capa de dominio ni en
  el Excel
- **Escritura atómica:** Al actualizar estructura, escribir a `.tmp` y renombrar
  para evitar corrupción
- **No romper el comportamiento existente:** La modificación de `injection.dart`
  es aditiva (añadir import + llamada). Los cambios en `core/error/` son
  aditivos
- **Secuencia sugerida:** Domain → Data → BLoC → UI → DI → i18n
- **Estado: Listo para implementación**
