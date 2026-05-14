# Technical Analysis: Migración de llamadas Factura Directa a Cloud Function proxy

- **Fecha:** 2026-05-11
- **Identificador:** fd-proxy-migration
- **Fuente:** docs/functional-analysis/2026-05-11-fd-proxy-migration.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Reescribir `FacturaDirectaApiDataSourceImpl` para que **todos** sus métodos usen
exclusivamente `FirebaseFunctions.httpsCallable('fdProxy')`, eliminando la
dependencia de `Dio`, el `_apiToken`, el `_baseUrl` y toda lógica de llamada
HTTP directa. Simultáneamente, eliminar `companyId` y `apiToken` de toda la
cadena: `AppConfig`, `FacturaDirectaConfig`, `SettingsLocalDataSource`,
`SettingsRepository`, `FacturaDirectaRemoteDataSource`, use cases y UI de
Settings.

- **Áreas impactadas:** core data source, app config, settings feature
  (domain/data/presentation), clients use cases (×4), products use cases (×1),
  invoices use cases (×3) + repository (×1), DI modules (×3), Cloud Function,
  tests.
- **Riesgo general:** medio — cambio extenso en número de archivos pero
  mecánicamente repetitivo; la pieza más crítica (el proxy) ya funciona en
  producción con `getInvoices`.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt, fpdart.
- `FacturaDirectaApiDataSource` (interfaz) en `lib/core/data/datasources/` —
  singleton compartido entre features.
- `FacturaDirectaApiDataSourceImpl` tiene un patrón híbrido: `getInvoices()` ya
  usa el proxy, los otros 6 métodos hacen llamadas directas con Dio.

### Patrón `setApiToken()` (a eliminar)

Presente en 7 use cases + 1 repository. Todos siguen el mismo patrón:

```dart
if (_fdApi is FacturaDirectaApiDataSourceImpl) {
  _fdApi.setApiToken(fdConfig.apiToken);
}
```

Esto viola inversión de dependencias (importan la implementación concreta) y es
estado mutable en un singleton.

### Cloud Function `fdProxy`

- Desplegada en `europe-west1`, usa Firebase Secret `FD_API_TOKEN`.
- `ALLOWED_COMPANY_ID` hardcodeado como constante.
- Soporta `GET` y `POST`.
- Valida: autenticación Firebase, path empiece con `/{ALLOWED_COMPANY_ID}/`,
  método soportado.
- Recibe `{ path, method, body?, queryParameters? }`, devuelve JSON de FD.
- **Detalle importante:** El proxy valida que el `path` comience con
  `/${ALLOWED_COMPANY_ID}/`. Esto implica que el cliente debe seguir enviando el
  company ID en el path. La decisión de diseño es: **el proxy ya conoce el
  company ID y lo valida**, pero el path sigue incluyéndolo. Dado que el company
  ID está en el proxy (no es secreto como el token), y cambiar la lógica del
  proxy para inyectarlo es más complejo, mantendremos el company ID en el proxy
  como constante y el cliente lo envía como parte del path. Sin embargo, el
  objetivo funcional es que **no esté en el código Flutter**. Por tanto, se
  moverá a la Cloud Function: el cliente envía paths sin company ID y el proxy
  lo antepone.

### Credenciales expuestas

- `ProConfig.facturaDirectaApiToken` =
  `'DdaxdT.4QY1XXjF3qd3pRDGMEvvarMb5uxyllsx'` — hardcodeado en código fuente.
- `ProConfig.facturaDirectaCompanyId` =
  `'com_ba5a008b-d08a-4de7-9144-aa073248b267'` — hardcodeado.
- Mismo valor en `LocalConfig`.
- Almacenados también en `SharedPreferences` y `FlutterSecureStorage`.

### Restricciones

- Dependencia `cloud_functions` ya presente en el proyecto (usada por
  `getInvoices`).
- La Cloud Function callable tiene un límite de ~10 MB por respuesta (suficiente
  para el volumen actual).
- No se pueden usar `PUT`/`PATCH`/`DELETE` (no se necesitan según código
  actual).

## 3) Objetivo técnico

1. **Eliminar** toda referencia a `facturaDirectaApiToken` y
   `facturaDirectaCompanyId` del código Flutter.
2. **Unificar** todas las llamadas FD a través de un único helper `_callProxy()`
   en el data source.
3. **Simplificar** la interfaz `FacturaDirectaApiDataSource` eliminando
   `companyId` de todos los métodos.
4. **Eliminar** el flujo completo de `verifyConnection` (data source,
   repository, cubit, UI).
5. **Eliminar** el almacenamiento local de credenciales FD (SharedPreferences +
   FlutterSecureStorage).
6. **Actualizar** la Cloud Function para que el cliente no necesite enviar el
   company ID — el proxy lo inyecta.
7. **Corregir** la violación de inversión de dependencias en use cases que
   importan la impl concreta.

### Limitaciones a respetar

- No cambiar la lógica de negocio de facturación, clientes o productos.
- No modificar modelos de datos en Firestore.
- Mantener los mismos tipos de excepciones (`ServerException`,
  `NetworkException`, `ParsingException`).

## 4) Diseño técnico de la solución

### Enfoque propuesto

**A. Cloud Function `fdProxy` — el proxy inyecta el company ID:**

Cambio en la CF: el cliente envía `path` sin company ID (ej: `/contacts`), y el
proxy antepone `/${ALLOWED_COMPANY_ID}` antes de llamar a FD. Se elimina la
validación `path.startsWith(/${ALLOWED_COMPANY_ID}/)` y se reemplaza por la
inyección automática.

Esto permite que el company ID no exista en el código Flutter.

**B. `FacturaDirectaApiDataSource` — nueva interfaz sin `companyId`:**

```dart
abstract class FacturaDirectaApiDataSource {
  Future<List<Map<String, dynamic>>> getContacts();
  Future<List<Map<String, dynamic>>> getProducts();
  Future<List<Map<String, dynamic>>> getInvoices();
  Future<Map<String, dynamic>> getInvoiceById(String id);
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body);
  Future<List<Map<String, dynamic>>> getInvoicesByContact({
    required String contactUuid,
    required String minDate,
    required String maxDate,
    String? draft,
  });
  Future<Map<String, dynamic>> getContactById(
    String contactId, {
    Map<String, dynamic>? queryParameters,
  });
}
```

**C. `FacturaDirectaApiDataSourceImpl` — solo Cloud Functions:**

- Eliminar: `Dio`, `_baseUrl`, `_apiToken`, `setApiToken()`, `_authOptions()`,
  `_get()`, `_post()`, `_validateResponse()`, `_handleDioException()`.
- Añadir: `_callProxy()` — helper genérico basado en el patrón ya implementado
  en `getInvoices()`.
- Constructor: solo recibe `AppLogger`.
- Cada método público delega en `_callProxy()` con el path, método,
  queryParameters y body adecuados.

**D. Eliminación de `FacturaDirectaConfig`:**

La entidad `FacturaDirectaConfig` pierde su propósito (ya no hay `companyId` ni
`apiToken` en el cliente). Se elimina. Los use cases ya no necesitan obtener
config de FD del repository antes de cada llamada.

**E. Simplificación de `SettingsRepository`:**

Se eliminan:

- `getFacturaDirectaConfig()`
- `saveFacturaDirectaConfig()`
- `clearFacturaDirectaConfig()`
- `verifyFacturaDirectaConnection()`

Se mantiene: `getPageSize()`, `savePageSize()`.

**F. Simplificación de use cases:**

En cada use case se elimina:

1. La dependencia de `SettingsRepository` (ya no necesitan obtener FD config).
2. El import de `FacturaDirectaApiDataSourceImpl` (ya no hay cast).
3. El bloque `setApiToken(...)`.
4. La obtención de `fdConfig.companyId` para pasarlo a los métodos del data
   source.

Los use cases ahora llaman directamente al data source sin configuración previa.

**G. Simplificación de `FacturaDirectaCubit`:**

- Se elimina `verifyConnection()` y `loadSaved()` (ya no hay config que cargar
  ni verificar).
- Se mantiene `syncClients()`.
- Se simplifica: ya no necesita `_getConfigOrEmitError()`.

**H. Simplificación de estados y UI:**

- Se eliminan estados: `FacturaDirectaSaved`, `FacturaDirectaVerifying`,
  `FacturaDirectaVerified`.
- Se eliminan error types: `configNotFound`, `verifyFailed`,
  `invalidCredentials`.
- Se mantienen: `FacturaDirectaInitial`, `FacturaDirectaSyncing`,
  `FacturaDirectaSynced`, `FacturaDirectaError` (con `syncFailed`).
- UI: Se elimina el banner de "Cuenta configurada", el botón "Verificar", y el
  manejo de errores de verificación. Se mantiene solo el botón de
  sincronización.

### Componentes / módulos / servicios afectados

| Componente                           | Cambio                                                                                               |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `functions/src/index.ts`             | El proxy inyecta `ALLOWED_COMPANY_ID` en el path                                                     |
| `FacturaDirectaApiDataSource`        | Eliminar `companyId` de todos los métodos                                                            |
| `FacturaDirectaApiDataSourceImpl`    | Reescribir: eliminar Dio, usar solo proxy                                                            |
| `AppConfig`                          | Eliminar `facturaDirectaCompanyId`, `facturaDirectaApiToken`                                         |
| `LocalConfig`                        | Eliminar los 2 getters de FD                                                                         |
| `ProConfig`                          | Eliminar los 2 getters de FD                                                                         |
| `FacturaDirectaConfig`               | Eliminar archivo completo                                                                            |
| `FacturaDirectaRemoteDataSource`     | Eliminar archivo completo                                                                            |
| `FacturaDirectaRemoteDataSourceImpl` | Eliminar archivo completo                                                                            |
| `SettingsLocalDataSource`            | Eliminar métodos de FD config                                                                        |
| `SettingsLocalDataSourceImpl`        | Eliminar métodos y keys de FD config                                                                 |
| `SettingsRepository`                 | Eliminar 4 métodos de FD                                                                             |
| `SettingsRepositoryImpl`             | Eliminar 4 métodos de FD, quitar dependencia de `AppConfig` y `FacturaDirectaRemoteDataSource`       |
| `FacturaDirectaCubit`                | Eliminar `verifyConnection()`, `loadSaved()`, `_getConfigOrEmitError()`. Simplificar `syncClients()` |
| `FacturaDirectaState`                | Eliminar estados de verify. Reducir error types                                                      |
| `FacturaDirectaSection` (widget)     | Simplificar a solo botón sync                                                                        |
| `SyncClientsFromFd`                  | Eliminar dependencia de `SettingsRepository`, eliminar `setApiToken`                                 |
| `GetFdFiscalIds`                     | Ídem                                                                                                 |
| `GetClientFdData`                    | Ídem                                                                                                 |
| `FetchNewFdContacts`                 | Ídem                                                                                                 |
| `GetFdProducts`                      | Ídem                                                                                                 |
| `CreateProvisionalInvoice`           | Ídem                                                                                                 |
| `CheckDuplicateInvoice`              | Ídem                                                                                                 |
| `PrepareInvoicePreview`              | Eliminar obtención de config, simplificar llamada a `getContactById`                                 |
| `InvoicesRepositoryImpl`             | Eliminar `setApiToken`, simplificar `getInvoices`                                                    |
| `core_module.dart`                   | Cambiar constructor del data source (quitar Dio)                                                     |
| `settings_module.dart`               | Eliminar registro de `FacturaDirectaRemoteDataSource`. Simplificar `SettingsRepositoryImpl`          |
| `clients_module.dart`                | Simplificar constructores de use cases (quitar `sl()` de SettingsRepo)                               |
| `products_module.dart`               | Simplificar `GetFdProducts`                                                                          |
| `invoices_module.dart`               | Simplificar constructores                                                                            |

### Contratos e interfaces

**Nueva interfaz `FacturaDirectaApiDataSource`:** Todos los métodos pierden el
parámetro `companyId`. Los query parameters que estaban embebidos en el path
(ej: `?limit=500`) se envían como objetos separados.

**Contrato `fdProxy` (Cloud Function):**

```typescript
// Request data
{
  path: string,       // ej: "/contacts", "/invoices/abc123"
  method?: string,    // "GET" | "POST" (default: "GET")
  body?: object,      // solo para POST
  queryParameters?: Record<string, string>
}
// Response: JSON directo de FD
```

**`SettingsRepository` simplificado:**

```dart
abstract class SettingsRepository {
  int getPageSize();
  Future<Either<Failure, Unit>> savePageSize(int size);
}
```

### Flujo de datos (después del cambio)

```
UseCase → FacturaDirectaApiDataSource.getContacts()
       → FacturaDirectaApiDataSourceImpl._callProxy(path: '/contacts', ...)
       → FirebaseFunctions.httpsCallable('fdProxy').call({path, method, queryParameters})
       → Cloud Function fdProxy: prepend /${COMPANY_ID}, add API token, fetch FD
       → Response JSON → parse → return to UseCase
```

### Gestión de errores y validaciones

Se mantiene el mapeo actual de `getInvoices()`:

- `FirebaseFunctionsException` con code `unauthenticated` →
  `ServerException(401)`
- `FirebaseFunctionsException` con otro code → `ServerException`
- Cualquier otra excepción → `NetworkException`
- Errores de parsing del JSON → `ParsingException`

### Consideraciones de compatibilidad o migración

- **Almacenamiento local residual:** Los valores de
  `settings_factura_directa_company_id` y `settings_factura_directa_api_token`
  pueden quedar en SharedPreferences/SecureStorage de usuarios existentes. No es
  necesario migrarlos ni limpiarlos activamente; simplemente dejarán de usarse.
  Si se desea una limpieza explícita, se podría añadir una migración al
  bootstrap, pero no es crítico.
- **Cloud Function:** El cambio en la CF (inyectar company ID) debe desplegarse
  **antes** de desplegar la nueva versión del cliente Flutter, o bien mantener
  retrocompatibilidad temporal aceptando ambos formatos de path.

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno. No se crean archivos nuevos.

### Artefactos a modificar

| Artefacto                                                                           | Cambio esperado                                                                    |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `functions/src/index.ts`                                                            | Inyectar company ID en path; eliminar validación de company ID en path del cliente |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`                    | Eliminar `companyId` de todos los métodos                                          |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`               | Reescribir completo: eliminar Dio, usar solo proxy via `_callProxy()`              |
| `lib/app/config/app_config.dart`                                                    | Eliminar `facturaDirectaCompanyId` y `facturaDirectaApiToken`                      |
| `lib/app/config/environments/local_config.dart`                                     | Eliminar 2 getters de FD                                                           |
| `lib/app/config/environments/pro_config.dart`                                       | Eliminar 2 getters de FD                                                           |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`      | Eliminar 4 métodos de FD                                                           |
| `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart` | Eliminar métodos, keys y dependencia de `FlutterSecureStorage`                     |
| `lib/features/settings/domain/repositories/settings_repository.dart`                | Eliminar 4 métodos de FD                                                           |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`             | Eliminar métodos FD, quitar dependencias de `AppConfig` y remote DS                |
| `lib/features/settings/presentation/bloc/factura_directa_cubit.dart`                | Eliminar verify, loadSaved; simplificar syncClients                                |
| `lib/features/settings/presentation/bloc/factura_directa_state.dart`                | Eliminar estados de verify; reducir error types                                    |
| `lib/features/settings/presentation/widgets/factura_directa_section.dart`           | Simplificar a botón sync                                                           |
| `lib/features/clients/domain/usecases/sync_clients_from_fd.dart`                    | Eliminar SettingsRepo, setApiToken, companyId                                      |
| `lib/features/clients/domain/usecases/get_fd_fiscal_ids.dart`                       | Ídem                                                                               |
| `lib/features/clients/domain/usecases/get_client_fd_data.dart`                      | Ídem                                                                               |
| `lib/features/clients/domain/usecases/fetch_new_fd_contacts.dart`                   | Ídem                                                                               |
| `lib/features/products/domain/usecases/get_fd_products.dart`                        | Ídem                                                                               |
| `lib/features/invoices/domain/usecases/create_provisional_invoice.dart`             | Ídem                                                                               |
| `lib/features/invoices/domain/usecases/check_duplicate_invoice.dart`                | Ídem                                                                               |
| `lib/features/invoices/domain/usecases/prepare_invoice_preview.dart`                | Eliminar obtención de config, quitar `config.companyId` de llamadas                |
| `lib/features/invoices/data/repositories/invoices_repository_impl.dart`             | Eliminar setApiToken, simplificar getInvoices                                      |
| `lib/app/di/modules/core_module.dart`                                               | Cambiar constructor del data source (solo `AppLogger`)                             |
| `lib/app/di/modules/settings_module.dart`                                           | Eliminar `FacturaDirectaRemoteDataSource`, simplificar `SettingsRepositoryImpl`    |
| `lib/app/di/modules/clients_module.dart`                                            | Quitar `sl()` extra de use cases que ya no reciben SettingsRepo                    |
| `lib/app/di/modules/products_module.dart`                                           | Ídem para `GetFdProducts`                                                          |
| `lib/app/di/modules/invoices_module.dart`                                           | Ídem para use cases de invoices                                                    |
| `test/features/settings/presentation/bloc/factura_directa_cubit_test.dart`          | Reescribir: eliminar tests de verify; actualizar tests de sync                     |
| `test/features/settings/data/repositories/settings_repository_impl_test.dart`       | Eliminar tests de FD config y verify                                               |

### Artefactos a retirar o reemplazar

| Artefacto                                                                                    | Motivo                                  |
| -------------------------------------------------------------------------------------------- | --------------------------------------- |
| `lib/features/settings/domain/entities/factura_directa_config.dart`                          | Ya no existe config de FD en el cliente |
| `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source.dart`      | Verificación de conexión eliminada      |
| `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source_impl.dart` | Verificación de conexión eliminada      |

## 6) Estrategia de implementación

### Paso 1: Actualizar la Cloud Function `fdProxy`

- Modificar para que el cliente envíe paths sin company ID (ej: `/contacts`).
- El proxy antepone `/${ALLOWED_COMPANY_ID}` al path antes de construir la URL.
- Eliminar la validación de que el path empiece con `/${ALLOWED_COMPANY_ID}/`.
- **Alternativa retrocompatible:** Si se necesita desplegar gradualmente,
  aceptar ambos formatos (con y sin company ID). Detectar si el path ya empieza
  con `/com_` y actuar en consecuencia.

### Paso 2: Reescribir el data source

- Modificar la interfaz `FacturaDirectaApiDataSource`: eliminar `companyId` de
  todos los métodos.
- Reescribir `FacturaDirectaApiDataSourceImpl`:
  - Eliminar `Dio`, `_baseUrl`, `_apiToken`, `setApiToken()`, `_authOptions()`,
    `_get()`, `_post()`, `_validateResponse()`, `_handleDioException()`.
  - Crear
    `_callProxy({required String path, String method = 'GET', Map<String, dynamic>? queryParameters, Map<String, dynamic>? body})`
    que encapsula la lógica de
    `FirebaseFunctions.httpsCallable('fdProxy').call(...)` con manejo de errores
    unificado.
  - Crear `_parseList(Map<String, dynamic> data)` para parsear respuestas con
    `items`.
  - Migrar cada método público a usar `_callProxy()`.

### Paso 3: Eliminar credenciales de AppConfig

- Eliminar `facturaDirectaCompanyId` y `facturaDirectaApiToken` de `AppConfig`,
  `LocalConfig`, `ProConfig`.

### Paso 4: Eliminar `FacturaDirectaConfig` y flujos de settings

- Eliminar `FacturaDirectaConfig` (entidad).
- Eliminar `FacturaDirectaRemoteDataSource` y su impl.
- Eliminar métodos de FD de `SettingsLocalDataSource` e impl.
- Eliminar métodos de FD de `SettingsRepository` e impl.
- Eliminar dependencia de `AppConfig` y remote DS en `SettingsRepositoryImpl`.

### Paso 5: Simplificar use cases y repository

- En cada use case (`SyncClientsFromFd`, `GetFdFiscalIds`, `GetClientFdData`,
  `FetchNewFdContacts`, `GetFdProducts`, `CreateProvisionalInvoice`,
  `CheckDuplicateInvoice`, `PrepareInvoicePreview`):
  - Eliminar `SettingsRepository` de dependencias.
  - Eliminar import de `FacturaDirectaApiDataSourceImpl`.
  - Eliminar bloque `setApiToken()`.
  - Eliminar obtención de `fdConfig` y uso de `fdConfig.companyId`.
  - Llamar directamente a `_fdApi.getContacts()` etc., sin parámetros de config.
- En `InvoicesRepositoryImpl`:
  - Eliminar `SettingsRepository` de dependencias.
  - Eliminar `setApiToken()` y obtención de config.
  - Llamar directamente a `_apiDataSource.getInvoices()`.

### Paso 6: Simplificar cubit, estados y UI

- `FacturaDirectaCubit`: eliminar `verifyConnection()`, `loadSaved()`,
  `_getConfigOrEmitError()`. Simplificar `syncClients()` (ya no necesita
  config).
- `FacturaDirectaState`: eliminar `FacturaDirectaSaved`,
  `FacturaDirectaVerifying`, `FacturaDirectaVerified`. Reducir enum
  `FacturaDirectaErrorType` a solo `syncFailed`.
- `FacturaDirectaSection`: eliminar banner de cuenta configurada, botón
  verificar. Mantener solo botón sync.

### Paso 7: Actualizar módulos DI

- `core_module.dart`: constructor del data source cambia de `(sl(), sl())` (Dio,
  Logger) a `(sl())` (Logger).
- `settings_module.dart`: eliminar registro de `FacturaDirectaRemoteDataSource`.
  Reducir args de `SettingsRepositoryImpl`.
- `clients_module.dart`: reducir args de use cases que pierden
  `SettingsRepository`.
- `products_module.dart`: `GetFdProducts(sl())` en vez de
  `GetFdProducts(sl(), sl())`.
- `invoices_module.dart`: reducir args de use cases y repo.

### Paso 8: Actualizar tests

- `factura_directa_cubit_test.dart`: eliminar tests de verify/loadSaved,
  actualizar sync tests.
- `settings_repository_impl_test.dart`: eliminar tests de FD config y verify,
  actualizar constructor del sut.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

Los pasos 3, 4, 5, 6 y 7 tienen dependencias cruzadas fuertes y probablemente se
ejecuten como un bloque atómico para que el proyecto compile.

### Dependencias entre pasos

- Paso 2 depende de paso 1 (el proxy debe aceptar paths sin company ID).
- Pasos 3-7 son interdependientes y deben hacerse juntos.
- Paso 8 depende de todos los anteriores.

### Puntos delicados

- **Despliegue coordinado:** Si la Cloud Function se actualiza antes de que el
  cliente se despliegue, la versión actual del cliente (que envía paths con
  company ID) podría fallar si se elimina la validación sin retrocompatibilidad.
  **Solución:** hacer que el paso 1 sea retrocompatible (detectar si el path ya
  incluye el company ID).
- **Query parameters en el path:** Actualmente `getContacts()` llama a
  `_get('/$companyId/contacts?limit=500')`, embebiendo query params en el path.
  En el nuevo diseño, deben enviarse como `queryParameters: {'limit': '500'}`
  para que la Cloud Function los procese correctamente.
- **`_parseListResponse` vs respuesta de proxy:** El helper actual parsea
  `Response<dynamic>` de Dio. El proxy devuelve directamente
  `Map<String, dynamic>`. El parsing debe adaptarse a la nueva estructura.

## 7) Estrategia de validación

### Verificación automática

- Compilación sin errores ni warnings (`flutter analyze`).
- Grep en codebase: búsqueda de `facturaDirectaApiToken`,
  `facturaDirectaCompanyId`, `setApiToken`, `_apiToken` → 0 resultados en
  `lib/`.
- Tests unitarios actualizados pasan (`flutter test`).

### Verificación manual

- Sincronización de clientes desde Settings.
- Lista de facturas (ya usa proxy, sin regresión).
- Crear factura provisional.
- Comprobar duplicados de factura.
- Obtener productos de FD.
- Obtener datos de un contacto.
- Verificar con DevTools del navegador que **ninguna** petición sale
  directamente a `app.facturadirecta.com` — todas van a `cloudfunctions.net` o
  similar.
- Inspeccionar el bundle JS compilado y confirmar ausencia del API token.

### Escenarios a cubrir

- Usuario autenticado → todas las operaciones funcionan.
- Usuario no autenticado → todas las operaciones fallan con error claro.
- Cloud Function caída → las operaciones fallan con `NetworkException`.
- Respuesta de FD con error → se propaga como `ServerException`.

### Tipos de pruebas recomendables

- Tests unitarios del data source (mock de `FirebaseFunctions`).
- Tests unitarios de los use cases simplificados.
- Tests unitarios del cubit simplificado.
- Tests de integración del repository.
- Smoke test manual en web.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

1. **Despliegue no coordinado CF ↔ cliente:** Si el nuevo cliente se despliega
   antes de la CF actualizada, los paths sin company ID serán rechazados.
2. **Query parameters incorrectos:** Si un endpoint FD requiere un query param
   que estaba embebido en el path y se omite al migrar, la respuesta será
   incorrecta.
3. **Impacto en tests no detectados:** Puede haber tests que no estén en la
   búsqueda inicial y fallen.

### Impacto potencial

- Todas las operaciones de Factura Directa dependen de este cambio — un error
  afecta sincronización de clientes, facturación y visualización de datos.

### Mitigación

1. **CF retrocompatible:** En paso 1, mantener ambos formatos de path (con y sin
   company ID) durante la transición.
2. **Revisión exhaustiva de query params:** Mapear cada llamada actual y
   verificar que todos los params se migran correctamente.
3. **Ejecutar `flutter test` y `flutter analyze`** antes de merge.

### Plan de rollback

- **Cloud Function:** Revertir al commit anterior de `functions/src/index.ts` y
  redesplegar.
- **Cliente Flutter:** Revertir al commit anterior y redesplegar.
- Si se usa CF retrocompatible, el rollback del cliente es independiente.

## 9) Suposiciones

- La Cloud Function `fdProxy` es el único punto de contacto con FD y está
  operativa.
- El company ID es estable y no cambiará a corto plazo.
- No hay otros consumidores del contrato `FacturaDirectaApiDataSource` fuera de
  los identificados.
- Los datos de FlutterSecureStorage y SharedPreferences obsoletos no causan
  problemas si quedan huérfanos.
- No se necesita `FlutterSecureStorage` en ninguna otra parte del módulo
  settings (si sí, la dependencia se mantiene en DI pero se elimina del local
  data source de settings).

## 10) Preguntas abiertas

Ninguna. Todas las decisiones están tomadas.

## 11) Notas para implementación

- **Patrón de referencia:** El método `getInvoices()` actual en
  `FacturaDirectaApiDataSourceImpl` es la plantilla exacta para migrar los otros
  6 métodos. Extraer la lógica común a `_callProxy()`.
- **Secuencia recomendada:** Implementar como un bloque atómico (pasos 2-8)
  precedido del despliegue retrocompatible de la CF (paso 1). Esto evita estados
  intermedios donde el proyecto no compile.
- **No romper comportamiento existente:** `getInvoices()` ya funciona vía proxy.
  Al migrar los demás, asegurar que los query parameters sean exactamente
  equivalentes.
- **Limpieza de imports:** Al eliminar `FacturaDirectaApiDataSourceImpl` de los
  imports de use cases, verificar que no queden imports huérfanos de `Dio` o
  `package:cloud_functions`.
- **`SettingsLocalDataSourceImpl`:** Al eliminar los métodos de FD config,
  evaluar si aún necesita `FlutterSecureStorage` como dependencia. Si solo se
  usaba para el API token de FD, se puede eliminar del constructor.
- **`SettingsRepositoryImpl`:** Pasará de 4 dependencias
  `(localDS, remoteDS, logger, appConfig)` a solo 2 `(localDS, logger)`.
  Actualizar DI acorde.
- **`FacturaDirectaCubit`:** Ya no necesita `SettingsRepository` como
  dependencia directa. Solo necesita `SyncClientsFromFd`.
- **Verificar que `Dio` se sigue usando en otros módulos** antes de considerar
  eliminarlo del DI global. (Probablemente sí se usa en otras partes de la app.)
- **Estado: Listo para implementación**
