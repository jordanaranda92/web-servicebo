# Technical Analysis: Integración con FacturaDirecta

- **Fecha:** 2026-05-06
- **Identificador:** facturadirecta-integration
- **Fuente:** docs/functional-analysis/2026-05-06-facturadirecta-integration.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Se crean **4 nuevas features** Clean Architecture (`contacts`, `products`,
  `invoices`, `delivery_notes`), cada una con capas `data/`, `domain/` y
  `presentation/`.
- Se refactoriza la entidad `FacturaDirectaConfig` existente: `subdomain` →
  `companyId` y se actualiza la URL base a `https://app.facturadirecta.com/api`.
- Se introduce un **data source remoto compartido**
  (`FacturaDirectaApiDataSource`) en `core/` para centralizar la comunicación
  HTTP con la API de FacturaDirecta (autenticación Basic, base URL, manejo de
  errores HTTP).
- Se extiende el **menú lateral** de 4 a 8 ítems y el `IndexedStack` con las 4
  nuevas páginas.
- Se añade un ajuste de **elementos por página** en Settings, persistido con
  `SharedPreferences`.
- Principales áreas impactadas: `lib/features/settings/`, `lib/features/home/`,
  `lib/core/`, `lib/app/di/`, `lib/app/localization/`, 4 nuevos módulos en
  `lib/features/`.
- Riesgo general estimado: **medio** — el cambio es amplio en cantidad de
  artefactos pero los patrones están bien establecidos y se replican.

## 2) Contexto técnico observado

### Arquitectura y patrones

- **Clean Architecture feature-first** con BLoC/Cubit, GetIt, fpdart.
- Patrón consistente: `Domain` (entities, repository contracts, usecases) →
  `Data` (datasources, DTOs, mappers, repository impl) → `Presentation`
  (bloc/cubit, pages, widgets).
- UseCases extienden `UseCase<Type, Params>` con retorno
  `Either<Failure, Type>`.
- Cubits registrados como `registerFactory` (por pantalla); repositories y
  datasources como `registerLazySingleton`.
- Excepciones técnicas (`ServerException`, `NetworkException`, `CacheException`)
  lanzadas en datasources, capturadas en repository impl → convertidas a
  `Failure`.

### Módulos relevantes existentes

- **Settings feature:** Gestiona `FacturaDirectaConfig` (`subdomain`,
  `apiToken`). El `apiToken` se persiste en `FlutterSecureStorage`; el
  `subdomain` en `SharedPreferences`. Tiene un remote data source para verificar
  conexión que usa `Dio` con autenticación Basic
  (`base64Encode(utf8.encode('$apiToken:'))`).
- **Home feature:** `SideMenuShell` con `SideMenuCubit` (estado:
  `selectedIndex`, `isExpanded`), `IndexedStack` de 4 páginas, widget `SideMenu`
  con lista de `_MenuItemData`.
- **Core:** `Failure` hierarchy, `AppException` hierarchy, `UseCase` base class,
  `AppLogger`, `PageHeader` widget.

### Restricciones técnicas

- La API de FacturaDirecta usa **Basic Auth** con `apiToken:` (apiToken como
  usuario, contraseña vacía).
- La URL base actual (`https://$subdomain.facturadirecta.com/api`) cambia a
  `https://app.facturadirecta.com/api` con `companyId` como segmento de ruta.
- La app solo soporta idioma `es` (un solo ARB file).
- Plataformas target: `windows`, `macos` (desktop landscape).

### Dependencias relevantes

- `dio: ^5.9.2` — cliente HTTP (ya registrado en `settings_module`).
- `flutter_secure_storage: ^10.0.0` — para apiToken.
- `shared_preferences: ^2.5.5` — para config persistente.
- `equatable: ^2.0.7` — para entities y states.
- `fpdart: ^1.2.0` — para Either.
- `flutter_bloc: ^9.0.0` — state management.
- `get_it: ^9.0.0` — DI.
- No se requieren nuevas dependencias externas.

## 3) Objetivo técnico

- **Qué debe cambiar:** Implementar la capa completa (data + domain +
  presentation) para consumir 7 endpoints de la API de FacturaDirecta,
  refactorizar `FacturaDirectaConfig`, extender la navegación lateral y añadir
  configuración de paginación.
- **Resultado técnico:** 4 features funcionales con listados, filtros,
  paginación y detalle; un data source HTTP centralizado; configuración
  actualizada.
- **Limitaciones a respetar:** No introducir dependencias nuevas. Respetar Clean
  Architecture estricta. No invocar POST de albaranes desde UI. Filtrado y
  paginación client-side.

## 4) Diseño técnico de la solución

### Enfoque propuesto

1. **Data source HTTP centralizado** en `core/` — Un
   `FacturaDirectaApiDataSource` (interfaz + impl) que encapsula Dio con la
   autenticación Basic, base URL y manejo de errores HTTP. Cada feature inyecta
   este datasource en su repository impl para las llamadas específicas.

2. **4 features independientes** siguiendo el patrón exacto del proyecto:
   - `contacts` — listado con filtro por nombre.
   - `products` — listado con filtro por nombre.
   - `invoices` — listado paginado con filtros por fecha/cliente + detalle.
   - `delivery_notes` — listado paginado con filtros por fecha/cliente +
     detalle + POST (sin UI).

3. **Refactorización de Settings** — `subdomain` → `companyId` en toda la cadena
   (entity, state, cubit, data sources, widgets, i18n). Nuevo campo `pageSize`
   en settings local data source.

4. **Extensión de navegación** — `SideMenuCubit._maxIndex` de 3 a 7, nuevos
   ítems en `SideMenu`, nuevas páginas en `SideMenuShell`.

### Componentes / módulos / servicios afectados

| Módulo                         | Tipo de cambio                                            |
| ------------------------------ | --------------------------------------------------------- |
| `lib/core/`                    | Crear `FacturaDirectaApiDataSource` (interfaz + impl)     |
| `lib/features/settings/`       | Refactorizar `subdomain` → `companyId`; añadir `pageSize` |
| `lib/features/home/`           | Extender menú lateral (8 ítems), extender `IndexedStack`  |
| `lib/features/contacts/`       | **Nuevo** — feature completa                              |
| `lib/features/products/`       | **Nuevo** — feature completa                              |
| `lib/features/invoices/`       | **Nuevo** — feature completa                              |
| `lib/features/delivery_notes/` | **Nuevo** — feature completa                              |
| `lib/app/di/`                  | 4 nuevos módulos DI + registro en `injection.dart`        |
| `lib/app/localization/`        | Nuevas claves i18n en ARB                                 |

### Contratos e interfaces

#### `FacturaDirectaApiDataSource` (core)

```dart
abstract class FacturaDirectaApiDataSource {
  Future<List<Map<String, dynamic>>> getContacts(String companyId);
  Future<List<Map<String, dynamic>>> getProducts(String companyId);
  Future<List<Map<String, dynamic>>> getInvoices(String companyId);
  Future<Map<String, dynamic>> getInvoiceById(String companyId, String id);
  Future<List<Map<String, dynamic>>> getDeliveryNotes(String companyId);
  Future<Map<String, dynamic>> getDeliveryNoteById(String companyId, String id);
  Future<Map<String, dynamic>> createDeliveryNote(String companyId, Map<String, dynamic> data);
}
```

> Devuelve `Map<String, dynamic>` (JSON crudo). Cada feature mapea a sus
> DTOs/Entities.

#### Repositories (contrato por feature)

```dart
// contacts
abstract class ContactsRepository {
  Future<Either<Failure, List<Contact>>> getContacts();
}

// products
abstract class ProductsRepository {
  Future<Either<Failure, List<Product>>> getProducts();
}

// invoices
abstract class InvoicesRepository {
  Future<Either<Failure, List<Invoice>>> getInvoices();
  Future<Either<Failure, InvoiceDetail>> getInvoiceById(String id);
}

// delivery_notes
abstract class DeliveryNotesRepository {
  Future<Either<Failure, List<DeliveryNote>>> getDeliveryNotes();
  Future<Either<Failure, DeliveryNoteDetail>> getDeliveryNoteById(String id);
  Future<Either<Failure, DeliveryNoteDetail>> createDeliveryNote(CreateDeliveryNoteParams params);
}
```

> Los repositories obtienen `companyId` y `apiToken` del `SettingsRepository`
> existente. Si no hay config guardada, retornan un `Failure` específico (e.g.
> `ConfigNotFoundFailure`).

#### UseCases por feature

| Feature        | UseCase                 | Params                          | Return               |
| -------------- | ----------------------- | ------------------------------- | -------------------- |
| contacts       | `GetContacts`           | `NoParams`                      | `List<Contact>`      |
| products       | `GetProducts`           | `NoParams`                      | `List<Product>`      |
| invoices       | `GetInvoices`           | `NoParams`                      | `List<Invoice>`      |
| invoices       | `GetInvoiceDetail`      | `InvoiceDetailParams(id)`       | `InvoiceDetail`      |
| delivery_notes | `GetDeliveryNotes`      | `NoParams`                      | `List<DeliveryNote>` |
| delivery_notes | `GetDeliveryNoteDetail` | `DeliveryNoteDetailParams(id)`  | `DeliveryNoteDetail` |
| delivery_notes | `CreateDeliveryNote`    | `CreateDeliveryNoteParams(...)` | `DeliveryNoteDetail` |

### Entities (domain)

Las entities se inferirán de la especificación OpenAPI. Estructura estimada:

```dart
// Contact
class Contact extends Equatable {
  final String id;
  final String name;       // nombre/razón social
  final String? email;
  final String? phone;
  final String? taxId;     // NIF/CIF
  // ...campos según OpenAPI
}

// Product
class Product extends Equatable {
  final String id;
  final String name;
  final double? price;
  final String? code;
  // ...campos según OpenAPI
}

// Invoice (listado)
class Invoice extends Equatable {
  final String id;
  final String number;
  final DateTime date;
  final String? customerName;
  final String? customerId;
  final double? totalAmount;
  final String? status;
}

// InvoiceDetail (detalle con líneas)
class InvoiceDetail extends Equatable {
  final String id;
  final String number;
  final DateTime date;
  final String? customerName;
  final String? customerId;
  final double? totalAmount;
  final String? status;
  final List<InvoiceLine> lines;
}

// DeliveryNote / DeliveryNoteDetail — análogo a Invoice/InvoiceDetail
```

### Flujo de datos o de control

```
UI (Page) → Cubit/Bloc → UseCase → Repository (contrato)
                                        ↓
                              RepositoryImpl
                              ├─ SettingsRepository.getFacturaDirectaConfig()
                              │   → obtiene companyId + apiToken
                              │   → si null → Left(ConfigNotFoundFailure)
                              └─ FacturaDirectaApiDataSource.getXxx(companyId)
                                  → Dio GET con Basic Auth
                                  → JSON response
                                  → DTO.fromJson → Mapper → Entity
                                  → Right(entities)
```

**Flujo de filtrado (Contactos/Productos):**

```
Cubit state contiene:
  - allItems: List<T>         ← datos completos del API
  - filteredItems: List<T>    ← resultado tras filtro
  - nameFilter: String        ← texto del filtro

Al cargar: allItems = sorted(response), filteredItems = allItems
Al filtrar: filteredItems = allItems.where(name.contains(filter))
```

**Flujo de filtrado + paginación (Facturas/Albaranes):**

```
Cubit state contiene:
  - allItems: List<T>
  - filteredItems: List<T>
  - pagedItems: List<T>         ← subset paginado de filteredItems
  - dateFrom / dateTo: DateTime?
  - selectedClientIds: Set<String>
  - currentPage: int
  - pageSize: int
  - totalPages: int

Al cargar: allItems = sorted(response), aplicar filtros, paginar
Al filtrar: reset page=0, filteredItems = apply filters, paginar
Al cambiar página: pagedItems = filteredItems.skip(page*size).take(size)
```

**Carga automática de contactos para filtro:**

```
Al abrir Facturas o Albaranes:
  1. Cubit lanza evento LoadList
  2. En paralelo (o secuencialmente): carga contactos para el selector de filtro
  3. El state del cubit incluye contactsForFilter: List<Contact>
  4. Si falla la carga de contactos: contactsLoadError = true (selector vacío con retry)
```

### Gestión de errores y validaciones

| Escenario              | Excepción en datasource | Failure en repository           | Estado en UI                                  |
| ---------------------- | ----------------------- | ------------------------------- | --------------------------------------------- |
| Sin config guardada    | —                       | `ConfigNotFoundFailure`         | Mensaje "Configura FacturaDirecta en Ajustes" |
| Error de red / timeout | `NetworkException`      | `NetworkFailure`                | Mensaje error + botón reintentar              |
| 401 / 403              | `ServerException(401)`  | `ServerFailure` / `AuthFailure` | Mensaje credenciales inválidas + reintentar   |
| 404                    | `ServerException(404)`  | `ServerFailure`                 | Mensaje error genérico                        |
| 5xx                    | `ServerException(5xx)`  | `ServerFailure`                 | Mensaje error servidor + reintentar           |
| Respuesta vacía        | —                       | `Right([])`                     | Estado vacío                                  |
| Error de parseo        | `ParsingException`      | `EntityMappingFailure`          | Mensaje error genérico                        |

Se añade un nuevo `Failure` tipo `ConfigNotFoundFailure` en
`core/error/failure.dart` para distinguir el caso de configuración ausente.

### Consideraciones de compatibilidad o migración

- **Migración `subdomain` → `companyId`:** La key en `SharedPreferences` cambia
  de `settings_factura_directa_subdomain` a
  `settings_factura_directa_company_id`. Usuarios con configuración previa
  perderán el valor guardado y deberán reconfigurar. Esto es aceptable dado que
  el campo cambia de semántica (ya no es un subdominio sino un identificador de
  compañía). Si se desea migrar, se puede leer la key antigua y eliminarla en el
  primer arranque.
- **`FacturaDirectaRemoteDataSource` existente:** El método `verifyConnection`
  actual construye la URL con `subdomain`. Deberá actualizarse para usar la
  nueva URL base + `companyId`.
- **`Dio` singleton:** Actualmente se registra en `settings_module`. Se
  reutilizará la misma instancia para el nuevo `FacturaDirectaApiDataSource`.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                               | Propósito                                                    |
| ----------------------------------------------------------------------- | ------------------------------------------------------------ |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`        | Interfaz del data source HTTP centralizado                   |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`   | Implementación con Dio + Basic Auth                          |
| `lib/core/error/failure.dart` (modificar)                               | Añadir `ConfigNotFoundFailure`                               |
| `lib/features/contacts/domain/entities/contact.dart`                    | Entity Contact                                               |
| `lib/features/contacts/domain/repositories/contacts_repository.dart`    | Contrato repository                                          |
| `lib/features/contacts/domain/usecases/get_contacts.dart`               | UseCase                                                      |
| `lib/features/contacts/data/dto/contact_dto.dart`                       | DTO con fromJson                                             |
| `lib/features/contacts/data/mappers/contact_mapper.dart`                | DTO → Entity                                                 |
| `lib/features/contacts/data/repositories/contacts_repository_impl.dart` | Impl                                                         |
| `lib/features/contacts/presentation/bloc/contacts_cubit.dart`           | Cubit                                                        |
| `lib/features/contacts/presentation/bloc/contacts_state.dart`           | States                                                       |
| `lib/features/contacts/presentation/pages/contacts_page.dart`           | Page                                                         |
| `lib/features/contacts/presentation/widgets/contacts_list.dart`         | Widget listado                                               |
| `lib/features/contacts/presentation/widgets/contact_filter_bar.dart`    | Widget filtro nombre                                         |
| `lib/features/products/...`                                             | Estructura análoga a contacts                                |
| `lib/features/invoices/domain/entities/invoice.dart`                    | Entity Invoice (listado)                                     |
| `lib/features/invoices/domain/entities/invoice_detail.dart`             | Entity InvoiceDetail (con líneas)                            |
| `lib/features/invoices/domain/entities/invoice_line.dart`               | Entity línea de factura                                      |
| `lib/features/invoices/domain/repositories/invoices_repository.dart`    | Contrato                                                     |
| `lib/features/invoices/domain/usecases/get_invoices.dart`               | UseCase listado                                              |
| `lib/features/invoices/domain/usecases/get_invoice_detail.dart`         | UseCase detalle                                              |
| `lib/features/invoices/data/dto/invoice_dto.dart`                       | DTO listado                                                  |
| `lib/features/invoices/data/dto/invoice_detail_dto.dart`                | DTO detalle                                                  |
| `lib/features/invoices/data/mappers/invoice_mapper.dart`                | Mappers                                                      |
| `lib/features/invoices/data/repositories/invoices_repository_impl.dart` | Impl                                                         |
| `lib/features/invoices/presentation/bloc/invoices_cubit.dart`           | Cubit con paginación+filtros                                 |
| `lib/features/invoices/presentation/bloc/invoices_state.dart`           | States                                                       |
| `lib/features/invoices/presentation/pages/invoices_page.dart`           | Page listado                                                 |
| `lib/features/invoices/presentation/pages/invoice_detail_page.dart`     | Page detalle                                                 |
| `lib/features/invoices/presentation/widgets/...`                        | Widgets (listado, filtros, paginación)                       |
| `lib/features/delivery_notes/...`                                       | Estructura análoga a invoices + `CreateDeliveryNote` usecase |
| `lib/app/di/modules/contacts_module.dart`                               | DI contacts                                                  |
| `lib/app/di/modules/products_module.dart`                               | DI products                                                  |
| `lib/app/di/modules/invoices_module.dart`                               | DI invoices                                                  |
| `lib/app/di/modules/delivery_notes_module.dart`                         | DI delivery_notes                                            |

### Artefactos a modificar

| Artefacto                                                                                    | Cambio esperado                                                                                                      |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `lib/features/settings/domain/entities/factura_directa_config.dart`                          | `subdomain` → `companyId`; `baseUrl` → `https://app.facturadirecta.com/api`                                          |
| `lib/features/settings/presentation/bloc/factura_directa_cubit.dart`                         | Renombrar params `subdomain` → `companyId`                                                                           |
| `lib/features/settings/presentation/bloc/factura_directa_state.dart`                         | Renombrar campo `subdomain` → `companyId` en todos los states                                                        |
| `lib/features/settings/presentation/widgets/factura_directa_section.dart`                    | `_subdomainController` → `_companyIdController`; label i18n                                                          |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`               | Renombrar métodos `getFacturaDirectaSubdomain` → `getFacturaDirectaCompanyId`; añadir `getPageSize` / `savePageSize` |
| `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`          | Renombrar key + métodos; implementar pageSize con SharedPreferences                                                  |
| `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source.dart`      | Renombrar param `subdomain` → `companyId`                                                                            |
| `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source_impl.dart` | Actualizar URL base y param                                                                                          |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`                      | Adaptar a renombramientos                                                                                            |
| `lib/features/settings/domain/repositories/settings_repository.dart`                         | Añadir `getPageSize` / `savePageSize`                                                                                |
| `lib/features/settings/presentation/pages/settings_page.dart`                                | Añadir sección de pageSize (o integrar en FacturaDirectaSection)                                                     |
| `lib/features/home/presentation/pages/side_menu_shell.dart`                                  | Añadir 4 páginas al `_pages`, reordenar (Settings al final)                                                          |
| `lib/features/home/presentation/widgets/side_menu.dart`                                      | Añadir 4 ítems al menú, reordenar                                                                                    |
| `lib/features/home/presentation/bloc/side_menu_cubit.dart`                                   | `_maxIndex` de 3 → 7                                                                                                 |
| `lib/app/di/injection.dart`                                                                  | Registrar 4 nuevos módulos + `FacturaDirectaApiDataSource` en core module                                            |
| `lib/app/di/modules/core_module.dart`                                                        | Registrar `FacturaDirectaApiDataSource`                                                                              |
| `lib/app/localization/l10n/app_es.arb`                                                       | Añadir ~40-50 nuevas claves i18n                                                                                     |
| `lib/core/error/failure.dart`                                                                | Añadir `ConfigNotFoundFailure`                                                                                       |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                                                                                      |
| --------- | ------------------------------------------------------------------------------------------- |
| Ninguno   | No se retira ningún artefacto. La refactorización de `subdomain` → `companyId` es in-place. |

## 6) Estrategia de implementación

### Orden recomendado

1. **Paso 1 — Core: Failure y DataSource API**
   - Añadir `ConfigNotFoundFailure` a `core/error/failure.dart`.
   - Crear `FacturaDirectaApiDataSource` (interfaz + impl) en
     `core/data/datasources/`.
   - Registrar en `core_module.dart` (depende de `Dio` y `SettingsRepository`
     para obtener credenciales).

2. **Paso 2 — Refactorizar Settings (`subdomain` → `companyId`)**
   - Renombrar campo en `FacturaDirectaConfig` entity.
   - Actualizar `baseUrl` getter.
   - Propagar renombramiento en: local data source (interfaz + impl), remote
     data source (interfaz + impl), repository impl, cubit, states, widget.
   - Actualizar claves i18n afectadas.
   - Añadir `pageSize` a local data source y `SettingsRepository`.
   - Añadir widget/sección de configuración de pageSize en la página de Ajustes.

3. **Paso 3 — Feature: Contacts**
   - Crear la estructura completa: entity, repository contract, usecase, DTO,
     mapper, repository impl, cubit, state, page, widgets.
   - Crear `contacts_module.dart` en DI.
   - Añadir claves i18n.

4. **Paso 4 — Feature: Products**
   - Estructura análoga a Contacts (mismos patrones).
   - Crear `products_module.dart`.
   - Añadir claves i18n.

5. **Paso 5 — Feature: Invoices**
   - Estructura con entities de listado + detalle + líneas.
   - Cubit con estado complejo: filtros por fecha/cliente, paginación.
   - Pages de listado + detalle.
   - Carga automática de contactos para filtro.
   - Crear `invoices_module.dart`.
   - Añadir claves i18n.

6. **Paso 6 — Feature: Delivery Notes**
   - Estructura análoga a Invoices + `CreateDeliveryNote` usecase (sin wiring en
     UI).
   - Crear `delivery_notes_module.dart`.
   - Añadir claves i18n.

7. **Paso 7 — Integración en navegación**
   - Extender `SideMenuShell` con las 4 nuevas páginas.
   - Extender `SideMenu` con los 4 nuevos ítems.
   - Actualizar `SideMenuCubit._maxIndex` a 7.
   - Reordenar: Settings al final (índice 7).
   - Registrar los 4 nuevos módulos DI en `injection.dart`.

8. **Paso 8 — i18n completo y limpieza**
   - Verificar todas las claves i18n en `app_es.arb`.
   - Ejecutar `flutter gen-l10n`.
   - Ejecutar `flutter analyze` para detectar errores.

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (necesita `ConfigNotFoundFailure`).
- Pasos 3, 4, 5, 6 dependen de Pasos 1 y 2 (necesitan el API data source y la
  config refactorizada).
- Pasos 3 y 4 son independientes entre sí.
- Paso 5 puede depender parcialmente de Paso 3 (reutilizar entities de Contact
  para el filtro por cliente).
- Paso 6 depende de Paso 5 (mismos patrones de paginación/filtro; puede
  compartir widgets).
- Paso 7 depende de Pasos 3-6 (necesita las páginas creadas).
- Paso 8 depende de todos los anteriores.

### Puntos delicados

- **Reordenamiento de índices del menú:** Al insertar 4 ítems nuevos y mover
  Settings al final, los índices cambian. El `selectedIndex` persistido (si lo
  hubiera) se invalidaría — actualmente no se persiste, así que no hay riesgo.
- **Carga de contactos para filtro en Invoices/DeliveryNotes:** La feature de
  invoices/delivery_notes necesita acceder al repositorio de contacts para
  cargar la lista de contactos del filtro. Esto implica una dependencia
  cross-feature. Se resuelve inyectando `ContactsRepository` en los cubits de
  invoices/delivery_notes, o bien creando un `GetContacts` usecase compartido.
- **Instancia de Dio compartida:** El `Dio` se registra actualmente en
  `settings_module`. Debe moverse a `core_module` o asegurarse de que la
  instancia sea accesible por el API data source centralizado. La impl actual no
  tiene interceptores de auth globales, lo cual es correcto porque la auth se
  aplica por request.
- **Migración de datos `subdomain` → `companyId`:** Los usuarios que tengan
  configuración guardada la perderán. Considerar migración automática o aceptar
  el reset.

## 7) Estrategia de validación

### Verificación automática (tests unitarios)

| Componente                        | Test                                                                                                        |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `FacturaDirectaApiDataSourceImpl` | Mock de Dio; verificar headers de auth, URLs construidas, manejo de status codes                            |
| `ContactsRepositoryImpl`          | Mock de API datasource + SettingsRepository; verificar mapeo DTO→Entity, manejo de errores, caso sin config |
| `ProductsRepositoryImpl`          | Análogo                                                                                                     |
| `InvoicesRepositoryImpl`          | Incluir test de listado y detalle                                                                           |
| `DeliveryNotesRepositoryImpl`     | Incluir test de listado, detalle y creación                                                                 |
| `ContactsCubit`                   | Verificar estados: loading → loaded/error; filtro por nombre                                                |
| `ProductsCubit`                   | Análogo                                                                                                     |
| `InvoicesCubit`                   | Verificar filtros por fecha/cliente, paginación, carga de contactos para filtro                             |
| `DeliveryNotesCubit`              | Análogo a InvoicesCubit                                                                                     |
| `FacturaDirectaCubit` (refactor)  | Actualizar tests existentes con `companyId` en lugar de `subdomain`                                         |
| Mappers                           | Verificar conversión DTO→Entity con datos válidos y campos null                                             |

### Verificación manual

- Navegar a cada nueva sección sin configuración → mensaje de "Configura en
  Ajustes".
- Configurar companyId + apiToken en Ajustes → navegar a cada sección → datos
  cargados.
- Verificar filtros en Contactos/Productos: escribir texto → lista se reduce.
- Verificar filtros en Facturas/Albaranes: seleccionar fechas y clientes → lista
  se filtra y paginación se reinicia.
- Verificar paginación: navegar entre páginas, cambiar pageSize en Ajustes.
- Verificar detalle de factura y albarán: pulsar ítem → pantalla de detalle con
  información completa.
- Verificar estados de error: desconectar red → mensaje de error con reintentar.
- Verificar 8 ítems en menú lateral colapsado y expandido en landscape.

### Escenarios de test relevantes

- Config ausente → `ConfigNotFoundFailure`
- Config con credenciales inválidas → error 401 → `ServerFailure`
- Respuesta vacía → estado vacío
- Filtro que no coincide con nada → estado vacío filtrado
- Paginación: pageSize=20, 55 registros → 3 páginas (20, 20, 15)
- Cambio de pageSize en Ajustes → reflejo inmediato en listados
- Rango de fechas inválido (desde > hasta) → no aplicar o advertencia

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                          | Probabilidad | Impacto                               |
| --------------------------------------------------------------- | ------------ | ------------------------------------- |
| Esquemas de la API difieren de lo esperado (campos, estructura) | Media        | Medio — requiere ajustar DTOs/mappers |
| Menú lateral con 8 ítems no cabe bien en landscape              | Baja         | Bajo — ajuste de tamaños en el widget |
| Volumen de datos alto sin paginación server-side                | Media        | Medio — lentitud en carga inicial     |
| Pérdida de config guardada al migrar subdomain → companyId      | Alta         | Bajo — el usuario reconfigura una vez |

### Impacto potencial

- Feature de Settings se modifica sustancialmente (renombramiento propagado).
- La navegación lateral cambia para todos los usuarios.
- No hay impacto en features existentes (orders_today, orders_history, home
  dashboard) más allá del reordenamiento de índices.

### Mitigación

- Consultar la especificación OpenAPI real antes de definir DTOs finales.
- Probar el menú lateral con 8 ítems en las resoluciones target.
- Implementar migración automática de `subdomain` → `companyId` en
  `settings_local_data_source_impl.dart` para evitar pérdida de config.
- Si el volumen de datos es problemático, se puede añadir paginación server-side
  en una iteración futura.

### Plan de rollback

- Cada paso se puede implementar como commit independiente.
- Si se necesita revertir, se pueden revertir los commits en orden inverso.
- La refactorización de Settings (paso 2) es el cambio más delicado. Si se
  revierte, se restaura `subdomain` y se elimina `pageSize`.
- Las 4 features nuevas son aditivas; eliminarlas no afecta al código existente
  (salvo las referencias en el menú lateral y DI).

## 9) Suposiciones

- La API de FacturaDirecta sigue usando Basic Auth con `apiToken:` (token como
  usuario, contraseña vacía) según se observa en el datasource existente.
- La URL base real es `https://app.facturadirecta.com/api` y los endpoints
  siguen el patrón `/{companyId}/contacts`, etc.
- Los campos de las entities se determinarán de la especificación OpenAPI en
  tiempo de implementación.
- El `Dio` registrado en `settings_module` se reutiliza (o se mueve a
  `core_module`) para el datasource centralizado.
- No se necesita manejo de tokens de refresco ni sesiones; la API key es
  estática.

## 10) Preguntas abiertas

- Ninguna. Todas las preguntas del análisis funcional están resueltas.

## 11) Notas para implementación

- **No duplicar Dio:** Mover el registro de `Dio` de `settings_module` a
  `core_module` para que sea accesible por todos los módulos.
- **Mover `FlutterSecureStorage`** también a `core_module` por la misma razón.
- **Dependencia cross-feature (contactos para filtro):** Los cubits de invoices
  y delivery_notes necesitan obtener la lista de contactos para el selector de
  filtro por cliente. Opción recomendada: inyectar `ContactsRepository` en esos
  cubits. El `ContactsRepository` ya estará registrado como singleton en GetIt.
- **DTOs:** Generar `fromJson` manualmente (sin code generation como
  `json_serializable`), coherente con el patrón del proyecto que no usa
  build_runner.
- **Widgets reutilizables:** Los widgets de paginación y filtros por
  fecha/cliente se pueden compartir entre invoices y delivery_notes. Considerar
  colocarlos en `core/presentation/widgets/` si son genéricos, o en
  `invoices/presentation/widgets/` con imports desde delivery_notes.
- **Ordenación:** Ordenar en el cubit tras recibir los datos:
  `.sort((a, b) => a.name.compareTo(b.name))` para contactos/productos;
  `.sort((a, b) => b.date.compareTo(a.date))` para facturas/albaranes.
- **Cancelación de peticiones:** Usar `CancelToken` de Dio en el API datasource
  y cancelar en `close()` del cubit para evitar que peticiones de una sección
  anterior resuelvan en otra.
- **Secuencia sugerida:** Implementar en el orden de la sección 6 para minimizar
  dependencias cruzadas.
- **Estado: Listo para implementación**
