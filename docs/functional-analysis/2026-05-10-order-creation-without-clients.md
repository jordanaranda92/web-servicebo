# Functional Analysis: Creación de pedido de hoy sin clientes precargados

- **Fecha:** 2026-05-10
- **Identificador:** order-creation-without-clients
- **Estado:** Ready for technical analysis

## 1) Resumen

Modificar la creación del pedido de hoy en Firestore para que se genere
únicamente con los productos activos y **sin ningún cliente**. Las columnas de
clientes no deben aparecer en la tabla hasta que se añadan manualmente conforme
se reciban pedidos.

## 2) Contexto y objetivo

### Qué se solicita

Actualmente, al crear el pedido de hoy (`createTodaySheet`), el sistema:

1. Lee todos los **clientes activos** y todos los **productos activos**.
2. Crea el documento `orders/{YYYY-MM-DD}` con ambos listados (`clientIds`,
   `productIds`).
3. Crea subdocumentos `rows/{productId}` con un mapa vacío de `quantities`.
4. La tabla resultante muestra inmediatamente columnas para cada cliente activo,
   con cantidades en cero.

Se solicita que la creación del pedido **no incluya clientes**. El documento
Firestore debe crearse con `clientIds: []` y la tabla debe mostrarse únicamente
con productos (filas), las columnas fijas (PEDIDOS, STOCKS, QUEDAN) y **sin
columnas de clientes**. Los clientes se irán incorporando de forma incremental,
mediante la funcionalidad existente de "Añadir clientes" (`addClients`), a
medida que se reciban los pedidos.

### Qué problema resuelve

- **Ruido en la tabla**: precargar todos los clientes activos genera una tabla
  ancha con columnas en cero que no aportan valor hasta que llegan pedidos
  reales.
- **Alineación con flujo real**: en la operativa diaria, los pedidos se reciben
  progresivamente; la tabla debe reflejar solo los clientes que efectivamente
  han realizado un pedido.
- **Simplificación de la creación**: se reduce la operación de creación al
  mínimo necesario (solo productos), delegando la gestión de clientes al flujo
  incremental.

### Qué resultado funcional se espera

Al pulsar "Crear pedido de hoy", la tabla se muestra con filas de productos y
columnas fijas (PEDIDOS, STOCKS, QUEDAN) pero sin ninguna columna de cliente.
Los clientes se añaden individualmente a partir de ese momento.

## 3) Alcance

### En alcance

- Modificar la lógica de creación del pedido de hoy para que no incluya
  clientes.
- Asegurar que la tabla se renderice correctamente sin columnas de clientes
  (estado con 0 clientes).
- Mantener la funcionalidad existente de "Añadir clientes" como mecanismo para
  incorporar clientes al pedido.
- Asegurar que PEDIDOS, STOCKS y QUEDAN se calculen correctamente con 0 clientes
  (PEDIDOS = 0, QUEDAN = STOCKS).

### Fuera de alcance

- Automatización de la adición de clientes (p.ej., escuchar pedidos entrantes
  desde un canal externo y añadir clientes automáticamente). La adición sigue
  siendo manual mediante la UI existente.
- Cambios en la funcionalidad de "Añadir productos".
- Cambios en la estructura de Firestore (`orders/{YYYY-MM-DD}` y
  `rows/{productId}`).
- Cambios en la visualización de pedidos históricos.
- Modificaciones al flujo de sincronización en tiempo real (listeners de
  Firestore).

## 4) Actores implicados

- **Operador / usuario de la app**: persona que crea el pedido del día y
  gestiona la tabla de pedidos. Es quien decide cuándo y qué clientes añadir.

## 5) Requisitos funcionales

- **RF-01**: Al crear el pedido de hoy, el documento `orders/{YYYY-MM-DD}` en
  Firestore debe crearse con `clientIds: []` (lista vacía) y `productIds` con
  los productos activos.
- **RF-02**: Los subdocumentos `rows/{productId}` deben crearse con
  `quantities: {}` (mapa vacío) y `stock: 0`, igual que actualmente.
- **RF-03**: La tabla de pedidos del día debe renderizarse correctamente cuando
  `clientIds` esté vacío: solo filas de productos y columnas fijas (PEDIDOS,
  STOCKS, QUEDAN).
- **RF-04**: La columna PEDIDOS debe mostrar 0 para todos los productos cuando
  no haya clientes.
- **RF-05**: La columna QUEDAN debe mostrar el valor de STOCKS cuando no haya
  clientes (QUEDAN = STOCKS - 0).
- **RF-06**: La funcionalidad de "Añadir clientes" (`addClients`) debe seguir
  funcionando sin cambios para incorporar clientes al pedido de forma
  incremental.
- **RF-07**: La funcionalidad de "Eliminar clientes" (`removeClients`) debe
  seguir funcionando, incluyendo el caso de eliminar el último cliente y volver
  al estado sin clientes.

## 6) Criterios de aceptación

- **CA-01**: Al crear un pedido nuevo, el documento en Firestore contiene
  `clientIds: []` y `productIds` con todos los productos activos.
- **CA-02**: La tabla se muestra sin columnas de clientes, solo con filas de
  productos y las columnas PEDIDOS (0), STOCKS (editable) y QUEDAN (= STOCKS).
- **CA-03**: Al añadir un cliente mediante la funcionalidad existente, su
  columna aparece en la tabla y las cantidades se pueden editar.
- **CA-04**: Al eliminar todos los clientes, la tabla vuelve al estado sin
  columnas de cliente.
- **CA-05**: No se producen errores ni excepciones al operar con una tabla sin
  clientes (cálculos de sumas, renderizado, scroll, etc.).
- **CA-06**: El listener de Firestore en tiempo real emite correctamente el
  `OrderSheet` con `clients: []` sin errores.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El operador abre la pantalla "Pedidos de hoy".
2. No existe pedido para la fecha actual → se muestra el estado "No file" (botón
   de crear).
3. El operador pulsa "Crear pedido de hoy".
4. El sistema crea el documento Firestore con `clientIds: []` y los productos
   activos.
5. Se muestra la tabla con filas de productos y columnas PEDIDOS (0), STOCKS
   (0), QUEDAN (0). Sin columnas de clientes.
6. El operador pulsa "Añadir clientes" y selecciona uno o varios clientes.
7. Las columnas de los clientes seleccionados aparecen en la tabla.
8. El operador introduce cantidades en las celdas cliente–producto.

### Flujos alternativos

- **FA-01 — Pedido ya existente**: Si el documento ya existe para la fecha, se
  carga tal cual (con los clientes que tenga, incluyendo ninguno). No se
  sobreescribe.
- **FA-02 — No hay productos activos**: Si no hay productos activos, el pedido
  se crea con `productIds: []` y `clientIds: []`. La tabla se mostrará vacía
  (sin filas ni columnas de clientes). El operador puede añadir productos y
  clientes posteriormente.
- **FA-03 — Eliminar último cliente**: Si el operador elimina el último cliente
  de la tabla, se vuelve al estado de "tabla sin clientes" (solo filas de
  producto y columnas fijas).

### Estados especiales / excepciones

- **Estado vacío (sin clientes)**: Tabla muestra solo productos +
  PEDIDOS/STOCKS/QUEDAN. Este es ahora el **estado inicial** al crear el pedido.
- **Estado loading/procesando**: Sin cambios respecto al comportamiento actual.
- **Estado error**: Sin cambios; si falla la creación en Firestore, se muestra
  el error al usuario.

## 8) Edge cases

- **EC-01**: Crear pedido cuando no hay clientes activos en el sistema → El
  resultado es idéntico al nuevo comportamiento (sin clientes). No hay
  diferencia funcional.
- **EC-02**: Crear pedido cuando no hay productos activos → Pedido se crea con
  ambos listados vacíos. La tabla debería manejar este caso mostrando un estado
  vacío o informativo.
- **EC-03**: Sincronización en tiempo real con tabla sin clientes → El listener
  emite `OrderSheet` con `clients: []`. Los cálculos de `quantities`, `pedidos`,
  `quedan` deben funcionar con listas vacías (matrices de 0 columnas).
- **EC-04**: Otro usuario añade clientes mientras el operador ve la tabla sin
  clientes → El listener en tiempo real debe detectar el cambio y actualizar la
  tabla, mostrando las nuevas columnas.

## 9) Impacto funcional

- **Módulos afectados**:
  - `orders_today` — repositorio (`createTodaySheet`), datasource
    (`createOrder`), presentación (renderizado de tabla con 0 clientes).
- **Impacto en usuario**: La experiencia cambia al crear el pedido: en lugar de
  ver una tabla llena de columnas de clientes con ceros, verá una tabla limpia
  solo con productos. La adición de clientes es un paso explícito posterior.
- **Impacto en experiencia de usuario**: Positivo — tabla más limpia y enfocada
  en lo relevante. Requiere una acción adicional para añadir clientes, pero se
  alinea con el flujo real de recepción de pedidos.

## 10) Suposiciones

- La funcionalidad de "Añadir clientes" ya existe y funciona correctamente para
  añadir clientes a un pedido existente (incluyendo un pedido con
  `clientIds: []`).
- El renderizado de la tabla (grid) ya soporta o puede soportar el caso de 0
  columnas de clientes sin errores.
- No se requiere ningún cambio en la estructura de datos de Firestore, solo en
  los valores iniciales al crear.
- La Google Sheets datasource (`OrdersSheetDataSource`) no se ve afectada; este
  cambio aplica exclusivamente al flujo Firestore.

## 11) Preguntas abiertas

Todas resueltas.

- ~~**PA-01**: ¿Debe mostrarse algún mensaje o indicador visual al operador
  cuando la tabla no tiene clientes?~~ → **No**. No se requiere placeholder ni
  call-to-action adicional.
- ~~**PA-02**: ¿Se espera en el futuro que la adición de clientes sea
  automática?~~ → **No**. La adición de clientes será siempre manual.

## 12) Notas para análisis técnico

- El cambio principal se localiza en
  `OrdersTodayRepositoryImpl.createTodaySheet()`: dejar de obtener clientes
  activos y pasar `clientIds: []` a `_firestoreDataSource.createOrder()`.
- El datasource `OrderFirestoreDataSource.createOrder()` ya acepta `clientIds`
  como parámetro; pasarle una lista vacía debería funcionar sin modificaciones
  al datasource.
- Verificar que `_buildOrderSheet()` y la entidad `OrderSheet` manejan
  correctamente el caso `clientIds: []` y `clients: []` (matrices de 0 columnas
  en `quantities`).
- Verificar que el widget de tabla/grid en la capa de presentación renderiza
  correctamente con 0 columnas de clientes.
- Los tests existentes del repositorio, use cases y BLoC deberán actualizarse
  para reflejar que la creación produce un `OrderSheet` con `clients: []`.
- **Estado: Listo para análisis técnico**
