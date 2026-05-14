# Technical Analysis: Migración de clientes de Google Sheets a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** clients-firestore-migration
- **Fuente:** docs/functional-analysis/2026-05-08-clients-firestore-migration.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Reemplazar la lectura/escritura de datos complementarios de clientes (activo,
  categoría, orden) de Google Sheets por Firestore, creando una colección
  `clients` y un nuevo datasource `ClientFirestoreDataSource`.
- Simplificar `ClientsRepositoryImpl` eliminando dependencias de Google Sheets,
  Google Drive, FacturaDirecta API y SettingsRepository, dejándolo solo con el
  datasource Firestore de clientes y el de categorías.
- Reestructurar la entidad `Client` para reflejar el modelo Firestore (ya no
  viene de FD API).
- Crear un nuevo caso de uso `SyncClientsFromFd` en la feature `clients`
  (dominio compartido), invocado desde un botón "Sincronizar clientes" en
  `FacturaDirectaSection` de la pantalla de Ajustes.
- Eliminar artefactos obsoletos: `ClientDto`, `ClientSheetDto`, `ClientsResult`,
  use cases individuales no usados (`ToggleClientField`, `UpdateClientOrder`,
  `UpdateClientCategory` de la feature clients), y estados/warnings ligados a
  Sheets.
- **Áreas impactadas:** feature `clients` (data, domain, presentation), feature
  `settings` (presentation), DI module `clients_module`.
- **Riesgo general:** medio — refactoring amplio pero con patrón existente claro
  (`client_categories` Firestore).

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt para DI, fpdart para
  `Either`.
- Patrón consistente: `DataSource` (abstract) → `DataSourceImpl` → `Repository`
  (abstract) → `RepositoryImpl` → `UseCase` → `Cubit` → Page.

### Módulos relevantes

- **`lib/features/clients/`**: entidad `Client` (identitarios FD +
  complementarios Sheets), `ClientsResult` (con `sheetWarning`),
  `ClientsRepository` (5 métodos: `getClients`, `toggleClientField`,
  `updateClientCategory`, `updateClientOrder`, `saveClientsBatch`),
  `ClientsRepositoryImpl` (~770 líneas, depende de
  `FacturaDirectaApiDataSource`, `SettingsRepository`, `GoogleSheetsDataSource`,
  `GoogleDriveRemoteDataSource`, `ClientCategoryFirestoreDataSource`), DTOs
  (`ClientDto` para FD API, `ClientSheetDto` para Sheets,
  `ClientCategorySheetDto` para categorías de Sheets).
- **`lib/features/client_categories/`**: ya migrado a Firestore.
  `ClientCategoryFirestoreDataSource` / `Impl` es el patrón de referencia.
- **`lib/features/settings/`**: `FacturaDirectaCubit` con estados de
  verificación. `FacturaDirectaSection` widget con botón "Verificar conexión".
- **`lib/app/di/modules/clients_module.dart`**: registra
  `ClientsRepositoryImpl(sl(), sl(), sl(), sl(), sl())` (5 deps), `GetClients`,
  `SaveClientsBatch`, `ClientsCubit(sl(), sl(), sl())`.

### Restricciones

- `FacturaDirectaApiDataSource` y `SettingsRepository` son dependencias
  core/compartidas que otros módulos usan (delivery notes, invoices, dashboard).
  No se eliminan globalmente, solo se desacoplan de `clients`.
- `PrerequisiteFailure` se usa en `clients_cubit.dart`; tras la migración, la
  vista de clientes ya no necesita este tipo de error.
- `ClientCategory` entity vive en `clients/domain/entities/` pero se usa desde
  `client_categories` feature — no mover.

### Dependencias

- `cloud_firestore` — ya en el proyecto.
- No se introducen nuevas dependencias externas.

## 3) Objetivo técnico

- **Qué debe cambiar:** la fuente de datos de clientes pasa de ser FD API +
  Google Sheets a Firestore exclusivamente para lectura; la sincronización FD →
  Firestore pasa a ser manual desde Ajustes.
- **Resultado:** `ClientsRepositoryImpl` con 1-2 dependencias (datasources
  Firestore), vista de clientes sin prerequisitos de configuración externa,
  botón "Sincronizar clientes" funcional en Ajustes.
- **Limitaciones:** no se modifica `FacturaDirectaApiDataSource` ni
  `SettingsRepository`; no se eliminan de otros módulos; `PrerequisiteFailure`
  se mantiene en `failure.dart` para uso potencial de otros módulos.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Seguir el patrón de `ClientCategoryFirestoreDataSource` para crear un datasource
Firestore de clientes. Reescribir `ClientsRepositoryImpl` para que solo use este
datasource. Mover la lógica de sincronización FD → Firestore a un use case nuevo
`SyncClientsFromFd` que se invoque desde `FacturaDirectaCubit`.

### Componentes / módulos / servicios afectados

#### A. Nuevo: `ClientFirestoreDataSource` (data layer, feature clients)

```
lib/features/clients/data/datasources/
  client_firestore_data_source.dart          # abstract
  client_firestore_data_source_impl.dart     # impl
```

**Contrato:**

```dart
abstract class ClientFirestoreDataSource {
  Future<List<ClientModel>> getAll();
  Future<void> updateFields({
    required String id,
    required Map<String, dynamic> fields,
  });
  Future<void> batchUpdate(Map<String, Map<String, dynamic>> updates);
  Future<ClientModel?> findByFdUuid(String facturaDirectaUuid);
  Future<void> add(ClientModel client);
  Future<void> batchAdd(List<ClientModel> clients);
}
```

Colección Firestore: `clients`.\
Cada documento tiene campos: `name`, `facturaDirectaUuid`, `facturaDirectaName`,
`isActive`, `clientCategoryId`, `order`.

#### B. Nuevo: `ClientModel` (data layer DTO)

```
lib/features/clients/data/models/client_model.dart
```

DTO para mapear entre Firestore documents y la entidad `Client`. Incluye
`fromFirestore(DocumentSnapshot)`, `toMap()` y `toEntity()`.

#### C. Modificado: entidad `Client` (domain layer)

La entidad `Client` se simplifica. Ya no tiene campos identitarios de FD (email,
phone, fiscalId, country, city) porque la vista ahora solo lee de Firestore.
Campos resultantes:

```dart
class Client extends Equatable {
  final String id;              // Firestore document ID
  final String name;            // nombre de visualización
  final String facturaDirectaUuid;
  final String facturaDirectaName;
  final bool isActive;
  final String? clientCategoryId;
  final String? categoryName;   // resuelto en runtime, no almacenado en Firestore
  final int? order;
}
```

> `copyWith` se ajusta a los nuevos campos mutables: `isActive`,
> `clientCategoryId`, `categoryName`, `order`.

#### D. Modificado: `ClientsRepository` (domain layer)

Contrato simplificado:

```dart
abstract class ClientsRepository {
  Future<Either<Failure, List<Client>>> getClients();
  Future<Either<Failure, Unit>> saveClientsBatch({
    Map<String, bool> activeToggles,
    Map<String, String?> categoryChanges,
    Map<String, int> orderChanges,
  });
}
```

Se eliminan: `toggleClientField`, `updateClientCategory`, `updateClientOrder`
(eran operaciones individuales contra Sheets, ya no necesarias; la UI usa batch
save).

#### E. Modificado: `ClientsRepositoryImpl` (data layer)

Dependencias reducidas a:

```dart
ClientsRepositoryImpl(
  this._clientDataSource,      // ClientFirestoreDataSource
  this._categoryDataSource,    // ClientCategoryFirestoreDataSource
)
```

- `getClients()`: lee `_clientDataSource.getAll()`, carga categorías de
  `_categoryDataSource.getAll()`, enriquece `categoryName`, ordena
  alfabéticamente por `name`.
- `saveClientsBatch()`: construye mapa de actualizaciones por documento y llama
  a `_clientDataSource.batchUpdate()`.

#### F. Nuevo: use case `SyncClientsFromFd` (domain layer, feature clients)

```
lib/features/clients/domain/usecases/sync_clients_from_fd.dart
```

```dart
class SyncClientsFromFd extends UseCase<SyncClientsResult, NoParams> {
  final FacturaDirectaApiDataSource _fdApi;
  final SettingsRepository _settingsRepo;
  final ClientFirestoreDataSource _clientDataSource;
  
  // ...
  // 1. Lee config FD de _settingsRepo
  // 2. Llama a _fdApi.getContacts(companyId)
  // 3. Para cada contacto: busca por fdUuid en Firestore
  //    - No existe → crea documento
  //    - Existe pero nombre cambió → actualiza facturaDirectaName
  // 4. Retorna SyncClientsResult(created: n, updated: m)
}
```

> **Nota:** Este use case vive en `clients/domain/usecases/` porque opera sobre
> la colección `clients`. Se invoca desde `FacturaDirectaCubit` en settings.

#### G. Nuevo: `SyncClientsResult` (domain layer)

```dart
class SyncClientsResult extends Equatable {
  final int created;
  final int updated;
  // ...
}
```

#### H. Modificado: `ClientsCubit` (presentation layer, feature clients)

- Eliminar dependencia de `GetClientCategories` (las categorías se resuelven en
  el repositorio).
- Eliminar `fetchCategories()` — las categorías ya vienen resueltas con el
  nombre en la lista.
- Simplificar `loadClients()`: solo llama a `GetClients`, no maneja
  `PrerequisiteFailure`.
- Eliminar `ClientsConfigMissing` state.

#### I. Modificado: `ClientsState` (presentation layer)

- Eliminar `ClientsConfigMissing`.
- Eliminar `sheetWarning` de `ClientsLoaded`.
- Mantener `ClientsLoaded`, `ClientsLoading`, `ClientsError`, `ClientsInitial`.

#### J. Modificado: `ClientsPage` (presentation layer)

- Eliminar `_buildConfigMissing()`.
- Eliminar `_buildWarningBanner()` (sheet warning).
- Eliminar `_loadCategories()` y `_cachedCategories` — las categorías vienen en
  `Client.categoryName`.
- La lógica de pending changes y batch save se mantiene, solo cambia que
  `categoryChanges` almacena IDs de documento Firestore (ya lo hace
  actualmente).

> **Nota sobre categorías en la UI:** actualmente `ClientsPage` carga categorías
> para mostrar un dropdown. Tras la migración, las categorías siguen
> necesitándose para el dropdown de selección. Se puede mantener
> `GetClientCategories` como dependencia del cubit para popular el dropdown, o
> cargarse directamente en la page. Decisión: mantener `GetClientCategories` en
> el cubit para el dropdown.

#### K. Modificado: `FacturaDirectaCubit` (presentation layer, feature settings)

Añadir método `syncClients()` que invoca `SyncClientsFromFd` y emite estados de
progreso/resultado.

Nuevos estados necesarios en `FacturaDirectaState`:

```dart
class FacturaDirectaSyncing extends FacturaDirectaState { ... }
class FacturaDirectaSynced extends FacturaDirectaState {
  final int created;
  final int updated;
  ...
}
```

#### L. Modificado: `FacturaDirectaSection` (presentation layer, feature settings)

Añadir botón "Sincronizar clientes" debajo del botón "Verificar conexión".
Manejar estados de syncing/synced con feedback (snackbar).

#### M. Modificado: DI `clients_module.dart`

```dart
void registerClientsModule(GetIt sl) {
  // Data — DataSource
  sl.registerLazySingleton<ClientFirestoreDataSource>(
    () => ClientFirestoreDataSourceImpl(sl()),
  );

  // Data — Repository
  sl.registerLazySingleton<ClientsRepository>(
    () => ClientsRepositoryImpl(sl(), sl()),  // 2 deps
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => GetClients(sl()));
  sl.registerLazySingleton(() => SaveClientsBatch(sl()));
  sl.registerLazySingleton(() => SyncClientsFromFd(sl(), sl(), sl()));

  // Presentation — Cubits
  sl.registerFactory(() => ClientsCubit(sl(), sl(), sl()));
}
```

#### N. Modificado: DI `settings_module.dart`

`FacturaDirectaCubit` necesita recibir `SyncClientsFromFd` como dependencia:

```dart
sl.registerFactory(() => FacturaDirectaCubit(sl(), sl()));
// FacturaDirectaCubit(SettingsRepository, SyncClientsFromFd)
```

### Contratos e interfaces

| Contrato                                   | Operación         | Input                        | Output                               |
| ------------------------------------------ | ----------------- | ---------------------------- | ------------------------------------ |
| `ClientFirestoreDataSource.getAll()`       | Lectura           | —                            | `List<ClientModel>`                  |
| `ClientFirestoreDataSource.updateFields()` | Escritura parcial | `id`, `Map<String, dynamic>` | `void`                               |
| `ClientFirestoreDataSource.batchUpdate()`  | Escritura batch   | `Map<docId, fields>`         | `void`                               |
| `ClientFirestoreDataSource.findByFdUuid()` | Query             | `facturaDirectaUuid`         | `ClientModel?`                       |
| `ClientFirestoreDataSource.add()`          | Creación          | `ClientModel`                | `void`                               |
| `ClientFirestoreDataSource.batchAdd()`     | Creación batch    | `List<ClientModel>`          | `void`                               |
| `ClientsRepository.getClients()`           | Lectura           | —                            | `Either<Failure, List<Client>>`      |
| `ClientsRepository.saveClientsBatch()`     | Escritura         | toggles, categories, orders  | `Either<Failure, Unit>`              |
| `SyncClientsFromFd.call()`                 | Sync              | `NoParams`                   | `Either<Failure, SyncClientsResult>` |

### Flujo de datos o de control

**Carga de clientes (vista):**

```
ClientsPage → ClientsCubit.loadClients() → GetClients → ClientsRepository.getClients()
  → ClientFirestoreDataSource.getAll() → Firestore collection 'clients'
  → ClientCategoryFirestoreDataSource.getAll() → Firestore collection 'client_categories'
  → Enriquecer Client.categoryName
  → Ordenar por name
  → return List<Client>
```

**Guardado batch:**

```
ClientsPage → ClientsCubit.saveBatchChanges() → SaveClientsBatch → ClientsRepository.saveClientsBatch()
  → ClientFirestoreDataSource.batchUpdate() → Firestore batch write
```

**Sincronización manual (Ajustes):**

```
FacturaDirectaSection → FacturaDirectaCubit.syncClients() → SyncClientsFromFd
  → SettingsRepository.getFacturaDirectaConfig()
  → FacturaDirectaApiDataSource.getContacts(companyId)
  → ClientFirestoreDataSource.getAll() (para tener el mapa fdUuid → doc)
  → Para cada contacto FD:
      if no existe → ClientFirestoreDataSource.add()
      if nombre cambió → ClientFirestoreDataSource.updateFields()
  → return SyncClientsResult(created, updated)
```

### Gestión de errores y validaciones

- `ClientFirestoreDataSource`: captura excepciones Firestore y lanza
  `ServerException` (mismo patrón que `ClientCategoryFirestoreDataSourceImpl`).
- `ClientsRepositoryImpl`: envuelve en `try/catch` y retorna
  `Left(ServerFailure())`, `Left(NetworkFailure())`, etc. (patrón existente).
- `SyncClientsFromFd`: valida que FD config exista, retorna
  `Left(ConfigNotFoundFailure())` si no. Captura errores de API y Firestore.
- Validación de `facturaDirectaUuid` no vacío antes de buscar/crear en
  Firestore.

### Consideraciones de compatibilidad o migración

- **Migración one-time de datos:** se necesita un script o proceso para volcar
  los datos de la hoja "clientes" a la colección Firestore `clients`. Esto puede
  hacerse:
  1. Como un script Dart standalone que lea la hoja y escriba a Firestore.
  2. Manualmente desde la consola de Firebase.
  3. Ejecutando la primera sincronización FD → Firestore (botón "Sincronizar
     clientes"), que creará documentos para todos los contactos de FD, y luego
     ajustando manualmente los campos `isActive`, `clientCategoryId`, `order`
     para los que tengan valores no-default en la hoja.

  **Opción recomendada:** Ejecutar la sincronización FD → Firestore primero
  (crea todos los clientes), y luego un script que lea la hoja de Sheets y
  actualice los campos `isActive`, `clientCategoryId`, `order` en los documentos
  correspondientes por `facturaDirectaUuid`.

- **Mapeo de categorías:** la columna "Categoría cliente" de Sheets almacena un
  ID numérico (e.g. "3"). Los documentos en `client_categories` de Firestore
  tienen auto-IDs. Durante la migración, se necesita un mapeo
  `ID numérico → Firestore document ID` basado en algún criterio (nombre,
  orden). Si las categorías ya se migraron de Sheets a Firestore, el mapeo
  debería basarse en el nombre de la categoría.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                      | Propósito                                              |
| ------------------------------------------------------------------------------ | ------------------------------------------------------ |
| `lib/features/clients/data/datasources/client_firestore_data_source.dart`      | Contrato abstract del datasource Firestore de clientes |
| `lib/features/clients/data/datasources/client_firestore_data_source_impl.dart` | Implementación Firestore del datasource de clientes    |
| `lib/features/clients/data/models/client_model.dart`                           | DTO Firestore ↔ entidad Client                         |
| `lib/features/clients/domain/usecases/sync_clients_from_fd.dart`               | Use case de sincronización manual FD → Firestore       |
| `lib/features/clients/domain/entities/sync_clients_result.dart`                | Entidad resultado de sincronización                    |

### Artefactos a modificar

| Artefacto                                                                 | Cambio esperado                                                                                                                                                                                                           |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/domain/entities/client.dart`                        | Simplificar campos: eliminar `title`, `email`, `phone`, `fiscalId`, `country`, `city`. Añadir `facturaDirectaUuid`, `facturaDirectaName`, `clientCategoryId`. Renombrar `orderInNewOrders` → `order`. Ajustar `copyWith`. |
| `lib/features/clients/domain/entities/clients_result.dart`                | Eliminar `sheetWarning`. Simplificar o eliminar la clase si solo envuelve `List<Client>`.                                                                                                                                 |
| `lib/features/clients/domain/repositories/clients_repository.dart`        | Eliminar `toggleClientField`, `updateClientCategory`, `updateClientOrder`. Mantener `getClients` (retorna `List<Client>` en lugar de `ClientsResult`), `saveClientsBatch`.                                                |
| `lib/features/clients/data/repositories/clients_repository_impl.dart`     | Reescribir completamente: eliminar ~600 líneas de lógica Sheets/FD. Solo depende de `ClientFirestoreDataSource` + `ClientCategoryFirestoreDataSource`.                                                                    |
| `lib/features/clients/presentation/bloc/clients_cubit.dart`               | Simplificar `loadClients()`: sin `PrerequisiteFailure`. Ajustar a nuevo retorno `List<Client>`. Mantener `fetchCategories()` para dropdown UI.                                                                            |
| `lib/features/clients/presentation/bloc/clients_state.dart`               | Eliminar `ClientsConfigMissing`. Eliminar `sheetWarning` de `ClientsLoaded`.                                                                                                                                              |
| `lib/features/clients/presentation/pages/clients_page.dart`               | Eliminar `_buildConfigMissing()`, `_buildWarningBanner()`. Ajustar a nuevos campos de `Client` (e.g. `client.name` en vez de `client.title ?? client.name`).                                                              |
| `lib/features/clients/domain/usecases/get_clients.dart`                   | Ajustar tipo de retorno a `List<Client>` si se elimina `ClientsResult`.                                                                                                                                                   |
| `lib/features/clients/domain/usecases/save_clients_batch.dart`            | Mantener, ajustar `categoryChanges` a `Map<String, String?>` si necesario.                                                                                                                                                |
| `lib/features/settings/presentation/bloc/factura_directa_cubit.dart`      | Añadir `syncClients()` method. Añadir dependencia de `SyncClientsFromFd`.                                                                                                                                                 |
| `lib/features/settings/presentation/bloc/factura_directa_state.dart`      | Añadir estados `FacturaDirectaSyncing`, `FacturaDirectaSynced`.                                                                                                                                                           |
| `lib/features/settings/presentation/widgets/factura_directa_section.dart` | Añadir botón "Sincronizar clientes" con manejo de estados sync.                                                                                                                                                           |
| `lib/app/di/modules/clients_module.dart`                                  | Registrar `ClientFirestoreDataSource`, `SyncClientsFromFd`. Actualizar `ClientsRepositoryImpl` a 2 deps. Eliminar registros de use cases obsoletos.                                                                       |
| `lib/app/di/modules/settings_module.dart`                                 | Actualizar `FacturaDirectaCubit` para recibir `SyncClientsFromFd`.                                                                                                                                                        |
| `lib/app/localization/l10n/*.arb`                                         | Añadir claves i18n para "Sincronizar clientes", feedback de sincronización, estado vacío.                                                                                                                                 |

### Artefactos a retirar o reemplazar

| Artefacto                                                                            | Motivo                                                                                                           |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/data/dto/client_dto.dart`                                      | Mapeaba JSON de FD API a entidad. Ya no se usa en la carga normal; la sincronización puede parsear directamente. |
| `lib/features/clients/data/dto/client_sheet_dto.dart`                                | Parseaba datos de Google Sheets. Completamente obsoleto.                                                         |
| `lib/features/clients/data/dto/client_category_sheet_dto.dart`                       | Parseaba categorías de Google Sheets. Categorías ya se leen de Firestore.                                        |
| `lib/features/clients/domain/usecases/toggle_client_field.dart`                      | Operación individual contra Sheets, no registrada en DI. Obsoleto.                                               |
| `lib/features/clients/domain/usecases/update_client_category.dart` (feature clients) | Operación individual contra Sheets, no registrada en DI. Obsoleto.                                               |
| `lib/features/clients/domain/usecases/update_client_order.dart`                      | Operación individual contra Sheets, no registrada en DI. Obsoleto.                                               |

## 6) Estrategia de implementación

### Pasos

1. **Crear `ClientModel` y `ClientFirestoreDataSource`** (abstract + impl).
   - Seguir patrón de `ClientCategoryFirestoreDataSourceImpl`.
   - Colección: `clients`.
   - Incluir `findByFdUuid()` con query Firestore
     `.where('facturaDirectaUuid', isEqualTo: uuid).limit(1)`.

2. **Crear entidad `SyncClientsResult` y use case `SyncClientsFromFd`**.
   - Depende de `FacturaDirectaApiDataSource`, `SettingsRepository`,
     `ClientFirestoreDataSource`.
   - Usa `ClientDto.fromJson()` para parsear respuesta de FD (mantener
     temporalmente `ClientDto` o mover parsing inline al use case).

3. **Refactorizar entidad `Client`**.
   - Simplificar campos según diseño.
   - Ajustar `copyWith`, `props`.

4. **Simplificar `ClientsResult`** o eliminarlo.
   - Si se elimina, `GetClients` retorna `Either<Failure, List<Client>>`.

5. **Simplificar `ClientsRepository` contrato**.
   - Eliminar métodos individuales de escritura.
   - Ajustar `getClients()` para retornar `List<Client>`.

6. **Reescribir `ClientsRepositoryImpl`**.
   - Solo depende de `ClientFirestoreDataSource` +
     `ClientCategoryFirestoreDataSource`.
   - `getClients()`: lee clientes, carga categorías, enriquece `categoryName`,
     ordena.
   - `saveClientsBatch()`: construye batch update y delega a datasource.

7. **Actualizar `ClientsCubit` y `ClientsState`**.
   - Eliminar `ClientsConfigMissing`, `sheetWarning`.
   - Simplificar `loadClients()`.

8. **Actualizar `ClientsPage`**.
   - Eliminar lógica de config missing y sheet warning.
   - Ajustar campos de Client a nuevos nombres.

9. **Extender `FacturaDirectaCubit` y `FacturaDirectaState`**.
   - Añadir `syncClients()`, estados de sync.

10. **Actualizar `FacturaDirectaSection`**.
    - Añadir botón "Sincronizar clientes".

11. **Actualizar DI modules**.
    - `clients_module.dart`: registrar datasource, actualizar repository,
      registrar `SyncClientsFromFd`.
    - `settings_module.dart`: actualizar `FacturaDirectaCubit`.

12. **Eliminar artefactos obsoletos**.
    - `ClientDto`, `ClientSheetDto`, `ClientCategorySheetDto`.
    - Use cases individuales no registrados.

13. **Añadir claves i18n** para nuevos textos.

14. **Actualizar/crear tests** para los componentes modificados/nuevos.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14

### Dependencias entre pasos

- Paso 2 depende de 1 (usa `ClientFirestoreDataSource`).
- Pasos 3-5 son refactoring de interfaces; deben hacerse juntos o
  secuencialmente.
- Paso 6 depende de 1, 3, 4, 5.
- Paso 7 depende de 5, 6.
- Paso 8 depende de 3, 7.
- Pasos 9-10 dependen de 2.
- Paso 11 depende de 1, 2, 6, 9.
- Paso 12 se puede hacer después de que todo compile.

### Puntos delicados

- **Refactoring de `Client` entity**: cambiar campos afecta a toda la cadena
  presentation → domain → data. Hay que hacerlo de forma coordinada para que
  compile en cada paso. Considerar hacer cambios incrementales.
- **`ClientDto.fromJson()`**: actualmente se usa para parsear la respuesta de FD
  API. Tras la migración, solo se usa en `SyncClientsFromFd`. Se puede mantener
  como utilidad dentro del use case o en el datasource, no necesariamente como
  archivo separado.
- **Categorías en la UI**: `ClientsPage` muestra un dropdown de categorías. Tras
  la migración, el cubit puede seguir exponiendo `fetchCategories()` para este
  propósito, delegando a `GetClientCategories`.
- **`delivery_notes_repository_impl.dart`**: usa `getContacts()` de FD API
  directamente para su propia lógica. No se ve afectado por esta migración, pero
  confirmar que no depende de `ClientsRepository`.

## 7) Estrategia de validación

### Verificación automática (tests)

- **Unit tests para `ClientFirestoreDataSourceImpl`**: mock de
  `FirebaseFirestore`, verificar CRUD y query por `facturaDirectaUuid`.
- **Unit tests para `ClientsRepositoryImpl`**: mock datasources, verificar
  `getClients()` enriquece categorías, `saveClientsBatch()` construye updates
  correctos.
- **Unit tests para `SyncClientsFromFd`**: mock FD API, settings, datasource.
  Verificar escenarios: contactos nuevos creados, nombres actualizados, config
  missing.
- **Unit tests para `ClientsCubit`**: verificar estados emitidos con mock
  repository.
- **Unit tests para `FacturaDirectaCubit.syncClients()`**: verificar estados de
  sync.

### Validación manual

- Verificar que la vista de clientes carga correctamente desde Firestore.
- Verificar toggle activo, cambio de categoría, cambio de orden → persistencia
  en Firestore.
- Verificar batch save con múltiples cambios.
- Verificar botón "Sincronizar clientes" en Ajustes: crea nuevos, actualiza
  nombres.
- Verificar estado vacío (sin datos en Firestore).
- Verificar que no se llama a FD API al acceder a la vista de clientes
  (verificar en logs/network).

### Escenarios a cubrir

1. Carga con 0 clientes en Firestore → estado vacío.
2. Carga con N clientes → lista ordenada alfabéticamente.
3. Carga con clientes que tienen `clientCategoryId` → nombre de categoría
   resuelto.
4. Carga con clientes con `clientCategoryId` que no existe en
   `client_categories` → `categoryName` null.
5. Toggle activo + guardar → verificar en Firestore.
6. Cambio categoría + orden + guardar → verificar batch write.
7. Sincronización con contactos nuevos en FD → documentos creados.
8. Sincronización con nombre cambiado en FD → `facturaDirectaName` actualizado.
9. Sincronización sin FD config → error informativo.
10. Error de red en lectura Firestore → estado error.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

1. **Migración de datos incompleta:** si la migración one-time de Sheets a
   Firestore no mapea correctamente `clientCategoryId` (ID numérico de Sheets →
   document ID de Firestore), los clientes perderán su categoría asignada.
2. **Pérdida de datos complementarios:** si se despliega antes de completar la
   migración, los clientes aparecerán sin datos de activo/categoría/orden.
3. **Campos de `Client` usados en otros módulos:** si algún módulo referencia
   campos eliminados (`title`, `email`, etc.) de `Client`, se romperá la
   compilación.

### Impacto potencial

- La vista de clientes dejará de funcionar con datos de Sheets inmediatamente —
  es el objetivo.
- Otros módulos que usen `Client` entity directamente podrían verse afectados si
  dependen de campos eliminados.

### Mitigación

1. **Ejecutar migración antes del despliegue.** Verificar datos en Firestore
   console.
2. **Buscar usos de `Client` en todo el proyecto** antes de eliminar campos. Si
   otros módulos lo usan (e.g. `orders_today`, `delivery_notes`), evaluar si
   necesitan campos identitarios y, si es así, mantenerlos o usar una entidad
   diferente.
3. **Crear índice Firestore** para `facturaDirectaUuid` si las queries de
   sincronización son lentas con muchos documentos.

### Plan de rollback

- Git revert del commit/branch.
- Los datos en Firestore quedan como están (no destructivo).
- La hoja de Sheets sigue existiendo como referencia.

## 9) Suposiciones

- Los campos `title`, `email`, `phone`, `fiscalId`, `country`, `city` de
  `Client` no se usan en la vista de clientes ni en otros módulos que dependan
  de `Client` entity. Si se confirma que sí se usan, se mantendrán en la entidad
  con valor null (cargados solo durante sincronización).
- La colección `clients` de Firestore no existe aún.
- El mapeo de `clientCategoryId` durante la migración se basará en el nombre de
  la categoría (buscar en `client_categories` el documento con ese nombre y usar
  su ID).
- Firestore batch writes soportan hasta 500 operaciones por batch — suficiente
  para el volumen esperado de clientes.

## 10) Preguntas abiertas

- **PT-01:** ¿La entidad `Client` se usa en otros módulos además de la feature
  `clients`? Si `orders_today` o `delivery_notes` referencian `Client` con
  campos identitarios (email, phone, etc.), hay que mantener esos campos o crear
  una entidad separada para esos módulos.
- **PT-02:** ¿Cuántos clientes se esperan como máximo? Si son menos de 500, el
  batch write de Firestore cubre todo en un solo batch. Si son más, hay que
  particionar.

## 11) Notas para implementación

- **Restricciones técnicas a respetar:**
  - Seguir el patrón de `ClientCategoryFirestoreDataSourceImpl` estrictamente.
  - No introducir nuevas dependencias externas.
  - Usar `try/catch` + `ServerException` en el datasource, `Left/Right` en el
    repositorio (patrón existente).
  - i18n obligatorio para todos los textos nuevos.
  - Design tokens del tema para cualquier UI nueva.

- **Secuencia sugerida:**
  - Empezar por la capa data (datasource + model), luego domain (entity +
    repository + use cases), luego presentation (cubit + state + page), y
    finalmente DI + cleanup.
  - Hacer commits incrementales por capa para facilitar revisión.

- **Consideraciones para no romper comportamiento existente:**
  - Verificar que `ClientsPage` no referencia `client.title` directamente
    (actualmente usa `client.title ?? client.name`). Tras la migración, `name`
    es el campo de display.
  - Verificar que el dropdown de categorías sigue funcionando: debe cargar
    categorías activas desde `client_categories` Firestore para el selector.
  - El campo `id` de `Client` pasa de ser el UUID de FD a ser el document ID de
    Firestore. Verificar que los maps de pending changes en la page usen este
    nuevo ID consistentemente.

- **Estado: Listo para implementación**
