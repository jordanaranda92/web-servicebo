# Functional Analysis: Migración de clientes de Google Sheets a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** clients-firestore-migration
- **Estado:** Ready for technical analysis

## 1) Resumen

Migrar la fuente de datos complementarios de clientes (activo, categoría, orden)
desde la hoja "clientes" del spreadsheet "configuracion" de Google Sheets a una
colección `clients` en Firebase Firestore. La lectura y escritura de estos datos
pasará a ser exclusivamente contra Firestore.

## 2) Contexto y objetivo

### Qué se solicita

Actualmente los datos de clientes se obtienen de dos fuentes:

1. **API de FacturaDirecta (FD):** datos identitarios (uuid, name, title, email,
   phone, fiscalId, country, city).
2. **Google Sheets** (hoja "clientes" en spreadsheet "configuracion"): datos de
   gestión interna (UUID, Nombre, Activo, Categoría cliente, Orden).

Se solicita reemplazar la fuente (2) por una colección Firestore `clients` con
los siguientes campos:

| Campo Firestore      | Origen                                    | Tipo    |
| -------------------- | ----------------------------------------- | ------- |
| `name`               | Nombre visible del cliente en la app      | String  |
| `facturaDirectaUuid` | UUID del contacto en FacturaDirecta       | String  |
| `facturaDirectaName` | Nombre original devuelto por la API de FD | String  |
| `isActive`           | Columna "Activo" de la hoja               | bool    |
| `clientCategoryId`   | Columna "Categoría cliente" de la hoja    | String? |
| `order`              | Columna "Orden" de la hoja                | int?    |

### Qué problema resuelve

- Elimina la dependencia de Google Sheets como almacén de datos de clientes,
  simplificando la arquitectura (las categorías ya están en Firestore).
- Mejora el rendimiento: lectura directa de Firestore vs. llamadas a Google
  Sheets API.
- Reduce la complejidad del flujo de sincronización bidireccional entre FD API y
  Google Sheets.
- Unifica el almacenamiento de datos de gestión interna en un solo backend
  (Firestore).

### Qué resultado funcional se espera

- La vista de clientes carga sus datos desde Firestore (combinando con FD API
  cuando aplique).
- Las modificaciones (toggle activo, cambio de categoría, cambio de orden) se
  persisten en Firestore.
- La hoja "clientes" de Google Sheets deja de usarse como fuente de
  lectura/escritura para estos datos.

## 3) Alcance

### En alcance

- **Definición del modelo Firestore:** colección `clients` con los campos
  especificados.
- **Lectura de clientes:** obtener datos complementarios desde Firestore en
  lugar de Google Sheets.
- **Escritura de clientes:** persistir cambios de `isActive`, `clientCategoryId`
  y `order` en Firestore.
- **Guardado batch:** el flujo de guardado por lotes debe operar contra
  Firestore.
- **Sincronización manual FD → Firestore:** nuevo botón "Sincronizar clientes"
  en la pantalla de ajustes (sección FacturaDirecta). Al pulsarlo, se descargan
  los contactos de FD y se sincronizan con Firestore (creando nuevos documentos
  y actualizando nombres cambiados).
- **Eliminación de sincronización automática:** la vista de clientes ya NO
  descarga contactos de FD ni los vuelca a Firestore al acceder. Solo lee datos
  de Firestore.
- **Migración de datos existentes:** carga inicial de los datos actuales de la
  hoja "clientes" a la colección Firestore `clients`.

### Fuera de alcance

- Eliminación de la hoja "clientes" del spreadsheet (puede mantenerse como
  respaldo histórico).
- Migración de otros datos que actualmente residen en Google Sheets (productos,
  pedidos, etc.).
- Reglas de seguridad de Firestore (se asume configuración existente).

## 4) Actores implicados

- **Usuario administrador:** gestiona clientes desde la aplicación
  (activa/desactiva, asigna categoría, establece orden).
- **Sistema — API FacturaDirecta:** fuente primaria de contactos.
- **Sistema — Firebase Firestore:** nuevo almacén de datos complementarios de
  clientes.
- **Sistema — Google Sheets:** fuente actual que será reemplazada
  (lectura/escritura de datos de clientes).

## 5) Requisitos funcionales

- **RF-01:** La colección `clients` en Firestore almacenará documentos con los
  campos: `name` (String), `facturaDirectaUuid` (String), `facturaDirectaName`
  (String), `isActive` (bool), `clientCategoryId` (String, nullable), `order`
  (int, nullable).
- **RF-02:** Al cargar la vista de clientes, los datos complementarios
  (isActive, clientCategoryId, order) se obtendrán de Firestore en lugar de
  Google Sheets.
- **RF-03:** Al modificar el estado activo de un cliente, el cambio se
  persistirá en el documento correspondiente de Firestore.
- **RF-04:** Al modificar la categoría de un cliente, el cambio se persistirá en
  el campo `clientCategoryId` del documento correspondiente de Firestore.
- **RF-05:** Al modificar el orden de un cliente, el cambio se persistirá en el
  campo `order` del documento correspondiente de Firestore.
- **RF-06:** El guardado por lotes (batch save) aplicará todos los cambios
  pendientes (activo, categoría, orden) directamente en Firestore.
- **RF-07:** La sincronización de contactos FD → Firestore será un proceso
  manual, iniciado por el usuario desde un botón "Sincronizar clientes" en la
  pantalla de Ajustes (sección FacturaDirecta).
- **RF-08:** Al sincronizar, para cada contacto de FD que no tenga documento en
  Firestore, se creará uno con: `facturaDirectaUuid` = uuid de FD,
  `facturaDirectaName` = nombre de FD, `name` = título o nombre de FD,
  `isActive` = true, `clientCategoryId` = null, `order` = null.
- **RF-09:** Al sincronizar, si el nombre de un contacto en FD difiere del
  `facturaDirectaName` almacenado en Firestore, se actualizará
  `facturaDirectaName` en Firestore.
- **RF-10:** La vista de clientes NO descargará contactos de FD al acceder. Solo
  leerá datos existentes en Firestore.
- **RF-11:** Se deberá realizar una carga inicial (migración one-time) de los
  datos actuales de la hoja "clientes" a la colección Firestore, mapeando: UUID
  → `facturaDirectaUuid`, Nombre → `name` y `facturaDirectaName`, Activo →
  `isActive`, Categoría cliente → `clientCategoryId` (ID del documento Firestore
  en `client_categories`), Orden → `order`.
- **RF-12:** El campo `clientCategoryId` debe almacenar el ID del documento de
  la colección `client_categories` de Firestore (FK). Puede ser nulo.
- **RF-13:** La carga de clientes desde Firestore no debe requerir que Google
  Drive esté configurado (elimina ese prerequisito para datos de clientes).
- **RF-14:** Se corta de inmediato toda lectura/escritura a Google Sheets para
  datos de clientes. Sin periodo de transición.

## 6) Criterios de aceptación

- **CA-01:** La vista de clientes muestra los mismos datos que actualmente
  (nombre, estado activo, categoría, orden) pero obtenidos desde Firestore.
- **CA-02:** Toggle de "activo" de un cliente se refleja en Firestore
  inmediatamente y persiste tras recargar la vista.
- **CA-03:** Cambio de categoría de un cliente se guarda en Firestore con el
  `clientCategoryId` correcto y se muestra el nombre de categoría
  correspondiente.
- **CA-04:** Cambio de orden de un cliente se guarda en Firestore y persiste
  tras recargar.
- **CA-05:** Guardado batch de múltiples cambios (activo + categoría + orden) se
  persiste correctamente en Firestore.
- **CA-06:** Al pulsar "Sincronizar clientes" en Ajustes, los contactos nuevos
  de FD se crean en Firestore con `isActive: true`, y los nombres cambiados se
  actualizan.
- **CA-07:** Tras sincronizar, los nuevos clientes aparecen en la vista de
  clientes al recargar.
- **CA-08:** La vista de clientes NO requiere que FacturaDirecta esté
  configurado. Muestra los clientes existentes en Firestore.
- **CA-09:** La vista de clientes NO requiere que Google Drive esté configurado.
- **CA-10:** Si no hay clientes en Firestore (primera vez), la vista muestra
  estado vacío con indicación de sincronizar.
- **CA-11:** Tras la migración inicial, los datos en Firestore coinciden con los
  de la hoja de Google Sheets para todos los clientes existentes.

## 7) Flujos y comportamiento esperado

### Flujo principal — Carga de clientes

1. El usuario accede a la vista de clientes.
2. El sistema lee la colección `clients` de Firestore.
3. Se resuelven los nombres de categoría consultando la colección
   `client_categories`.
4. Se muestra la lista de clientes ordenada alfabéticamente.

> **Nota:** Ya NO se llama a la API de FacturaDirecta al acceder a la vista. Los
> datos de clientes se leen exclusivamente de Firestore.

### Flujo principal — Modificación y guardado

1. El usuario modifica uno o más campos (activo, categoría, orden) de uno o más
   clientes.
2. Los cambios se acumulan localmente como pendientes (comportamiento actual).
3. El usuario pulsa "Guardar".
4. El sistema envía los cambios a Firestore (batch write).
5. Se recargan los datos para reflejar el estado actualizado.

### Flujo principal — Sincronización manual (Ajustes)

1. El usuario accede a la pantalla de Ajustes.
2. En la sección de FacturaDirecta, pulsa el botón "Sincronizar clientes".
3. El sistema muestra estado de progreso (loading).
4. El sistema descarga todos los contactos de la API de FacturaDirecta.
5. Para cada contacto de FD:
   - Si no existe documento en Firestore con ese `facturaDirectaUuid` → se crea
     con valores por defecto (`isActive: true`, `clientCategoryId: null`,
     `order: null`).
   - Si existe pero el nombre ha cambiado → se actualiza `facturaDirectaName` en
     Firestore.
6. Se muestra feedback de éxito o error al usuario (snackbar o similar).

### Flujos alternativos

- **FA-01 — FD no configurado al sincronizar:** Se muestra mensaje indicando que
  FacturaDirecta no está configurado.
- **FA-02 — Error de red durante sincronización:** Se muestra mensaje de error.
  Los datos ya sincronizados antes del error se mantienen.
- **FA-03 — Firestore no disponible al cargar clientes:** Se muestra error
  (mismo patrón que errores actuales).
- **FA-04 — Sincronización sin contactos nuevos:** Se completa sin cambios y se
  muestra feedback de que todo está actualizado.

### Estados especiales / excepciones

- **Estado vacío:** No hay clientes en Firestore (aún no se ha sincronizado) →
  lista vacía con indicación de que debe sincronizarse desde Ajustes.
- **Estado loading/procesando:** Spinner mientras se cargan datos de Firestore.
- **Estado error:** Error de red o servidor → mensaje de error al usuario
  (mantiene UX actual).
- **Sin configuración FD:** Ya NO es un error para la vista de clientes. Solo es
  relevante al intentar sincronizar desde Ajustes.
- **Sin Google Drive configurado:** Ya NO es un error para la vista de clientes.

## 8) Edge cases

- **EC-01:** Un cliente existe en la hoja de Sheets con un `clientCategoryId`
  que no corresponde a ningún documento de la colección `client_categories` →
  durante la migración, se almacena el valor tal cual; en la vista se mostrará
  sin categoría asignada.
- **EC-02:** Documentos duplicados en Firestore con el mismo
  `facturaDirectaUuid` → el campo `facturaDirectaUuid` debería ser único;
  durante la carga se toma el primero encontrado.
- **EC-03:** Cliente en Firestore cuyo `facturaDirectaUuid` ya no existe en FD →
  se mantiene en Firestore y SÍ aparece en la vista (la lista ahora se construye
  a partir de Firestore, no de FD).
- **EC-04:** Escritura simultánea: dos usuarios modifican el mismo cliente →
  last-write-wins (comportamiento estándar de Firestore, aceptable para este
  caso de uso).
- **EC-05:** El campo `order` con valor null → el cliente no tiene orden
  asignado; se muestra vacío en la UI (comportamiento actual).
- **EC-06:** Migración con filas de la hoja que tienen UUID vacío → se ignoran
  (comportamiento actual del parser).

## 9) Impacto funcional

- **Módulos afectados:**
  - `clients` (feature): cambio de datasource de Google Sheets a Firestore.
    Eliminación de llamada a API de FD al cargar vista.
  - `clients_repository_impl`: eliminación de lógica de lectura/escritura contra
    Sheets y de sincronización automática FD → Firestore.
  - `settings` (feature): nuevo botón "Sincronizar clientes" en sección
    FacturaDirecta. Nuevo caso de uso y lógica de sincronización FD → Firestore.
  - Inyección de dependencias: nuevo datasource Firestore para clientes.
  - Eliminación del prerequisito de Google Drive y FacturaDirecta para la vista
    de clientes.
- **Módulos NO afectados:**
  - `client_categories`: ya usa Firestore, sin cambios.
  - Otras features que usen Google Sheets (productos, pedidos): sin cambios.
- **Impacto en usuario:** La vista de clientes carga más rápido (solo
  Firestore). La sincronización con FD pasa a ser una acción explícita en
  Ajustes.
- **Impacto en experiencia de usuario:** Positivo — carga más rápida, sin
  dependencia de configuraciones externas para ver la lista.

## 10) Suposiciones

- **S-01:** La estructura de la colección `client_categories` en Firestore no
  cambia.
- **S-02:** Las reglas de seguridad de Firestore existentes permiten
  lectura/escritura en la nueva colección `clients` para el usuario autenticado
  de la app.
- **S-03:** El campo `clientCategoryId` almacenará el ID del documento Firestore
  de `client_categories`, no el ID numérico de la hoja de Sheets. Durante la
  migración se deberá mapear el ID de la hoja al ID del documento Firestore
  correspondiente.
- **S-04:** La migración inicial de datos se ejecutará como un proceso one-time
  (script, función Cloud, o manualmente).
- **S-05:** El campo `name` en Firestore corresponde al nombre de visualización
  del cliente (`title` de FD si existe, sino `name` de FD), y
  `facturaDirectaName` almacena el `name` original devuelto por la API.
- **S-06:** Tras la migración, Firestore es la fuente autoritativa de la lista
  de clientes. FD solo se usa para sincronización manual de nuevos contactos.

## 11) Preguntas abiertas

- ~~**PA-01:** Resuelta — Se corta de inmediato, sin periodo de transición.~~
- ~~**PA-02:** Resuelta — `clientCategoryId` almacena el ID del documento
  Firestore de `client_categories` (FK). Puede ser nulo.~~
- ~~**PA-03:** Resuelta — No hay procesos externos. La sincronización FD →
  Firestore pasa a ser manual desde Ajustes.~~

No quedan preguntas abiertas.

## 12) Notas para análisis técnico

- **Patrón existente:** La colección `client_categories` ya está en Firestore
  con datasource `ClientCategoryFirestoreDataSource` /
  `ClientCategoryFirestoreDataSourceImpl`. Se debe seguir el mismo patrón para
  crear `ClientFirestoreDataSource`.
- **Dependencias a eliminar de `ClientsRepositoryImpl`:**
  `GoogleSheetsDataSource`, `GoogleDriveRemoteDataSource`,
  `FacturaDirectaApiDataSource`, `SettingsRepository`. El repositorio solo
  necesitará el nuevo `ClientFirestoreDataSource` y
  `ClientCategoryFirestoreDataSource`.
- **El `_SheetLoadResult`, `ClientSheetDto` y `ClientDto`** quedarán obsoletos o
  se simplificarán tras la migración.
- **Nueva lógica de sincronización:** debe residir en la feature `settings` o en
  un caso de uso compartido. Requiere `FacturaDirectaApiDataSource`,
  `SettingsRepository` y `ClientFirestoreDataSource`.
- **Considerar query Firestore** por `facturaDirectaUuid` para búsquedas
  eficientes durante la sincronización.
- **Vista de clientes simplificada:** ya no necesita `PrerequisiteFailure` para
  FD ni Google Drive. Solo lee de Firestore.
- **Botón en Settings:** añadir "Sincronizar clientes" a
  `FacturaDirectaSection`, con estados de loading, éxito y error.
- **Estado: Listo para análisis técnico**
