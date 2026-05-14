# Functional Analysis: Migración de sincronización en tiempo real de RTDB a Firestore listeners

- **Fecha:** 2026-05-09
- **Identificador:** orders-realtime-firestore-listeners
- **Estado:** Ready for technical analysis

## 1) Resumen

Reemplazar Firebase Realtime Database (RTDB) como mecanismo de broadcast de
cambios de celdas y estructura (clientes/productos) entre usuarios simultáneos,
sustituyéndolo por listeners nativos de Firestore (`snapshots()`). RTDB se
mantiene exclusivamente para presencia colaborativa (cursores y locks de celda).

## 2) Contexto y objetivo

### Qué se solicita

Actualmente la sincronización en tiempo real de la pantalla "Pedidos de hoy"
opera con una arquitectura dual:

- **Firestore** es la fuente de verdad para persistencia (documentos
  `orders/{YYYY-MM-DD}` y subcollección `rows/{productId}`).
- **RTDB** actúa como canal de broadcast para que otros usuarios conectados vean
  cambios de valores de celdas en tiempo real (nodo `today/cells/`), además de
  gestionar cursores (`today/cursors/`) y locks de edición (`today/locks/`).

Se solicita eliminar el uso de RTDB para el broadcast de datos de celdas y
reemplazarlo por listeners de Firestore, que ya contiene los datos
autoritativos. RTDB se conserva únicamente para los datos de presencia (cursores
y locks).

### Qué problema resuelve

- **Dual-write inconsistente**: cada edición de celda escribe a RTDB
  (fire-and-forget) y a Firestore (debounced). Si una escritura falla y la otra
  no, los datos divergen entre usuarios.
- **Cambios estructurales invisibles**: cuando un usuario añade o elimina
  clientes/productos, los demás usuarios NO ven el cambio hasta que refrescan
  manualmente. RTDB solo transmite valores de celdas, no modificaciones en
  `clientIds[]`/`productIds[]`.
- **Complejidad innecesaria**: mantener dos fuentes de datos sincronizadas (RTDB
  cells + Firestore docs) añade código, DTOs, eventos y lógica de reconciliación
  que se pueden eliminar.
- **Coste**: RTDB cobra por conexiones simultáneas y GB almacenados. Reducir su
  uso a solo cursores/locks minimiza costes.

### Qué resultado funcional se espera

- Todos los usuarios conectados a la pantalla "Pedidos de hoy" ven cambios de
  celdas (cantidades, stocks) realizados por otros usuarios en tiempo real
  (latencia aceptable ≤ 1 segundo).
- Todos los usuarios ven cambios estructurales (clientes o productos
  añadidos/eliminados) realizados por otros usuarios en tiempo real, sin
  necesidad de refrescar manualmente.
- La funcionalidad de presencia colaborativa (cursores de otros usuarios, locks
  de celdas en edición) sigue funcionando sin cambios.
- El operador que edita sigue viendo su cambio de forma inmediata (optimistic
  update local), independientemente de la latencia de Firestore.

## 3) Alcance

### En alcance

- **Sincronización de valores de celdas** (cantidades y stocks) entre usuarios
  simultáneos mediante Firestore listeners en lugar de RTDB `cells/`.
- **Sincronización de cambios estructurales** (añadir/quitar clientes o
  productos) entre usuarios simultáneos mediante Firestore listeners en el
  documento raíz `orders/{YYYY-MM-DD}`.
- **Eliminación del nodo `today/cells/`** de RTDB y todo el código asociado
  (writeCell, onCellChanged, getAllCells, CellDelta DTO, RemoteCellReceived
  event, suscripción RTDB para celdas).
- **Simplificación del `resetToday`** de RTDB: ya no necesita limpiar el nodo
  `cells/`.
- **Mantenimiento de cursores y locks en RTDB** (`today/cursors/` y
  `today/locks/`): sin cambios funcionales.

### Fuera de alcance

- **Cambios en la UI**: la interfaz de usuario no se modifica. Solo cambia el
  canal de sincronización subyacente.
- **Cambios en el modelo de datos de Firestore**: la estructura de documentos
  (`orders/{date}`, `rows/{productId}`) no se modifica.
- **Cambios en la creación de pedidos**: el flujo de "Crear pedido de hoy" no se
  modifica.
- **Gestión offline**: la app opera en modo online exclusivamente; no se
  requiere sincronización offline.
- **Feature de histórico de pedidos** (`orders_history`): no se ve afectada.
- **Security rules de Firestore o RTDB**: no se modifican en este cambio.
- **Migración de PresenceCubit o lógica de locks/cursores**: se mantienen tal
  cual están, usando RTDB.

## 4) Actores implicados

| Actor                     | Rol                                                                               |
| ------------------------- | --------------------------------------------------------------------------------- |
| **Operador A**            | Usuario que realiza un cambio (edita celda, añade/quita cliente o producto)       |
| **Operador B..N**         | Usuarios simultáneos que deben ver los cambios de A en tiempo real                |
| **Sistema (app Flutter)** | Gestiona los listeners de Firestore, aplica optimistic updates y reconcilia datos |
| **Firestore**             | Fuente de verdad y canal de broadcast para datos de pedidos                       |
| **RTDB**                  | Canal de presencia para cursores y locks de edición (sin cambios)                 |

## 5) Requisitos funcionales

- **RF-01**: Cuando un operador modifica una celda de cantidad o stock, los
  demás operadores conectados a la misma pantalla deben ver el cambio reflejado
  en su tabla sin acción manual (latencia aceptable ≤ 1 segundo).

- **RF-02**: Cuando un operador añade uno o más clientes al pedido del día, los
  demás operadores deben ver las nuevas columnas aparecer en su tabla sin acción
  manual.

- **RF-03**: Cuando un operador elimina uno o más clientes del pedido del día,
  los demás operadores deben ver las columnas eliminadas desaparecer de su tabla
  sin acción manual.

- **RF-04**: Cuando un operador añade uno o más productos al pedido del día, los
  demás operadores deben ver las nuevas filas aparecer en su tabla sin acción
  manual.

- **RF-05**: Cuando un operador elimina uno o más productos del pedido del día,
  los demás operadores deben ver las filas eliminadas desaparecer de su tabla
  sin acción manual.

- **RF-06**: El operador que realiza el cambio debe seguir viendo su
  modificación de forma instantánea mediante optimistic update local, sin
  esperar confirmación de Firestore.

- **RF-07**: La sincronización de datos entre usuarios debe usar exclusivamente
  Firestore listeners (no RTDB) para valores de celdas y estructura del pedido.

- **RF-08**: La funcionalidad de cursores remotos (ver la posición de otros
  usuarios en la tabla) debe seguir funcionando mediante RTDB sin cambios.

- **RF-09**: La funcionalidad de locks de celda (bloquear edición cuando otro
  usuario está editando una celda) debe seguir funcionando mediante RTDB sin
  cambios.

- **RF-10**: Si el propio usuario genera un cambio que activa el listener de
  Firestore, el sistema no debe aplicar el cambio de nuevo (ya fue aplicado
  optimísticamente). No debe haber parpadeos ni re-renders innecesarios.

- **RF-11**: Si se producen múltiples cambios rápidos (ej: un usuario añade 3
  clientes en rápida sucesión), la UI de otros usuarios no debe reconstruirse 3
  veces individualmente; se debe agrupar/debouncer los eventos del listener para
  evitar reconstrucciones innecesarias.

- **RF-12**: El nodo `today/cells/` de RTDB deja de utilizarse. No se escribe ni
  se lee de él.

- **RF-13**: Los productos y clientes en la tabla deben mostrarse ordenados por
  su campo `order` de la entidad original, independientemente del orden en que
  estén almacenados en el array de Firestore.

## 6) Criterios de aceptación

- **CA-01**: El Operador A edita la celda de cantidad del producto "Pan" para el
  cliente "Bar Sol" cambiándola a 5. El Operador B, conectado simultáneamente,
  ve el valor 5 en esa celda en menos de 1 segundo sin refrescar.

- **CA-02**: El Operador A añade el cliente "Restaurante Luna" al pedido. El
  Operador B ve una nueva columna "Restaurante Luna" aparecer en su tabla sin
  refrescar, en la posición correspondiente a su campo `order`.

- **CA-03**: El Operador A elimina el producto "Croissant" del pedido. El
  Operador B ve la fila "Croissant" desaparecer de su tabla sin refrescar.

- **CA-04**: El Operador A modifica el stock de "Pan" a 100. El Operador B ve el
  stock actualizado y QUEDAN recalculado correctamente en menos de 1 segundo.

- **CA-05**: El Operador A edita una celda. Su tabla se actualiza
  instantáneamente (optimistic update). No se produce un segundo re-render
  cuando el listener de Firestore notifica el mismo cambio.

- **CA-06**: No se realizan escrituras ni lecturas al nodo `today/cells/` de
  RTDB para ninguna operación de datos.

- **CA-07**: Los cursores de otros usuarios siguen apareciendo correctamente en
  la tabla, indicando la celda que están editando. El sistema de locks sigue
  impidiendo la edición simultánea de la misma celda.

- **CA-08**: Si el Operador A añade 3 clientes rápidamente, el Operador B no
  experimenta 3 reconstrucciones consecutivas de la tabla; los cambios se
  agrupan en una sola actualización visual.

- **CA-09**: Tras la migración, la tabla sigue mostrando clientes (columnas) y
  productos (filas) ordenados por su campo `order`.

- **CA-10**: Si Firestore deja de estar disponible temporalmente, el operador ve
  un error apropiado. Los datos ya mostrados en la tabla se mantienen visibles
  (no se pierden por desconexión momentánea).

## 7) Flujos y comportamiento esperado

### Flujo principal — Edición de celda con sincronización

1. El Operador A abre "Pedidos de hoy". El sistema establece un listener
   Firestore sobre `orders/{fecha}` (doc raíz) y `orders/{fecha}/rows`
   (subcollección).
2. El Operador B abre la misma pantalla. Se establece su propio listener.
3. El Operador A toca una celda de cantidad y la cambia a 5.
4. La app de A aplica optimistic update → la UI muestra 5 inmediatamente.
5. La app de A escribe el valor en Firestore (debounced o directo).
6. Firestore notifica al listener de B → B reconstruye su OrderSheet → la UI de
   B muestra 5 en esa celda.
7. Firestore también notifica al listener de A → A detecta que el valor ya está
   aplicado (optimistic) → no re-renderiza.

### Flujo alternativo — Añadir cliente con sincronización

1. El Operador A pulsa "Añadir cliente" → selecciona "Restaurante Luna" →
   confirma.
2. La app de A escribe en Firestore: añade el ID a `clientIds[]` del doc raíz.
3. La app de A re-lee y muestra la tabla actualizada con la nueva columna.
4. Firestore notifica al listener del doc raíz de B → B detecta que `clientIds`
   cambió → reconstruye OrderSheet con la nueva columna → UI de B se actualiza.

### Flujo alternativo — Eliminar producto con sincronización

1. El Operador A selecciona la fila "Croissant" → pulsa eliminar → confirma.
2. La app de A escribe en Firestore: elimina el ID de `productIds[]` y borra el
   subdocumento `rows/croissant_id`.
3. La app de A re-lee y muestra la tabla sin esa fila.
4. Firestore notifica al listener de B (cambio en doc raíz + eliminación en
   rows) → B reconstruye OrderSheet sin esa fila → UI de B se actualiza.

### Flujo alternativo — Edición concurrente de la misma celda

1. Operador A empieza a editar la celda (3,2). Se adquiere un lock en RTDB.
2. Operador B intenta editar la misma celda. RTDB informa que hay lock activo →
   B recibe un mensaje de que la celda está bloqueada.
3. A termina de editar → se libera el lock en RTDB → se escribe el valor en
   Firestore.
4. B ve el nuevo valor vía Firestore listener. Ya puede editar esa celda.

### Estados especiales / excepciones

- **Estado vacío**: no aplica a este cambio; el flujo de "No hay pedidos para
  hoy" no cambia.
- **Estado loading**: cuando se establece el listener por primera vez, se
  muestra el estado de carga actual hasta recibir el primer snapshot.
- **Estado error**: si Firestore falla al establecer el listener o deja de
  responder, se muestra un error. Los datos ya en memoria se mantienen
  visualmente (graceful degradation).
- **Sin permisos**: si las security rules deniegan acceso, se trata como error
  de Firestore (mismo tratamiento que actualmente).
- **Desconexión del listener**: si la conexión se pierde temporalmente,
  Firestore reconecta automáticamente y envía los cambios acumulados.

## 8) Edge cases

- **EC-01**: Dos operadores editan celdas distintas del mismo producto (misma
  fila) simultáneamente. Ambas escrituras deben coexistir correctamente en el
  mapa `quantities` de ese producto. Firestore resuelve esto con field-level
  updates.

- **EC-02**: Un operador elimina un cliente mientras otro operador está editando
  una celda de ese cliente. El operador que edita verá la columna desaparecer
  tras el cambio estructural; cualquier escritura pendiente a esa celda fallará
  silenciosamente (el campo ya no existe).

- **EC-03**: Un operador añade un producto y otro operador elimina un producto
  simultáneamente. Ambas operaciones son independientes a nivel Firestore
  (documentos distintos en `rows/`). El listener recibe ambos cambios y la tabla
  se reconstruye con el estado correcto.

- **EC-04**: El listener de Firestore recibe un snapshot con
  `metadata.
  hasPendingWrites == true` (escritura local aún no confirmada por
  el servidor). El sistema debe poder usar este dato para evitar re-renders de
  cambios propios aún no confirmados.

- **EC-05**: Un operador cierra la pantalla y la reabre. El listener se
  re-establece y carga el estado actual completo desde Firestore (snapshot
  inicial).

- **EC-06**: Se produce un cambio estructural (ej: se quita un cliente) y al
  mismo tiempo llega un cambio de celda de otro usuario. Ambos cambios pueden
  llegar como snapshots separados. El sistema debe reconstruir la tabla de forma
  consistente independientemente del orden de llegada.

- **EC-07**: El Operador A tiene productos/clientes seleccionados (para
  eliminar) y el Operador B elimina uno de los mismos. Cuando A recibe la
  actualización vía listener, sus índices de selección pueden ser inválidos. El
  sistema debe limpiar las selecciones cuando la estructura cambia.

## 9) Impacto funcional

- **Módulos afectados**:
  - `orders_today`: datasource RTDB (parcialmente), repositorio, BLoC, eventos,
    suscripciones.
  - `orders_today` presencia: NO afectado (se mantiene en RTDB).
  - `orders_history`: NO afectado.

- **Impacto en usuario**:
  - **Positivo**: los cambios de otros usuarios (tanto de celdas como
    estructurales) ahora se ven en tiempo real sin refrescar.
  - **Neutro a leve**: la latencia de cambios de celdas podría ser ligeramente
    mayor que con RTDB (~300-500ms vs ~100ms), pero dentro del rango aceptable
    para una tabla de pedidos.

- **Impacto en experiencia de usuario**:
  - Mejora significativa: elimina la situación actual donde un usuario añade un
    cliente y otro usuario no lo ve hasta refrescar.
  - El optimistic update local garantiza que el operador que edita no nota
    ninguna diferencia.

## 10) Suposiciones

- La latencia de Firestore snapshots (200-500ms) es aceptable para la operativa
  de pedidos diarios. No se trata de un editor colaborativo de texto donde cada
  milisegundo importa.
- Los operadores simultáneos son típicamente 2-5 personas. No se esperan decenas
  de listeners concurrentes en el mismo documento.
- Firestore soporta listeners concurrentes sobre el mismo documento/
  subcollección sin problemas de rendimiento para este volumen.
- La estructura actual de Firestore (`orders/{date}/rows/{productId}`) es
  suficientemente granular para que los snapshots de subcollección notifiquen
  solo el documento que cambió, no todos.
- El campo `order` de clientes y productos ya está correctamente asignado en
  Firestore para todos los registros activos.

## 11) Preguntas abiertas

- Ninguna. Todas las preguntas han sido resueltas.

### Decisiones confirmadas

- **PA-01**: Se mantiene el debounce de 500ms para escrituras a Firestore.
- **PA-02**: Sí, se limpian automáticamente las selecciones del usuario local
  cuando llega un cambio estructural remoto vía listener.

## 12) Notas para análisis técnico

- **Listener dual**: se necesitan dos listeners de Firestore:
  1. `orders/{date}` (documento raíz) → detecta cambios en `clientIds[]` y
     `productIds[]`.
  2. `orders/{date}/rows` (subcollección) → detecta cambios en quantities y
     stock. Valorar si se combinan con `combineLatest` o se procesan
     independientemente.

- **Detección de cambios propios**: usar `SnapshotMetadata.hasPendingWrites` de
  Firestore y/o comparación con el estado optimístico local para evitar
  re-renders del propio usuario.

- **Debounce del stream**: considerar un buffer temporal (~200ms) en el listener
  combinado para agrupar múltiples cambios rápidos en una sola reconstrucción.

- **Ciclo de vida del listener**: el listener debe crearse al entrar en la
  pantalla (o al cargar el pedido) y cancelarse al salir. Considerar su relación
  con el BLoC lifecycle.

- **Código eliminable de RTDB**: `writeCell`, `onCellChanged`, `getAllCells`,
  `CellDelta` DTO, `RemoteCellReceived` event, la parte de `cells/` en
  `resetToday`, y la suscripción RTDB de celdas en el BLoC.

- **Reconciliación de índices**: cuando llega un cambio estructural vía
  listener, los índices de selección, edición y cursor del usuario local pueden
  quedar invalidados. Hay que gestionar esta reconciliación.

- **Ordenación consistente**: la reconstrucción del `OrderSheet` desde el
  snapshot debe aplicar la misma ordenación por campo `order` que ya existe en
  `_buildOrderSheet`.

- **Dependencia existente**: el `_buildOrderSheet` actual ya necesita los order
  maps de clientes y productos. Para el listener, estos datos deben estar
  disponibles (cachearlos al iniciar o re-leerlos cuando cambia la estructura).

- **Estado: Listo para análisis técnico**
