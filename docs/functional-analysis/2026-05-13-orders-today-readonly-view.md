# Functional Analysis: Vista de solo lectura de pedidos de hoy (pantalla empaquetado)

- **Fecha:** 2026-05-13
- **Identificador:** orders-today-readonly-view
- **Estado:** Ready for technical analysis

## 1) Resumen

Al pulsar el botón de "ampliar" (icono `open_in_full`) en la esquina inferior
derecha de la pantalla de pedidos de hoy, se abre una nueva ventana/pestaña del
navegador con la tabla de pedidos del día en modo solo lectura, sin menú
lateral, optimizada para monitores grandes en la zona de empaquetado. La vista
se actualiza en tiempo real mediante los listeners de Firestore existentes y
muestra la fecha/hora de la última modificación.

## 2) Contexto y objetivo

- **Qué se solicita:** Una vista de solo lectura de la tabla de pedidos de hoy
  accesible desde una nueva ventana del navegador, pensada para ser mostrada en
  un monitor grande en la zona de empaquetado.
- **Qué problema resuelve:** Los empleados del área de empaquetado necesitan ver
  los pedidos del día en tiempo real sin tener que interactuar con la aplicación
  completa. Actualmente no existe una forma de visualizar la tabla en una
  pantalla secundaria dedicada.
- **Qué resultado funcional se espera:** Una pantalla a pantalla completa (sin
  menú lateral) que muestra la misma tabla de pedidos de hoy, actualizada
  automáticamente, con la fecha/hora de última modificación visible.

## 3) Alcance

### En alcance

- Acción del botón "ampliar" existente: abrir nueva ventana/pestaña del
  navegador con la ruta de la vista de solo lectura
- Nueva ruta/página dedicada para la vista de solo lectura
- Tabla de pedidos con el mismo diseño visual que `OrdersTable`
- Modo solo lectura: sin edición de celdas, sin menú contextual de edición, sin
  toolbar de acciones (eliminar, resetear)
- Sin menú lateral (`SideMenuShell`): la tabla ocupa todo el espacio disponible
- Actualización en tiempo real vía `watchTodayOrders` de Firestore (mecanismo ya
  existente)
- Mostrar fecha y hora de última modificación en la esquina inferior derecha de
  la tabla
- Sin botones de acción (exportar Excel, ampliar, añadir cliente/producto)
- Sin sección de usuarios conectados en el footer

### Fuera de alcance

- Edición de celdas desde la vista de solo lectura
- Autenticación específica para esta vista (se usa la sesión existente del
  navegador)
- Diseño responsivo para móviles (la vista es exclusivamente para monitores
  grandes)
- Funcionalidad offline
- Personalización del diseño de la tabla (zoom, colores, etc.)
- Modo kiosco o auto-inicio del navegador

## 4) Actores implicados

- **Usuario editor (back-office):** Pulsa el botón ampliar desde la pantalla de
  pedidos de hoy para abrir la vista en un monitor secundario.
- **Empleado de empaquetado (consumidor visual):** Visualiza la tabla en el
  monitor grande; no interactúa con la aplicación.

## 5) Requisitos funcionales

- **RF-01:** Al pulsar el botón "ampliar" (`Icons.open_in_full`) en el footer de
  la tabla de pedidos de hoy, se abre una nueva ventana/pestaña del navegador
  con la URL de la vista de solo lectura.
- **RF-02:** La vista de solo lectura muestra la tabla de pedidos de hoy con el
  mismo diseño visual (productos × clientes, columnas ADELANTAR, PEDIDOS,
  STOCKS, QUEDAN, colores, nombres de productos y clientes).
- **RF-03:** La tabla se muestra sin menú lateral, ocupando el 100% del ancho y
  alto disponible de la ventana.
- **RF-04:** Las celdas de la tabla NO son editables (no se activa edición al
  hacer clic/doble clic).
- **RF-05:** No se muestran acciones de edición: toolbar de eliminar/resetear,
  botones de añadir cliente/producto, exportar Excel, botón ampliar ni menú
  contextual de edición.
- **RF-06:** La tabla se actualiza automáticamente cuando se realizan cambios en
  los pedidos de hoy desde la pantalla principal, utilizando los listeners de
  Firestore ya existentes (`watchTodayOrders`).
- **RF-07:** En la esquina inferior derecha de la vista se muestra la fecha y
  hora de la última modificación del documento de pedidos, formateada de forma
  legible (ej: "Última actualización: 13/05/2026 14:32:05").
- **RF-08:** La vista requiere autenticación (misma sesión de Firebase Auth). Si
  el usuario no está autenticado, se redirige al login.
- **RF-09:** El campo `lastModifiedAt` ya existe en el documento de Firestore
  (`orders/{YYYY-MM-DD}`) y se actualiza con cada operación de escritura. Este
  campo debe estar disponible en la entidad `OrderSheet` para poder mostrarlo en
  la vista.
- **RF-10:** Se muestra un punto verde parpadeante (animación) junto a la
  fecha/hora de última modificación como indicador de que la vista está
  conectada y recibiendo datos en tiempo real vía Firestore.

## 6) Criterios de aceptación

- **CA-01:** Pulsar el botón ampliar abre una nueva pestaña/ventana del
  navegador con la tabla de pedidos de hoy.
- **CA-02:** La nueva ventana no muestra menú lateral ni barra de navegación de
  la aplicación.
- **CA-03:** La tabla muestra los mismos datos (productos, clientes, cantidades,
  PEDIDOS, STOCKS, QUEDAN) que la pantalla de pedidos de hoy.
- **CA-04:** Al modificar una celda en la pantalla de edición, el cambio se
  refleja automáticamente en la vista de solo lectura en menos de ~2 segundos.
- **CA-05:** No es posible editar ninguna celda ni ejecutar ninguna acción de
  modificación desde la vista de solo lectura.
- **CA-06:** Se muestra la fecha y hora de la última modificación en la esquina
  inferior derecha.
- **CA-07:** La fecha/hora de última modificación se actualiza automáticamente
  cuando se reciben cambios de Firestore.
- **CA-08:** Si el usuario no está autenticado y accede a la URL directamente,
  se redirige a la pantalla de login.
- **CA-09:** Se muestra un punto verde parpadeante junto al timestamp de última
  modificación mientras la conexión con Firestore está activa.
- **CA-10:** Si la conexión con Firestore se pierde, el punto verde deja de
  parpadear o cambia de estado visual (ej: gris).

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario navega a "Pedidos de hoy" en la aplicación.
2. La tabla de pedidos se carga con los datos del día.
3. El usuario pulsa el botón "ampliar" (icono `open_in_full`) en la esquina
   inferior derecha.
4. Se abre una nueva pestaña/ventana del navegador con la URL de la vista de
   solo lectura (ej: `/orders-today/view`).
5. La vista carga los datos de pedidos del día y suscribe el listener de
   Firestore.
6. La tabla se muestra a pantalla completa (sin menú lateral).
7. Cuando un editor modifica un pedido en la pantalla principal, el cambio se
   propaga en tiempo real a la vista de solo lectura.
8. La fecha/hora de última modificación se actualiza con cada cambio recibido.

### Flujos alternativos

- **FA-01 — Acceso directo por URL:** Un usuario autenticado navega directamente
  a la URL de solo lectura. La vista carga correctamente sin necesidad de pasar
  por la pantalla de edición.
- **FA-02 — No hay pedidos del día:** Si aún no se ha creado el documento de
  pedidos del día, la vista muestra un estado vacío o mensaje indicativo (no
  debe intentar crear el documento).
- **FA-03 — Sesión expirada:** Si la sesión de Firebase Auth expira mientras la
  vista está abierta, se redirige al login al intentar reconectarse.

### Estados especiales / excepciones

- **Estado vacío:** Si no existe el documento de pedidos del día, mostrar un
  mensaje tipo "No hay pedidos para hoy" sin opción de crear.
- **Estado loading:** Mostrar indicador de carga centrado mientras se obtienen
  los datos iniciales.
- **Estado error:** Si falla la carga desde Firestore, mostrar mensaje de error
  con opción de reintentar (solo recarga, no edición).
- **Sin conexión:** Si se pierde la conexión, Firestore SDK mantiene la última
  versión en caché. La tabla continúa mostrando los últimos datos conocidos.

## 8) Edge cases

- **EC-01:** Se añade o elimina un cliente/producto en la pantalla principal
  mientras la vista de solo lectura está abierta → la tabla debe reflejar el
  cambio estructural (nueva columna/fila o eliminación).
- **EC-02:** Múltiples ventanas de solo lectura abiertas simultáneamente → cada
  una tiene su propia suscripción a Firestore; todas se actualizan
  independientemente.
- **EC-03:** El botón ampliar se pulsa cuando la tabla aún está en estado de
  carga → no se debe abrir la ventana hasta que los datos estén cargados (el
  botón solo aparece con estado `OrdersTodayLoaded`).
- **EC-04:** El navegador bloquea la apertura de la nueva ventana (bloqueador de
  popups) → usar `window.open` o `url_launcher` de forma que sea una acción
  directa del usuario (no asíncrona) para evitar el bloqueo.
- **EC-05:** La ventana se deja abierta de un día para otro → al cambiar de día,
  la vista seguirá mostrando los pedidos del día en que se abrió (no se
  auto-actualiza al día siguiente). Esto es aceptable.

## 9) Impacto funcional

- **Módulos afectados:**
  - `orders_today`: nueva página de solo lectura, reutilización del widget
    `OrdersTable` en modo solo lectura.
  - `app/router`: nueva ruta fuera del `ShellRoute` (sin `SideMenuShell`).
  - `domain/entities/order_sheet.dart`: podría requerir añadir `lastModifiedAt`
    a la entidad para mostrarlo en la UI.
- **Impacto en usuario:** Mejora la visibilidad operativa para empleados de
  empaquetado sin necesidad de acceder a la aplicación completa.
- **Impacto en experiencia de usuario:** La pantalla principal no se ve
  afectada. El botón ampliar que actualmente no tiene funcionalidad asignada
  (`onPressed: () {}`) pasa a tener una acción concreta.

## 10) Suposiciones

- El widget `OrdersTable` actual puede configurarse en modo solo lectura
  anulando todos los callbacks de edición (`onCellUpdated`, `onCellFlagUpdated`,
  etc.) y los callbacks de acción (`onAddClient`, `onAddProduct`,
  `onDeleteClients`, etc.).
- La suscripción `watchTodayOrders` del repositorio ya emite actualizaciones en
  tiempo real incluyendo cambios estructurales (añadir/eliminar
  clientes/productos).
- El campo `lastModifiedAt` ya se persiste en Firestore en cada operación de
  escritura y se puede propagar a la capa de dominio sin cambios significativos.
- La sesión de Firebase Auth se comparte entre pestañas del mismo navegador
  (comportamiento estándar de Firebase Auth web).
- La web app está desplegada en Firebase Hosting y el routing funciona con URLs
  directas (ya confirmado por el análisis existente `web-only-url-routing`).

## 11) Preguntas abiertas

- ~~**PA-01:** ¿Acceso sin autenticación?~~ → **Resuelto:** Requiere
  autenticación (Firebase Auth). No se expone como URL pública.
- ~~**PA-02:** ¿Indicador visual de conexión en vivo?~~ → **Resuelto:** Sí, se
  muestra un punto verde parpadeante junto a la fecha/hora de última
  modificación para indicar que la vista está conectada y recibiendo datos en
  tiempo real.

## 12) Notas para análisis técnico

- El botón ampliar ya existe en la UI con `onPressed: () {}` vacío — solo hay
  que conectar la acción.
- La ruta de solo lectura debe estar **fuera** del `ShellRoute` que envuelve con
  `SideMenuShell`, para que no se renderice el menú lateral.
- Reutilizar `OrdersTable` pasando todos los callbacks de edición como `null` y
  sin `footerTrailing` debería ser suficiente para el modo solo lectura.
  Verificar que el widget maneja correctamente los callbacks nulos (no muestra
  campos editables ni menús contextuales).
- `lastModifiedAt` existe en `OrderDocumentModel` pero **no** se propaga a la
  entidad `OrderSheet`. Será necesario añadirlo a `OrderSheet` y al mapping del
  repositorio.
- Para abrir la nueva ventana, usar `dart:html` (`window.open`) en web, con la
  URL de la ruta de solo lectura.
- La nueva página necesita su propio `BlocProvider<OrdersTodayBloc>` que solo
  cargue y escuche cambios (sin operaciones de escritura).
- El guard de autenticación del router ya redirige a login si no hay sesión
  activa — la nueva ruta se beneficia automáticamente.
- **Estado: Listo para análisis técnico**
