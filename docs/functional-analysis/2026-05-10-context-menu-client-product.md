# Functional Analysis: Menú contextual para clientes y productos

- **Fecha:** 2026-05-10
- **Identificador:** context-menu-client-product
- **Estado:** Ready for technical analysis

## 1) Resumen

Reemplazar los botones de eliminación (icono ✕) de clientes (columnas) y
productos (filas) en la tabla de pedidos por un **menú contextual** (click
derecho). El menú ofrecerá acciones específicas según el tipo de elemento: para
clientes incluye generación de hoja de pedido, factura provisional,
restablecimiento de pedido y eliminación; para productos solo eliminación. Se
eliminan los botones ✕ actuales.

## 2) Contexto y objetivo

- **Qué se solicita:** Sustituir la interacción actual de eliminación directa
  (botón ✕) por un menú contextual con click derecho, tanto en las cabeceras de
  columna (clientes) como en las celdas de la primera columna (productos).
- **Qué problema resuelve:** El botón ✕ es una interacción limitada que solo
  permite eliminar. Un menú contextual ofrece un punto de extensión para más
  acciones por elemento sin sobrecargar la UI visual.
- **Resultado funcional esperado:** El usuario puede hacer click derecho sobre
  un cliente o producto para ver un menú con opciones contextuales. Los botones
  ✕ desaparecen de la interfaz.

## 3) Alcance

### En alcance

- Implementar menú contextual al hacer click derecho en la cabecera de un
  cliente (columna).
- Implementar menú contextual al hacer click derecho en la celda de nombre de un
  producto (fila).
- Eliminar los botones ✕ existentes de clientes y productos.
- Opciones del menú de cliente: «Generar hoja de pedido», «Generar factura
  provisional», divisor, «Restablecer pedido», «Eliminar cliente».
- Opción del menú de producto: «Eliminar producto».
- Diálogos de confirmación para «Restablecer pedido», «Eliminar cliente» y
  «Eliminar producto».
- Las opciones «Generar hoja de pedido» y «Generar factura provisional» no
  ejecutan ninguna acción por ahora (placeholder).

### Fuera de alcance

- Lógica de generación de hoja de pedido (se implementará en el futuro).
- Lógica de generación de factura provisional (se implementará en el futuro).
- Menú contextual en celdas de datos (cantidades, pedidos, stocks, quedan).
- Selección múltiple de clientes o productos para acciones en lote desde el menú
  contextual.
- Cambios en la toolbar existente u otros mecanismos de eliminación/reset fuera
  de la tabla.

## 4) Actores implicados

- **Usuario final:** Operador que gestiona la tabla de pedidos diarios.
  Interactúa directamente con las cabeceras de clientes y las filas de
  productos.

## 5) Requisitos funcionales

- **RF-01:** Al hacer click derecho sobre la cabecera de un cliente (columna),
  se muestra un menú contextual con las opciones: «Generar hoja de pedido»,
  «Generar factura provisional», un divisor visual, «Restablecer pedido» y
  «Eliminar cliente».
- **RF-02:** Al hacer click derecho sobre la celda de nombre de un producto
  (fila), se muestra un menú contextual con la opción: «Eliminar producto».
- **RF-03:** Las opciones «Generar hoja de pedido» y «Generar factura
  provisional» se muestran en el menú **deshabilitadas** (grayed out / no
  interactivas) como placeholder para futuras funcionalidades.
- **RF-04:** La opción «Restablecer pedido» muestra un diálogo de confirmación.
  Si el usuario confirma, se eliminan todas las cantidades de ese cliente
  (equivalente a poner todos sus valores a 0 o vacío).
- **RF-05:** La opción «Eliminar cliente» muestra un diálogo de confirmación. Si
  el usuario confirma, se elimina la columna del cliente de la tabla.
- **RF-06:** La opción «Eliminar producto» muestra un diálogo de confirmación.
  Si el usuario confirma, se elimina la fila del producto de la tabla.
- **RF-07:** Se eliminan los botones ✕ (iconos `Icons.cancel`) que actualmente
  aparecen en las cabeceras de columna de clientes y en las filas de productos.
- **RF-08:** El menú contextual se posiciona en la ubicación del cursor del
  click derecho.

## 6) Criterios de aceptación

- **CA-01:** Click derecho sobre una cabecera de cliente muestra un menú con
  exactamente 5 elementos: 2 opciones de generación, 1 divisor, y 2 opciones
  destructivas.
- **CA-02:** Click derecho sobre un nombre de producto muestra un menú con
  exactamente 1 opción: «Eliminar producto».
- **CA-03:** No existen botones ✕ visibles en las cabeceras de clientes ni en
  las filas de productos.
- **CA-04:** «Eliminar cliente» muestra confirmación y, al aceptar, elimina la
  columna (mismo comportamiento que el botón ✕ anterior).
- **CA-05:** «Eliminar producto» muestra confirmación y, al aceptar, elimina la
  fila (mismo comportamiento que el botón ✕ anterior).
- **CA-06:** «Restablecer pedido» muestra confirmación y, al aceptar, pone a
  cero las cantidades del cliente.
- **CA-07:** «Generar hoja de pedido» y «Generar factura provisional» aparecen
  deshabilitadas (grayed out) y no son seleccionables.
- **CA-08:** Click izquierdo sobre la cabecera de cliente o nombre de producto
  NO muestra el menú contextual.
- **CA-09:** El menú se cierra al seleccionar una opción o al hacer click fuera
  de él.

## 7) Flujos y comportamiento esperado

### Flujo principal — Menú de cliente

1. El usuario hace click derecho sobre la cabecera de una columna de cliente.
2. Se muestra un menú contextual anclado a la posición del cursor.
3. El menú muestra:
   - «Generar hoja de pedido»
   - «Generar factura provisional»
   - ─── (divisor) ───
   - «Restablecer pedido»
   - «Eliminar cliente»
4. El usuario selecciona una opción.
5. Según la opción:
   - Hoja de pedido / Factura provisional → opciones deshabilitadas, no se
     pueden seleccionar.
   - Restablecer pedido → se muestra diálogo de confirmación → si acepta, se
     resetean las cantidades.
   - Eliminar cliente → se muestra diálogo de confirmación → si acepta, se
     elimina la columna.

### Flujo principal — Menú de producto

1. El usuario hace click derecho sobre la celda del nombre de un producto.
2. Se muestra un menú contextual anclado a la posición del cursor.
3. El menú muestra: «Eliminar producto».
4. El usuario selecciona «Eliminar producto».
5. Se muestra diálogo de confirmación → si acepta, se elimina la fila.

### Flujos alternativos

- **FA-01:** El usuario abre el menú contextual pero hace click fuera → el menú
  se cierra sin acción.
- **FA-02:** El usuario abre el menú contextual y pulsa Escape → el menú se
  cierra sin acción.
- **FA-03:** El usuario selecciona «Eliminar cliente» o «Eliminar producto» pero
  cancela en el diálogo de confirmación → no se realiza ningún cambio.
- **FA-04:** El usuario selecciona «Restablecer pedido» pero cancela en el
  diálogo de confirmación → no se realiza ningún cambio.

### Estados especiales / excepciones

- **Estado vacío:** Si la tabla no tiene clientes o productos, no hay elementos
  sobre los que mostrar el menú. No aplica.
- **Estado loading/procesando:** Si se está procesando una operación previa, el
  menú puede abrirse pero la acción se delega al callback existente (que ya
  gestiona este estado).
- **Estado error:** Los errores de las operaciones subyacentes (eliminar,
  resetear) se gestionan por la capa existente. No se requiere manejo adicional
  en el menú.

## 8) Edge cases

- **EC-01:** Click derecho rápido sucesivo sobre el mismo cliente → si el menú
  ya está abierto, se cierra y se reabre (comportamiento nativo de
  `showMenu`/`PopupMenuButton`).
- **EC-02:** Click derecho sobre la zona de la cabecera que no corresponde a un
  cliente (ej: columna de pedidos, stocks, quedan) → no se muestra menú
  contextual.
- **EC-03:** Click derecho sobre la celda de un producto que está filtrado por
  búsqueda → se muestra el menú con el producto correcto (el índice debe
  corresponder al producto real, no al filtrado).
- **EC-04:** El usuario confirma «Eliminar cliente» mientras otro usuario está
  editando una celda de ese cliente → la eliminación se procesa normalmente (la
  lógica de concurrencia ya existe en la capa de datos).

## 9) Impacto funcional

- **Módulos afectados:** `OrdersTable` widget (eliminación de botones ✕, adición
  de menús contextuales).
- **Impacto en usuario:** Cambio en la interacción para eliminar
  clientes/productos: de click sobre ✕ a click derecho + selección de opción.
  Requiere que el usuario conozca la convención de click derecho.
- **Impacto en experiencia de usuario:** La tabla queda visualmente más limpia
  al eliminar los iconos ✕. Se gana un punto de extensión para futuras acciones.
  El flujo requiere un paso adicional (click derecho → selección) respecto al
  anterior (click directo en ✕), pero a cambio se evitan eliminaciones
  accidentales y se centralizan las acciones por elemento.

## 10) Suposiciones

- Se asume que «Restablecer pedido» equivale a invocar el callback
  `onResetOrders` existente con el índice del cliente seleccionado.
- Se asume que los callbacks `onDeleteClients`, `onDeleteProducts` y
  `onResetOrders` ya implementados en `OrdersTable` siguen siendo la interfaz
  correcta para estas acciones.
- Se asume que el diálogo de confirmación para «Restablecer pedido» tendrá un
  estilo y tono similar a los diálogos de confirmación de eliminación
  existentes.
- Las opciones placeholder («Generar hoja de pedido», «Generar factura
  provisional») se muestran **deshabilitadas** (grayed out) para indicar que aún
  no están disponibles.

## 11) Preguntas abiertas

- Ninguna. Todas las preguntas han sido resueltas.

## 12) Notas para análisis técnico

- Los callbacks `onDeleteClients`, `onDeleteProducts` y `onResetOrders` ya
  existen en `OrdersTable` y están conectados desde `OrdersTodayPage`. Se
  reutilizan directamente.
- El método `_showDeleteConfirmation` existente puede reutilizarse para las
  confirmaciones de eliminación de cliente y producto.
- Para «Restablecer pedido» se necesita un diálogo de confirmación similar
  (puede ser el mismo método con un parámetro adicional o uno nuevo).
- La eliminación de los botones ✕ implica modificar `_buildProductCell` (quitar
  el `IconButton` con `Icons.cancel`) y la sección de cabecera de cliente dentro
  del builder de headers (quitar el `GestureDetector` con `Icons.cancel`).
- Se recomienda usar `showMenu()` de Flutter para el menú contextual posicional,
  capturando la posición del puntero con `GestureDetector.onSecondaryTapDown`.
- Los textos del menú deben internacionalizarse (i18n) añadiendo nuevas claves
  de localización.
- **Dependencia visible:** Las opciones «Generar hoja de pedido» y «Generar
  factura provisional» necesitarán callbacks futuros en `OrdersTable`. Por ahora
  no se añaden.
- **Estado: Listo para análisis técnico**
