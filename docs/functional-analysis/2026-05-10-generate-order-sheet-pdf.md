# Functional Analysis: Generación de hoja de pedido en PDF

- **Fecha:** 2026-05-10
- **Identificador:** generate-order-sheet-pdf
- **Estado:** Ready for technical analysis

## 1) Resumen

Implementar la funcionalidad del botón «Generar hoja de pedido» del menú
contextual de cliente en la tabla de pedidos del día. Al pulsar esta opción, se
genera un documento PDF estilizado con los datos del pedido de ese cliente
(productos, cantidades y notas), pensado para que los trabajadores lo impriman y
lo usen como guía para preparar el paquete físico del pedido.

## 2) Contexto y objetivo

- **Qué se solicita:** Activar la opción «Generar hoja de pedido» (actualmente
  deshabilitada como placeholder) en el menú contextual que aparece al hacer
  click derecho sobre un cliente en la cabecera de la tabla de pedidos. Al
  seleccionarla, se genera un PDF con los datos del pedido de ese cliente y se
  presenta al usuario para su impresión o descarga.
- **Qué problema resuelve:** Actualmente no existe un mecanismo para generar una
  ficha imprimible por cliente. Los trabajadores que preparan los paquetes
  necesitan saber qué productos y cantidades incluir para cada cliente. Sin esta
  ficha, deben consultar la pantalla directamente o anotar los datos a mano, lo
  cual es propenso a errores.
- **Resultado funcional esperado:** El usuario genera un PDF con formato
  profesional y legible que contiene la información necesaria para preparar el
  pedido de un cliente concreto. El documento se puede imprimir directamente o
  guardar como archivo.

## 3) Alcance

### En alcance

- Generación de un documento PDF al seleccionar «Generar hoja de pedido» en el
  menú contextual de un cliente.
- Contenido del PDF: datos de cabecera (cliente, fecha, hora de generación) y
  tabla de productos con cantidades y notas.
- Solo se incluyen productos con cantidad mayor a 0 para ese cliente.
- Diseño estilizado del PDF (cabecera con datos del cliente, tabla con estilo
  visual claro, bordes, colores de fondo en cabeceras de tabla).
- Presentación del PDF al usuario mediante diálogo de impresión/previsualización
  del sistema operativo (para imprimir o guardar).
- Habilitar la opción de menú (actualmente `enabled: false`).

### Fuera de alcance

- Generación de factura provisional (opción separada del menú, sigue
  deshabilitada).
- Generación de hojas de pedido en lote (múltiples clientes a la vez).
- Envío del PDF por email, WhatsApp u otro canal.
- Almacenamiento persistente del PDF generado (no se guarda automáticamente en
  ningún directorio del proyecto ni en la nube).
- Personalización del formato por parte del usuario (plantillas, logotipos
  configurables, etc.).
- Inclusión de precios, totales o información fiscal en la hoja de pedido.

## 4) Actores implicados

- **Usuario operador:** Gestiona la tabla de pedidos diarios en la aplicación de
  escritorio. Hace click derecho sobre un cliente para generar la hoja de
  pedido.
- **Trabajador de preparación (usuario indirecto):** Recibe la hoja impresa y la
  utiliza como guía para preparar el paquete del cliente. No interactúa con la
  aplicación.

## 5) Requisitos funcionales

- **RF-01:** Al seleccionar «Generar hoja de pedido» en el menú contextual de un
  cliente, se genera un documento PDF con los datos del pedido de ese cliente.
- **RF-02:** El PDF incluye una sección de cabecera con: nombre del cliente,
  fecha del pedido (según la hoja de pedidos del día) y hora de generación del
  documento.
- **RF-03:** El PDF incluye una tabla de productos con tres columnas: Producto,
  Cantidad y Notas.
- **RF-04:** Solo se incluyen en la tabla los productos cuya cantidad asignada
  al cliente sea mayor que 0.
- **RF-05:** Si un producto tiene una nota asociada al cliente (campo
  `cellNotes`), esta se muestra en la columna Notas de la fila correspondiente.
- **RF-06:** El PDF tiene un diseño estilizado y profesional: cabeceras de tabla
  con fondo diferenciado, bordes definidos, tipografía clara y legible,
  espaciado adecuado.
- **RF-07:** Una vez generado el PDF, se presenta al usuario mediante el diálogo
  nativo de impresión/previsualización del sistema operativo, permitiendo
  imprimir directamente o guardar como archivo PDF.
- **RF-08:** La opción «Generar hoja de pedido» del menú contextual pasa a estar
  habilitada (actualmente está deshabilitada como placeholder).
- **RF-09:** Los productos se listan en el mismo orden en que aparecen en la
  tabla de pedidos.
- **RF-10:** Si el cliente no tiene ningún producto con cantidad > 0, se debe
  informar al usuario de que no hay productos para generar la hoja (no se genera
  PDF vacío).

## 6) Criterios de aceptación

- **CA-01:** Al hacer click derecho sobre un cliente y seleccionar «Generar hoja
  de pedido», se abre el diálogo de impresión/previsualización con un PDF
  generado.
- **CA-02:** El PDF muestra correctamente el nombre del cliente, la fecha del
  pedido y la hora de generación.
- **CA-03:** La tabla del PDF contiene únicamente los productos con cantidad > 0
  para ese cliente, con las columnas Producto, Cantidad y Notas.
- **CA-04:** Las notas asociadas a celdas de ese cliente se muestran
  correctamente en la columna Notas del producto correspondiente.
- **CA-05:** Los productos sin nota muestran la celda de Notas vacía.
- **CA-06:** El PDF tiene un diseño visual profesional: cabeceras con fondo de
  color, bordes en las tablas, tipografía legible.
- **CA-07:** Si el cliente no tiene productos con cantidad > 0, se muestra un
  mensaje informativo al usuario y no se genera PDF.
- **CA-08:** La opción «Generar hoja de pedido» en el menú contextual aparece
  habilitada y es seleccionable.
- **CA-09:** El diálogo de impresión/previsualización permite al usuario
  imprimir o guardar el PDF como archivo.
- **CA-10:** El orden de los productos en el PDF coincide con el orden en la
  tabla de pedidos.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario abre la pantalla de «Pedidos de hoy» con una hoja de pedidos
   cargada.
2. El usuario hace click derecho sobre el nombre de un cliente en la cabecera de
   la tabla.
3. Se muestra el menú contextual con la opción «Generar hoja de pedido»
   habilitada.
4. El usuario selecciona «Generar hoja de pedido».
5. El sistema extrae los datos del pedido del cliente: nombre, fecha, productos
   con cantidad > 0 y notas asociadas.
6. El sistema genera un PDF estilizado con la cabecera (cliente, fecha, hora) y
   la tabla de productos.
7. Se abre el diálogo nativo de impresión/previsualización del sistema operativo
   con el PDF generado.
8. El usuario imprime el documento o lo guarda como archivo desde el diálogo del
   SO.

### Flujos alternativos

- **FA-01 — Cliente sin productos pedidos:** En el paso 5, si ningún producto
  tiene cantidad > 0 para ese cliente, se muestra un mensaje informativo
  (snackbar o diálogo) indicando que no hay productos en el pedido y no se
  genera PDF. El flujo termina.
- **FA-02 — Usuario cancela el diálogo:** En el paso 8, el usuario cierra el
  diálogo de impresión sin imprimir ni guardar. No se produce ningún efecto
  adicional.
- **FA-03 — Productos con notas:** En el paso 5, algunos productos tienen notas
  asociadas (`cellNotes`) al cliente. Estas se incluyen en la columna Notas del
  PDF junto al producto correspondiente.

### Estados especiales / excepciones

- **Estado error en generación:** Si ocurre un error durante la generación del
  PDF, se muestra un mensaje de error al usuario (snackbar). No se abre el
  diálogo de impresión.
- **Estado carga:** La generación del PDF debería ser prácticamente instantánea
  dado el volumen de datos (decenas de filas como máximo). No se requiere
  indicador de carga explícito, pero si se detectara latencia, se podría añadir
  un indicador breve.

## 8) Edge cases

- **EC-01:** Cliente con un solo producto con cantidad > 0 → Se genera PDF con
  una sola fila en la tabla.
- **EC-02:** Cliente con todos los productos con cantidad > 0 → Se genera PDF
  con todos los productos. Si la tabla supera una página, el contenido debe
  fluir a la siguiente página.
- **EC-03:** Nombre de cliente con caracteres especiales (tildes, ñ, etc.) → Se
  muestra correctamente en el PDF.
- **EC-04:** Nombre de producto muy largo → Se ajusta (word wrap) dentro de la
  celda de la tabla sin truncarse.
- **EC-05:** Nota con texto largo → Se ajusta (word wrap) dentro de la celda de
  Notas sin truncarse.
- **EC-06:** Cantidades decimales (ej: 0.5) → Se muestran tal como aparecen en
  la tabla, sin redondeo.
- **EC-07:** Cantidad = 0 exacto → El producto no se incluye en el PDF (solo >
  0).

## 9) Impacto funcional

- **Módulos afectados:** Feature `orders_today` (presentación — menú contextual;
  lógica de extracción de datos; generación de PDF).
- **Impacto en usuario:** Mejora significativa en la operativa diaria. Los
  trabajadores de preparación disponen de una ficha impresa clara para montar
  los pedidos sin consultar la pantalla.
- **Impacto en experiencia de usuario:** La opción del menú contextual pasa de
  deshabilitada a funcional, completando la interacción prevista desde el diseño
  original del menú.
- **Impacto en datos:** Ninguno. La generación del PDF es de solo lectura; no
  modifica el estado de la hoja de pedidos ni escribe datos en Firestore ni en
  ningún almacenamiento persistente.

## 10) Suposiciones

- **S-01:** El paquete `pdf` (ya incluido en `pubspec.yaml`) es suficiente para
  generar PDFs con diseño estilizado en entorno desktop (Windows/macOS).
- **S-02:** Se utilizará el paquete `printing` (o equivalente) para presentar el
  diálogo nativo de impresión/previsualización. Se asume que es compatible con
  las plataformas objetivo (Windows y macOS).
- **S-03:** No se requiere incluir logotipo de empresa en el PDF en esta primera
  versión.
- **S-04:** No se requiere incluir precios ni información económica. La hoja es
  exclusivamente para preparación logística del paquete.
- **S-05:** Las notas de celda (`cellNotes`) son el único dato adicional
  relevante por producto. Las flags (`compensation`, `reservation`) y refunds no
  se incluyen en la hoja de pedido.
- **S-06:** El formato de fecha en el PDF sigue el formato local del usuario
  (ej: `10/05/2026`).

## 11) Preguntas abiertas

- **PA-01:** ¿Se desea incluir el logotipo de la empresa en la cabecera del PDF
  en una futura iteración? (Asumido: no en esta versión.)
- **PA-02:** ¿Se desea que el nombre del archivo sugerido al guardar siga alguna
  convención específica? (Propuesta: `Pedido_<NombreCliente>_<YYYY-MM-DD>.pdf`)
- **PA-03:** ¿Deben incluirse las filas de productos con flags de compensación o
  reserva de forma diferenciada en el PDF, o simplemente se tratan como
  productos normales con su cantidad?

## 12) Notas para análisis técnico

- La opción del menú contextual ya existe en `_showClientContextMenu` de
  `OrdersTable` con `enabled: false` y valor `'generate_order_sheet'`. Solo
  requiere habilitarla y añadir el handler en el `switch`.
- Los datos necesarios están disponibles en el `OrderSheet`: `clients[col]`,
  `clientIds[col]`, `date`, `quantities[p][col]`, `products[p]`,
  `cellNotes[p][clientId]`.
- El paquete `pdf` (v3.12.0) ya está en `pubspec.yaml`. El paquete `printing` no
  está incluido y debería añadirse para el diálogo nativo de
  impresión/previsualización.
- Se recomienda crear un servicio de generación PDF en la capa de datos
  (`data/services/`) siguiendo los patrones del proyecto.
- La generación es síncrona y de solo lectura — no requiere interacción con
  BLoC, repositorio ni Firestore.
- Plataformas objetivo: Windows (producción) y macOS (desarrollo/test).
  Verificar compatibilidad del paquete `printing` en ambas.

**Estado: Listo para análisis técnico**
