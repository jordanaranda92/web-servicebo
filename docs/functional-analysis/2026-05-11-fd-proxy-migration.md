# Functional Analysis: Migración de llamadas Factura Directa a Cloud Function proxy

- **Fecha:** 2026-05-11
- **Identificador:** fd-proxy-migration
- **Estado:** Ready for technical analysis

## 1) Resumen

Migrar **todas** las llamadas a la API de Factura Directa para que se realicen a
través de la Cloud Function `fdProxy` existente, eliminando del código cliente
(Flutter) el API token y el company ID. Actualmente solo `getInvoices()` usa el
proxy; el resto de endpoints (`getContacts`, `getProducts`, `getInvoiceById`,
`createInvoice`, `getInvoicesByContact`, `getContactById`) hacen llamadas
directas desde el navegador, exponiendo credenciales sensibles.

## 2) Contexto y objetivo

### Qué se solicita

- Redirigir el 100 % del tráfico hacia Factura Directa a través de la Cloud
  Function `fdProxy` (ya desplegada en `europe-west1`).
- Eliminar completamente el API token y el company ID de Factura Directa del
  código fuente de la aplicación Flutter y de cualquier almacenamiento local del
  cliente (SharedPreferences, FlutterSecureStorage).

### Qué problema resuelve

- **Seguridad crítica:** El API token de producción
  (`DdaxdT.4QY1XXjF3qd3pRDGMEvvarMb5uxyllsx`) está hardcodeado en `ProConfig` y
  `LocalConfig`, visible en el código fuente y en el bundle de la web app.
  Cualquier usuario con acceso al inspector del navegador puede extraerlo.
- **Superficie de ataque:** Las llamadas directas desde el cliente permiten que
  un atacante use el token para operar contra la API de Factura Directa sin
  restricciones.
- **Principio de mínimo privilegio:** El proxy centraliza el control de acceso y
  valida autenticación Firebase antes de reenviar peticiones.

### Resultado funcional esperado

- La aplicación web no contiene ni transmite credenciales de Factura Directa.
- Todas las operaciones de Factura Directa siguen funcionando exactamente igual
  para el usuario (transparente).
- Solo usuarios autenticados en Firebase pueden acceder a la API de Factura
  Directa (ya implementado en el proxy).

## 3) Alcance

### En alcance

1. **Migrar las 6 llamadas directas restantes** al proxy `fdProxy`:
   - `getContacts(companyId)` — obtención de contactos
   - `getProducts(companyId)` — obtención de productos
   - `getInvoiceById(companyId, id)` — detalle de factura
   - `createInvoice(companyId, body)` — creación de factura (POST)
   - `getInvoicesByContact(companyId, ...)` — facturas por contacto
   - `getContactById(companyId, contactId, ...)` — detalle de contacto
2. **Eliminar credenciales del cliente:**
   - Quitar `facturaDirectaApiToken` y `facturaDirectaCompanyId` de `AppConfig`,
     `LocalConfig` y `ProConfig`
   - Quitar `apiToken` de la entidad `FacturaDirectaConfig`
   - Eliminar el almacenamiento local del token (FlutterSecureStorage) y del
     company ID (SharedPreferences)
   - Eliminar el método `setApiToken()` y el campo `_apiToken` del data source
   - Eliminar la dependencia de `Dio` del data source de FD (ya no se necesita
     para llamadas directas)
3. **Eliminar el flujo de verificación de conexión:**
   - `FacturaDirectaRemoteDataSourceImpl.verifyConnection()` hace una llamada
     directa con credenciales; se elimina junto con todo su stack (data source,
     repository method, cubit states, UI)
4. **Simplificar use cases:** Eliminar el patrón
   `setApiToken(fdConfig.apiToken)` repetido en 7 use cases y 1 repository
5. **Actualizar la UI de Settings:**
   - Eliminar campos de entrada de company ID y API token (ya no los gestiona el
     usuario)
   - Eliminar el botón y flujo de verificación de conexión (ya no tiene sentido
     sin credenciales en cliente)
   - Mantener la funcionalidad de sincronización de clientes
6. **Actualizar la Cloud Function `fdProxy`** si necesita soportar los
   paths/métodos que actualmente no gestiona (verificar cobertura)

### Fuera de alcance

- Cambios en la lógica de negocio de facturación, sincronización de clientes o
  productos
- Cambios en el modelo de datos de Firestore
- Migración a otra API de facturación
- Rotación o revocación del API token existente en Firebase Secrets (se
  recomienda hacerlo tras la migración, pero es operacional)
- Implementación de rate limiting o caché en la Cloud Function

## 4) Actores implicados

| Actor                                           | Rol                                                                                                           |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Usuario final** (operario/admin de Servicebo) | Usa la app web para gestionar clientes, productos y facturas. No debe notar cambios funcionales.              |
| **Cloud Function `fdProxy`**                    | Intermediario que recibe peticiones autenticadas de la app y las reenvía a Factura Directa con el token real. |
| **API de Factura Directa**                      | Servicio externo de facturación. Sin cambios.                                                                 |
| **Firebase Auth**                               | Valida que el usuario está autenticado antes de permitir el acceso al proxy.                                  |

## 5) Requisitos funcionales

- **RF-01:** Todas las peticiones a la API de Factura Directa desde la
  aplicación Flutter deben pasar exclusivamente por la Cloud Function `fdProxy`.
- **RF-02:** El API token de Factura Directa no debe existir en ningún archivo
  del código fuente de la aplicación Flutter ni en almacenamiento local del
  cliente.
- **RF-03:** El company ID de Factura Directa no debe existir en ningún archivo
  del código fuente de la aplicación Flutter ni en almacenamiento local del
  cliente. El proxy debe resolverlo internamente.
- **RF-04:** La Cloud Function `fdProxy` debe soportar todos los endpoints
  utilizados actualmente: contacts (GET), products (GET), invoices (GET/POST),
  invoices por contacto (GET), contacto por ID (GET).
- **RF-05:** La aplicación debe requerir autenticación Firebase para cualquier
  operación con Factura Directa (ya garantizado por el proxy).
- **RF-06:** Los errores del proxy deben mapearse a los mismos tipos de error
  que actualmente maneja la aplicación (ServerException, NetworkException,
  ParsingException).
- **RF-07:** La pantalla de Settings debe reflejar que la configuración de
  Factura Directa es gestionada a nivel de servidor, eliminando los campos de
  entrada de credenciales.

## 6) Criterios de aceptación

- **CA-01:** Al inspeccionar el código fuente compilado de la web app (bundle
  JS), no aparece el API token ni el company ID de Factura Directa.
- **CA-02:** Ejecutar la funcionalidad de sincronización de clientes desde
  Settings produce el mismo resultado que antes (mismos clientes
  creados/actualizados).
- **CA-03:** La lista de facturas carga correctamente (ya usa proxy — sin
  regresión).
- **CA-04:** Crear una factura provisional funciona correctamente a través del
  proxy.
- **CA-05:** Comprobar facturas duplicadas funciona correctamente a través del
  proxy.
- **CA-06:** Obtener productos de FD funciona correctamente a través del proxy.
- **CA-07:** Obtener datos de un contacto por ID funciona correctamente a través
  del proxy.
- **CA-08:** Obtener IDs fiscales de contactos funciona correctamente a través
  del proxy.
- **CA-09:** Si el usuario no está autenticado en Firebase, todas las
  operaciones de FD fallan con error de autenticación.
- **CA-10:** La aplicación compila sin referencias a `facturaDirectaApiToken` ni
  a `facturaDirectaCompanyId` en `AppConfig` o sus implementaciones.
- **CA-11:** Los tests unitarios existentes se actualizan y pasan.

## 7) Flujos y comportamiento esperado

### Flujo principal (cualquier operación FD)

1. El usuario realiza una acción que requiere datos de Factura Directa (ej: ver
   facturas, sincronizar clientes, crear factura).
2. El use case correspondiente invoca el data source de FD.
3. El data source construye la petición con `path`, `method`, `queryParameters`
   y opcionalmente `body`.
4. El data source llama a `FirebaseFunctions.httpsCallable('fdProxy')` con esos
   datos.
5. La Cloud Function verifica autenticación Firebase, valida el path, inyecta el
   API token y reenvía a la API de Factura Directa.
6. La Cloud Function devuelve la respuesta al cliente.
7. El data source parsea la respuesta y la devuelve al use case.
8. El use case transforma los datos y los entrega a la capa de presentación.

### Flujos alternativos

- **FA-01 — Usuario no autenticado:** La Cloud Function rechaza la petición con
  `unauthenticated`. El data source lanza `ServerException(401)`. La UI muestra
  error de autenticación.
- **FA-02 — Error en la API de FD (5xx, timeout):** La Cloud Function devuelve
  `internal`. El data source lanza `ServerException` o `NetworkException`. La UI
  muestra mensaje de error genérico.
- **FA-03 — Path inválido o company ID no autorizado:** La Cloud Function
  rechaza con `permission-denied` o `invalid-argument`. El data source lanza
  `ServerException`.

### Estados especiales / excepciones

- **Estado vacío:** Sin cambios. Si FD devuelve listas vacías, el comportamiento
  se mantiene.
- **Estado loading/procesando:** Sin cambios. Los indicadores de carga
  existentes aplican.
- **Estado error:** Los errores del proxy se mapean a las mismas excepciones que
  ya maneja la app. La UI no cambia.
- **Sin conexión a internet:** `FirebaseFunctionsException` con error de red →
  `NetworkException`.

## 8) Edge cases

- **EC-01:** La Cloud Function actualmente solo permite `GET` y `POST`.
  Verificar que no exista ningún endpoint FD que use `PUT`, `PATCH` o `DELETE`.
  (Revisión del código indica que solo se usan GET y POST — OK).
- **EC-02:** El endpoint `getContacts` y `getProducts` usa `?limit=500` como
  query string en el path (ej: `/$companyId/contacts?limit=500`). Hay que
  asegurar que los query parameters se envíen como objeto `queryParameters` y no
  embebidos en el path, para que la Cloud Function los procese correctamente.
- **EC-03:** `verifyConnection()` en Settings se elimina completamente. Al no
  haber credenciales en el cliente, la verificación de conexión pierde su
  propósito.
- **EC-04:** Tamaño de respuesta — las Cloud Functions callable tienen un límite
  de ~10 MB en la respuesta. Verificar que ninguna respuesta de FD (ej: 500
  contactos, 500 facturas) supere este límite.
- **EC-05:** Latencia adicional — las llamadas ahora pasan por un intermediario
  (Cloud Function). El tiempo de respuesta aumentará ligeramente (~50-200ms). No
  se espera impacto significativo en UX.
- **EC-06:** El campo `companyId` se elimina de la interfaz
  `FacturaDirectaApiDataSource`. Los métodos ya no necesitan recibir `companyId`
  como parámetro ya que el proxy lo resuelve internamente. Esto implica cambio
  de contrato de la interfaz.

## 9) Impacto funcional

### Módulos afectados

| Módulo                       | Impacto                                                                                                                                                                                          |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Core / Data Sources**      | Reescritura de `FacturaDirectaApiDataSourceImpl`: eliminar Dio, usar solo Cloud Functions. Cambio de interfaz `FacturaDirectaApiDataSource` (eliminar `companyId` de todos los métodos).         |
| **Settings / Config**        | Eliminar `facturaDirectaApiToken` y `facturaDirectaCompanyId` de `AppConfig` y sus implementaciones. Eliminar `FacturaDirectaConfig.apiToken`. Eliminar almacenamiento local de credenciales FD. |
| **Settings / UI**            | Eliminar formulario de ingreso de credenciales. Simplificar la sección a solo verificación/sync.                                                                                                 |
| **Settings / Data Sources**  | Eliminar `FacturaDirectaRemoteDataSource` y su impl (verificación directa). Eliminar la dependencia de `Dio` en este módulo.                                                                     |
| **Clients / Use Cases**      | `SyncClientsFromFd`, `GetFdFiscalIds`, `GetClientFdData`, `FetchNewFdContacts`: eliminar `setApiToken()` y el import de la impl.                                                                 |
| **Products / Use Cases**     | `GetFdProducts`: eliminar `setApiToken()` y el import de la impl.                                                                                                                                |
| **Invoices / Use Cases**     | `CreateProvisionalInvoice`, `CheckDuplicateInvoice`, `PrepareInvoicePreview`: eliminar `setApiToken()` y el import de la impl.                                                                   |
| **Invoices / Repository**    | `InvoicesRepositoryImpl`: eliminar `setApiToken()`.                                                                                                                                              |
| **DI Modules**               | `core_module.dart`, `settings_module.dart`: actualizar registro de dependencias.                                                                                                                 |
| **Cloud Function `fdProxy`** | Posiblemente necesite ajustes para soportar query parameters embebidos en path vs. como objeto separado.                                                                                         |
| **Tests**                    | Actualizar todos los tests que referencian `apiToken`, `companyId`, `FacturaDirectaConfig`, `setApiToken`, `verifyConnection`.                                                                   |

### Impacto en usuario

- **Transparente:** El usuario no necesita hacer nada diferente. Las
  funcionalidades existentes siguen operando.
- **Mejora de seguridad:** Las credenciales ya no están expuestas en el cliente.
- **Settings simplificado:** El usuario ya no ve ni necesita gestionar
  credenciales de FD.

### Impacto en experiencia de usuario

- La sección de Factura Directa en Settings se simplifica (menos campos). El
  usuario ve que la integración está activa sin necesidad de configurar nada.
- Posible incremento menor en tiempos de respuesta (~50-200ms por llamada)
  debido al paso por la Cloud Function. No debería ser perceptible en uso
  normal.

## 10) Suposiciones

- **S-01:** La Cloud Function `fdProxy` ya está desplegada y operativa
  (confirmado por el código en `functions/src/index.ts` y por el hecho de que
  `getInvoices` ya la usa con éxito).
- **S-02:** La Cloud Function ya tiene el API token configurado como Firebase
  Secret (`FD_API_TOKEN`) y el company ID hardcodeado como constante
  (`ALLOWED_COMPANY_ID`).
- **S-03:** La aplicación es una **web app** (confirmado por la existencia de
  `web/` y las preocupaciones de seguridad del usuario). En una web app, el
  código fuente y las credenciales son accesibles para cualquier usuario.
- **S-04:** Solo existe un company ID de FD en uso. El proxy ya lo tiene
  configurado como constante.
- **S-05:** Solo existe una cuenta de Firebase con una única Cloud Function
  desplegada. No hay entornos separados (dev, pre, staging).
- **S-06:** El formulario de configuración de FD en Settings (company ID + API
  token) fue diseñado para una fase anterior donde las credenciales vivían en el
  cliente. Con esta migración, ese formulario pierde su propósito.

## 11) Preguntas abiertas

Todas resueltas:

- ~~**PA-01:**~~ Se elimina la funcionalidad de verificar conexión. Sin
  credenciales en el cliente, no tiene sentido.
- ~~**PA-02:**~~ Solo existe una cuenta de Firebase con una única Cloud
  Function. No hay múltiples entornos.
- ~~**PA-03:**~~ No se requiere rotación del API token tras la migración.

## 12) Notas para análisis técnico

- La Cloud Function `fdProxy` ya existe y está probada con `getInvoices`. El
  patrón de llamada desde Flutter está implementado en ese método y sirve como
  referencia para migrar los demás.
- Hay que decidir si el `companyId` se elimina del contrato de
  `FacturaDirectaApiDataSource` (el proxy lo inyecta) o si se mantiene y el
  proxy lo ignora/valida. Eliminar es más limpio pero implica cambiar la firma
  de 7 métodos.
- El patrón actual de `setApiToken()` es un code smell (estado mutable en un
  singleton). La migración lo elimina naturalmente.
- `FacturaDirectaRemoteDataSource` (feature settings) se elimina por completo
  junto con `verifyConnection`.
- Varios use cases importan `FacturaDirectaApiDataSourceImpl` (la implementación
  concreta) para hacer el cast y llamar `setApiToken()`. Esto viola el principio
  de inversión de dependencias. La migración corrige este problema.
- Los query parameters que actualmente se embeben en el path (ej:
  `/$companyId/contacts?limit=500`) deben extraerse y enviarse como
  `queryParameters` al proxy para que la Cloud Function los añada correctamente
  a la URL.
- Considerar si la Cloud Function necesita ampliar los métodos HTTP soportados
  (actualmente solo GET/POST). Según el código, no se necesitan otros.
- **Estado: Listo para análisis técnico**
