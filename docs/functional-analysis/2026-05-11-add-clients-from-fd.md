# Functional Analysis: Añadir clientes desde Factura Directa con selección

- **Fecha:** 2026-05-11
- **Identificador:** add-clients-from-fd
- **Estado:** Ready for technical analysis

## 1) Resumen

Reemplazar el botón "Sincronizar desde Factura Directa" en la pantalla de
clientes por un botón "Añadir desde Factura Directa" que, en lugar de
sincronizar automáticamente todos los contactos, permita al usuario
**seleccionar manualmente** qué contactos nuevos de Factura Directa desea añadir
a Firestore.

## 2) Contexto y objetivo

### Qué se solicita

Cambiar el comportamiento actual del botón de sincronización de clientes. El
flujo actual descarga todos los contactos de Factura Directa y crea/actualiza
automáticamente en Firestore sin intervención del usuario. El nuevo flujo debe:

1. Descargar los contactos de Factura Directa.
2. Compararlos con los clientes existentes en Firestore (por UUID de FD).
3. Filtrar solo los contactos **nuevos** (no existentes en Firestore).
4. Presentar un dialog de selección con los nuevos contactos.
5. Guardar en Firestore únicamente los seleccionados por el usuario.

### Qué problema resuelve

El flujo actual de sincronización automática no da control al usuario sobre qué
contactos se importan. Esto puede generar clientes no deseados en la base de
datos. Con el nuevo flujo, el usuario decide qué contactos añadir, evitando
ruido en su lista de clientes.

### Qué resultado funcional se espera

El usuario puede importar selectivamente contactos nuevos de Factura Directa a
su lista de clientes, manteniendo control total sobre qué contactos se
incorporan al sistema.

## 3) Alcance

### En alcance

- Cambio del texto del botón de "Sincronizar desde Factura Directa" a "Añadir
  desde Factura Directa"
- Cambio del icono del botón (de `sync_rounded` a uno que represente la acción
  de añadir, p. ej. `person_add_rounded` o `add_rounded`)
- Nuevo flujo al pulsar el botón: descarga → comparación → dialog de selección →
  guardado
- Dialog de selección múltiple con lista de contactos nuevos de FD
- Mensajes de feedback: éxito, error, sin contactos nuevos
- Actualización de las cadenas de i18n afectadas

### Fuera de alcance

- Actualización de contactos ya existentes en Firestore (el flujo de sync/update
  se elimina)
- Modificación del modelo de datos de Firestore (no se añaden campos nuevos)
- Cambio en la API de Factura Directa o en el datasource
  `FacturaDirectaApiDataSource`
- Gestión de categorías o métodos de envío durante la importación
- Eliminación de clientes desde esta pantalla
- Paginación o búsqueda dentro del dialog de selección (ver Notas para análisis
  técnico)

## 4) Actores implicados

| Actor                  | Rol                                                               |
| ---------------------- | ----------------------------------------------------------------- |
| Usuario administrador  | Inicia el proceso, selecciona contactos y confirma la importación |
| API de Factura Directa | Provee la lista de contactos disponibles                          |
| Firestore              | Almacén de clientes existentes y destino de los nuevos            |

## 5) Requisitos funcionales

- **RF-01:** El botón en la pantalla de clientes debe mostrar el texto "Añadir
  desde Factura Directa" en lugar de "Sincronizar desde Factura Directa".
- **RF-02:** Al pulsar el botón, el sistema debe obtener la configuración de
  Factura Directa (API token, company ID) del repositorio de settings.
- **RF-03:** El sistema debe descargar todos los contactos de Factura Directa
  mediante la API existente.
- **RF-04:** El sistema debe obtener todos los clientes existentes en Firestore
  y construir un mapa de UUIDs de FD ya registrados.
- **RF-05:** El sistema debe calcular la diferencia: contactos de FD cuyo `uuid`
  no existe en ningún `facturaDirectaUuid` de los clientes de Firestore.
- **RF-06:** Si no hay contactos nuevos, el sistema debe informar al usuario con
  un mensaje claro (p. ej. "No hay contactos nuevos en Factura Directa") y no
  mostrar el dialog de selección.
- **RF-07:** Si hay contactos nuevos, el sistema debe mostrar un dialog con la
  lista de contactos nuevos, permitiendo selección múltiple mediante checkboxes.
- **RF-08:** Cada elemento del dialog debe mostrar al menos el nombre del
  contacto (nombre comercial si existe, nombre fiscal como fallback) y el
  NIF/CIF (fiscalId) para facilitar la identificación.
- **RF-09:** El dialog debe incluir un mecanismo para seleccionar/deseleccionar
  todos los contactos (checkbox "Seleccionar todos" o similar).
- **RF-10:** El dialog debe tener un botón de confirmación ("Añadir
  seleccionados") y un botón de cancelación ("Cancelar").
- **RF-11:** El botón de confirmación debe estar deshabilitado si no hay ningún
  contacto seleccionado.
- **RF-12:** Al confirmar, los contactos seleccionados deben guardarse en
  Firestore usando `batchAdd`, mapeados al modelo `ClientModel` con: `name` =
  nombre comercial (o fiscal como fallback), `facturaDirectaUuid` = uuid del
  contacto FD, `facturaDirectaName` = nombre fiscal del contacto FD,
  `clientCategoryId` = null, `shippingMethodsByDay` = vacío.
- **RF-13:** Tras el guardado exitoso, se deben recargar los fiscal IDs
  (comportamiento existente post-sync) y mostrar un mensaje de éxito con el
  número de clientes añadidos.
- **RF-14:** Si ocurre un error durante la descarga o el guardado, se debe
  mostrar un mensaje de error al usuario.

## 6) Criterios de aceptación

- **CA-01:** El botón muestra "Añadir desde Factura Directa" con un icono
  adecuado (no el icono de sync).
- **CA-02:** Al pulsar el botón, se muestra un indicador de carga mientras se
  descargan los contactos de FD y se comparan con Firestore.
- **CA-03:** Si no hay contactos nuevos, se muestra un mensaje informativo y el
  flujo termina sin abrir un dialog.
- **CA-04:** Si hay contactos nuevos, se abre un dialog con la lista completa de
  nuevos contactos, cada uno con checkbox, nombre y NIF/CIF.
- **CA-05:** El usuario puede seleccionar/deseleccionar contactos
  individualmente y mediante "Seleccionar todos".
- **CA-06:** El botón "Añadir seleccionados" está deshabilitado cuando no hay
  selección; habilitado cuando hay al menos uno seleccionado.
- **CA-07:** Al confirmar, los contactos seleccionados se crean en Firestore con
  los campos correctos (`name`, `facturaDirectaUuid`, `facturaDirectaName`,
  `clientCategoryId` = null).
- **CA-08:** Tras la importación exitosa, la tabla de clientes se actualiza
  automáticamente (vía stream de `watchAll`) reflejando los nuevos clientes.
- **CA-09:** Se muestra feedback de éxito indicando cuántos clientes se
  añadieron (p. ej. "3 clientes añadidos correctamente").
- **CA-10:** Si la configuración de FD no está disponible, se muestra un error
  descriptivo.
- **CA-11:** Si la API de FD falla o Firestore falla, se muestra un mensaje de
  error genérico.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario está en la pantalla de clientes y pulsa "Añadir desde Factura
   Directa".
2. Se muestra un indicador de carga ("Buscando nuevos contactos en Factura
   Directa…" o similar).
3. El sistema obtiene la configuración de FD (API token, company ID).
4. El sistema descarga todos los contactos de FD.
5. El sistema obtiene todos los clientes de Firestore.
6. El sistema calcula los contactos nuevos (FD UUIDs no presentes en Firestore).
7. Se cierra el indicador de carga.
8. Se abre el dialog con la lista de contactos nuevos.
9. El usuario selecciona los contactos deseados.
10. El usuario pulsa "Añadir seleccionados".
11. Se muestra un indicador de carga durante el guardado.
12. Los contactos seleccionados se guardan en Firestore via `batchAdd`.
13. Se recargan los fiscal IDs.
14. Se cierra el dialog y se muestra feedback de éxito ("N clientes añadidos
    correctamente").
15. La tabla de clientes se actualiza automáticamente.

### Flujos alternativos

- **FA-01 — Sin contactos nuevos:** En el paso 6, si no hay contactos nuevos, se
  cierra el indicador de carga y se muestra un mensaje informativo ("No hay
  contactos nuevos en Factura Directa"). El flujo termina.
- **FA-02 — Cancelación:** En el paso 9 o 10, el usuario pulsa "Cancelar". Se
  cierra el dialog sin guardar nada. No se muestra feedback.
- **FA-03 — Seleccionar todos:** El usuario usa el checkbox de "Seleccionar
  todos" para marcar/desmarcar todos los contactos de la lista de golpe.

### Estados especiales / excepciones

- **Estado loading:** Indicador de progreso no dismissable durante la descarga
  de contactos FD y durante el guardado en Firestore. Similar al actual dialog
  de sync.
- **Estado vacío (sin nuevos):** Mensaje informativo en lugar del dialog de
  selección (no es un error).
- **Estado error — Config no encontrada:** Si no hay configuración de FD
  guardada, se muestra un error indicando que debe configurar Factura Directa en
  Ajustes.
- **Estado error — Fallo de red/API:** Si la llamada a la API de FD falla (red,
  servidor, credenciales inválidas), se muestra un mensaje de error genérico.
- **Estado error — Fallo de Firestore:** Si el `batchAdd` falla, se muestra un
  mensaje de error y no se confirma ningún añadido parcial (el batch es
  atómico).

## 8) Edge cases

- **EC-01 — Todos los contactos de FD ya existen en Firestore:** Se muestra el
  mensaje "No hay contactos nuevos" (flujo FA-01). No se abre el dialog.
- **EC-02 — FD devuelve contactos con UUID vacío:** Estos contactos deben ser
  ignorados (comportamiento consistente con el sync actual que hace
  `if (uuid.isEmpty) continue`).
- **EC-03 — Lista de contactos de FD muy grande (>100 nuevos):** El dialog debe
  ser scrollable. No se requiere paginación en esta iteración, pero la UI debe
  soportar listas largas con scroll.
- **EC-04 — El usuario no selecciona ningún contacto y pulsa "Añadir":** El
  botón de añadir debe estar deshabilitado si no hay selección (RF-11), por lo
  que este caso no debería ocurrir.
- **EC-05 — Doble pulsación del botón:** El indicador de carga bloquea la
  interacción (no dismissable), previniendo doble ejecución.
- **EC-06 — Contacto de FD sin nombre fiscal ni comercial:** Se debe usar un
  string vacío como nombre (consistente con el mapeo actual). Podría mostrarse
  como "(Sin nombre)" en el dialog para UX, pero el dato guardado será vacío.

## 9) Impacto funcional

- **Módulos afectados:**
  - Feature `clients`: se modifica la pantalla principal, el cubit/use case de
    sync se reemplaza por un nuevo flujo de "fetch + filter + add selected".
  - Cadenas de i18n: se añaden/modifican claves de localización.
  - Módulo DI (`clients_module.dart`): posible registro de nuevo use case.

- **Impacto en usuario:**
  - El usuario gana control sobre qué contactos importar.
  - Se pierde la funcionalidad de **actualización automática** de contactos
    existentes (p. ej., si el nombre fiscal cambia en FD, ya no se actualizará
    automáticamente). Este es un trade-off aceptado según la petición.

- **Impacto en experiencia de usuario:**
  - Flujo más interactivo: requiere un paso adicional (selección), pero da
    confianza sobre qué se importa.
  - El botón ahora refleja mejor la acción real ("Añadir" vs "Sincronizar").

## 10) Suposiciones

- **S-01:** El flujo de actualización automática de contactos existentes (que
  actualizaba `facturaDirectaName` si había cambiado) se elimina por completo.
  El nuevo botón solo añade contactos nuevos, no actualiza los existentes.
- **S-02:** El dialog de selección no requiere búsqueda/filtrado interno en esta
  iteración. Si la lista es grande, basta con scroll.
- **S-03:** El nombre mostrado en el dialog para cada contacto sigue la misma
  lógica actual: nombre comercial (`title`) si existe, nombre fiscal (`name`)
  como fallback.
- **S-04:** El NIF/CIF (`fiscalId`) de cada contacto de FD está disponible en la
  respuesta de la API bajo `content.main.fiscal_id` o campo equivalente, y se
  mostrará en el dialog solo como ayuda visual de identificación, no se persiste
  en Firestore (no se añaden campos nuevos al modelo).
- **S-05:** No se requiere persistir el NIF/CIF en el modelo de Firestore como
  parte de este cambio.
- **S-06:** El dialog muestra un contador de seleccionados (p. ej. "3 de 15
  seleccionados") para orientar al usuario.

## 11) Preguntas abiertas

- **PA-01:** ¿Se desea mantener en algún lugar la funcionalidad de actualización
  de datos de FD para clientes ya existentes (p. ej., como un botón separado o
  proceso en segundo plano), o se descarta definitivamente?
- **PA-02:** ¿Se necesita mostrar algún dato adicional de los contactos de FD en
  el dialog además de nombre y NIF/CIF (p. ej., email, teléfono, dirección)?

## 12) Notas para análisis técnico

- El use case actual `SyncClientsFromFd` debe ser reemplazado o refactorizado.
  Se sugiere crear un nuevo use case (p. ej. `FetchNewFdContacts`) que devuelva
  la lista de contactos nuevos sin guardarlos, y reutilizar `batchAdd` del
  datasource para el guardado.
- La lógica de comparación por UUID (pasos 3-6 del flujo actual de sync) es
  reutilizable; solo hay que separar la fase de "identificar nuevos" de la fase
  de "guardar".
- El dialog de selección es un widget nuevo en la capa de presentación.
- Las cadenas de i18n a modificar/añadir incluyen: texto del botón, título del
  dialog, mensaje de sin contactos nuevos, mensaje de éxito con conteo, mensaje
  de error, label de "Seleccionar todos", label del botón confirmar, label del
  botón cancelar, texto de carga.
- Considerar si `SyncClientsFromFd` y su uso en `FacturaDirectaCubit` (módulo
  settings) también deben actualizarse o si ese flujo de sync en settings se
  mantiene independiente.
- Restricción: no se añaden campos nuevos al modelo de Firestore.
- Arquitectura: Clean Architecture feature-first con BLoC/Cubit, GetIt y fpdart.
- **Estado: Listo para análisis técnico**
