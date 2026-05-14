# Functional Analysis: Integración con FacturaDirecta (Contactos, Productos, Facturas, Albaranes)

- **Fecha:** 2026-05-06
- **Identificador:** facturadirecta-integration
- **Estado:** Ready for technical analysis

## 1) Resumen

Integrar la aplicación Servicebo con la API de FacturaDirecta para consultar
contactos, productos, facturas y albaranes, así como preparar la creación de
albaranes. Se añadirán cuatro nuevos ítems al menú lateral (Contactos,
Productos, Albaranes, Facturas), cada uno con su vista de listado y filtros
específicos. Las vistas de detalle aplican solo a facturas y albaranes. La
operación de creación de albarán (POST) se dejará montada a nivel de código pero
sin invocar desde la UI. Los listados de Contactos y Productos se ordenan
alfabéticamente por nombre; los de Facturas y Albaranes se ordenan por fecha
descendente (más reciente primero) y disponen de paginación.

## 2) Contexto y objetivo

- **Qué se solicita:** Implementar la capa de datos y presentación para consumir
  los endpoints de FacturaDirecta (contactos, productos, facturas, albaranes) y
  mostrar los resultados en nuevas secciones accesibles desde el menú lateral.
- **Qué problema resuelve:** Actualmente la app tiene la configuración de
  conexión con FacturaDirecta (identificador de compañía + apiToken) en la
  sección de Ajustes, pero no consume ningún dato de la API. El usuario necesita
  consultar contactos, productos, facturas y albaranes sin salir de la
  aplicación.
- **Qué resultado funcional se espera:** El usuario puede navegar a cada sección
  del menú, ver los listados de datos provenientes de FacturaDirecta y aplicar
  filtros para localizar registros rápidamente. Para facturas y albaranes puede
  acceder al detalle individual.

## 3) Alcance

### En alcance

- Consumo de los siguientes endpoints de la API FacturaDirecta:
  - `GET /{companyId}/contacts` — listado de contactos
  - `GET /{companyId}/products` — listado de productos
  - `GET /{companyId}/invoices` — listado de facturas
  - `GET /{companyId}/invoices/{id}` — detalle de factura
  - `GET /{companyId}/deliveryNotes` — listado de albaranes
  - `GET /{companyId}/deliveryNotes/{id}` — detalle de albarán
  - `POST /{companyId}/deliveryNotes` — creación de albarán (montado en código,
    sin invocar desde UI)
- Cuatro nuevos ítems en el menú lateral: **Contactos**, **Productos**,
  **Albaranes**, **Facturas**
- Vista de listado para cada sección con los datos relevantes
- Filtro por nombre en las vistas de **Contactos** y **Productos**
- Filtros por rango de fechas y por cliente(s) en las vistas de **Albaranes** y
  **Facturas**
- Vista de detalle individual para **Facturas** y **Albaranes**
- Uso del `companyId` (identificador de compañía) almacenado en la configuración
  de FacturaDirecta en Ajustes
- Autenticación con la API usando el `apiToken` ya configurado en Ajustes
- Campos a mostrar en listados y detalle inferidos de la especificación OpenAPI
  de FacturaDirecta
- Ordenación por defecto: alfabética por nombre en Contactos y Productos; por
  fecha descendente (más reciente primero) en Albaranes y Facturas
- Paginación en los listados de Albaranes y Facturas
- Textos de UI internacionalizados (i18n)
- Estados de carga, error y vacío en todas las vistas

### Fuera de alcance

- Invocación del POST de creación de albarán desde la UI (se monta el código
  pero no se conecta a ningún botón/acción)
- Operaciones de escritura sobre contactos, productos o facturas (PUT, DELETE,
  POST)
- Búsqueda server-side (los filtros se aplican localmente sobre los datos
  obtenidos)
- Caché o persistencia local de los datos de FacturaDirecta
- Modificación de la configuración de conexión existente en Ajustes (ya
  implementada)
- Exportación o impresión de facturas/albaranes

## 4) Actores implicados

- **Usuario final:** Persona que opera Servicebo y necesita consultar datos de
  facturación, contactos, productos y albaranes de FacturaDirecta.
- **Sistema externo:** API REST de FacturaDirecta
  (`https://app.facturadirecta.com/api/{companyId}/...`).

## 5) Requisitos funcionales

- **RF-01:** El menú lateral debe incluir cuatro nuevos ítems de navegación:
  Contactos, Productos, Albaranes y Facturas, añadidos a los ítems existentes
  (Inicio, Pedidos Hoy, Historial Pedidos, Ajustes).
- **RF-02:** Cada nuevo ítem del menú debe navegar a su vista de listado
  correspondiente.
- **RF-03:** La vista de **Contactos** debe mostrar el listado de contactos
  obtenidos del endpoint `GET /{companyId}/contacts` y permitir filtrar por
  nombre.
- **RF-04:** La vista de **Productos** debe mostrar el listado de productos
  obtenidos del endpoint `GET /{companyId}/products` y permitir filtrar por
  nombre.
- **RF-05:** La vista de **Albaranes** debe mostrar el listado de albaranes
  obtenidos del endpoint `GET /{companyId}/deliveryNotes` y permitir filtrar por
  rango de fechas y por cliente(s).
- **RF-06:** La vista de **Facturas** debe mostrar el listado de facturas
  obtenidos del endpoint `GET /{companyId}/invoices` y permitir filtrar por
  rango de fechas y por cliente(s).
- **RF-07:** Desde el listado de **Albaranes**, el usuario puede acceder al
  detalle de un albarán específico (`GET /{companyId}/deliveryNotes/{id}`).
- **RF-08:** Desde el listado de **Facturas**, el usuario puede acceder al
  detalle de una factura específica (`GET /{companyId}/invoices/{id}`).
- **RF-09:** El código para la creación de albaranes
  (`POST /{companyId}/deliveryNotes`) debe estar implementado a nivel de
  repositorio/use case pero no conectado a la UI.
- **RF-10:** Las llamadas a la API deben usar el identificador de compañía
  (`companyId`) y autenticarse con el `apiToken`, ambos almacenados en la
  configuración de FacturaDirecta (feature Settings existente).
- **RF-11:** Si no hay configuración de FacturaDirecta guardada (identificador
  de compañía / apiToken), las vistas deben mostrar un mensaje indicando que es
  necesario configurar la conexión en Ajustes.
- **RF-16:** Los listados de Contactos y Productos deben ordenarse
  alfabéticamente por nombre.
- **RF-17:** Los listados de Albaranes y Facturas deben ordenarse por fecha
  descendente (más reciente primero).
- **RF-18:** Los listados de Albaranes y Facturas deben incluir paginación,
  mostrando un número fijo de elementos por página con controles para
  avanzar/retroceder.
- **RF-12:** Todas las vistas deben manejar los estados de carga (loading),
  error y vacío (sin resultados).
- **RF-13:** El filtro por nombre en Contactos y Productos debe ser un campo de
  texto que filtre localmente los resultados ya cargados.
- **RF-14:** El filtro por fechas en Albaranes y Facturas debe permitir
  seleccionar un rango de fechas (fecha desde / fecha hasta).
- **RF-15:** El filtro por cliente(s) en Albaranes y Facturas debe permitir
  seleccionar uno o varios clientes de entre los contactos disponibles. Los
  contactos se cargan automáticamente al abrir la sección.
- **RF-19:** Las vistas de detalle de factura y albarán son de solo lectura
  informativa, sin acciones adicionales (no descargar PDF, no enviar por email).
- **RF-20:** El número de elementos por página en los listados paginados
  (Albaranes y Facturas) debe ser configurable desde la sección de Ajustes, con
  un valor por defecto de 20.

## 6) Criterios de aceptación

- **CA-01:** Al pulsar "Contactos" en el menú lateral, se muestra una lista de
  contactos ordenada alfabéticamente por nombre. Un campo de filtro por nombre
  reduce la lista en tiempo real.
- **CA-02:** Al pulsar "Productos" en el menú lateral, se muestra una lista de
  productos ordenada alfabéticamente por nombre. Un campo de filtro por nombre
  reduce la lista en tiempo real.
- **CA-03:** Al pulsar "Albaranes" en el menú lateral, se muestra una lista
  paginada de albaranes ordenada por fecha descendente. Se pueden aplicar
  filtros por rango de fechas y por cliente(s). Al pulsar un albarán se navega a
  su detalle.
- **CA-04:** Al pulsar "Facturas" en el menú lateral, se muestra una lista
  paginada de facturas ordenada por fecha descendente. Se pueden aplicar filtros
  por rango de fechas y por cliente(s). Al pulsar una factura se navega a su
  detalle.
- **CA-11:** Los listados de Albaranes y Facturas muestran controles de
  paginación (anterior/siguiente) y el usuario puede navegar entre páginas sin
  perder los filtros aplicados.
- **CA-05:** La vista de detalle de albarán muestra la información completa del
  albarán (número, fecha, cliente, líneas/ítems, totales). Es solo lectura, sin
  acciones adicionales.
- **CA-06:** La vista de detalle de factura muestra la información completa de
  la factura (número, fecha, cliente, líneas/ítems, totales, estado). Es solo
  lectura, sin acciones adicionales.
- **CA-12:** Al abrir la sección de Albaranes o Facturas, los contactos se
  cargan automáticamente para alimentar el filtro por cliente(s), sin
  intervención del usuario.
- **CA-13:** En Ajustes existe una opción para configurar el número de elementos
  por página en los listados paginados (valor por defecto: 20). El cambio se
  aplica inmediatamente al navegar a Albaranes o Facturas.
- **CA-07:** Si la conexión con FacturaDirecta no está configurada, se muestra
  un mensaje informativo con indicación de ir a Ajustes.
- **CA-08:** Durante la carga de datos se muestra un indicador de carga; si hay
  error de red/API se muestra un mensaje de error con opción de reintentar; si
  no hay datos se muestra un estado vacío.
- **CA-09:** El endpoint `POST /{companyId}/deliveryNotes` existe en el código
  (data source, repository, use case) pero no hay botón ni acción de UI que lo
  invoque.
- **CA-10:** Todos los textos visibles al usuario están internacionalizados.

## 7) Flujos y comportamiento esperado

### Flujo principal — Consultar listado (aplica a las 4 secciones)

1. El usuario pulsa un ítem del menú lateral (Contactos / Productos / Albaranes
   / Facturas).
2. El sistema verifica que existe configuración de FacturaDirecta guardada
   (identificador de compañía + apiToken).
3. El sistema muestra un indicador de carga.
4. El sistema realiza la llamada GET al endpoint correspondiente usando el
   companyId y la autenticación configurada.
5. El sistema recibe la respuesta y muestra los datos en formato listado.
6. Los resultados se muestran ordenados: alfabéticamente por nombre
   (Contactos/Productos) o por fecha descendente (Albaranes/Facturas).
7. En Albaranes y Facturas, los resultados se muestran paginados con controles
   de navegación entre páginas.
8. El usuario puede aplicar filtros (nombre para Contactos/Productos; fechas y
   cliente(s) para Albaranes/Facturas).
9. La lista se actualiza según los filtros aplicados (filtrado local). Al
   cambiar filtros en Albaranes/Facturas, la paginación se reinicia a la primera
   página.

### Flujo principal — Consultar detalle (Facturas / Albaranes)

1. El usuario pulsa sobre un ítem del listado de facturas o albaranes.
2. El sistema muestra un indicador de carga.
3. El sistema realiza la llamada GET al endpoint de detalle
   (`/{companyId}/invoices/{id}` o `/{companyId}/deliveryNotes/{id}`).
4. El sistema muestra la información completa del documento.
5. El usuario puede volver al listado.

### Flujos alternativos

- **FA-01 — Sin configuración de FacturaDirecta:** En el paso 2 del flujo
  principal, si no hay configuración guardada, se muestra un mensaje indicando
  que debe configurarse la conexión en Ajustes. No se realiza ninguna llamada a
  la API.
- **FA-02 — Error de red o API:** En el paso 4 del flujo principal, si la
  llamada falla (timeout, error HTTP, credenciales inválidas), se muestra un
  mensaje de error descriptivo con opción de reintentar.
- **FA-03 — Respuesta vacía:** Si la API devuelve una lista vacía, se muestra un
  estado vacío ("No hay contactos/productos/albaranes/facturas").
- **FA-04 — Filtro sin resultados:** Si tras aplicar filtros no hay
  coincidencias, se muestra un estado vacío indicando que no hay resultados para
  los filtros aplicados.

### Estados especiales / excepciones

- **Estado loading:** Indicador de carga centrado mientras se obtienen datos de
  la API.
- **Estado error:** Mensaje de error con botón de reintentar. Debe distinguir
  entre error de conexión y credenciales inválidas si es posible.
- **Estado vacío:** Mensaje informativo cuando no hay datos que mostrar (ni del
  servidor ni tras filtrar).
- **Sin configuración:** Mensaje especial indicando que es necesario configurar
  FacturaDirecta en Ajustes antes de poder usar estas secciones.

## 8) Edge cases

- **EC-01:** El usuario accede a una sección de FacturaDirecta justo después de
  instalar la app, sin haber configurado Ajustes → se muestra el mensaje de
  configuración pendiente.
- **EC-02:** La API key o el identificador de compañía configurados son
  inválidos (expirados o erróneos) → la API devuelve 401/403 → se muestra error
  de credenciales inválidas.
- **EC-03:** El identificador de compañía configurado no existe en
  FacturaDirecta → la API devuelve 404 → se muestra error genérico.
- **EC-04:** La lista de contactos/productos es muy grande (cientos o miles de
  registros) → el filtro local sigue funcionando, pero podría haber lentitud en
  la carga inicial. Aceptable en esta iteración.
- **EC-09:** El usuario está en la última página de un listado paginado y aplica
  un filtro que reduce los resultados → la paginación se reinicia a la primera
  página.
- **EC-05:** El usuario aplica un filtro por fechas con fecha "desde" posterior
  a fecha "hasta" → el sistema no debe permitir este rango inválido o debe
  mostrar una advertencia.
- **EC-06:** El usuario intenta filtrar albaranes/facturas por cliente pero la
  carga automática de contactos falla (error de red) → el selector de clientes
  aparece vacío con mensaje de error y opción de reintentar la carga de
  contactos.
- **EC-07:** Se pierde la conexión de red mientras se están cargando los datos →
  se muestra estado de error con opción de reintentar.
- **EC-08:** El usuario navega rápidamente entre secciones del menú → las
  peticiones anteriores deben cancelarse o ignorarse para evitar mostrar datos
  de una sección en otra.

## 9) Impacto funcional

- **Módulos afectados:**
  - **Home / SideMenuShell:** Se amplía de 4 a 8 ítems en el menú lateral. Se
    añaden 4 nuevas páginas al `IndexedStack`.
  - **Settings (existente):** Se modifica la entidad `FacturaDirectaConfig` para
    sustituir `subdomain` por `companyId` (identificador de compañía). Se añade
    una nueva opción para configurar el número de elementos por página en
    listados paginados. Se consume esta configuración como dependencia.
  - **Nuevas features:** Se crean 4 nuevos módulos feature-first: `contacts`,
    `products`, `invoices`, `delivery_notes`.
- **Impacto en usuario:** El usuario pasa de una app con 4 secciones a 8
  secciones. Tiene acceso directo a datos de facturación sin salir de Servicebo.
- **Impacto en experiencia de usuario:** El menú lateral crece
  significativamente. Debe evaluarse si el espacio vertical es suficiente para 8
  ítems en estado colapsado y expandido, dado que la app opera en landscape.

## 10) Suposiciones

- **S-01:** El `companyId` (identificador de compañía) se almacena en la
  configuración de FacturaDirecta en Ajustes, sustituyendo el campo `subdomain`
  actual. No se hardcodea en el código fuente.
- **S-02:** La autenticación con la API de FacturaDirecta se realiza mediante el
  `apiToken` ya gestionado en la feature Settings, enviándolo como header de
  autorización (Bearer token o API key header según la especificación OpenAPI).
- **S-03:** La URL base de la API es `https://app.facturadirecta.com/api` y el
  `companyId` se usa como segmento de ruta en los endpoints.
- **S-04:** Los filtros se aplican localmente (client-side) sobre los datos ya
  obtenidos de la API, no como query parameters en las llamadas.
- **S-05:** La paginación en Albaranes y Facturas es local (client-side): se
  cargan todos los registros y se paginan en el frontend.
- **S-06:** El orden de los nuevos ítems en el menú lateral será: Inicio,
  Pedidos Hoy, Historial Pedidos, **Contactos**, **Productos**, **Albaranes**,
  **Facturas**, Ajustes (Ajustes permanece al final).
- **S-07:** Las vistas de detalle de factura y albarán se muestran como una
  nueva página dentro del área de contenido (no como un diálogo o panel
  lateral).
- **S-08:** La API key no debe almacenarse en el README ni en el código fuente;
  debe gestionarse exclusivamente a través de la UI de Ajustes y persistirse de
  forma segura.

## 11) Preguntas abiertas

- ~~**PA-01:** Resuelto — El `companyId` se almacena en Ajustes sustituyendo el
  campo `subdomain`.~~
- ~~**PA-02:** Resuelto — Los campos se infieren de la especificación OpenAPI.~~
- ~~**PA-03:** Resuelto — Sí, los contactos se cargan automáticamente al abrir
  la sección de Albaranes o Facturas.~~
- ~~**PA-04:** Resuelto — Alfabético por nombre para Contactos/Productos; fecha
  descendente para Albaranes/Facturas.~~
- ~~**PA-05:** Resuelto — Solo lectura informativa, sin acciones adicionales.~~
- ~~**PA-06:** Resuelto — 20 elementos por página como valor por defecto,
  configurable en Ajustes.~~

No quedan preguntas abiertas.

## 12) Notas para análisis técnico

- Ya existe la entidad `FacturaDirectaConfig` en
  `lib/features/settings/domain/entities/` con `subdomain`, `apiToken` y la
  propiedad computada `baseUrl`. Se debe refactorizar: sustituir `subdomain` por
  `companyId` (identificador de compañía) y actualizar `baseUrl` a
  `https://app.facturadirecta.com/api`.
- Ya existe el `SettingsRepository` con métodos para guardar/obtener/verificar
  la configuración de FacturaDirecta. El formulario de Ajustes deberá
  actualizarse para pedir "Identificador de compañía" en lugar de "Subdominio".
- La app usa `Dio` como cliente HTTP; las nuevas llamadas deben seguir el mismo
  patrón.
- El menú lateral está implementado en `SideMenuShell` con un `IndexedStack` de
  4 páginas; habrá que extenderlo a 8.
- La especificación OpenAPI está disponible en
  `https://app.facturadirecta.com/openapi.json` para consultar los esquemas de
  request/response de cada endpoint.
- Cada nueva sección debe ser un módulo feature-first independiente (Clean
  Architecture): `contacts`, `products`, `invoices`, `delivery_notes`.
- El `POST /deliveryNotes` debe implementarse hasta la capa de use
  case/repository pero sin wiring en la UI.
- Las vistas de detalle son solo lectura; no se necesitan acciones de descarga,
  envío o edición.
- Al abrir las secciones de Albaranes o Facturas, se debe lanzar automáticamente
  la carga de contactos para el filtro por cliente(s). Si falla, el selector
  queda vacío con opción de reintentar.
- En Ajustes, añadir un campo para configurar el número de elementos por página
  (valor por defecto: 20). Este valor debe persistirse con el mismo mecanismo
  que el resto de la configuración.
- **Seguridad:** La API key expuesta actualmente en el README.md debe
  eliminarse. Las credenciales solo deben gestionarse mediante la UI de Ajustes
  y almacenarse de forma segura (actualmente via `SharedPreferences`; considerar
  secure storage en futuras iteraciones).
- **Estado: Listo para análisis técnico**
