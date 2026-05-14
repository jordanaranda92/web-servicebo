# Technical Analysis: Migración de productos a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** products-firestore-migration
- **Fuente:**
  docs/functional-analysis/2026-05-08-products-firestore-migration.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Reestructurar la feature `products` para que utilice Firestore como única fuente
de datos, replicando el patrón ya establecido en la feature `clients`. Esto
implica:

- Reemplazar completamente la capa `data/` (datasource Firestore en lugar de
  Google Sheets + FD API)
- Simplificar la capa `domain/` (nueva entidad con ID tipo `String`, nuevo
  contrato de repositorio, dos use cases en lugar de ocho)
- Reescribir la capa `presentation/` (cubit simplificado, UI con guardado
  individual por campo)
- Adaptar `orders_today` para leer productos activos desde Firestore en lugar de
  Google Sheets
- Eliminar el botón de sincronización de productos en settings

**Áreas impactadas**: `features/products/`, `features/orders_today/`,
`features/settings/`, `app/di/modules/` **Riesgo general**: Medio — cambio
extenso pero con patrón probado (clientes)

## 2) Contexto técnico observado

### Arquitectura detectada

- **Clean Architecture feature-first** con capas `data/`, `domain/`,
  `presentation/`
- **BLoC/Cubit** para gestión de estado
- **GetIt** para DI, con módulos por feature en `app/di/modules/`
- **fpdart** (`Either<Failure, T>`) para manejo de errores en domain/data
- **Firestore** ya integrado (usado en `clients`, `client_categories`)

### Estado actual de `features/products/`

| Capa                   | Componentes actuales                                                                  | Dependencias externas                                                                                        |
| ---------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `data/dto/`            | `ProductDto` (FD API), `ProductSheetDto` (Google Sheets)                              | —                                                                                                            |
| `data/repositories/`   | `ProductsRepositoryImpl`                                                              | `GoogleSheetsDataSource`, `GoogleDriveRemoteDataSource`, `FacturaDirectaApiDataSource`, `SettingsRepository` |
| `domain/entities/`     | `Product` (id: int), `FdProduct`, `ProductsResult`                                    | —                                                                                                            |
| `domain/repositories/` | `ProductsRepository` (8 métodos)                                                      | —                                                                                                            |
| `domain/usecases/`     | 8 use cases                                                                           | —                                                                                                            |
| `presentation/bloc/`   | `ProductsCubit` (8 dependencias), `ProductsState` (con `fdWarning`, `configNotFound`) | —                                                                                                            |
| `presentation/pages/`  | `ProductsPage` (batch save, add/delete, FD linking, NavigationGuard)                  | —                                                                                                            |

### Patrón de referencia: `features/clients/`

| Capa                   | Componentes                                             | Notas                                        |
| ---------------------- | ------------------------------------------------------- | -------------------------------------------- |
| `data/models/`         | `ClientModel` con `fromFirestore`/`toMap`/`toEntity`    | Patrón a replicar                            |
| `data/datasources/`    | `ClientFirestoreDataSource` (abstract) + `Impl`         | `getAll`, `updateFields`, `batchUpdate`      |
| `data/repositories/`   | `ClientsRepositoryImpl`                                 | 2 dependencias: datasource + categories DS   |
| `domain/entities/`     | `Client` (id: String)                                   | —                                            |
| `domain/repositories/` | `ClientsRepository`                                     | 2 métodos: `getClients`, `saveClientsBatch`  |
| `domain/usecases/`     | `GetClients`, `SaveClientsBatch` (+`SyncClientsFromFd`) | —                                            |
| `presentation/bloc/`   | `ClientsCubit` (4 deps)                                 | `saveBatchChanges` con `reload` param        |
| `presentation/pages/`  | `ClientsPage`                                           | Guardado individual por campo, feedback card |

### Dependencia en `orders_today`

- `OrdersTodayRepositoryImpl._readActiveProducts(configId)` lee productos
  activos desde la hoja Google Sheets `productos` del spreadsheet
  `configuracion`
- Retorna `List<({String uuid, String name})>` filtrado por `isActive` y
  `mostrarEnNuevosPedidos`, ordenado por `order`
- Se usa en `createTodaySheet` para escribir productos en el nuevo sheet del día

## 3) Objetivo técnico

- **Qué debe cambiar**: La feature `products` pasa de Google Sheets + FD API a
  Firestore. La feature `orders_today` pasa a leer productos activos desde
  Firestore
- **Resultado técnico**: Arquitectura unificada con `clients`, menor
  complejidad, sin dependencias externas de Sheets/FD en products
- **Limitaciones**: No romper `orders_today` — mantener su funcionalidad de
  crear sheet del día con productos activos

## 4) Diseño técnico de la solución

### Enfoque propuesto

Replicar exactamente la arquitectura de `clients` para `products`, adaptando
campos y eliminando funcionalidades no necesarias (sync, categories,
add/delete).

### Componentes / módulos / servicios afectados

#### A. Nueva entidad `Product` (domain)

```dart
class Product extends Equatable {
  final String id;                    // document ID (antes int)
  final String name;
  final String facturaDirectaUuid;
  final String facturaDirectaName;
  final bool isActive;
  final String color;                 // hex, default '#FFFFFF'
  final int? order;
  final double? facturaDirectaSalesPrice;
  final String? facturaDirectaCurrency;
}
```

#### B. Nuevo `ProductModel` (data/models)

Patrón idéntico a `ClientModel`:

- `fromFirestore(String id, Map<String, dynamic> data)`
- `toMap() → Map<String, dynamic>`
- `toEntity() → Product`

#### C. Nuevo `ProductFirestoreDataSource` (data/datasources)

Contrato (abstract):

```dart
abstract class ProductFirestoreDataSource {
  Future<List<ProductModel>> getAll();
  Future<void> updateFields({required String id, required Map<String, dynamic> fields});
  Future<void> batchUpdate(Map<String, Map<String, dynamic>> updates);
}
```

Implementación: colección `products`, mismo patrón que
`ClientFirestoreDataSourceImpl` (sin `add`, `batchAdd`, `findByFdUuid` — no se
necesitan).

#### D. Nuevo `ProductsRepository` (domain/repositories)

```dart
abstract class ProductsRepository {
  Future<Either<Failure, List<Product>>> getProducts();
  Future<Either<Failure, Unit>> saveProductsBatch({
    Map<String, String> nameChanges,
    Map<String, bool> activeToggles,
    Map<String, int> orderChanges,
  });
}
```

#### E. Nuevo `ProductsRepositoryImpl` (data/repositories)

Dependencia única: `ProductFirestoreDataSource`.

- `getProducts()`: lee todos, ordena por `order` (nulls al final), luego
  alfabéticamente
- `saveProductsBatch()`: construye mapa de updates y delega a `batchUpdate`

#### F. Use cases simplificados (domain/usecases)

Solo 2:

- `GetProducts` → `UseCase<List<Product>, NoParams>`
- `SaveProductsBatch` → `UseCase<Unit, SaveProductsBatchParams>`

`SaveProductsBatchParams` con `Map<String, String> nameChanges`,
`Map<String, bool> activeToggles`, `Map<String, int> orderChanges`.

#### G. `ProductsCubit` simplificado (presentation/bloc)

Dependencias: `GetProducts`, `SaveProductsBatch` (2 en lugar de 8).

Métodos:

- `loadProducts()` — emite `ProductsLoading` → `ProductsLoaded` o
  `ProductsError`
- `filterByName(String)` — filtra `allProducts` por nombre
- `saveBatchChanges({nameChanges, activeToggles, orderChanges, reload})` —
  patrón idéntico a `ClientsCubit`

#### H. `ProductsState` simplificado

```dart
class ProductsLoaded extends ProductsState {
  final List<Product> allProducts;
  final List<Product> filteredProducts;
  final String nameFilter;
  final bool isSaving;
}
```

Eliminar: `fdWarning`, `configNotFound` de `ProductsErrorType`.

#### I. `ProductsPage` reescrita

Patrón idéntico a `ClientsPage`:

- Guardado individual por campo con
  `_saveField(productId, {name, isActive, order})`
- Diálogo de progreso + feedback card (éxito/error con auto-dismiss 3s)
- Sin `NavigationGuard`, sin pending changes, sin add/delete, sin FD linking
- Sin banner de warning FD
- Columnas: Nombre (editable), Nombre FD (read-only), Activo (switch), Orden
  (editable)

#### J. Adaptación de `OrdersTodayRepositoryImpl`

Reemplazar `_readActiveProducts(configSpreadsheetId)` (que lee de Google Sheets)
por una versión que lea de Firestore:

- Inyectar `ProductFirestoreDataSource` en `OrdersTodayRepositoryImpl`
- Nuevo método `_readActiveProductsFromFirestore()`:
  - Lee todos los productos con `getAll()`
  - Filtra por `isActive == true`
  - Ordena por `order` (nulls al final)
  - Retorna `List<({String uuid, String name})>` donde `uuid` =
    `facturaDirectaUuid`
- Eliminar el parámetro `configSpreadsheetId` de `_readActiveProducts`

#### K. Eliminar botón sync en settings

Eliminar el `OutlinedButton.icon` con `settingsSyncProductsButton` de
`factura_directa_section.dart`.

### Contratos e interfaces

| Contrato                     | Métodos                                 | Consumidores                                          |
| ---------------------------- | --------------------------------------- | ----------------------------------------------------- |
| `ProductFirestoreDataSource` | `getAll`, `updateFields`, `batchUpdate` | `ProductsRepositoryImpl`, `OrdersTodayRepositoryImpl` |
| `ProductsRepository`         | `getProducts`, `saveProductsBatch`      | `GetProducts`, `SaveProductsBatch`                    |

### Flujo de datos o de control

**Carga de productos:**

```
ProductsPage → ProductsCubit.loadProducts()
  → GetProducts(NoParams)
    → ProductsRepositoryImpl.getProducts()
      → ProductFirestoreDataSource.getAll()
        → Firestore collection('products').get()
      ← List<ProductModel>
    ← List<Product> (sorted)
  ← ProductsLoaded(allProducts, filteredProducts)
```

**Guardado individual:**

```
ProductsPage._saveField(id, {name: 'X'})
  → ProductsCubit.saveBatchChanges(nameChanges: {id: 'X'}, reload: false)
    → SaveProductsBatch(params)
      → ProductsRepositoryImpl.saveProductsBatch(nameChanges: {id: 'X'})
        → ProductFirestoreDataSource.batchUpdate({id: {'name': 'X'}})
          → Firestore batch.update(doc(id), {'name': 'X'})
    ← Right(unit) | Left(Failure)
  ← bool success
```

**Crear sheet del día (orders_today):**

```
OrdersTodayRepositoryImpl.createTodaySheet(date)
  → _readActiveProductsFromFirestore()
    → ProductFirestoreDataSource.getAll()
      → Firestore collection('products').get()
    ← filter(isActive) → sort(order) → map((uuid, name))
  → _sheetDataSource.createTodaySheet(productUuids, productNames, ...)
```

### Gestión de errores y validaciones

- Mismo patrón que `ClientsRepositoryImpl`: `ServerException` → `ServerFailure`,
  `NetworkException` → `NetworkFailure`, catch-all → `InternalFailure`
- `ProductsErrorType` reducido a: `network`, `server`, `unknown`
- Validaciones en UI: nombre no vacío, orden ≥ 1, solo guardar si hay cambio
  real

### Consideraciones de compatibilidad o migración

- La colección `products` en Firestore debe estar pre-populada antes del deploy
- El campo `order` en la entidad actual se llama `orderInNewOrders` (Google
  Sheets) → pasa a `order` (Firestore)
- El ID cambia de `int` a `String` — no hay backwards compatibility posible, es
  un reemplazo completo
- `orders_today` necesita el `ProductFirestoreDataSource` inyectado — requiere
  cambio en DI de `orders_today`

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                    | Propósito                                               |
| ---------------------------------------------------------------------------- | ------------------------------------------------------- |
| `features/products/data/models/product_model.dart`                           | Modelo Firestore con `fromFirestore`/`toMap`/`toEntity` |
| `features/products/data/datasources/product_firestore_data_source.dart`      | Contrato abstracto del datasource Firestore             |
| `features/products/data/datasources/product_firestore_data_source_impl.dart` | Implementación con `cloud_firestore`                    |

### Artefactos a modificar

| Artefacto                                                                   | Cambio esperado                                                                                                                                                                                                                        |
| --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `features/products/domain/entities/product.dart`                            | Reescribir: `id` de `int` a `String`, eliminar campos FD enriquecidos, añadir `facturaDirectaUuid`, `facturaDirectaName`, `color`, renombrar `orderInNewOrders` → `order`, añadir `facturaDirectaSalesPrice`, `facturaDirectaCurrency` |
| `features/products/domain/repositories/products_repository.dart`            | Reescribir: 2 métodos (`getProducts`, `saveProductsBatch`) en lugar de 8                                                                                                                                                               |
| `features/products/data/repositories/products_repository_impl.dart`         | Reescribir: usar `ProductFirestoreDataSource`, eliminar Sheets/FD/Drive deps                                                                                                                                                           |
| `features/products/domain/usecases/get_products.dart`                       | Adaptar: retorna `List<Product>` en lugar de `ProductsResult`                                                                                                                                                                          |
| `features/products/domain/usecases/save_products_batch.dart`                | Adaptar: params con `Map<String, ...>` en lugar de `Map<int, ...>`                                                                                                                                                                     |
| `features/products/presentation/bloc/products_cubit.dart`                   | Reescribir: 2 deps, métodos simplificados, sin FD/add/delete                                                                                                                                                                           |
| `features/products/presentation/bloc/products_state.dart`                   | Simplificar: eliminar `fdWarning`, eliminar `configNotFound` de `ProductsErrorType`                                                                                                                                                    |
| `features/products/presentation/pages/products_page.dart`                   | Reescribir: patrón de `ClientsPage`, guardado individual, sin add/delete/FD/NavigationGuard                                                                                                                                            |
| `features/settings/presentation/widgets/factura_directa_section.dart`       | Eliminar botón `settingsSyncProductsButton`                                                                                                                                                                                            |
| `features/orders_today/data/repositories/orders_today_repository_impl.dart` | Reemplazar `_readActiveProducts(configId)` por lectura desde Firestore vía `ProductFirestoreDataSource`                                                                                                                                |
| `app/di/modules/products_module.dart`                                       | Reescribir: registrar datasource Firestore, 2 use cases, cubit con 2 deps                                                                                                                                                              |
| `app/di/modules/orders_today_module.dart` (o donde se registre)             | Añadir `ProductFirestoreDataSource` como dependencia de `OrdersTodayRepositoryImpl`                                                                                                                                                    |

### Artefactos a retirar o reemplazar

| Artefacto                                                     | Motivo                                                                     |
| ------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `features/products/data/dto/product_dto.dart`                 | DTO de Factura Directa API — ya no se consulta FD                          |
| `features/products/data/dto/product_sheet_dto.dart`           | DTO de Google Sheets — ya no se lee de Sheets                              |
| `features/products/domain/entities/fd_product.dart`           | Entidad de producto FD — ya no existe vinculación en runtime               |
| `features/products/domain/entities/products_result.dart`      | Wrapper con `fdWarning` — ya no aplica                                     |
| `features/products/domain/usecases/get_fd_products.dart`      | Use case de FD — eliminado                                                 |
| `features/products/domain/usecases/link_fd_product.dart`      | Use case de FD — eliminado                                                 |
| `features/products/domain/usecases/add_product.dart`          | Use case de crear producto — eliminado (gestión en Firestore directamente) |
| `features/products/domain/usecases/delete_product.dart`       | Use case de eliminar producto — eliminado                                  |
| `features/products/domain/usecases/toggle_product_field.dart` | Use case de toggle — reemplazado por `saveProductsBatch`                   |
| `features/products/domain/usecases/update_product.dart`       | Use case de update nombre — reemplazado por `saveProductsBatch`            |
| `features/products/domain/usecases/update_product_order.dart` | Use case de update orden — reemplazado por `saveProductsBatch`             |

## 6) Estrategia de implementación

### Paso 1: Data layer — Modelo y datasource Firestore

1. Crear `product_model.dart` con `fromFirestore`/`toMap`/`toEntity`
2. Crear `product_firestore_data_source.dart` (contrato)
3. Crear `product_firestore_data_source_impl.dart` (implementación)

### Paso 2: Domain layer — Entidad, repositorio, use cases

1. Reescribir `product.dart` (entidad con campos Firestore)
2. Reescribir `products_repository.dart` (2 métodos)
3. Adaptar `get_products.dart` (retorna `List<Product>`)
4. Adaptar `save_products_batch.dart` (params con `String` keys)
5. Eliminar use cases obsoletos (7 archivos)
6. Eliminar entidades obsoletas (`fd_product.dart`, `products_result.dart`)

### Paso 3: Data layer — Repositorio Firestore

1. Reescribir `products_repository_impl.dart`
2. Eliminar DTOs obsoletos (`product_dto.dart`, `product_sheet_dto.dart`)

### Paso 4: Presentation layer — Cubit y estado

1. Reescribir `products_state.dart`
2. Reescribir `products_cubit.dart`

### Paso 5: Presentation layer — Página

1. Reescribir `products_page.dart` siguiendo el patrón de `clients_page.dart`

### Paso 6: DI — Módulo de productos

1. Reescribir `products_module.dart`

### Paso 7: Adaptar `orders_today`

1. Inyectar `ProductFirestoreDataSource` en `OrdersTodayRepositoryImpl`
2. Reemplazar `_readActiveProducts` para leer desde Firestore
3. Actualizar DI de `orders_today` para pasar el datasource

### Paso 8: Settings — Eliminar botón sync

1. Eliminar el `OutlinedButton.icon` de `settingsSyncProductsButton` en
   `factura_directa_section.dart`

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

Los pasos 7 y 8 son independientes entre sí y pueden hacerse en paralelo después
del paso 6.

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (entidad usa campos del modelo)
- Paso 3 depende de Paso 1 y 2 (repositorio usa datasource y contrato domain)
- Paso 4 depende de Paso 2 (cubit usa use cases y entidad)
- Paso 5 depende de Paso 4 (página usa cubit y estado)
- Paso 6 depende de Pasos 1-4 (DI registra todo)
- Paso 7 depende de Paso 1 (usa el datasource)
- Paso 8 es independiente

### Puntos delicados

- **Cambio de tipo de ID** (`int` → `String`): afecta a todos los Maps en
  cubit/page que indexan por ID. No hay conversión — es reemplazo total
- **`orders_today`**: la inyección del datasource de productos en el repositorio
  de orders_today añade una dependencia cross-feature. Aceptable porque es solo
  a nivel de data source (no repositorio), y es un patrón transitorio hasta que
  orders_today también migre completamente
- **Strings i18n**: las keys de traducción de productos que se eliminen (ej:
  `productsAdd`, `productsDelete`, `productsSelectFdProduct`, etc.) pueden
  dejarse en los archivos `.arb` sin impacto funcional — no rompen la app

## 7) Estrategia de validación

### Verificación automática

- `dart analyze` / `flutter analyze` — sin errores ni warnings en archivos
  modificados
- Compilación exitosa del proyecto (`flutter build`)

### Verificación manual

- Abrir pantalla de productos → los productos se cargan desde Firestore
- Editar nombre de un producto → se guarda en Firestore y muestra feedback
- Toggle activo → se actualiza en Firestore
- Editar orden → se guarda en Firestore
- Buscar por nombre → filtra correctamente
- Verificar que no aparecen columnas de FD (precio, moneda, selector FD)
- Verificar que no aparecen botones Añadir/Eliminar/Guardar/Descartar
- Ir a Settings → Factura Directa → verificar que no aparece "Sincronizar
  productos"
- Crear sheet del día en orders_today → verificar que los productos activos se
  escriben correctamente desde Firestore

### Escenarios a cubrir

- Colección `products` vacía → mensaje "No hay productos"
- Error de red → pantalla de error con reintento
- Producto sin `order` → aparece al final
- Producto sin `facturaDirectaName` → celda vacía

### Pruebas recomendables

- **Unit tests** para `ProductModel.fromFirestore` y `toMap`
- **Unit tests** para `ProductsRepositoryImpl` (getProducts, saveProductsBatch)
  con datasource mockeado
- **Unit tests** para `ProductsCubit` (loadProducts, filterByName,
  saveBatchChanges) con use cases mockeados

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                 | Probabilidad | Impacto                                 |
| ---------------------------------------------------------------------- | ------------ | --------------------------------------- |
| Colección `products` no pre-populada antes del deploy                  | Baja         | Alto — pantalla vacía                   |
| Reglas Firestore no configuradas para `products`                       | Baja         | Alto — error de permisos                |
| `orders_today` falla al crear sheet por cambio en lectura de productos | Media        | Alto — no se pueden crear hojas del día |
| Keys i18n eliminadas que se usen en otro sitio                         | Muy baja     | Bajo — error de compilación detectable  |

### Impacto potencial

- Los usuarios verán una UI diferente en la pantalla de productos (más simple,
  sin FD linking)
- La creación del sheet del día usará Firestore como fuente de productos en
  lugar de Google Sheets

### Mitigación

- Verificar que la colección `products` existe y tiene datos antes de merging
- Verificar reglas de Firestore para `products` en entorno de staging
- Probar la creación del sheet del día end-to-end en staging
- Hacer el deploy de Firestore data antes del deploy de código

### Plan de rollback

- Revert del commit/PR — la implementación anterior sigue siendo funcional
  mientras Google Sheets tenga los datos
- No hay migración destructiva de datos: Google Sheets y Firestore coexisten
  durante la transición

## 9) Suposiciones

- La colección `products` en Firestore estará disponible y con datos antes de
  desplegar
- Las reglas de seguridad de Firestore ya permiten lectura/escritura sobre
  `products`
- No hay otras features (aparte de `orders_today`) que lean productos desde
  Google Sheets
- El `ProductFirestoreDataSource` ya registrado en DI será accesible tanto por
  `ProductsRepositoryImpl` como por `OrdersTodayRepositoryImpl`
- `cloud_firestore` ya es dependencia del proyecto (usado por clientes)

## 10) Preguntas abiertas

- Ninguna — todas las dudas funcionales fueron resueltas en el análisis
  funcional

## 11) Notas para implementación

- **Modelo a seguir**: `features/clients/` en todas las capas. Copiar estructura
  y adaptar campos
- **No romper orders_today**: probar `createTodaySheet` después de la migración
- **Eliminar archivos obsoletos**: 11 archivos de la feature products + 2 DTOs.
  Hacerlo en un commit dedicado para facilitar review
- **No eliminar keys i18n**: dejarlas en `.arb` aunque no se usen — no causan
  daño y pueden limpiarse luego
- **NavigationGuard**: la página de productos actual usa `NavigationGuard` para
  cambios pendientes. Con guardado individual, ya no se necesita. No eliminarlo
  del core, solo dejar de usarlo en `ProductsPage`
- **Orden de campos en la tabla UI**: Nombre | Nombre FD | Activo | Orden (misma
  disposición que clientes, sin categoría)
- **Estado: Listo para implementación**
