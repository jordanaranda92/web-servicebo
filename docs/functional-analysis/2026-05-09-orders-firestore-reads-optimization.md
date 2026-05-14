# Functional Analysis: Optimización de lecturas/escrituras Firestore en pedidos de hoy

- **Fecha:** 2026-05-09
- **Identificador:** orders-firestore-reads-optimization
- **Estado:** Ready for technical analysis

## 1) Resumen

Reducir el consumo de lecturas Firestore en la pantalla de pedidos de hoy (~90%
de reducción estimada) mediante cuatro optimizaciones coordinadas: caché en
memoria de catálogos de clientes/productos (OPT-1), eliminación de re-lecturas
post-escritura (OPT-2), paso de IDs directos en vez de índices numéricos al
actualizar celdas (OPT-3), y limpieza de código muerto de polling (OPT-4).

## 2) Contexto y objetivo

### Qué se solicita

Optimizar el consumo de operaciones Firestore en la feature `orders_today` para
mantenerse dentro del free tier (50K reads/día, 20K writes/día) con margen
holgado, incluso con múltiples usuarios concurrentes.

### Qué problema resuelve

Actualmente, cada edición de celda genera ~132 lecturas Firestore: 1 lectura del
documento raíz + 30 de clientes + 50 de productos (para resolver
nombres/orden) + 1 re-lectura post-write del doc raíz + 50 re-lecturas de rows.
Con 200 ediciones diarias, solo `updateCell` consume ~26.400 reads (53% del free
tier). A esto se suman las operaciones CRUD (add/remove clientes y productos)
que repiten el mismo patrón de lecturas redundantes.

### Qué resultado funcional se espera

- El comportamiento visible para el usuario **no cambia**: misma UX, misma
  latencia percibida, misma sincronización en tiempo real.
- El consumo de reads Firestore pasa de ~29.500/día a ~2.800/día (estimación con
  2 usuarios y 200 ediciones).
- Se elimina código muerto que podría reactivarse accidentalmente generando
  lecturas innecesarias.

## 3) Alcance

### En alcance

- **OPT-1 — Caché in-memory de catálogos**: Cachear en memoria las listas de
  clientes y productos (nombre, orden, id, isActive) dentro del repositorio de
  `orders_today`. Invalidar el caché solo cuando cambie la estructura del pedido
  (cambio en `clientIds` o `productIds` del documento raíz).
- **OPT-2 — Eliminar re-lectura post-write en `updateCell`**: Tras la escritura
  de una celda en Firestore, no re-leer `getOrderDocument` + `getOrderRows`. El
  BLoC ya aplica un update optimista y el listener de Firestore propagará el
  estado autoritativo.
- **OPT-3 — Pasar IDs directos al use case de actualización de celda**:
  Modificar el contrato de `updateCell` para recibir `productId` + `clientId` (o
  `isStock: true`) en vez de índices numéricos (`productRow`, `clientCol`),
  eliminando la necesidad de leer el documento raíz y los catálogos para
  traducir índices a IDs.
- **OPT-4 — Eliminar evento y handler de polling `CheckModified`**: Eliminar
  `OrdersTodayCheckModifiedRequested`, su handler `_onCheckModified` y cualquier
  referencia. Es código muerto tras la migración a listeners Firestore.

### Fuera de alcance

- Optimización de la feature `orders_history` o del dashboard (usan los mismos
  datasources pero tienen flujos diferentes).
- Caché persistente en disco (SharedPreferences, Hive, etc.) — solo se contempla
  caché en memoria volátil.
- Optimización del listener Firestore en sí (debounce ya aplicado en 200ms).
- Cambios en el modelo de datos de Firestore (estructura de
  colecciones/documentos).
- Optimización de las operaciones
  `removeClients`/`removeProducts`/`addClients`/`addProducts` — benefician
  parcialmente de OPT-1 pero su refactorización completa queda fuera.
- Eliminación del campo `lastModifiedAt` en el documento raíz (OPT-6 del
  análisis previo — aplazada).

## 4) Actores implicados

- **Usuario final**: No percibe ningún cambio funcional. Beneficio indirecto:
  menor riesgo de superar el free tier y que el servicio deje de funcionar.
- **Sistema (Firestore)**: Receptor del ahorro de operaciones.
- **Desarrollador/mantenedor**: Código más limpio (menos dead code, contratos
  más directos).

## 5) Requisitos funcionales

- **RF-01 — Caché de catálogos**: El repositorio debe mantener en memoria las
  listas de clientes y productos, obtenidas del datasource Firestore. Estas
  listas se cargan la primera vez que se necesitan y se reutilizan en todas las
  operaciones posteriores dentro de la misma sesión de la pantalla.
- **RF-02 — Invalidación de caché**: Cuando el stream de Firestore detecte un
  cambio estructural (cambio en `clientIds` o `productIds`), el caché debe
  invalidarse y recargarse con datos frescos. Este mecanismo ya existe
  parcialmente en `watchTodayOrders` (variable `idsChanged`).
- **RF-03 — Escritura sin re-lectura**: Tras escribir una celda (quantity o
  stock), el repositorio no debe re-leer el documento ni las rows de Firestore.
  Debe devolver un resultado indicando éxito/fallo sin incluir un `OrderSheet`
  actualizado, ya que:
  - El BLoC ya aplica el update optimista antes de escribir.
  - El listener de Firestore empujará el estado confirmado.
- **RF-04 — Actualización por IDs directos**: El use case de actualización de
  celda debe recibir `productId` y `clientId` (para cantidades) o `productId` e
  indicador de stock (para stocks), eliminando la traducción de índices a IDs en
  el repositorio.
- **RF-05 — Traducción índice→ID en la capa de presentación**: El BLoC, que ya
  tiene el `OrderSheet` en estado (con la lista ordenada de clientes/productos),
  debe ser el responsable de traducir los índices de UI a IDs antes de enviarlos
  al use case. Esto requiere que el `OrderSheet` incluya los IDs de clientes y
  productos además de los nombres.
- **RF-06 — Eliminación del evento de polling**: El evento
  `OrdersTodayCheckModifiedRequested` y su handler `_onCheckModified` deben
  eliminarse del BLoC y del archivo de eventos.

## 6) Criterios de aceptación

- **CA-01**: Una edición de celda (quantity o stock) genera exactamente **2
  writes** Firestore (row + root `lastModifiedAt`) y **0 reads** adicionales en
  el repositorio (sin contar el listener que ya está activo).
- **CA-02**: La primera carga de la pantalla lee clientes y productos **una sola
  vez** desde Firestore. Todas las operaciones posteriores (updateCell,
  removeClients, addClients, etc.) reutilizan el caché.
- **CA-03**: Un cambio estructural remoto (otro usuario añade/elimina un cliente
  o producto) dispara la recarga del caché de catálogos de forma automática y
  transparente.
- **CA-04**: Tras aplicar las optimizaciones, el evento
  `OrdersTodayCheckModifiedRequested` no existe en el código.
- **CA-05**: La UI funciona exactamente igual: edición de celdas con update
  optimista, sincronización en tiempo real vía listener, add/remove clientes y
  productos.
- **CA-06**: `dart analyze lib/` no reporta errores ni warnings nuevos.
- **CA-07**: Los tests existentes siguen pasando (sin regresión).

## 7) Flujos y comportamiento esperado

### Flujo principal — Edición de celda (con optimizaciones)

1. El usuario modifica una celda en la tabla.
2. `OrdersTable` invoca `onCellUpdated(productRow, clientCol, value)`.
3. La página despacha `OrdersTodayCellUpdateRequested` al BLoC.
4. El BLoC: a. Aplica el update optimista en el `OrderSheet` local y emite el
   nuevo estado. b. **Traduce** `productRow` → `productId` y `clientCol` →
   `clientId` usando las listas del `OrderSheet` actual (que ahora incluye IDs).
   c. Despacha al use case con `productId`, `clientId` (o `isStock`) y `value`.
5. El use case llama al repositorio, que: a. Ejecuta el batch write directamente
   (row + `lastModifiedAt`) — **0 reads**. b. Devuelve `Right(unit)` — no
   devuelve un `OrderSheet`.
6. El listener Firestore recibe el cambio y emite un nuevo `OrderSheet`. El BLoC
   lo deduplica si es idéntico al optimista.

### Flujo principal — Carga inicial

1. El BLoC despacha `getTodayOrders`.
2. El repositorio: a. Lee `getOrderDocument` (1 read). b. Lee `getOrderRows` (P
   reads). c. Lee `_clientFirestore.getAll()` (C reads) → **cachea** resultado.
   d. Lee `_productFirestore.getAll()` (P reads) → **cachea** resultado.
3. Construye y devuelve el `OrderSheet` (ahora con IDs incluidos).
4. El BLoC inicia el listener Firestore.

### Flujo alternativo — Cambio estructural remoto

1. El listener detecta cambio en `clientIds` o `productIds`.
2. En `watchTodayOrders.asyncMap`, se detecta `idsChanged == true`.
3. Se llama `refreshMaps()` → invalida y recarga el caché de catálogos (C + P
   reads).
4. Se construye nuevo `OrderSheet` y se emite al BLoC.

### Flujo alternativo — Operaciones CRUD (add/remove)

1. El repositorio ejecuta la operación CRUD contra Firestore.
2. Para re-leer el estado, usa `_readOrderSheetWithoutSync` que ahora lee del
   **caché** para nombres/orden → solo lee doc + rows (no catálogos).
3. El listener también recibirá el cambio.

### Estados especiales / excepciones

- **Estado sin caché** (primera operación): Se carga automáticamente del
  datasource y se cachea.
- **Estado con caché stale** (admin cambió nombre de cliente en otra pantalla):
  El caché de nombres solo se invalida con cambios estructurales. Si un admin
  renombra un cliente sin cambiar la estructura del pedido, el nombre viejo se
  muestra hasta que se recargue la pantalla. Este es un tradeoff aceptable dado
  que los renombramientos son infrecuentes.
- **Error de lectura al refrescar caché**: El stream maneja errores con
  `handleError`, no se rompe la suscripción.

## 8) Edge cases

- **EC-01 — Caché y múltiples instancias del BLoC**: El caché vive en el
  repositorio (singleton en GetIt), por lo que es compartido si se recrease el
  BLoC. Esto es correcto: el caché refleja datos de Firestore que son globales.
- **EC-02 — Edición de celda con OrderSheet sin IDs**: Si por algún error el
  `OrderSheet` no tiene IDs (migración parcial), la traducción de índice a ID
  fallaría. Debe manejarse como error controlado.
- **EC-03 — updateCell tipo fire-and-forget**: Dado que `updateCell` ya no
  devuelve `OrderSheet`, si el write falla, el BLoC ya emitió el optimistic
  update. El listener no recibirá confirmación y el estado local quedará
  desincronizado. El BLoC debe manejar el fallo: loguear warning (ya lo hace) y
  confiar en que el siguiente evento del listener corregirá el estado.
- **EC-04 — Eliminación de `CheckModified` mientras hay timers activos**: No
  aplica — el timer de polling ya fue eliminado en la implementación anterior
  (paso 6).

## 9) Impacto funcional

- **Módulos afectados**:
  - `OrderSheet` (entidad de dominio) — se amplía con `clientIds` y
    `productIds`.
  - `OrdersTodayRepositoryImpl` — caché + cambio de firma de `updateCell`.
  - `OrdersTodayRepository` (contrato) — cambio de firma de `updateCell`.
  - `UpdateOrderCell` (use case) — cambio de parámetros.
  - `UpdateOrderCellParams` — de índices a IDs.
  - `OrdersTodayBloc` — traducción idx→ID + adaptación a nuevo retorno de
    `updateCell`.
  - `OrdersTodayEvent` — eliminación de `CheckModifiedRequested`.
- **Impacto en usuario**: Ninguno visible. Misma UX, misma latencia.
- **Impacto en costes**: Reducción de ~90% en reads Firestore diarios en esta
  pantalla.
- **Impacto en experiencia de usuario**: Potencial mejora de latencia en edición
  de celdas al eliminar las re-lecturas post-write (la respuesta al write será
  más rápida al no esperar a re-leer 50+ documentos).

## 10) Suposiciones

- **S-01**: Los catálogos de clientes y productos cambian con baja frecuencia
  durante una sesión de trabajo en la pantalla de pedidos (minutos a horas, no
  segundos).
- **S-02**: Aceptamos como tradeoff que un renombramiento de cliente/producto no
  se refleje inmediatamente si no hay cambio estructural en el pedido. El
  usuario puede recargar la pantalla para forzar la actualización.
- **S-03**: El `OrderSheet` puede extenderse con `clientIds` y `productIds` sin
  romper el contrato `Equatable` ni la lógica de deduplicación del listener (los
  IDs son deterministas dada la misma estructura).
- **S-04**: La eliminación del return `OrderSheet` en `updateCell` no afecta a
  ningún consumidor fuera de `OrdersTodayBloc` (el use case solo se usa desde
  ahí).

## 11) Preguntas abiertas

- **PA-01**: ¿Se debería invalidar el caché de catálogos también cuando el
  usuario navega a la pantalla de gestión de clientes/productos y vuelve a
  pedidos? Esto cubriría el caso de renombramiento. **Supuesto adoptado**: No,
  aceptamos stale names hasta recarga o cambio estructural.

## 12) Notas para análisis técnico

- El cambio de firma de `updateCell` (de índices a IDs) implica modificaciones
  en: contrato del repositorio, implementación, use case, params y BLoC. Es un
  cambio transversal a las capas pero contenido en la feature `orders_today`.
- Para OPT-3, el `OrderSheet` necesita exponer `clientIds` y `productIds`. Dos
  opciones:
  - Añadir campos `clientIds` y `productIds` a `OrderSheet` (más directo).
  - Crear un mapa de lookup en el BLoC a partir de las listas de nombres (frágil
    si hay nombres duplicados).
  - **Recomendación funcional**: añadir los IDs a la entidad.
- El caché (OPT-1) debe vivir en la capa de repositorio, no en el datasource,
  porque el repositorio es quien combina datos de múltiples datasources.
- OPT-2 cambia el tipo de retorno de `updateCell` de
  `Either<Failure, OrderSheet>` a `Either<Failure, Unit>`. Esto impacta el
  contrato del repositorio y del use case.
- OPT-4 es la más simple: eliminar evento + handler + handler registration.
  Limpieza directa.
- Dependencias visibles: OPT-2 y OPT-3 están acopladas — si `updateCell` ya no
  re-lee, tampoco necesita devolver `OrderSheet`, y si no necesita traducir IDs
  ya no necesita leer catálogos. Implementarlas juntas es más coherente.
- **Estado: Listo para análisis técnico**
