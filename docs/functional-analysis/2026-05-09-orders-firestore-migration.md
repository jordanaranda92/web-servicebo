# Functional Analysis: Migración de pedidos de hoy de Google Sheets a Firestore

- **Fecha:** 2026-05-09
- **Identificador:** orders-firestore-migration
- **Estado:** Ready for technical analysis

## 1) Resumen

Sustituir Google Sheets como origen y almacén de datos de la funcionalidad
"Pedidos de hoy" por una colección de Firestore (`orders/{YYYY-MM-DD}`),
manteniendo la interfaz de usuario actual sin cambios visibles para el operador.

## 2) Contexto y objetivo

### Qué se solicita

Actualmente, al pulsar "Crear pedido de hoy" la app copia una plantilla de
Google Sheets almacenada en Google Drive, la rellena con clientes activos,
productos activos, fórmulas y formato, y la usa como fuente de verdad para
lectura y escritura de cantidades, stocks y totales. Toda la operativa
(leer/escribir celdas, calcular PEDIDOS/QUEDAN, auto-refresh) depende de la
Google Sheets API y Drive API.

Se solicita reemplazar este flujo por completo: los datos de pedidos del día se
almacenarán en Firestore en la colección `orders`, eliminando la dependencia de
Google Sheets/Drive para esta feature.

### Qué problema resuelve

- **Dependencia externa frágil**: la operativa depende de la disponibilidad de
  las APIs de Google Sheets y Drive, plantillas versionadas y configuración de
  carpetas de Google Drive.
- **Latencia**: cada operación de lectura/escritura requiere llamadas HTTP a
  Sheets API.
- **Complejidad de sincronización**: actualmente se usa un patrón de polling
  (`modifiedTime`) complementado con RTDB para detectar cambios, lo que resulta
  en una arquitectura híbrida compleja.
- **Escalabilidad**: Firestore ofrece listeners en tiempo real nativos, lo que
  simplifica la sincronización sin necesidad de polling ni RTDB intermediario.

### Qué resultado funcional se espera

- Los pedidos del día se crean, leen, actualizan y persisten en Firestore.
- La interfaz de usuario permanece idéntica: misma tabla, mismos campos, misma
  interacción.
- La creación de un pedido del día sigue generándose a partir de los clientes y
  productos activos del sistema.

## 3) Alcance

### En alcance

- **Creación del documento de pedido del día** en Firestore
  (`orders/{YYYY-MM-DD}`) con clientes activos y productos activos.
- **Lectura de datos** del pedido del día desde Firestore en vez de Sheets API.
- **Escritura/actualización de celdas** (cantidades por cliente-producto y
  stock) directamente en Firestore.
- **Cálculos de PEDIDOS y QUEDAN**: se calculan en el cliente o se
  almacenan/actualizan en Firestore al modificar cantidades o stock.
- **Detección de existencia** del pedido del día (equivalente al estado "No hay
  pedidos para hoy").
- **Modelo de datos en Firestore** según la estructura propuesta:
  - `orders/{YYYY-MM-DD}` → documento raíz con `createdAt`, `lastModifiedAt`,
    `clientIds`, `productIds`.
  - `orders/{YYYY-MM-DD}/rows/{productId}` → subcolección con
    `quantities: { clientId: num }` y `stock: num`.

### Fuera de alcance

- **Cambios en la interfaz de usuario**: no se modifica la UI, solo el origen de
  datos.
- **Migración de pedidos históricos**: los pedidos anteriores almacenados en
  Google Sheets no se migran a Firestore.
- **Feature de histórico de pedidos** (`orders_history`): sigue funcionando con
  su flujo actual.
- **Eliminación del código de Google Sheets**: el datasource actual
  (`OrdersSheetDataSource`) se mantiene en el código base (puede ser eliminado
  en un futuro, pero no es parte de este cambio).
- **Modificación de las features de clientes o productos**: no se alteran.
- **Colaboración en tiempo real vía RTDB**: se evaluará en el análisis técnico
  si Firestore listeners reemplazan el flujo RTDB actual o si se mantienen
  ambos. Funcionalmente, el requisito es que los cambios se reflejen en tiempo
  razonable para otros usuarios.
- **Gestión de permisos/roles en Firestore**: se asume que las security rules de
  Firestore ya están o serán configuradas fuera de este alcance.

## 4) Actores implicados

| Actor                                              | Rol                                                                                                                                            |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Operador**                                       | Usuario de la app que crea el pedido del día, introduce cantidades por cliente-producto, modifica stocks y consulta totales (PEDIDOS, QUEDAN). |
| **Sistema (app Flutter)**                          | Ejecuta la creación, lectura y escritura de documentos en Firestore. Calcula totales derivados.                                                |
| **Firestore**                                      | Nuevo almacén de datos para pedidos del día.                                                                                                   |
| **Colecciones `clients` y `products` (Firestore)** | Fuente de clientes y productos activos para la creación del pedido.                                                                            |

## 5) Requisitos funcionales

- **RF-01**: Al pulsar "Crear pedido de hoy", el sistema debe crear un documento
  `orders/{YYYY-MM-DD}` en Firestore con:
  - `createdAt`: timestamp de creación.
  - `lastModifiedAt`: timestamp de creación (inicialmente igual a `createdAt`).
  - `clientIds`: lista de IDs de los clientes activos (de la colección
    `clients`, filtrados por `isActive == true`), ordenados por el campo
    `order`.
  - `productIds`: lista de IDs de los productos activos (de la colección
    `products`, filtrados por `isActive == true`), ordenados por el campo
    `order`.

- **RF-02**: Al crear el pedido del día, se debe crear un subdocumento
  `orders/{YYYY-MM-DD}/rows/{productId}` por cada producto activo con:
  - `quantities`: mapa vacío `{}` (sparse — solo se añaden entradas cuando se
    introduce una cantidad).
  - `stock`: `0`.

- **RF-03**: Al abrir la pantalla de "Pedidos de hoy", el sistema debe verificar
  si existe el documento `orders/{fecha_actual}` en Firestore:
  - Si existe → cargar los datos y mostrar la tabla.
  - Si no existe → mostrar el estado vacío ("No hay pedidos para hoy") con el
    botón "Crear pedido de hoy".

- **RF-04**: La tabla debe mostrar los datos con la misma disposición actual:
  - **Filas** = productos (nombre del producto en la primera columna).
  - **Columnas** = clientes (nombre del cliente en la cabecera).
  - **Celdas** = cantidad pedida por ese cliente para ese producto.
  - **Columna PEDIDOS** = suma de todas las cantidades de clientes para ese
    producto.
  - **Columna STOCKS** = valor de stock editable.
  - **Columna QUEDAN** = STOCKS − PEDIDOS (calculado).

- **RF-05**: Cuando el operador modifica una celda de cantidad, el sistema debe:
  - Actualizar el campo correspondiente en
    `orders/{YYYY-MM-DD}/rows/{productId}.quantities.{clientId}` en Firestore.
  - Actualizar `lastModifiedAt` del documento raíz.
  - Recalcular PEDIDOS y QUEDAN para esa fila en la UI.

- **RF-06**: Cuando el operador modifica una celda de stock, el sistema debe:
  - Actualizar `orders/{YYYY-MM-DD}/rows/{productId}.stock` en Firestore.
  - Actualizar `lastModifiedAt` del documento raíz.
  - Recalcular QUEDAN para esa fila en la UI.

- **RF-07**: Los nombres de clientes y productos mostrados en la tabla deben
  resolverse a partir de las colecciones `clients` y `products` de Firestore,
  usando los `clientIds` y `productIds` almacenados en el documento de pedido
  como referencia.

- **RF-08**: Si un producto no tiene cantidades para ningún cliente (mapa
  `quantities` vacío), debe mostrarse con todas las celdas en `0`.

- **RF-09**: PEDIDOS y QUEDAN se calculan en el cliente (no se almacenan en
  Firestore). Son valores derivados:
  - `PEDIDOS = sum(quantities.values)`
  - `QUEDAN = stock - PEDIDOS`

- **RF-10**: La visualización de QUEDAN debe seguir la misma convención de
  colores actual:
  - Rojo si QUEDAN < 0.
  - Verde si QUEDAN ≥ 0.

- **RF-11**: Si se activan o desactivan clientes después de haber creado el
  pedido del día, el documento `orders/{YYYY-MM-DD}` debe actualizarse
  dinámicamente:
  - **Cliente activado**: añadir su ID a `clientIds`. No se necesita modificar
    los subdocumentos de `rows` (el mapa `quantities` es sparse).
  - **Cliente desactivado**: eliminar su ID de `clientIds` y eliminar sus
    entradas de `quantities` en todos los subdocumentos de `rows`.

- **RF-12**: Si se activan o desactivan productos después de haber creado el
  pedido del día, el documento debe actualizarse dinámicamente:
  - **Producto activado**: añadir su ID a `productIds` y crear el subdocumento
    `rows/{productId}` con `quantities: {}` y `stock: 0`.
  - **Producto desactivado**: eliminar su ID de `productIds` y eliminar el
    subdocumento `rows/{productId}`.

- **RF-13**: La sincronización en tiempo real entre operadores se mantiene vía
  Firebase RTDB (locks, cursores y deltas de celdas). No se reemplaza por
  Firestore listeners en este cambio.

- **RF-14**: La funcionalidad opera exclusivamente en modo online. No se
  requiere persistencia offline de Firestore.

## 6) Criterios de aceptación

- **CA-01**: Al pulsar "Crear pedido de hoy" se crea el documento
  `orders/{YYYY-MM-DD}` con los clientes y productos activos y los subdocumentos
  de `rows` correspondientes.
- **CA-02**: Si ya existe un documento para la fecha actual, no se muestra el
  botón "Crear pedido de hoy" y se cargan los datos existentes directamente.
- **CA-03**: La tabla muestra los productos en filas y clientes en columnas con
  las cantidades, PEDIDOS, STOCKS y QUEDAN correctos.
- **CA-04**: Modificar una celda de cantidad actualiza Firestore y recalcula
  PEDIDOS/QUEDAN inmediatamente en la UI.
- **CA-05**: Modificar una celda de stock actualiza Firestore y recalcula QUEDAN
  inmediatamente en la UI.
- **CA-06**: Los valores de QUEDAN se muestran en rojo cuando son negativos y en
  verde cuando son ≥ 0.
- **CA-07**: La app no realiza ninguna llamada a Google Sheets API ni Drive API
  para la funcionalidad de pedidos de hoy.
- **CA-08**: Si Firestore no está disponible (sin conexión), el sistema muestra
  un error apropiado (comportamiento análogo al actual con Sheets API).
- **CA-09**: Al reabrir la pantalla o volver a ella, los datos se recargan desde
  Firestore y reflejan el estado actualizado.
- **CA-10**: Si se activa un cliente tras crear el pedido, aparece como nueva
  columna en la tabla al recargar.
- **CA-11**: Si se desactiva un cliente tras crear el pedido, desaparece de la
  tabla y sus cantidades se eliminan de Firestore.
- **CA-12**: Si se activa un producto tras crear el pedido, aparece como nueva
  fila con cantidades en 0.
- **CA-13**: Si se desactiva un producto tras crear el pedido, desaparece de la
  tabla y su subdocumento se elimina.
- **CA-14**: La sincronización en tiempo real vía RTDB sigue funcionando (locks,
  cursores, deltas).

## 7) Flujos y comportamiento esperado

### Flujo principal — Crear pedido del día

1. El operador abre la pantalla "Pedidos de hoy".
2. El sistema consulta Firestore: ¿existe `orders/{YYYY-MM-DD}`?
3. No existe → se muestra estado vacío con botón "Crear pedido de hoy".
4. El operador pulsa "Crear pedido de hoy".
5. El sistema obtiene los clientes activos (colección `clients`,
   `isActive == true`, ordenados por `order`).
6. El sistema obtiene los productos activos (colección `products`,
   `isActive == true`, ordenados por `order`).
7. El sistema crea el documento `orders/{YYYY-MM-DD}` con `createdAt`,
   `lastModifiedAt`, `clientIds`, `productIds`.
8. El sistema crea un subdocumento `rows/{productId}` por cada producto con
   `quantities: {}` y `stock: 0`.
9. El sistema carga la tabla vacía (todas las cantidades en 0, stock en 0,
   PEDIDOS = 0, QUEDAN = 0).

### Flujo principal — Cargar pedido existente

1. El operador abre la pantalla "Pedidos de hoy".
2. El sistema consulta Firestore: ¿existe `orders/{YYYY-MM-DD}`?
3. Sí existe → carga el documento raíz y todos los subdocumentos de `rows`.
4. Resuelve los nombres de clientes y productos desde sus colecciones Firestore.
5. Calcula PEDIDOS y QUEDAN para cada producto.
6. Muestra la tabla con los datos.

### Flujo principal — Editar celda de cantidad

1. El operador toca una celda de cantidad (intersección producto-cliente).
2. Introduce un valor numérico.
3. El sistema actualiza
   `orders/{YYYY-MM-DD}/rows/{productId}.quantities.{clientId}` en Firestore.
4. El sistema recalcula PEDIDOS y QUEDAN para esa fila en la UI.
5. El sistema actualiza `lastModifiedAt` del documento raíz.

### Flujo principal — Editar celda de stock

1. El operador toca una celda de stock.
2. Introduce un valor numérico.
3. El sistema actualiza `orders/{YYYY-MM-DD}/rows/{productId}.stock` en
   Firestore.
4. El sistema recalcula QUEDAN para esa fila en la UI.
5. El sistema actualiza `lastModifiedAt` del documento raíz.

### Flujos alternativos

- **FA-01 — Creación duplicada**: Si al intentar crear el pedido ya existe el
  documento (otro operador lo creó entre el check y la creación), el sistema
  carga los datos existentes sin error.
- **FA-02 — Sin clientes o productos activos**: Si no hay clientes o productos
  activos, el sistema crea el documento con listas vacías. La tabla se muestra
  vacía (sin columnas de clientes o sin filas de productos, respectivamente).
- **FA-03 — Sincronización de clientes/productos activos**: Al cargar el pedido
  del día, el sistema compara los `clientIds`/`productIds` del documento con los
  clientes/productos activos actuales. Si hay diferencias (nuevos activos o
  recién desactivados), actualiza el documento y los subdocumentos antes de
  mostrar la tabla.

### Estados especiales / excepciones

- **Estado vacío**: No existe documento para la fecha actual → se muestra el
  estado vacío con botón de creación (pantalla actual capturada en la imagen
  adjunta).
- **Estado loading**: Mientras se consulta o crea el documento → se muestra
  indicador de carga.
- **Estado error**: Fallo de conexión con Firestore o error de permisos → se
  muestra el estado de error con opción de reintentar.
- **Sin conexión a internet**: La app opera solo online. Si no hay conexión, se
  muestra un error con opción de reintentar.

## 8) Edge cases

- **EC-01 — Pedido creado por otro operador simultáneamente**: Si dos operadores
  intentan crear el pedido del día al mismo tiempo, el segundo debe detectar que
  ya existe y cargar los datos del primero sin duplicar.
- **EC-02 — Cliente o producto desactivado después de crear el pedido**: El
  sistema sincroniza dinámicamente: al cargar el pedido, detecta
  clientes/productos desactivados, los elimina del documento y limpia sus datos.
  Si un cliente/producto fue eliminado de Firestore (no solo desactivado), se
  elimina del documento igualmente.
- **EC-03 — Cantidad con valor 0**: Si se establece una cantidad a 0, se puede
  almacenar como `clientId: 0` en el mapa o eliminarse del mapa (sparse).
  Definir comportamiento: **se recomienda almacenar solo valores > 0** para
  mantener el mapa sparse y coherente con la semántica.
- **EC-04 — Valores no numéricos**: El sistema debe validar que solo se acepten
  valores numéricos en celdas de cantidad y stock (ya se hace actualmente en la
  UI).
- **EC-05 — Muchos productos × muchos clientes**: Si hay un volumen alto de
  productos activos, la lectura de todos los subdocumentos de `rows` debe ser
  eficiente. Considerar si un `collectionGroup` query o lectura batch es
  necesaria (nota para análisis técnico).
- **EC-06 — Cambio de día a medianoche**: Si la app está abierta a las 23:59 y
  pasa a las 00:00, la fecha de referencia cambia. El comportamiento actual
  debería mantenerse (el operador abre/refresca y ve el nuevo día).

## 9) Impacto funcional

| Área                                     | Impacto                                                                                                              |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Pedidos de hoy (origen de datos)**     | Alto — se reemplaza Google Sheets por Firestore como fuente de verdad.                                               |
| **Pedidos de hoy (UI)**                  | Ninguno — la interfaz no cambia.                                                                                     |
| **Histórico de pedidos**                 | Ninguno — sigue con su flujo actual (Google Sheets).                                                                 |
| **Dashboard**                            | Bajo — si el dashboard consume datos de pedidos del día, deberá leerlos de Firestore. Verificar en análisis técnico. |
| **Configuración de Google Drive**        | Bajo — ya no es prerrequisito para pedidos de hoy, pero sigue siendo necesario para otras features.                  |
| **RTDB (sincronización en tiempo real)** | Ninguno — se mantiene tal cual.                                                                                      |
| **Clientes y Productos**                 | Ninguno — se leen pero no se modifican.                                                                              |

### Impacto en experiencia de usuario

- **Positivo**: potencialmente menor latencia en lectura/escritura al usar
  Firestore directamente vs. Sheets API.
- **Neutro**: la interfaz permanece idéntica.
- **Decidido**: la funcionalidad es solo online, sin persistencia offline.

## 10) Suposiciones

- **S-01**: Las colecciones `clients` y `products` en Firestore ya existen y
  contienen datos fiables con campos `isActive` y `order`.
- **S-02**: Firebase/Firestore ya está configurado e inicializado en la app
  (confirmado por los datasources existentes `ClientFirestoreDataSourceImpl`,
  `ProductFirestoreDataSourceImpl`).
- **S-03**: Los `clientIds` y `productIds` almacenados en el documento de pedido
  son los IDs de documento de Firestore (no UUIDs de FacturaDirecta ni otros
  identificadores externos).
- **S-04**: Al establecer una cantidad a 0, se elimina la entrada del mapa
  `quantities` (sparse), no se almacena `clientId: 0`.
- **S-05**: PEDIDOS y QUEDAN son valores calculados en el cliente, no
  almacenados en Firestore.
- **S-06**: No se requiere funcionalidad de "deshacer" o "historial de cambios"
  en el pedido del día.
- **S-07**: Las security rules de Firestore para la colección `orders` serán
  configuradas adecuadamente (lectura/escritura restringida a usuarios
  autenticados).

## 11) Preguntas abiertas

_Todas las preguntas han sido resueltas._

### Decisiones tomadas

- **D-01 (ex PA-01)**: La sincronización en tiempo real vía RTDB **se mantiene**
  tal como está. No se reemplaza por Firestore listeners en este cambio.
- **D-02 (ex PA-02)**: Los `clientIds`, `productIds` y `rows` **se actualizan
  dinámicamente** al cargar el pedido del día si han cambiado los
  clientes/productos activos.
- **D-03 (ex PA-03)**: La funcionalidad opera **solo online**. No se habilita
  persistencia offline de Firestore para garantizar la colaboración en tiempo
  real.

## 12) Notas para análisis técnico

- El datasource actual `OrdersSheetDataSource` y su implementación deben **dejar
  de usarse** en esta feature, pero no eliminarse del código base (otras
  features podrían referenciarlo indirectamente).
- El `OrdersRtdbDataSource` actual gestiona locks, cursores y deltas de celdas
  en RTDB. **Se mantiene sin cambios** — la sincronización en tiempo real sigue
  vía RTDB.
- El modelo de dominio `OrderSheet` puede mantenerse con la misma estructura (ya
  está transpuesto: productos en filas, clientes en columnas). El cambio
  principal es en la capa data (nuevo datasource Firestore en vez de Sheets).
- La resolución de nombres de clientes/productos a partir de IDs puede hacerse
  con un join local contra las colecciones `clients`/`products`, que ya se
  cargan en la app.
- Considerar el volumen de lecturas Firestore: un pedido con 10 productos genera
  1 lectura del documento raíz + 10 lecturas de subdocumentos (o 1 query de
  subcolección). Evaluar costes.
- El módulo DI (`orders_today_module.dart`) necesitará actualizarse para
  registrar el nuevo datasource de Firestore en lugar del de Sheets.
- Las operaciones de escritura deben considerar batched writes o transactions
  para garantizar consistencia (especialmente para la creación inicial).
- **Estado: Listo para análisis técnico**
