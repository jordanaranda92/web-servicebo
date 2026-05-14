# Functional Analysis: Historial de pedidos desde Firestore

- **Fecha:** 2026-05-13
- **Identificador:** orders-history-firestore
- **Estado:** Ready for technical analysis

## 1) Resumen

Reemplazar la implementación stub del repositorio de historial de pedidos
(`OrdersHistoryRepositoryImpl`) por una implementación real que lea los pedidos
históricos desde la colección `orders` de Firestore, reutilizando la misma
estructura de datos que ya usa la feature "Pedidos de hoy".

## 2) Contexto y objetivo

### Qué se solicita

La pantalla de **Historial de pedidos** (`OrdersHistoryPage`) ya existe con toda
su capa de presentación funcional (BLoC, widgets, estados, navegación, filtros).
Sin embargo, el repositorio de datos es un **stub** que siempre retorna una
lista vacía de fechas y un error al intentar cargar pedidos. Esto se debe a que
el backend anterior (archivos Excel en Google Drive) fue eliminado.

Se solicita conectar esta pantalla a **Firestore** para que cargue pedidos
reales de días anteriores.

### Qué problema resuelve

- El usuario **no puede consultar pedidos de días anteriores** desde la
  aplicación. La pantalla existe pero siempre muestra el estado vacío.
- Los datos de pedidos **ya existen en Firestore** (colección
  `orders/{YYYY-MM-DD}`) porque la feature "Pedidos de hoy" los crea allí. Solo
  falta leerlos desde el historial.

### Qué resultado funcional se espera

- El usuario accede a "Historial de pedidos" y ve un listado de todas las fechas
  para las que existen pedidos en Firestore (excluyendo el día en curso).
- Al seleccionar una fecha, ve la tabla de pedidos de ese día en modo solo
  lectura (clientes × productos × cantidades), con totales por producto, por
  cliente y total general.
- Los filtros existentes (rango de fechas, búsqueda de clientes) funcionan
  correctamente sobre los datos reales.

## 3) Alcance

### En alcance

- **Obtener fechas disponibles**: listar los documentos existentes en la
  colección `orders` de Firestore, excluyendo la fecha actual, y devolver la
  lista de fechas ordenada de más reciente a más antigua.
- **Cargar pedido por fecha**: leer el documento raíz `orders/{YYYY-MM-DD}` y su
  subcolección `rows/{productId}` para construir un `OrderSheet` completo con
  nombres de clientes y productos resueltos.
- **Resolución de nombres**: traducir los IDs de clientes y productos
  almacenados en Firestore a nombres legibles, consultando las colecciones
  `clients` y `products`.
- **Integración con la presentación existente**: el BLoC, la página y los
  widgets ya existentes deben funcionar sin cambios (o con cambios mínimos de
  adaptación) al recibir datos reales.
- **Manejo de errores**: errores de red/Firestore deben mapearse a los tipos de
  error existentes del BLoC (`OrdersHistoryErrorType`).

### Fuera de alcance

- **Edición de pedidos históricos**: la vista sigue siendo de solo lectura.
- **Exportación a PDF/Excel** desde la vista de historial.
- **Paginación o carga lazy de fechas**: se cargan todas las fechas disponibles
  en una sola consulta (volumen esperado: cientos de documentos, no miles).
- **Tiempo real / listeners**: el historial se carga bajo demanda, no requiere
  actualizaciones en tiempo real.
- **Cambios en la UI/presentación**: la pantalla, widgets y flujos de navegación
  existentes se mantienen tal cual.
- **Migración de pedidos históricos desde Excel/Drive**: los pedidos anteriores
  a la migración a Firestore no están disponibles.

## 4) Actores implicados

| Actor                                  | Rol                                                            |
| -------------------------------------- | -------------------------------------------------------------- |
| **Operador**                           | Usuario de la app que consulta pedidos de días anteriores      |
| **Sistema (app Flutter)**              | Lee datos de Firestore y los presenta en la tabla de historial |
| **Firestore**                          | Almacén de datos; colección `orders` con subcolección `rows`   |
| **Colecciones `clients` y `products`** | Fuente de nombres para resolver IDs almacenados en los pedidos |

## 5) Requisitos funcionales

- **RF-01**: Al acceder a la pantalla de historial, el sistema debe listar todas
  las fechas para las que existe un documento en la colección `orders` de
  Firestore, **excluyendo la fecha del día en curso**.

- **RF-02**: Las fechas deben presentarse ordenadas de más reciente a más
  antigua, agrupadas por mes y año (comportamiento ya implementado en la UI).

- **RF-03**: Al seleccionar una fecha, el sistema debe leer el documento
  `orders/{YYYY-MM-DD}` y todos los subdocumentos de `rows/` para esa fecha.

- **RF-04**: Los IDs de clientes (`clientIds`) y productos (`productIds`) del
  documento de pedido deben resolverse a nombres legibles consultando las
  colecciones `clients` y `products` de Firestore.

- **RF-05**: Si un cliente o producto referenciado en el pedido ya no existe en
  su colección (fue eliminado), se debe mostrar un nombre de fallback (ej: el
  propio ID o un texto genérico como "Cliente eliminado").

- **RF-06**: El `OrderSheet` construido debe incluir toda la información
  necesaria para la tabla: nombres de clientes, nombres de productos, matriz de
  cantidades, totales PEDIDOS (suma de cantidades por producto), STOCKS y QUEDAN
  (stocks − pedidos), así como flags, notas, devoluciones y datos de facturación
  (`invoicedBy`) si existen en el documento.

- **RF-06b**: El listado de fechas debe mostrar por cada entrada: la fecha, el
  número de clientes y el número de productos del pedido de ese día.

- **RF-07**: El filtro por rango de fechas debe funcionar sobre las fechas
  cargadas desde Firestore (comportamiento ya implementado en el BLoC).

- **RF-08**: La búsqueda de clientes dentro de un día seleccionado debe
  funcionar sobre los nombres resueltos (comportamiento ya implementado en el
  widget).

- **RF-09**: Los tipos de error del BLoC deben adaptarse semánticamente a
  errores de Firestore (ej: error de red → tipo de error apropiado).

## 6) Criterios de aceptación

- **CA-01**: Al abrir "Historial de pedidos" con pedidos existentes en
  Firestore, se muestra un listado de fechas (no el estado vacío).

- **CA-02**: Las fechas mostradas no incluyen la fecha del día en curso.

- **CA-03**: Al seleccionar una fecha, se muestra la tabla con clientes,
  productos, cantidades, totales PEDIDOS, STOCKS y QUEDAN correctos y
  coincidentes con los datos almacenados en Firestore.

- **CA-04**: Los nombres de clientes y productos se muestran correctamente
  (resueltos desde sus colecciones, no como IDs).

- **CA-05**: Si un cliente o producto fue eliminado de Firestore pero aparece en
  un pedido histórico, se muestra un nombre de fallback en vez de un crash o
  campo vacío.

- **CA-06**: El filtro por rango de fechas filtra correctamente las fechas del
  listado.

- **CA-07**: La búsqueda de clientes dentro de un pedido seleccionado filtra
  correctamente los nombres.

- **CA-08**: Si Firestore no tiene documentos en `orders` (aparte del día
  actual), se muestra el estado vacío existente.

- **CA-09**: Si ocurre un error de red o de Firestore, se muestra el estado de
  error con botón de reintentar.

- **CA-10**: Los tests unitarios del repositorio verifican la lectura correcta
  de fechas y pedidos desde Firestore.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario navega a la sección "Historial de pedidos".
2. El BLoC emite `OrdersHistoryLoadDates`.
3. El use case `GetAvailableDates` invoca el repositorio.
4. El repositorio consulta Firestore para obtener los IDs de todos los
   documentos en `orders`, excluye la fecha actual, y devuelve la lista ordenada
   de `DateTime`.
5. El BLoC emite `OrdersHistoryDatesLoaded` con las fechas.
6. La UI muestra el listado de fechas agrupado por mes/año.
7. El usuario selecciona una fecha.
8. El BLoC emite `OrdersHistoryDateSelected`.
9. El use case `GetHistoryOrders` invoca el repositorio con la fecha.
10. El repositorio lee el documento raíz y los subdocumentos `rows/`, resuelve
    nombres de clientes y productos, y construye un `OrderSheet`.
11. El BLoC emite `OrdersHistoryDetailLoaded` con el `OrderSheet`.
12. La UI muestra la tabla de pedidos con totales.

### Flujos alternativos

- **Sin pedidos históricos**: El repositorio devuelve una lista vacía de fechas
  → el BLoC emite `OrdersHistoryEmpty` → la UI muestra el estado vacío.
- **Filtro por rango de fechas**: El usuario selecciona un rango de fechas → el
  BLoC filtra localmente las fechas ya cargadas → la UI se actualiza.
- **Búsqueda de clientes**: El usuario escribe en el buscador → el BLoC
  actualiza el filtro → el widget filtra visualmente las filas de la tabla.
- **Volver al listado**: El usuario pulsa el botón de retroceso → el BLoC emite
  `OrdersHistoryBackToList` → la UI vuelve al listado de fechas preservando el
  filtro de rango.

### Estados especiales / excepciones

- **Estado vacío**: No existen documentos en `orders` distintos al día actual →
  se muestra `HistoryEmptyState`.
- **Estado loading**: Mientras se consulta Firestore → se muestra
  `CircularProgressIndicator`.
- **Estado error (red/Firestore)**: Error al consultar Firestore → se muestra
  `HistoryErrorState` con botón de reintentar.
- **Cliente/producto eliminado**: Un ID referenciado en un pedido histórico ya
  no existe en la colección maestra → se muestra nombre de fallback.

## 8) Edge cases

- **EC-01**: Un pedido histórico tiene `clientIds` o `productIds` vacíos (pedido
  creado sin clientes/productos activos) → la tabla se muestra vacía o con el
  eje correspondiente vacío.

- **EC-02**: Un pedido histórico referencia clientes o productos que fueron
  eliminados de la colección maestra después de crear el pedido → se muestran
  con nombre de fallback (RF-05).

- **EC-03**: Solo existe un documento en `orders` y es el del día actual → se
  excluye y se muestra estado vacío.

- **EC-04**: Existen muchos documentos en `orders` (>500) → la consulta puede
  ser lenta. Aceptable para el volumen esperado del negocio, pero debe
  monitorizarse.

- **EC-05**: El documento de pedido existe pero no tiene subdocumentos en
  `rows/` (estado inconsistente) → se muestra la tabla sin filas de productos,
  sin error.

- **EC-06**: El usuario pierde conectividad durante la carga → se muestra estado
  de error con opción de reintentar.

## 9) Impacto funcional

- **Módulos afectados**:
  - `orders_history` (capa de datos): pasa de stub a implementación real con
    Firestore.
  - `orders_today` (solo dependencia de lectura): se reutilizan modelos y
    potencialmente el datasource de Firestore.
  - Módulo DI (`orders_history_module`): se actualiza para inyectar las
    dependencias de Firestore.

- **Impacto en usuario**: La pantalla de historial pasa de no funcional a
  completamente operativa. El usuario puede por primera vez consultar pedidos de
  días anteriores.

- **Impacto en experiencia de usuario**: Positivo. Se desbloquea una
  funcionalidad esencial para el operador que antes solo podía consultar el día
  actual. La experiencia de navegación (listado de fechas → detalle → vuelta) ya
  está diseñada e implementada en la UI.

## 10) Suposiciones

- Los pedidos del día ya se crean y persisten correctamente en Firestore gracias
  a la feature `orders_today` (verificado: la implementación existe y funciona).
- La colección `orders` solo contiene documentos con IDs en formato
  `YYYY-MM-DD`.
- Las colecciones `clients` y `products` de Firestore contienen los documentos
  necesarios para resolver nombres. Ya existen datasources para leerlos
  (`ClientFirestoreDataSource`, `ProductFirestoreDataSource`).
- El volumen de documentos en `orders` es manejable sin paginación (cientos, no
  miles) dado el modelo de negocio.
- La entidad `OrderSheet` existente es suficiente para representar los datos del
  historial sin necesidad de modificar su estructura.

## 11) Preguntas abiertas

- ~~**PA-01**~~: **Resuelta.** El listado de fechas muestra solo: fecha, número
  de clientes y número de productos. Al acceder al detalle de una fecha, se
  muestra la tabla completa igual que en "Pedidos de hoy" pero en modo solo
  lectura (incluyendo flags, notas, devoluciones, datos de facturación si los
  hubiera).

- ~~**PA-02**~~: **Resuelta.** Se excluye siempre la fecha del día actual,
  independientemente de si el pedido existe o no.

## 12) Notas para análisis técnico

- El `OrderFirestoreDataSource` de `orders_today` ya tiene los métodos
  `getOrderDocument(date)` y `getOrderRows(date)` necesarios para leer un pedido
  individual. Se debe evaluar si reutilizar este datasource directamente o crear
  uno dedicado para historial.
- Falta un método para **listar todos los documentos** de la colección `orders`
  (solo sus IDs/fechas). Este método no existe en el datasource actual y debe
  añadirse o crearse un datasource específico para historial.
- La resolución de nombres (IDs → nombres) requiere acceso a
  `ClientFirestoreDataSource` y `ProductFirestoreDataSource`, que ya existen en
  la feature `orders_today`. Evaluar si inyectarlos directamente en el
  repositorio de historial o extraerlos a `core/`.
- Los tipos de error del BLoC (`OrdersHistoryErrorType`) actualmente tienen
  `fileSystemError`, `invalidFormat`, `unknown` — heredados del backend de
  archivos. Deben adaptarse a errores de Firestore (ej: `serverError`,
  `networkError`).
- La construcción del `OrderSheet` a partir de `OrderDocumentModel` +
  `List<OrderRowModel>` + nombres ya está implementada en
  `OrdersTodayRepositoryImpl._buildOrderSheet()`. Evaluar reutilización.
- **Referencia anterior:**
  `docs/functional-analysis/2026-05-06-orders-history.md` (análisis original
  basado en archivos Excel, ya obsoleto).
- **Estado: Listo para análisis técnico**
