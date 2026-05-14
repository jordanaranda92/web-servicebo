# Technical Analysis: Migración de Categorías de Clientes a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** client-categories-firestore-migration
- **Fuente:**
  docs/functional-analysis/2026-05-08-client-categories-firestore-migration.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Reemplazar el datasource de Google Sheets por Cloud Firestore para el CRUD de
  categorías de clientes.
- Cambiar el tipo de ID de `int` a `String` (auto-generado por Firestore) en
  entidad, repositorio, use cases, cubit, state, page y todos los puntos de
  consumo en la feature `clients`.
- Crear un nuevo datasource abstracto + implementación para Firestore en
  `client_categories/data/datasources/`.
- Reescribir `ClientCategoriesRepositoryImpl` para usar el datasource de
  Firestore en lugar de Google Sheets.
- Adaptar `ClientsRepositoryImpl` para obtener el mapa de categorías desde
  Firestore (no del sheet) y trabajar con `String categoryId`.
- Principales áreas impactadas: feature `client_categories` (todas las capas),
  feature `clients` (data + domain + presentation), DI.
- Riesgo general estimado: **medio** (cambio transversal de tipo de dato
  `int→String` con múltiples puntos de impacto, pero lógica simple).

## 2) Contexto técnico observado

### Arquitectura detectada

Clean Architecture feature-first con BLoC/Cubit, GetIt para DI, fpdart para
manejo funcional de errores.

### Módulos y capas relevantes

| Módulo                            | Capas afectadas                                                                                                                        |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/client_categories/` | data (repository), domain (entity compartida, repository contract, 5 use cases), presentation (cubit, state, page)                     |
| `lib/features/clients/`           | data (repository, DTOs), domain (use case `UpdateClientCategory`, `SaveClientsBatch`, repository contract), presentation (cubit, page) |
| `lib/app/di/modules/`             | `client_categories_module.dart`, `clients_module.dart`, `core_module.dart`                                                             |
| `lib/core/error/`                 | Reutilizar `Failure` existentes: `ServerFailure`, `NetworkFailure`, `InternalFailure`                                                  |

### Restricciones relevantes

- `cloud_firestore: ^6.3.0` ya está en `pubspec.yaml` pero **no hay ningún
  datasource de Firestore implementado** en el proyecto. Se crea infraestructura
  nueva.
- `FirebaseFirestore` **no está registrado** en GetIt. Se debe registrar
  (similar al patrón de `FirebaseDatabase` en `core_module.dart`).
- La entidad `ClientCategory` vive en `lib/features/clients/domain/entities/`
  (no en `client_categories`). Se comparte entre ambas features.
- `ClientCategorySheetDto` (en `lib/features/clients/data/dto/`) se usa en 2
  sitios: `ClientCategoriesRepositoryImpl` y
  `ClientsRepositoryImpl._loadSheetData()`.
- En `ClientsRepositoryImpl`, `_SheetLoadResult.categoryMap` es
  `Map<int, String>`. Debe cambiar a `Map<String, String>`.
- En `ClientsRepositoryImpl`, `_enrichClients()` recibe
  `Map<int, String> categoryMap` y accede a `sheetData.categoryId` (que es
  `int?`).
- `ClientsRepository.saveClientsBatch()` tiene
  `Map<String, int> categoryChanges`. Debe cambiar a `Map<String, String>`.
- `ClientsRepository.updateClientCategory()` tiene `int categoryId`. Debe
  cambiar a `String categoryId`.
- En `ClientsCubit.saveBatchChanges()`, `categoryChanges` es `Map<String, int>`.
  Debe cambiar a `Map<String, String>`.
- En `clients_page.dart`, `_pendingCategoryChanges` es `Map<String, int>`. Debe
  cambiar a `Map<String, String>`. La línea
  `_pendingCategoryChanges[client.id] = selected.id` ya asigna `selected.id`
  (actualmente `int`, será `String`).
- En `client_categories_page.dart`, `_nameControllers`, `_pendingNames` y
  `_pendingToggles` usan `int` como key (el `category.id`). Deben cambiar a
  `String`.
- En `ClientCategoriesCubit`, los métodos `updateCategory`, `toggleCategory`,
  `deleteCategory` y `saveBatchChanges` reciben `int id`. Deben cambiar a
  `String`.
- No existen tests unitarios para la feature `client_categories` ni para los
  aspectos de categoría en `clients`.

### Dependencias e integraciones

- `cloud_firestore` (ya en pubspec).
- `firebase_core` (ya inicializado en la app).
- La pestaña `categorias_clientes` del spreadsheet `configuracion` deja de
  usarse. La pestaña `clientes` sigue usándose pero con `String` en la columna
  "Categoría cliente".

## 3) Objetivo técnico

- Reemplazar completamente el almacenamiento de categorías de clientes de Google
  Sheets a Firestore.
- Cambiar el tipo de ID de `int` a `String` de forma consistente en toda la
  codebase.
- El nuevo `ClientCategoriesRepositoryImpl` debe depender de un datasource de
  Firestore, no de Google Sheets.
- `ClientsRepositoryImpl` debe obtener categorías desde Firestore (a través de
  un datasource inyectado o del repositorio de categorías) en lugar de leer la
  pestaña `categorias_clientes`.
- Mantener la misma interfaz funcional: el dominio y la presentación no cambian
  su comportamiento, solo el tipo del ID.

## 4) Diseño técnico de la solución

### Enfoque propuesto

1. **Crear datasource de Firestore** en `client_categories/data/datasources/`
   con interfaz abstracta e implementación usando `cloud_firestore`.
2. **Reescribir `ClientCategoriesRepositoryImpl`** para delegar en el nuevo
   datasource.
3. **Cambiar tipo de ID** de `int` a `String` en `ClientCategory`, todos los use
   cases, cubit, state y pages de `client_categories`.
4. **Adaptar `ClientsRepositoryImpl`**: inyectar el datasource de Firestore de
   categorías (o el `ClientCategoriesRepository`) para obtener
   `Map<String, String>` en lugar de leer del sheet.
5. **Adaptar `ClientSheetDto.categoryId`** de `int?` a `String?`.
6. **Adaptar contracts, use cases y cubit de `clients`** para
   `String categoryId`.
7. **Registrar `FirebaseFirestore` en DI** y actualizar los módulos de
   `client_categories` y `clients`.

### Componentes / módulos / servicios afectados

#### Feature `client_categories`

| Capa         | Artefacto                                                 | Cambio                                                                            |
| ------------ | --------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Data         | **Nuevo:** `ClientCategoryFirestoreDataSource` (interfaz) | Contrato CRUD contra Firestore                                                    |
| Data         | **Nuevo:** `ClientCategoryFirestoreDataSourceImpl`        | Implementación con `cloud_firestore`                                              |
| Data         | `ClientCategoriesRepositoryImpl`                          | Reescribir: reemplazar dependencias de Sheets por datasource Firestore            |
| Domain       | `ClientCategory` (entity)                                 | `final int id` → `final String id`                                                |
| Domain       | `ClientCategoriesRepository` (contract)                   | `int id` → `String id` en `updateCategory`, `toggleCategory`, `deleteCategory`    |
| Domain       | `UpdateClientCategory` (use case)                         | `int id` → `String id` en params                                                  |
| Domain       | `ToggleClientCategory` (use case)                         | `int id` → `String id` en params                                                  |
| Domain       | `DeleteClientCategory` (use case)                         | `int id` → `String id` en params                                                  |
| Domain       | `AddClientCategory` (use case)                            | Sin cambio (solo recibe `name`)                                                   |
| Domain       | `GetClientCategories` (use case)                          | Sin cambio                                                                        |
| Presentation | `ClientCategoriesCubit`                                   | `int id` → `String id` en métodos y `saveBatchChanges`                            |
| Presentation | `ClientCategoriesState`                                   | Sin cambio funcional (ya usa `List<ClientCategory>`)                              |
| Presentation | `ClientCategoriesPage`                                    | `Map<int, ...>` → `Map<String, ...>` en pending changes; adaptar `_controllerFor` |

#### Feature `clients`

| Capa         | Artefacto                                    | Cambio                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------ | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Data         | `ClientSheetDto`                             | `int? categoryId` → `String? categoryId`; parseo de `_parseInt` → lectura directa como `String?`                                                                                                                                                                                                                                                                                                                |
| Data         | `ClientCategorySheetDto`                     | Deja de usarse en `ClientsRepositoryImpl` (se puede mantener por si hay otros consumidores, pero eliminar import)                                                                                                                                                                                                                                                                                               |
| Data         | `ClientsRepositoryImpl`                      | `_loadSheetData()`: dejar de leer `categorias_clientes` del sheet; inyectar datasource de Firestore para obtener `Map<String, String>`; `_enrichClients()`: cambiar firma de `categoryMap`; `_SheetLoadResult.categoryMap`: `Map<int, String>` → `Map<String, String>`; `updateClientCategory()`: `int categoryId` → `String`; `saveClientsBatch()`: `Map<String, int> categoryChanges` → `Map<String, String>` |
| Domain       | `ClientsRepository` (contract)               | `updateClientCategory(int categoryId)` → `String categoryId`; `saveClientsBatch(Map<String, int> categoryChanges)` → `Map<String, String>`                                                                                                                                                                                                                                                                      |
| Domain       | `UpdateClientCategory` (use case en clients) | `int categoryId` → `String categoryId` en params                                                                                                                                                                                                                                                                                                                                                                |
| Domain       | `SaveClientsBatch` (use case)                | `Map<String, int> categoryChanges` → `Map<String, String>` en params                                                                                                                                                                                                                                                                                                                                            |
| Presentation | `ClientsCubit`                               | `saveBatchChanges`: `Map<String, int>` → `Map<String, String>`                                                                                                                                                                                                                                                                                                                                                  |
| Presentation | `ClientsPage`                                | `Map<String, int> _pendingCategoryChanges` → `Map<String, String>`; `_pendingCategoryChanges[client.id] = selected.id` ya funciona (será `String`)                                                                                                                                                                                                                                                              |

#### DI / Core

| Artefacto                       | Cambio                                                                                                                                                    |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `core_module.dart`              | Registrar `FirebaseFirestore.instance` en GetIt (condicionado a `firebaseAvailable`)                                                                      |
| `client_categories_module.dart` | Cambiar dependencias del repository: pasar datasource Firestore en lugar de `SettingsRepository`, `GoogleSheetsDataSource`, `GoogleDriveRemoteDataSource` |
| `clients_module.dart`           | Inyectar datasource Firestore de categorías en `ClientsRepositoryImpl` (nueva dependencia)                                                                |

### Contratos e interfaces

**Nuevo: `ClientCategoryFirestoreDataSource`** (en
`lib/features/client_categories/data/datasources/`):

```dart
abstract class ClientCategoryFirestoreDataSource {
  Future<List<ClientCategory>> getAll();
  Future<void> add({required String name, required bool isActive});
  Future<void> update({required String id, required String name});
  Future<void> toggleActive({required String id, required bool isActive});
  Future<void> delete({required String id});
}
```

**Colección Firestore: `client_categories`**

```
client_categories/{auto-id}
  ├── name: String
  └── isActive: bool
```

### Flujo de datos o de control

#### CRUD de categorías (nuevo flujo)

```
Page → Cubit → UseCase → ClientCategoriesRepository → ClientCategoryFirestoreDataSource → Firestore
```

#### Resolución de categoría en clientes (nuevo flujo)

```
ClientsRepositoryImpl._loadSheetData()
  ├── Lee pestaña `clientes` del sheet (sin cambio)
  ├── Obtiene categorías via ClientCategoryFirestoreDataSource.getAll()
  ├── Construye Map<String, String> (firestoreId → name)
  └── _enrichClients() cruza sheetData.categoryId (String) con categoryMap
```

### Gestión de errores y validaciones

- Las operaciones de Firestore pueden lanzar `FirebaseException`. Capturar en el
  datasource y convertir a excepciones del dominio (`ServerException`,
  `NetworkException`).
- El repositorio mantiene el patrón actual de try/catch → `Left(Failure)`.
- Si `firebaseAvailable` es `false`, las operaciones devuelven
  `Left(ConfigNotFoundFailure())` o `Left(ServerFailure())`.
- Si Firestore no está disponible al cargar clientes, la resolución de
  categorías falla gracefully: `categoryMap` queda vacío y los clientes se
  muestran sin nombre de categoría (degradación funcional existente).

### Consideraciones de compatibilidad o migración

- **Corte limpio**: no hay periodo de transición. Se deja de leer
  `categorias_clientes` del sheet.
- Los IDs numéricos existentes en la columna "Categoría cliente" del sheet
  `clientes` no se resolverán contra Firestore. Se acepta pérdida temporal.
- La tabla `categorias_clientes` del spreadsheet queda obsoleta pero no se
  elimina.
- `ClientCategorySheetDto` deja de usarse en producción pero puede mantenerse en
  el código si no genera conflictos.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                                         | Propósito                                   |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `lib/features/client_categories/data/datasources/client_category_firestore_data_source.dart`      | Interfaz abstracta del datasource Firestore |
| `lib/features/client_categories/data/datasources/client_category_firestore_data_source_impl.dart` | Implementación con `cloud_firestore`        |

### Artefactos a modificar

| Artefacto                                                                                 | Cambio esperado                                                                                                                                                                                             |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/domain/entities/client_category.dart`                               | `final int id` → `final String id`                                                                                                                                                                          |
| `lib/features/client_categories/domain/repositories/client_categories_repository.dart`    | `int id` → `String id` en contratos                                                                                                                                                                         |
| `lib/features/client_categories/data/repositories/client_categories_repository_impl.dart` | Reescribir: depender de `ClientCategoryFirestoreDataSource`; eliminar dependencias de Sheets                                                                                                                |
| `lib/features/client_categories/domain/usecases/update_client_category.dart`              | `int id` → `String id` en params                                                                                                                                                                            |
| `lib/features/client_categories/domain/usecases/toggle_client_category.dart`              | `int id` → `String id` en params                                                                                                                                                                            |
| `lib/features/client_categories/domain/usecases/delete_client_category.dart`              | `int id` → `String id` en params                                                                                                                                                                            |
| `lib/features/client_categories/presentation/bloc/client_categories_cubit.dart`           | `int id` → `String id` en métodos públicos y `saveBatchChanges`                                                                                                                                             |
| `lib/features/client_categories/presentation/pages/client_categories_page.dart`           | `Map<int, ...>` → `Map<String, ...>` en `_nameControllers`, `_pendingNames`, `_pendingToggles`                                                                                                              |
| `lib/features/clients/data/dto/client_sheet_dto.dart`                                     | `int? categoryId` → `String? categoryId`; cambiar parseo de `_parseInt` a `_nonEmpty`                                                                                                                       |
| `lib/features/clients/data/repositories/clients_repository_impl.dart`                     | Inyectar datasource Firestore de categorías; cambiar `_loadSheetData()` para no leer `categorias_clientes`; adaptar `_enrichClients()`, `updateClientCategory()`, `saveClientsBatch()` y `_SheetLoadResult` |
| `lib/features/clients/domain/repositories/clients_repository.dart`                        | `int categoryId` → `String categoryId` en `updateClientCategory` y `saveClientsBatch`                                                                                                                       |
| `lib/features/clients/domain/usecases/update_client_category.dart` (en clients)           | `int categoryId` → `String categoryId` en params                                                                                                                                                            |
| `lib/features/clients/domain/usecases/save_clients_batch.dart`                            | `Map<String, int> categoryChanges` → `Map<String, String>`                                                                                                                                                  |
| `lib/features/clients/presentation/bloc/clients_cubit.dart`                               | `Map<String, int>` → `Map<String, String>` en `saveBatchChanges`                                                                                                                                            |
| `lib/features/clients/presentation/pages/clients_page.dart`                               | `Map<String, int> _pendingCategoryChanges` → `Map<String, String>`                                                                                                                                          |
| `lib/app/di/modules/core_module.dart`                                                     | Registrar `FirebaseFirestore.instance`                                                                                                                                                                      |
| `lib/app/di/modules/client_categories_module.dart`                                        | Cambiar dependencias del repository; registrar datasource Firestore                                                                                                                                         |
| `lib/app/di/modules/clients_module.dart`                                                  | Añadir datasource Firestore de categorías como dependencia de `ClientsRepositoryImpl`                                                                                                                       |

### Artefactos a retirar o reemplazar

| Artefacto                                                      | Motivo                                                                                                                                                                                       |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/data/dto/client_category_sheet_dto.dart` | Deja de usarse en producción. Se puede eliminar o marcar como deprecated. Ya no se necesita para el flujo de categorías. Nota: si se elimina, verificar que no quede ningún import huérfano. |

## 6) Estrategia de implementación

### Pasos ordenados

1. **Registrar `FirebaseFirestore` en DI**
   - En `core_module.dart`, añadir registro de `FirebaseFirestore.instance`
     condicionado a `firebaseAvailable`.

2. **Cambiar tipo de ID en `ClientCategory` entity**
   - `final int id` → `final String id`.
   - Actualizar `props`.

3. **Crear datasource de Firestore**
   - Crear `client_category_firestore_data_source.dart` (interfaz).
   - Crear `client_category_firestore_data_source_impl.dart` (implementación).
   - La implementación accede a
     `FirebaseFirestore.instance.collection('client_categories')`.
   - `getAll()`: obtiene todos los documentos, mapea a `ClientCategory`.
   - `add()`: crea documento con `name` e `isActive`.
   - `update()`: actualiza campo `name` del documento.
   - `toggleActive()`: actualiza campo `isActive`.
   - `delete()`: elimina documento.

4. **Actualizar contratos de `client_categories` domain**
   - `ClientCategoriesRepository`: `int id` → `String id`.
   - `UpdateClientCategoryParams`: `int id` → `String id`.
   - `ToggleClientCategoryParams`: `int id` → `String id`.
   - `DeleteClientCategoryParams`: `int id` → `String id`.

5. **Reescribir `ClientCategoriesRepositoryImpl`**
   - Eliminar dependencias de `SettingsRepository`, `GoogleSheetsDataSource`,
     `GoogleDriveRemoteDataSource`.
   - Inyectar `ClientCategoryFirestoreDataSource`.
   - Implementar cada método delegando al datasource.
   - Gestión de errores: capturar excepciones y devolver `Left(Failure)`.

6. **Actualizar DI de `client_categories`**
   - Registrar `ClientCategoryFirestoreDataSource` →
     `ClientCategoryFirestoreDataSourceImpl`.
   - Cambiar constructor de `ClientCategoriesRepositoryImpl` en el módulo.

7. **Actualizar `ClientCategoriesCubit` y `ClientCategoriesPage`**
   - Cubit: `int id` → `String id` en `updateCategory`, `toggleCategory`,
     `deleteCategory`, `saveBatchChanges`.
   - Page: `Map<int, ...>` → `Map<String, ...>` en `_nameControllers`,
     `_pendingNames`, `_pendingToggles`.
   - Page: la columna ID mostrará un String (puede acortarse visualmente si es
     muy largo).

8. **Adaptar `ClientSheetDto`**
   - `int? categoryId` → `String? categoryId`.
   - Cambiar parseo: de `_parseInt(_cell(row, categoriaIdx))` a
     `_nonEmpty(_cell(row, categoriaIdx))`.

9. **Adaptar `ClientsRepositoryImpl`**
   - Añadir nueva dependencia: `ClientCategoryFirestoreDataSource`.
   - En `_loadSheetData()`: eliminar lectura de `categorias_clientes` del sheet;
     obtener categorías desde datasource Firestore; construir
     `Map<String, String>`.
   - Cambiar `_SheetLoadResult.categoryMap` de `Map<int, String>` a
     `Map<String, String>`.
   - Cambiar `_enrichClients()`: firma `Map<String, String> categoryMap`; acceso
     `sheetData.categoryId` ya es `String?`.
   - `updateClientCategory()`: `int categoryId` → `String categoryId`; escribir
     `categoryId` directamente (ya es String).
   - `saveClientsBatch()`: `Map<String, int> categoryChanges` →
     `Map<String, String>`; escribir valor directamente.

10. **Adaptar contratos y use cases de `clients`**
    - `ClientsRepository`: `int categoryId` → `String` en `updateClientCategory`
      y `saveClientsBatch`.
    - `UpdateClientCategory` (en clients): `int categoryId` → `String`.
    - `SaveClientsBatchParams`: `Map<String, int> categoryChanges` →
      `Map<String, String>`.

11. **Adaptar `ClientsCubit` y `ClientsPage`**
    - Cubit: `Map<String, int>` → `Map<String, String>` en `saveBatchChanges`.
    - Page: `Map<String, int> _pendingCategoryChanges` → `Map<String, String>`.

12. **Actualizar DI de `clients`**
    - `ClientsRepositoryImpl` recibirá una dependencia adicional
      (`ClientCategoryFirestoreDataSource`). Actualizar `clients_module.dart`.

13. **Limpiar código obsoleto**
    - Eliminar o marcar como deprecated `ClientCategorySheetDto` si no tiene
      otros consumidores.
    - Eliminar imports huérfanos.

### Orden recomendado

Los pasos están diseñados para compilar en cada punto intermedio si se siguen en
orden. El paso 2 (cambiar tipo de ID) provocará errores de compilación que se
resuelven en cascada con los pasos siguientes.

### Dependencias entre pasos

- Paso 1 (DI Firestore) es prerequisito para pasos 3 y 6.
- Paso 2 (entity) causa errores en cascada: pasos 4, 5, 7, 8, 9, 10, 11 los
  resuelven.
- Paso 3 (datasource) es prerequisito para pasos 5 y 9.
- Pasos 4-7 resuelven la feature `client_categories`.
- Pasos 8-12 resuelven la feature `clients`.
- Paso 13 es limpieza final.

### Puntos delicados

- **Cascada de tipo `int→String`**: el cambio en la entidad `ClientCategory.id`
  propaga errores de compilación a ~15 archivos. Es necesario resolverlos todos
  antes de que compile.
- **`ClientsRepositoryImpl._loadSheetData()`**: actualmente lee 2 pestañas del
  sheet en paralelo. Tras la migración, leerá solo la pestaña `clientes` del
  sheet y obtendrá categorías de Firestore. Debe mantener la degradación
  funcional: si Firestore falla al obtener categorías, los clientes se muestran
  sin nombre de categoría.
- **DI de `ClientsRepositoryImpl`**: actualmente recibe 4 dependencias
  posicionales (`sl(), sl(), sl(), sl()`). Al añadir el datasource de Firestore
  será 5. Verificar que el orden de resolución en GetIt sea correcto.
- **Columna ID en la UI de categorías**: actualmente muestra un `int` corto (1,
  2...). Con Firestore será un ID largo tipo `abc123xyz`. Considerar si mostrar
  el ID completo, truncarlo, o no mostrarlo.

## 7) Estrategia de validación

### Verificación automática

- `dart analyze lib/` — sin errores ni warnings.
- `flutter test` — todos los tests existentes deben pasar sin regresiones.

### Verificación manual

- Abrir pantalla de Categorías de Clientes → deben listarse las categorías desde
  Firestore.
- Crear una nueva categoría → debe aparecer en Firestore con ID auto-generado.
- Editar nombre de categoría → debe actualizarse en Firestore.
- Activar/desactivar categoría → debe reflejarse en Firestore.
- Eliminar categoría → debe desaparecer de Firestore.
- Abrir pantalla de Clientes → la columna "Categoría" debe resolver nombres
  desde Firestore.
- Asignar categoría a un cliente → debe escribir el ID de Firestore en el sheet.
- Desconectar Firestore (sin internet) → debe mostrar error controlado en
  categorías y degradación funcional en clientes.

### Escenarios a cubrir

- CRUD completo de categorías.
- Resolución de categoría en tabla de clientes.
- Asignación de categoría a cliente vía selector.
- Guardado batch de cambios en clientes (activo + categoría + orden).
- Categoría eliminada referenciada por un cliente.
- Firebase no disponible.
- Colección vacía en Firestore.

### Tipo de pruebas recomendables

- Tests unitarios para `ClientCategoryFirestoreDataSourceImpl` (con mock de
  `FirebaseFirestore`).
- Tests unitarios para `ClientCategoriesRepositoryImpl` nuevo (con mock de
  datasource).
- Tests unitarios para `ClientsRepositoryImpl._enrichClients()` con
  `Map<String, String>`.
- Tests de integración manual para flujos end-to-end.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                        | Probabilidad                    | Impacto                 | Mitigación                                                                                 |
| ----------------------------------------------------------------------------- | ------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------ |
| R-01: Cascada de errores de compilación por cambio de tipo `int→String`       | Alta (seguro)                   | Medio                   | Seguir el orden de pasos propuesto; resolver todos los archivos antes de intentar compilar |
| R-02: DI rota por cambio en número de dependencias de `ClientsRepositoryImpl` | Media                           | Alto (crash en runtime) | Verificar registros en `clients_module.dart` y `core_module.dart`; test de resolución DI   |
| R-03: Datos legacy con IDs numéricos en sheet `clientes` no se resuelven      | Alta (seguro)                   | Bajo (aceptado)         | Decisión ya tomada: se acepta pérdida temporal                                             |
| R-04: Firebase no inicializado en algún flavor/entorno                        | Baja                            | Alto                    | Condicionar registro de Firestore a `firebaseAvailable` (patrón existente)                 |
| R-05: Performance si la colección de Firestore crece mucho                    | Muy baja (son pocas categorías) | Bajo                    | No aplica para el volumen actual                                                           |

### Impacto potencial

- Feature `client_categories`: cambio completo de datasource. Si falla, el CRUD
  de categorías no funciona.
- Feature `clients`: la resolución de nombres de categoría depende de Firestore.
  Si falla, degradación funcional (sin nombre de categoría).
- No afecta a otras features del sistema.

### Plan de rollback

- Revertir el commit/PR completo.
- No se requiere rollback de datos en Firestore (los datos se crean
  manualmente).
- La pestaña `categorias_clientes` del sheet no se modifica ni elimina, por lo
  que sigue disponible si se revierte.

## 9) Suposiciones

- S-01: Firebase está inicializado correctamente y `firebaseAvailable` es `true`
  en los entornos donde se use la app.
- S-02: La colección `client_categories` de Firestore se creará manualmente con
  los 2 documentos iniciales (Decathlon, Otras tiendas) antes del despliegue.
- S-03: No se necesitan reglas de seguridad específicas de Firestore para esta
  colección en esta iteración.
- S-04: El volumen de categorías es pequeño (decenas como máximo), por lo que
  `getAll()` sin paginación es aceptable.

## 10) Preguntas abiertas

- Ninguna. Todas las decisiones necesarias fueron tomadas en el análisis
  funcional.

## 11) Notas para implementación

- Respetar el patrón existente de manejo de errores: try/catch en datasource →
  throw `ServerException`/`NetworkException` → catch en repository →
  `Left(Failure)`.
- El constructor de `ClientCategoriesRepositoryImpl` cambia radicalmente (de 3
  dependencias Sheets a 1 datasource Firestore). Actualizar el módulo DI
  cuidadosamente.
- `ClientsRepositoryImpl` pasa de 4 a 5 dependencias. Verificar el orden
  posicional en `sl()`.
- En `_loadSheetData()`, la llamada paralela a `categorias_clientes` del sheet
  se reemplaza por una llamada al datasource Firestore. Mantener el paralelismo:
  lanzar la lectura del sheet `clientes` y la lectura de Firestore en paralelo.
- La columna ID en la UI de `client_categories_page.dart` mostrará el ID de
  Firestore (String largo). Considerar truncar o ajustar el ancho de columna.
- Al eliminar `ClientCategorySheetDto` de los imports de
  `ClientsRepositoryImpl`, verificar que no queden referencias huérfanas.
- Secuencia sugerida para evitar downtime: implementar todo en un único PR,
  migrar datos manualmente en Firestore, desplegar.
- **Estado: Listo para implementación**
