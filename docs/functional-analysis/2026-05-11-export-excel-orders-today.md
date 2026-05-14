# Functional Analysis: Exportar Excel desde Pedidos de Hoy

- **Fecha:** 2026-05-11
- **Identificador:** export-excel-orders-today
- **Estado:** Ready for technical analysis

---

## 1) Resumen

Añadir un botón "Exportar Excel" en la esquina inferior derecha de la pantalla
_Pedidos de Hoy_ para generar y descargar un archivo `.xlsx` que reproduzca
fielmente la tabla de pedidos del día, incluyendo coloración de celdas según su
estado (reserva, compensación, stock estricto, quedan crítico).

---

## 2) Contexto y objetivo

**Qué se solicita:** Un `FloatingActionButton` (o botón fijo) en la parte
inferior derecha de la pantalla de Pedidos de Hoy que, al pulsarse, genere un
archivo Excel descargable con el contenido actual de la tabla.

**Qué problema resuelve:** El equipo necesita compartir/archivar el estado de
pedidos del día en formato Excel, conservando la misma estructura visual
(colores, columnas especiales) que se trabaja actualmente en Google Sheets, para
facilitar la coordinación y el registro.

**Resultado funcional esperado:** Al pulsar el botón, el usuario obtiene un
archivo `.xlsx` con:

- La misma estructura de filas (productos) y columnas (clientes +
  PEDIDOS/STOCKS/QUEDAN) que aparece en pantalla.
- Coloración de celdas acorde al estado de cada celda (reserva = azul,
  compensación = verde, stock estricto = rojo en la celda de stock, quedan
  crítico = naranja).
- Nombre de archivo sugerido con la fecha del día.

---

## 3) Alcance

### En alcance

- Botón "Exportar Excel" posicionado en la parte inferior derecha de la pantalla
  de Pedidos de Hoy.
- Generación de un archivo `.xlsx` con la estructura de la tabla actual.
- Columnas: nombre del producto (congelado a la izquierda) + una columna por
  cliente + PEDIDOS + STOCKS + QUEDAN.
- Fila de cabecera con: día y fecha (estilo "SÁBADO, 28 MARZO") + nombres de
  clientes + etiquetas PEDIDOS/STOCKS/QUEDAN.
- Fila de números de orden de cliente (fila 2 de la captura).
- Datos numéricos de cantidades, pedidos, stocks y quedan por producto.
- Coloración de celdas:
  - **Reserva** → azul (equivalente a `reservation`, color `#BBDEFB`).
  - **Compensación** → verde (equivalente a `compensation`, color `#C8E6C9`).
  - **Stock estricto** → texto/fondo rojo en la celda de STOCKS del producto
    afectado.
  - **QUEDAN crítico** → naranja si el valor de QUEDAN es menor a un umbral
    configurable (supuesto: 10 unidades, ver Suposiciones).
  - **QUEDAN negativo** → rojo (ya ocurre en la UI actual).
- Soporte de plataformas: macOS y Web (las plataformas target del proyecto).
- Diálogo de guardar archivo (save dialog) para elegir ubicación, consistente
  con el flujo ya implementado en `_generateOrderSheetPdf`.
- Filtrado de búsqueda respetado: si hay un filtro activo en la tabla, el Excel
  solo incluye las filas visibles.

### Fuera de alcance

- Exportación de notas de celda (tooltip de nota) como comentarios Excel — se
  puede incluir como texto pero no como comentario nativo de celda en esta
  versión.
- Exportación de devoluciones (refunds) como columna separada.
- Exportación del historial de pedidos (otras fechas).
- Envío por email o subida a Google Drive automática.
- Edición del Excel dentro de la app.
- Exportación mientras la tabla está en estado de carga o error.

---

## 4) Actores implicados

- **Usuario operador de reparto** — persona que gestiona la tabla de pedidos del
  día y necesita exportarla.
- **Sistema** — la app Flutter/Dart que genera y descarga el archivo.

---

## 5) Requisitos funcionales

- **RF-01:** Existirá un botón "Exportar Excel" (`FloatingActionButton` o
  equivalente) visible en la parte inferior derecha de la pantalla de Pedidos de
  Hoy, únicamente cuando el estado sea `OrdersTodayLoaded`.
- **RF-02:** Al pulsar el botón, el sistema generará un archivo `.xlsx` con la
  estructura completa de la tabla de pedidos del día (cabeceras + filas de
  producto + columnas de cliente + columnas resumen).
- **RF-03:** El Excel incluirá una fila de cabecera con el día y la fecha
  formateados (ej: "SÁBADO, 28 MARZO") en la celda de producto, y los nombres de
  clientes en las columnas correspondientes, más las etiquetas PEDIDOS, STOCKS,
  QUEDAN.
- **RF-04:** El Excel incluirá una segunda fila de cabecera con los números de
  orden de cada cliente (del 1 al N).
- **RF-05:** Cada fila de producto mostrará los valores numéricos de cantidad
  por cliente, total pedido, stock y quedan.
- **RF-06:** Las celdas de cliente marcadas como **reserva** se rellenarán con
  fondo azul (`#BBDEFB`).
- **RF-07:** Las celdas de cliente marcadas como **compensación** se rellenarán
  con fondo verde (`#C8E6C9`).
- **RF-08:** La celda de STOCKS de un producto marcado como **stock estricto**
  se coloreará con fondo rojo o texto rojo (color de peligro, `#FF1744` o
  equivalente).
- **RF-09:** ~~Las celdas de la columna QUEDAN con valor menor al umbral crítico
  se rellenarán con fondo naranja.~~ **Descartado** — no habrá coloración
  naranja por umbral en el Excel.
- **RF-10:** Las celdas de la columna QUEDAN con valor negativo se rellenarán
  con fondo rojo.
- **RF-11:** El Excel exporta **siempre la tabla completa**, independientemente
  de si hay un filtro de búsqueda activo en pantalla.
- **RF-12:** El nombre de archivo sugerido seguirá el patrón
  `Pedidos_YYYY-MM-DD.xlsx`.
- **RF-13:** El sistema presentará un diálogo nativo de guardar archivo (save
  dialog) para que el usuario elija la ubicación de descarga.
- **RF-14:** El botón estará deshabilitado o ausente en estados distintos a
  `OrdersTodayLoaded` (loading, error, sin archivo).

---

## 6) Criterios de aceptación

- **CA-01:** Al pulsar "Exportar Excel" con datos cargados, se abre un save
  dialog y al confirmar se genera un archivo `.xlsx` válido en la ruta
  seleccionada.
- **CA-02:** El Excel generado tiene tantas filas de datos como productos
  visibles en la tabla (respetando el filtro activo).
- **CA-03:** El Excel generado tiene tantas columnas de datos como clientes + 3
  columnas resumen (PEDIDOS, STOCKS, QUEDAN).
- **CA-04:** Las celdas de reserva tienen fondo azul en el Excel exportado.
- **CA-05:** Las celdas de compensación tienen fondo verde en el Excel
  exportado.
- **CA-06:** La celda de stock de un producto con stock estricto tiene fondo o
  texto rojo.
- **CA-07:** Las celdas de QUEDAN con valor negativo tienen fondo rojo. No se
  aplica coloración naranja por umbral.
- **CA-08:** El archivo se llama `Pedidos_YYYY-MM-DD.xlsx` con la fecha del día
  actual.
- **CA-09:** Si el usuario cancela el save dialog, no se genera ningún archivo y
  la app vuelve al estado normal.
- **CA-10:** El botón no aparece (o está deshabilitado) cuando la tabla está en
  estado de carga o error.

---

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario está en la pantalla de Pedidos de Hoy con datos cargados
   (`OrdersTodayLoaded`).
2. El usuario pulsa el botón "Exportar Excel" (inferior derecha).
3. El sistema muestra un indicador de progreso breve (o el botón se deshabilita
   temporalmente) mientras genera el `.xlsx` en memoria.
4. El sistema presenta el diálogo nativo de guardar archivo con el nombre
   sugerido `Pedidos_YYYY-MM-DD.xlsx`.
5. El usuario elige la ubicación y confirma.
6. El sistema escribe el archivo en disco.
7. El sistema muestra un `SnackBar` de éxito ("Excel exportado correctamente").
8. La app vuelve al estado normal.

### Flujos alternativos

- **FA-01 — Usuario cancela el save dialog:** No se genera ningún archivo. No se
  muestra mensaje de error. La app continúa normalmente.
- **FA-02 — Filtro activo:** Aunque haya un filtro de búsqueda activo en
  pantalla, el Excel exporta siempre la tabla completa (todos los productos).
- **FA-03 — Tabla sin clientes o sin productos:** El Excel se genera con la
  estructura de cabeceras pero sin filas de datos (o sin columnas de clientes).
  Se muestra el Excel vacío sin error.

### Estados especiales / excepciones

- **Estado loading/generando:** El botón se deshabilita mientras se genera el
  archivo.
- **Error de escritura en disco:** Se muestra un `SnackBar` de error ("Error al
  exportar el Excel").
- **Estado no cargado:** El botón no se muestra (el widget solo se renderiza en
  `OrdersTodayLoaded`).

---

## 8) Edge cases

- **EC-01:** Producto con todas las cantidades a 0 — se exporta igualmente con
  valores vacíos o cero.
- **EC-02:** Nombre de cliente o producto con caracteres especiales (`/`, `\`,
  `:`) — el nombre de archivo se sanitiza; los nombres en las celdas se escriben
  tal cual.
- **EC-03:** Tabla con más de 25 clientes (más columnas que en la captura de
  referencia) — el Excel se genera con tantas columnas como sean necesarias; no
  hay límite máximo.
- **EC-04:** Celda con flag `compensation` Y valor cero — se exporta con fondo
  verde y valor vacío/cero.
- **EC-05:** Una celda de QUEDAN con valor exactamente 0 — no es negativo, no se
  colorea. Solo se colorea rojo si el valor es negativo.
- **EC-06:** Stock estricto con valor 0 — la celda de STOCKS se muestra en rojo.
- **EC-07:** Nombre de producto muy largo — no truncar en el Excel; el texto se
  adapta a la celda.

---

## 9) Impacto funcional

- **Módulos afectados:** `orders_today/presentation` (página, tabla, footer o
  FAB nuevo).
- **Impacto en usuario:** Añade una funcionalidad nueva no destructiva. No
  modifica datos ni flujos existentes.
- **Impacto en UX:** El botón de exportar Excel coexiste con el flujo actual
  (generación de PDF de albarán por cliente). Son acciones independientes.
- **Sin impacto en Firestore:** La exportación es de solo lectura sobre el
  `OrderSheet` ya cargado en memoria.

---

## 10) Suposiciones

- **S-01:** ~~Umbral naranja de QUEDAN~~ — **Eliminado**. No habrá coloración
  naranja por umbral. Solo rojo para valores negativos.
- **S-02:** Las notas de celda **no** se incluyen como comentarios nativos Excel
  en esta versión (complejidad añadida). Pueden añadirse en una iteración
  futura.
- **S-03:** Los abonos/devoluciones (refunds) **se suman a la cantidad de la
  celda** del cliente correspondiente en el Excel. El valor exportado en cada
  celda de cliente es `cantidad + refund` (equivalente al valor ya sumado en
  `pedidos`). No se añade columna separada de abonos.
- **S-04:** El formato de cabecera del día sigue el patrón de la captura:
  "SÁBADO, 28 MARZO" (sin año).
- **S-05:** El filtro de búsqueda activo **no** afecta al contenido del Excel.
  El Excel exporta siempre la tabla completa.
- **S-06:** La plataforma objetivo principal es **macOS desktop** y **web**
  (según la estructura del proyecto). En web, la descarga usará el mecanismo de
  descarga de archivos del navegador en lugar de un save dialog nativo.
- **S-07:** Los colores del Excel se corresponden con los colores usados en la
  UI: reserva `#BBDEFB`, compensación `#C8E6C9`, peligro `#FF1744`, naranja
  `#FFA726` (o similar del tema).

---

## 11) Preguntas abiertas

~~Todas las preguntas abiertas han sido resueltas:~~

- **P-01 → Resuelta:** No habrá umbral ni coloración naranja en el Excel.
- **P-02 → Resuelta:** Los abonos se suman a la cantidad de la celda; no se
  añade columna separada.
- **P-03 → Resuelta:** El Excel exporta siempre la tabla completa, ignorando el
  filtro de búsqueda activo.
- **P-04 → Resuelta:** La fila "GRABADO POR" no se incluye de momento.

---

## 12) Notas para análisis técnico

- La entidad `OrderSheet` contiene toda la información necesaria para la
  exportación: `clients`, `products`, `quantities`, `pedidos`, `stocks`,
  `quedan`, `cellFlags`, `strictStocks`, `cellNotes`, `cellRefunds`,
  `clientOrders`, `date`.
- El Excel siempre itera sobre **todos** los productos (`orderSheet.products`),
  sin aplicar `_filteredIndices`.
- Para cada celda de cliente, el valor exportado es
  `quantities[productIdx][clientIdx] + refunds[productIdx][clientId]` (suma de
  cantidad + abono). La generación del Excel puede realizarse como servicio
  inyectable similar a `OrderSheetPdfService`.
- La plataforma ya usa `file_picker` (para save dialog en macOS) y la generación
  de PDF en memoria (`_generateOrderSheetPdf`). El patrón puede replicarse con
  una librería Excel (ej. `excel` pub.dev).
- En web, `file_picker` puede no soportar save dialog; se requerirá un mecanismo
  alternativo de descarga (ej. `dart:html` `AnchorElement` con blob, o
  `universal_io`).
- El botón debe integrarse en la pantalla `OrdersTodayPage` /
  `_OrdersTodayContent`, condicionado al estado `OrdersTodayLoaded`.
- No se requieren cambios en BLoC, repositorio, ni Firestore.
- Considerar si el servicio de exportación Excel debe vivir en `data/services/`
  (como `OrderSheetPdfService`) o en `presentation/` si es puramente UI.
- **Estado: Listo para análisis técnico**
