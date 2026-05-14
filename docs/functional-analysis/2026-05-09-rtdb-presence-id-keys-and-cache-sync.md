# Functional Analysis: Migración de presencia RTDB a claves por ID e invalidación reactiva de caché

- **Fecha:** 2026-05-09
- **Identificador:** rtdb-presence-id-keys-and-cache-sync
- **Estado:** Ready for technical analysis

## 1) Resumen

Actualmente el sistema de presencia colaborativa (locks y cursors en RTDB) usa
**índices posicionales** (`row_col`, `stock_row`, `{r, c}`) para identificar
celdas. Cualquier operación que modifique la estructura de la tabla —añadir,
eliminar o reordenar clientes/productos— invalida esas posiciones, provocando
que los locks protejan la celda incorrecta y los cursors se muestren en la
posición equivocada.

Además, el caché in-memory de catálogos (`_cachedClients`, `_cachedProducts`)
del repositorio de pedidos del día no se invalida cuando otro módulo (pantalla
de clientes/productos) modifica los datos del catálogo, lo que puede causar
**escrituras en Firestore dirigidas al producto/cliente incorrecto**.

Esta especificación cubre:

- Migrar locks y cursors de claves posicionales a claves basadas en IDs de
  entidad.
- Suscribir el repositorio de pedidos del día a cambios en las colecciones
  Firestore de clientes y productos para invalidar el caché de forma reactiva.

## 2) Contexto y objetivo

### Qué se solicita

1. **Locks y cursors basados en IDs**: Reemplazar las claves posicionales
   (`"3_2"`, `"stock_1"`, `{r:3, c:2}`) por claves semánticas basadas en los IDs
   de entidad de Firestore (`"prodABC_cliXYZ"`, `"stock_prodABC"`,
   `{productId, clientId}`).
2. **Invalidación reactiva del caché de catálogos**: Escuchar los streams
   `watchAll()` de los datasources de clientes y productos para invalidar
   `_cachedClients` / `_cachedProducts` cuando haya cambios en esas colecciones.

### Qué problema resuelve

| Problema | Descripción                                                                                                                 | Gravedad   |
| -------- | --------------------------------------------------------------------------------------------------------------------------- | ---------- |
| P1       | Eliminar un cliente/producto desplaza los índices → locks y cursors apuntan a la celda incorrecta                           | Media-Alta |
| P2       | Cambiar el orden de productos/clientes → misma inconsistencia posicional                                                    | Media      |
| P3       | Añadir un cliente/producto inserta un elemento → los índices posteriores se desplazan                                       | Media      |
| P5       | Caché stale tras cambio de orden/nombre → el BLoC traduce `productRow` a un ID incorrecto → escritura corrupta en Firestore | **Alta**   |

### Resultado funcional esperado

- Los locks y cursors identifican celdas de forma estable independientemente del
  orden o la cantidad de filas/columnas.
- El caché de catálogos siempre refleja el estado actual de Firestore, evitando
  traducciones de índice a ID incorrectas.

## 3) Alcance

### En alcance

- Redefinir el formato de claves de locks en RTDB: de `"row_col"` /
  `"stock_row"` a `"productId_clientId"` / `"stock_productId"`.
- Redefinir el formato de cursors en RTDB: de `{r: int, c: int}` a
  `{productId: String, clientId: String?}`.
- Actualizar DTOs (`CursorInfo`, `LockInfo`), entidades de dominio (`CellLock`,
  `RemoteCursor`), utilidades (`cell_key_utils.dart`) y `OrdersPresenceCubit`
  para operar con claves por ID.
- Actualizar `orders_table.dart` para construir las claves a partir de los IDs
  disponibles en `OrderSheet.clientIds` / `OrderSheet.productIds` y traducir de
  vuelta a posiciones visuales al renderizar cursors/locks remotos.
- Suscribir `OrdersTodayRepositoryImpl` a los streams `watchAll()` de
  `ClientFirestoreDataSource` y `ProductFirestoreDataSource` para invalidar el
  caché cuando se detecten cambios.
- Limpiar locks y cursors huérfanos cuando se detecte que un ID ya no pertenece
  al sheet actual (por eliminación de cliente/producto).

### Fuera de alcance

- Problema 4 (`resetToday` no invocado) — será abordado por separado.
- Migración de datos existentes en RTDB — los datos de presencia son efímeros
  (TTL 60s en locks; cursors se eliminan al desconectar). No requieren
  migración.
- Cambios en la pantalla de gestión de clientes/productos.
- Cambios en `orders_history` u otros módulos.

## 4) Actores implicados

| Actor                        | Rol                                                                                                                                                                      |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Usuario A                    | Edita la tabla de pedidos del día (tiene locks/cursors activos)                                                                                                          |
| Usuario B                    | Modifica la estructura de la tabla (añade/elimina/reordena clientes o productos) desde la misma pantalla de pedidos o desde la pantalla de gestión de clientes/productos |
| Sistema (Firestore listener) | Propaga cambios de estructura a todos los clientes conectados                                                                                                            |
| Sistema (RTDB listener)      | Propaga cambios de presencia entre usuarios                                                                                                                              |

## 5) Requisitos funcionales

### Bloque A — Locks basados en IDs

- **RF-01**: El sistema debe generar claves de lock con el formato
  `"{productId}_{clientId}"` para celdas de cantidad y `"stock_{productId}"`
  para celdas de stock.
- **RF-02**: Al intentar adquirir un lock, el sistema debe usar la clave basada
  en IDs, no en índices posicionales.
- **RF-03**: Al liberar un lock, el sistema debe usar la misma clave basada en
  IDs con la que lo adquirió.
- **RF-04**: Al recibir un evento de lock remoto desde RTDB, el sistema debe
  traducir `productId`/`clientId` a la posición visual actual para determinar
  qué celda está bloqueada.
- **RF-05**: Si un lock hace referencia a un `productId` o `clientId` que ya no
  existe en el sheet actual, el lock debe ignorarse visualmente (no mostrar
  indicador de bloqueo).

### Bloque B — Cursors basados en IDs

- **RF-06**: El sistema debe almacenar la posición del cursor en RTDB con
  `{productId: String, clientId: String?}` en lugar de `{r: int, c: int}`.
  `clientId = null` indica que el cursor está en la columna de stocks.
- **RF-07**: Al renderizar cursors remotos, el sistema debe traducir
  `productId`/`clientId` a las coordenadas (row, col) visuales actuales.
- **RF-08**: Si un cursor remoto hace referencia a un ID que ya no existe en el
  sheet, el cursor debe ocultarse (no renderizar en posición inválida).

### Bloque C — Invalidación reactiva del caché de catálogos

- **RF-09**: El repositorio de pedidos del día debe suscribirse a los streams de
  cambios de las colecciones `clients` y `products` de Firestore.
- **RF-10**: Cuando el stream de clientes o productos emita una actualización,
  el sistema debe invalidar el caché correspondiente (`_cachedClients` /
  `_cachedProducts`) de forma inmediata.
- **RF-11**: La suscripción debe iniciarse al crear el repositorio y cancelarse
  al disponer los recursos (`dispose`).
- **RF-12**: La invalidación del caché no debe forzar una recarga inmediata; la
  siguiente operación que consulte el caché disparará la recarga (estrategia
  lazy).

### Bloque D — Limpieza de presencia huérfana

- **RF-13**: Cuando el listener de Firestore detecte que un `clientId` o
  `productId` ha sido eliminado del sheet, el sistema debe liberar cualquier
  lock local que haga referencia a ese ID.

## 6) Criterios de aceptación

- **CA-01**: Dado un usuario A editando la celda del producto P1/cliente C2,
  cuando el usuario B elimina el cliente C1 (que estaba antes de C2), entonces
  el lock de A sigue protegiendo la celda P1/C2 (no se desplaza a otra celda).
- **CA-02**: Dado un usuario A con un cursor en P3/C1, cuando otro usuario
  cambia el orden del producto P3 de posición 3 a posición 1, entonces el cursor
  remoto de A se mueve visualmente a la fila correcta (donde ahora está P3), no
  permanece fijo en la fila 3.
- **CA-03**: Dado un usuario A con un lock en P2/C3, cuando P2 es eliminado del
  sheet, entonces el lock se libera automáticamente y no se muestra indicador de
  bloqueo en ninguna celda.
- **CA-04**: Dado un usuario que modifica el orden de un producto desde la
  pantalla de productos, cuando vuelve a la tabla de pedidos y edita una celda,
  entonces la escritura se dirige al producto correcto (no al que ocupaba esa
  posición antes del cambio de orden).
- **CA-05**: Dado un usuario que añade un nuevo cliente al sheet, los locks y
  cursors de otros usuarios no se desplazan y siguen apuntando a las mismas
  entidades.
- **CA-06**: Dado que el repositorio está suscrito a `watchAll()` de clientes,
  cuando se modifica el nombre o el orden de un cliente en Firestore, el caché
  se invalida y la siguiente consulta devuelve los datos actualizados.
- **CA-07**: Los streams de `watchAll()` se cancelan correctamente al cerrar el
  repositorio (no memory leaks).

## 7) Flujos y comportamiento esperado

### Flujo principal — Edición con presencia basada en IDs

1. Usuario abre la tabla de pedidos del día.
2. `OrderSheet` contiene `clientIds` y `productIds` (ya implementado).
3. Usuario toca una celda del producto `prodABC` / cliente `cliXYZ`.
4. La UI genera la clave `"prodABC_cliXYZ"`.
5. `OrdersPresenceCubit` solicita `acquireLock("prodABC_cliXYZ")` en RTDB.
6. Si adquirido, almacena la clave y registra el cursor como
   `{productId: "prodABC", clientId: "cliXYZ"}`.
7. Otros usuarios reciben el evento de lock/cursor, traducen `prodABC`/`cliXYZ`
   a coordenadas visuales y renderizan el indicador.
8. Al terminar la edición, se llama `releaseLock("prodABC_cliXYZ")`.

### Flujo alternativo — Eliminación de entidad con lock activo

1. Usuario B elimina el cliente `cliXYZ` del sheet.
2. Firestore listener emite un `OrderSheet` sin `cliXYZ` en `clientIds`.
3. La UI detecta que el `_lockedCellKey` actual hace referencia a un `clientId`
   que ya no existe.
4. Libera el lock automáticamente y sale silenciosamente del modo edición (sin
   feedback visual).
5. Los cursors remotos que referencien `cliXYZ` se ocultan.

### Flujo alternativo — Cambio de orden con caché

1. Usuario modifica el orden de productos en la pantalla de productos.
2. El datasource de productos escribe en Firestore.
3. El stream `watchAll()` de productos emite.
4. El repositorio de pedidos del día recibe la emisión →
   `_cachedProducts = null`.
5. La siguiente operación (ej: `_getProducts()`) recarga desde Firestore con los
   datos actualizados.
6. `_sortIdsByOrder` produce el orden correcto → la traducción idx→ID es
   correcta.

### Estados especiales / excepciones

- **Estado vacío**: No hay locks ni cursors → sin impacto.
- **Estado loading/procesando**: Durante la recarga del caché, las operaciones
  de escritura esperan la resolución del `Future` de `_getClients()` /
  `_getProducts()` (el `??=` del lazy cache garantiza esto).
- **Estado error**: Si el stream de `watchAll()` emite error, se loguea y el
  caché permanece (no se invalida por error, se invalida por dato nuevo).
- **Desconexión RTDB**: `onDisconnect` ya limpia cursors; locks expiran en 60s —
  sin cambio.

## 8) Edge cases

- **EC-01**: Dos usuarios intentan hacer lock del mismo `productId_clientId`
  simultáneamente → la transacción atómica de RTDB ya resuelve esto (sin cambio
  necesario).
- **EC-02**: Un usuario navega rápidamente entre celdas (Tab) generando varios
  `acquireLock`/`releaseLock` en sucesión → el flujo actual con
  `_releaseLockIfNeeded()` sigue aplicando (solo cambia el formato de la clave).
- **EC-03**: El sheet está vacío (0 productos o 0 clientes) → no hay celdas
  editables, no se generan locks ni cursors.
- **EC-04**: Un lock referencia un `productId` válido pero un `clientId` que fue
  eliminado → se trata como huérfano (RF-05/RF-13).
- **EC-05**: El stream de `watchAll()` emite el mismo snapshot dos veces
  consecutivas → la invalidación es idempotente (`= null` repetido no causa
  daño).
- **EC-06**: El caché se invalida justo mientras una escritura está en curso
  (race condition) → la escritura ya tiene los IDs resueltos (se obtuvieron
  antes de invalidar), por lo que la escritura en Firestore es correcta. La
  siguiente operación recargará el caché actualizado.
- **EC-07**: `watchAll()` emite antes de que exista un `OrderSheet` activo → la
  invalidación ocurre pero no hay operaciones pendientes; sin impacto.

## 9) Impacto funcional

- **Módulos afectados**:
  - `orders_today` — Locks, cursors, caché, repositorio, presencia cubit, tabla
    UI.
  - Los datasources de `clients` y `products` ya exponen `watchAll()` — no
    requieren cambios.
- **Impacto en usuario**: Los usuarios que editan colaborativamente verán locks
  y cursors estables ante cambios de estructura. Se elimina el riesgo de
  escritura corrupta por caché stale.
- **Impacto en experiencia de usuario**: Ningún cambio visible en el flujo
  normal. Los indicadores de presencia seguirán apareciendo en el mismo lugar
  visual, pero ahora se moverán correctamente cuando la tabla se reestructure.

## 10) Suposiciones

- Los IDs de Firestore de productos y clientes no contienen el carácter `_`
  (underscore). Confirmado por el usuario — el separador `_` es seguro.
- Los datos de presencia en RTDB son efímeros y no requieren migración: los
  locks expiran en 60s y los cursors se limpian al desconectar.
- El `OrderSheet` ya contiene `clientIds` y `productIds` ordenados (implementado
  en la optimización anterior).
- Los datasources `ClientFirestoreDataSource.watchAll()` y
  `ProductFirestoreDataSource.watchAll()` están implementados y funcionan
  correctamente.

## 11) Preguntas abiertas

Todas resueltas:

- ~~**PA-01**~~: Los IDs de Firestore no contienen `_`. El separador `_` es
  seguro para las claves de lock.
- ~~**PA-02**~~: Basta con salir silenciosamente del modo edición. No se
  requiere feedback visual (snackbar) cuando un lock se libera por eliminación
  de la entidad.

## 12) Notas para análisis técnico

- **Restricciones funcionales**: Las claves de lock deben ser válidas como child
  keys de Firebase RTDB (no pueden contener `.`, `$`, `#`, `[`, `]`, `/`). Los
  IDs de Firestore son alfanuméricos de 20 caracteres y no contienen `_`, por lo
  que `_` como separador es seguro (PA-01 confirmada).
- **Dependencias visibles**:
  - `OrderSheet.clientIds` / `OrderSheet.productIds` (ya implementado).
  - `ClientFirestoreDataSource.watchAll()` /
    `ProductFirestoreDataSource.watchAll()` (ya implementado).
  - `OrdersRtdbDataSource` — interfaz y implementación a modificar.
  - `OrdersPresenceCubit` — lógica de traducción ID↔posición.
  - `OrdersTodayRepositoryImpl` — nuevas suscripciones + disposable.
- **Consideraciones relevantes**:
  - El repositorio actualmente no tiene un método `dispose()`. Será necesario
    añadirlo para cancelar las suscripciones a los streams de catálogo.
  - La invalidación del caché es **lazy**: solo se anula la referencia cacheada;
    la recarga ocurre en la siguiente llamada a `_getClients()` /
    `_getProducts()`.
  - El cambio en formato de claves RTDB es una ruptura con el formato anterior,
    pero dado que los datos son efímeros no requiere migración.
- **Estado: Listo para análisis técnico**
