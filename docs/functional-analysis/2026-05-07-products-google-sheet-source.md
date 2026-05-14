# Functional Analysis: Productos desde Google Sheet con enriquecimiento Factura Directa

- **Fecha:** 2026-05-07
- **Identificador:** products-google-sheet-source
- **Estado:** Ready for technical analysis

## 1) Resumen

Cambiar la fuente primaria de datos de la tabla de Productos: actualmente se
carga exclusivamente desde la API de Factura Directa. Se requiere que la fuente
primaria pase a ser la hoja **"productos"** del spreadsheet **"configuracion"**
de Google Sheets, y que los datos se enriquezcan con información de Factura
Directa (nombre FD y precio) utilizando el campo **UUID Factura Directa** como
clave de cruce.

## 2) Contexto y objetivo

### Qué se solicita

Replicar para Productos el mismo patrón que ya existe en Clientes: la fuente
primaria de datos es Google Sheets y se enriquece con datos de Factura Directa.

Sin embargo, la dirección del flujo se **invierte** respecto a Clientes:

- **Clientes (actual):** fuente primaria = Factura Directa, enriquecimiento =
  Google Sheets.
- **Productos (nuevo):** fuente primaria = Google Sheets, enriquecimiento =
  Factura Directa.

### Qué problema resuelve

- Los productos gestionados internamente en Google Sheets contienen campos
  operativos (activo, color, orden en pedidos, mostrar en nuevos pedidos) que no
  existen en Factura Directa.
- Google Sheets es la fuente de verdad para el catálogo de productos de la
  empresa, y Factura Directa aporta únicamente el nombre comercial y el precio
  de venta.
- La tabla actual solo muestra Nombre, Código (SKU) y Precio desde Factura
  Directa, sin reflejar la configuración operativa del negocio.

### Resultado funcional esperado

La tabla de Productos muestra todos los productos definidos en Google Sheets,
con las columnas definidas por el usuario, enriquecidos opcionalmente con nombre
y precio de Factura Directa cuando existe un UUID de cruce.

## 3) Alcance

### En alcance

- Lectura de la hoja **"productos"** del spreadsheet "configuracion" en Google
  Sheets
- Lectura de productos desde la API de Factura Directa (para enriquecimiento)
- Cruce por **UUID Factura Directa** (columna H en Google Sheet)
- Nueva estructura de la entidad Producto con campos de ambas fuentes
- Rediseño de la tabla en la UI con las 8 columnas solicitadas
- Manejo de productos sin UUID (columnas FD vacías)
- Filtro de búsqueda adaptado a los nuevos campos
- Estados de carga, error y vacío

### Fuera de alcance

- Edición de productos desde la aplicación
- Sincronización bidireccional entre Google Sheets y Factura Directa
- Gestión de la columna "Nombre Factura Directa" en Google Sheets (columna I,
  actualmente visible en el sheet pero no solicitada para la app)
- CRUD de productos en Google Sheets desde la app
- Cambios en otras features que consuman productos (pedidos, albaranes,
  facturas) — se mantendrá compatibilidad

## 4) Actores implicados

| Actor                    | Rol                                                         |
| ------------------------ | ----------------------------------------------------------- |
| Usuario de la aplicación | Consulta la tabla de productos                              |
| Google Sheets            | Fuente primaria de datos del catálogo de productos          |
| Factura Directa (API)    | Fuente secundaria para enriquecimiento (nombre FD y precio) |

## 5) Requisitos funcionales

- **RF-01:** La lista de productos se cargará desde la hoja "productos" del
  spreadsheet "configuracion" en Google Sheets (rango estimado:
  `productos!A3:I`), leyendo las columnas: ID, Nombre, Activo, Mostrar en nuevos
  pedidos, Orden en nuevos pedidos, Color por defecto, UUID Factura Directa,
  Nombre Factura Directa.
- **RF-02:** Se obtendrán en paralelo los productos de la API de Factura
  Directa.
- **RF-03:** Para cada producto de Google Sheets que tenga un valor en la
  columna "UUID Factura Directa", se cruzará con el producto correspondiente de
  Factura Directa para obtener el nombre comercial (`name`) y el precio de venta
  (`salesPrice` + `currency`).
- **RF-04:** Si un producto de Google Sheets **no** tiene UUID Factura Directa,
  las columnas "Producto FD" y "Precio" se mostrarán vacías.
- **RF-05:** La tabla de la aplicación mostrará las siguientes columnas en este
  orden:

| # | Columna                   | Fuente                                  | Tipo             |
| - | ------------------------- | --------------------------------------- | ---------------- |
| 1 | ID                        | Google Sheet (col B)                    | Entero           |
| 2 | Nombre                    | Google Sheet (col C)                    | Texto            |
| 3 | Activo                    | Google Sheet (col D)                    | Booleano (Sí/No) |
| 4 | Color                     | Google Sheet (col G)                    | Color hex        |
| 5 | Mostrar en nuevos pedidos | Google Sheet (col E)                    | Booleano (Sí/No) |
| 6 | Orden en nuevos pedidos   | Google Sheet (col F)                    | Entero           |
| 7 | Producto FD               | Factura Directa (name)                  | Texto            |
| 8 | Precio                    | Factura Directa (salesPrice + currency) | Decimal + moneda |

- **RF-06:** La lista de productos se ordenará por la columna "Orden en nuevos
  pedidos" (ascendente). Los productos sin valor de orden se colocarán al final.
- **RF-07:** El buscador existente filtrará por Nombre (Google Sheet) y Producto
  FD (Factura Directa).
- **RF-08:** Si Google Sheets no está configurado o el spreadsheet
  "configuracion" no se encuentra, se mostrará un mensaje de advertencia
  (similar al comportamiento en Clientes).
- **RF-09:** Si la API de Factura Directa falla, se mostrarán los productos de
  Google Sheets sin enriquecimiento (columnas "Producto FD" y "Precio" vacías),
  con un indicador/warning de que los datos de FD no están disponibles.

## 6) Criterios de aceptación

- **CA-01:** Al abrir la pantalla de Productos, se cargan los datos desde Google
  Sheets y se enriquecen con Factura Directa.
- **CA-02:** Un producto con UUID Factura Directa muestra nombre FD y precio en
  las columnas correspondientes.
- **CA-03:** Un producto sin UUID Factura Directa muestra las columnas "Producto
  FD" y "Precio" vacías.
- **CA-04:** Un producto con UUID Factura Directa que **no coincide** con ningún
  producto en FD muestra las columnas "Producto FD" y "Precio" vacías (sin
  error).
- **CA-05:** La columna "Activo" muestra "Sí" o "No" (no el valor raw).
- **CA-06:** La columna "Mostrar en nuevos pedidos" muestra "Sí" o "No".
- **CA-07:** La columna "Color" muestra el color visualmente (indicador de
  color) basado en el valor hex.
- **CA-08:** Si Google Sheets no está disponible, se muestra un error
  informativo.
- **CA-09:** Si Factura Directa falla, se muestran los productos de Google
  Sheets con warning y columnas FD vacías.
- **CA-10:** El buscador filtra correctamente por Nombre y Producto FD.
- **CA-11:** La tabla muestra las 8 columnas en el orden especificado en RF-05.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario navega a la pantalla de Productos.
2. El sistema inicia la carga en paralelo: Google Sheets (hoja "productos") y
   API de Factura Directa.
3. Se parsean los productos de Google Sheets.
4. Se obtiene el mapa de productos de Factura Directa indexado por UUID.
5. Se cruzan los productos: para cada producto de Google Sheets con UUID FD, se
   busca el producto FD correspondiente y se toman `name` y
   `salesPrice`/`currency`.
6. Se ordena la lista resultante por "Orden en nuevos pedidos" (ascendente,
   nulos al final).
7. Se muestra la tabla con las 8 columnas.
8. El usuario puede buscar productos usando el campo de búsqueda.

### Flujos alternativos

- **FA-01 — Google Sheets no configurado:** Se muestra mensaje de error
  indicando que Google Drive no está configurado. No se muestran productos.
- **FA-02 — Spreadsheet "configuracion" no encontrado:** Se muestra mensaje de
  error. No se muestran productos.
- **FA-03 — Hoja "productos" no encontrada o vacía:** Se muestra la tabla vacía
  con mensaje "No hay productos".
- **FA-04 — Factura Directa no configurada o falla:** Se muestran los productos
  de Google Sheets con columnas FD vacías y un indicador de warning (ej: banner
  o tooltip).
- **FA-05 — Ambas fuentes fallan:** Se muestra el error más relevante (Google
  Sheets, ya que es la fuente primaria).

### Estados especiales / excepciones

- **Estado vacío:** La hoja "productos" existe pero no tiene filas de datos → se
  muestra "No hay productos".
- **Estado loading:** Se muestra indicador de carga mientras se obtienen datos
  de ambas fuentes.
- **Estado error:** Diferenciado según la fuente que falle (ver flujos
  alternativos).
- **Sin permisos:** Si no hay acceso a Google Sheets o a la API de FD, se
  muestra error correspondiente.

## 8) Edge cases

- **EC-01:** Un producto en Google Sheets tiene UUID Factura Directa pero el
  producto fue eliminado en FD → columnas FD vacías, sin error.
- **EC-02:** Múltiples productos en Google Sheets apuntan al mismo UUID de FD →
  cada uno muestra los mismos datos de FD (nombre y precio).
- **EC-03:** El valor de "Color por defecto" no es un hex válido → se muestra
  sin indicador visual o con un fallback.
- **EC-04:** El campo "Orden en nuevos pedidos" contiene valores no numéricos →
  se trata como nulo (producto al final de la lista).
- **EC-05:** Campos "Activo" y "Mostrar en nuevos pedidos" con valores distintos
  de "Sí"/"No" → se tratan como nulo/indeterminado.
- **EC-06:** La hoja "productos" tiene filas vacías intermedias → se ignoran
  (filas sin ID ni Nombre).

## 9) Impacto funcional

- **Módulos afectados:**
  - `products` — Cambio completo de fuente de datos, entidad, repositorio, DTO,
    cubit y vista.
  - Potencialmente `orders_today`, `orders_history`, `delivery_notes`,
    `invoices` si consumen la entidad `Product` actual. Se requiere verificar
    durante el análisis técnico si estos módulos necesitan adaptación o si
    pueden convivir con la nueva entidad.

- **Impacto en usuario:** El usuario verá una tabla con más información y más
  alineada con su gestión real del catálogo de productos.

- **Impacto en experiencia de usuario:** La tabla pasa de 3 columnas (Nombre,
  Código, Precio) a 8 columnas, lo que requiere un diseño de tabla responsive o
  con scroll horizontal.

## 10) Suposiciones

- **S-01:** La hoja "productos" del spreadsheet "configuracion" tiene el formato
  mostrado en la captura: fila 2 = título "PRODUCTOS", fila 3 = cabeceras, datos
  desde fila 4.
- **S-02:** Las columnas de Google Sheets son fijas en orden: A (vacía), B (ID),
  C (Nombre), D (Activo), E (Mostrar en nuevos pedidos), F (Orden en nuevos
  pedidos), G (Color por defecto), H (UUID Factura Directa), I (Nombre Factura
  Directa).
- **S-03:** El rango de lectura será `productos!B3:I` (similar al patrón de
  clientes con `clientes!A3:G`).
- **S-04:** El patrón de acceso a Google Sheets y Google Drive ya está
  implementado y funcional (reutilizable desde la feature de Clientes).
- **S-05:** El ordenamiento por defecto de la tabla es por "Orden en nuevos
  pedidos" (ascendente). Si el usuario prefiere otro ordenamiento por defecto,
  debe indicarse.
- **S-06:** La columna "Color" se mostrará como un indicador visual (círculo,
  cuadrado o badge con el color hex), no como texto plano.

## 11) Preguntas abiertas (resueltas)

- **PA-01:** La columna "Nombre Factura Directa" (columna I) del Google Sheet es
  solo referencia interna. La columna "Producto FD" en la app se alimenta del
  `name` de la API de Factura Directa. → **No se muestra la columna I del sheet
  en la app.**
- **PA-02:** Los módulos que consumen productos (pedidos, albaranes, facturas)
  no se tocan en este cambio. Se mantienen tal cual. → **Fuera de alcance.**
- **PA-03:** El filtro de búsqueda filtra solo por Nombre (Google Sheet) y
  Producto FD (Factura Directa). No incluye ID. → **Confirmado.**

## 12) Notas para análisis técnico

- El patrón a seguir es el implementado en `ClientsRepositoryImpl`: lectura
  paralela de Google Sheets y Factura Directa, cruce por UUID, y resultado
  combinado.
- **Inversión de flujo:** En Clientes la fuente primaria es FD y se enriquece
  con Sheet. En Productos la fuente primaria es Sheet y se enriquece con FD.
  Esto cambia la lógica del repositorio: los productos base se construyen desde
  el Sheet DTO, y el enriquecimiento busca en el mapa de FD.
- Crear un `ProductSheetDto` similar a `ClientSheetDto` para parsear la hoja
  "productos".
- La entidad `Product` necesita rediseñarse para incluir los nuevos campos (id
  numérico del sheet, nombre sheet, activo, color, mostrar en nuevos pedidos,
  orden, nombre FD, precio FD, moneda).
- Evaluar impacto en otros features que consumen `Product` (buscar usages de la
  entidad).
- Se reutilizan los datasources existentes: `GoogleSheetsDataSource`,
  `GoogleDriveRemoteDataSource`, `FacturaDirectaApiDataSource`.
- La tabla de la UI pasa de 3 a 8 columnas: considerar scroll horizontal o
  diseño adaptativo.
- Se necesita un resultado tipo `ProductsResult` (similar a `ClientsResult`) que
  incluya un `sheetWarning` para manejar el caso de FD no disponible.
- **Estado: Listo para análisis técnico**
