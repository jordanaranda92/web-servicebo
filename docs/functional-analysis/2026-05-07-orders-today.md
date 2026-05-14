# Functional Analysis: Pedidos de hoy — Google Sheets con creación automática

- **Fecha:** 2026-05-07
- **Identificador:** orders-today
- **Estado:** Ready for technical analysis
- **Revisión:** v3 — preguntas abiertas resueltas; fórmulas en columnas
  Pedidos/Quedan; formato condicional en Quedan; auto-refresh por modifiedTime

## 1) Resumen

Implementar la funcionalidad completa de la pantalla "Pedidos de hoy" operando
sobre Google Sheets en Google Drive. Al acceder, el sistema busca en la
subcarpeta `historico/` un Google Sheet con la fecha actual. Si no existe, lo
crea automáticamente a partir de la plantilla de mayor versión disponible en
`plantillas/` (nombre `plantilla_vX.xlsx`, donde X es el número más alto). La
plantilla define una estructura donde los **productos activos** se listan en
filas (columna A, desde la fila 4) y los **clientes activos** se disponen en
columnas (fila 3, desde la columna B), seguidos de tres columnas de resumen:
**Pedidos**, **Stocks** y **Quedan**. La celda A3 muestra la fecha actual. Los
datos de productos y clientes se cargan dinámicamente desde las hojas
correspondientes del spreadsheet `configuracion` en la subcarpeta `interno/`.

**Fuente:** docs/functional-analysis/2026-05-06-orders-today.md (versión
original basada en Excel local, ahora supersedida por esta revisión)

## 2) Contexto y objetivo

### Qué se solicita

Una pantalla funcional de pedidos diarios que opere íntegramente con Google
Sheets a través de la API de Google Sheets/Drive, siguiendo la configuración
establecida en el análisis `google-drive-config`. Al crear el sheet del día, la
aplicación debe:

- Rellenar dinámicamente la celda A3 con la fecha actual.
- Poblar la fila 3 (desde B) con los nombres de todos los clientes activos
  obtenidos de Google Sheets (`configuracion` → hoja `clientes`).
- Poblar la columna A (desde fila 4) con los nombres de todos los productos
  activos obtenidos de Google Sheets (`configuracion` → hoja `productos`).
- Añadir tras la última columna de clientes las tres columnas de resumen:
  Pedidos, Stocks, Quedan.

### Qué problema resuelve

- El análisis original (2026-05-06) asumía archivos Excel locales; el flujo real
  de trabajo usa Google Sheets compartidos en Google Drive para que hasta 3
  operadores trabajen simultáneamente.
- Actualmente no existe forma de crear automáticamente el sheet del día con la
  estructura correcta (productos × clientes) desde la app.
- La estructura de la plantilla ha cambiado: los productos van en filas y los
  clientes en columnas (inverso al análisis original).

### Resultado funcional esperado

Al acceder a "Pedidos de hoy", el usuario ve una tabla con la estructura
productos (filas) × clientes (columnas) del Google Sheet del día. Si el sheet no
existe, la app lo crea automáticamente a partir de la plantilla versionada,
rellenando productos y clientes activos desde la fuente de datos centralizada.

## 3) Alcance

### En alcance

- Búsqueda del Google Sheet del día (`YYYY-MM-DD`) en la subcarpeta `historico/`
  de la carpeta de Google Drive configurada
- Lectura y presentación de los datos del sheet del día en formato tabla
  (productos en filas, clientes en columnas)
- Detección de ausencia del sheet del día y creación automática a partir de la
  plantilla
- Selección automática de la plantilla con versión más alta en `plantillas/`
  (patrón `plantilla_vX` donde X es un número; se usa la de mayor X)
- Copia de la plantilla como base del nuevo sheet del día en `historico/`
- Escritura dinámica en el nuevo sheet: fecha actual en A3, clientes activos en
  fila 3, productos activos en columna A, columnas resumen (Pedidos, Stocks,
  Quedan) tras el último cliente
- Obtención de clientes activos desde `configuracion` → hoja `clientes`
  (filtrados por campo "Activo" = Sí y "Mostrar en nuevos pedidos" = Sí,
  ordenados por "Orden en nuevos pedidos")
- Obtención de productos activos desde `configuracion` → hoja `productos`
  (filtrados por campo "Activo" = Sí y "Mostrar en nuevos pedidos" = Sí,
  ordenados por "Orden en nuevos pedidos")
- Scroll horizontal y vertical para soportar un número variable de columnas y
  filas
- Botón de recarga manual para refrescar los datos del sheet
- Validación de que Google Drive está configurado antes de intentar operar
- Estados de carga, error y vacío

### Fuera de alcance

- Edición de celdas de datos del sheet desde la app (los operadores editan
  directamente en Google Sheets)
- Creación o gestión de la plantilla base — se asume que ya existe en
  `plantillas/`
- Creación o gestión de las hojas `clientes` y `productos` en `configuracion`
- Sistema de versionado de estructura plantilla vs. sheet del día (se
  contemplará en análisis futuro si es necesario)
- Edición manual de datos dentro del sheet desde la app (los operadores editan
  directamente en Google Sheets)
- Histórico de pedidos (feature `orders_history` separada)
- Impresión o exportación de los datos mostrados
- Sincronización bidireccional en tiempo real (WebSockets/push) del sheet

## 4) Actores implicados

| Actor                       | Rol                                                                                 |
| --------------------------- | ----------------------------------------------------------------------------------- |
| Usuario final (operador)    | Consulta los pedidos del día; dispara la creación del sheet si no existe            |
| Google Sheets API           | Lee y escribe los datos del spreadsheet (pedidos del día, plantilla, configuración) |
| Google Drive API            | Localiza y copia archivos en las subcarpetas del Drive configurado                  |
| Feature `settings`          | Provee la configuración de Google Drive (tokens, ID de carpeta raíz)                |
| Spreadsheet `configuracion` | Contiene las hojas `clientes` y `productos` con los datos maestros                  |

## 5) Requisitos funcionales

### Acceso y validación inicial

- **RF-01:** Al acceder a "Pedidos de hoy", el sistema debe verificar que la
  configuración de Google Drive está completa (cuenta autenticada + carpeta
  seleccionada).
- **RF-02:** Si Google Drive no está configurado, mostrar un mensaje indicando
  que es necesario configurarlo, con orientación hacia Ajustes.

### Búsqueda del sheet del día

- **RF-03:** El sistema debe buscar en la subcarpeta `historico/` de la carpeta
  configurada un Google Sheet cuyo nombre coincida exactamente con la fecha
  actual en formato `YYYY-MM-DD`.
- **RF-04:** Si el sheet del día existe, leer sus datos y presentarlos en una
  tabla.

### Estructura de datos del sheet

- **RF-05:** La tabla debe reflejar la estructura del Google Sheet:
  - **Celda A3:** fecha del día (formato legible, p.ej. "SÁBADO, 7 MAYO")
  - **Fila 3, desde columna B:** nombre de cada cliente (uno por columna)
  - **Fila 3, tras el último cliente:** tres columnas de resumen: "PEDIDOS",
    "STOCKS", "QUEDAN"
  - **Columna A, desde fila 4:** nombre de cada producto (uno por fila)
  - **Celdas de datos (fila 4+, columnas B+):** cantidades numéricas por
    producto × cliente
- **RF-06:** La fila 2 (desde columna B hasta la última columna de cliente)
  puede contener un número de orden del cliente (correlativo). La app debe
  leerlo y mostrarlo si existe.
- **RF-07:** La tabla debe soportar scroll horizontal (para muchos clientes) y
  scroll vertical (para muchos productos), manteniendo fija la columna A
  (nombres de productos) y la fila de cabecera (nombres de clientes).

### Creación del sheet del día

- **RF-08:** Si el sheet del día NO existe en `historico/`, mostrar un estado
  informativo (icono + mensaje) indicando que no hay pedidos para hoy, con un
  botón "Crear pedido de hoy".
- **RF-09:** Al pulsar "Crear pedido de hoy", el sistema debe:
  1. Localizar la subcarpeta `plantillas/` en la carpeta configurada.
  2. Listar los Google Sheets en `plantillas/` que sigan el patrón
     `plantilla_vX` (donde X es un número entero).
  3. Seleccionar la plantilla con el valor más alto de X.
  4. Copiar dicha plantilla como un nuevo Google Sheet en `historico/` con
     nombre `YYYY-MM-DD` (fecha actual).
- **RF-10:** Tras copiar la plantilla, el sistema debe modificar el nuevo sheet:
  1. Escribir en la celda A3 la fecha actual en formato legible (día de la
     semana + día + mes, ej: "MIÉRCOLES, 7 MAYO").
  2. Leer los **clientes activos** del spreadsheet `configuracion` → hoja
     `clientes`, filtrando por campo "Activo" = Sí **y** "Mostrar en nuevos
     pedidos" = Sí, ordenados por "Orden en nuevos pedidos" (ascendente).
  3. Escribir los nombres de los clientes en la fila 3, uno por columna,
     empezando en B3.
  4. Escribir en la fila 2 los números de orden correlativos (1, 2, 3…) sobre
     cada columna de cliente.
  5. Tras la última columna de cliente, escribir en la fila 3 las cabeceras
     "PEDIDOS", "STOCKS", "QUEDAN".
  6. Leer los **productos activos** del spreadsheet `configuracion` → hoja
     `productos`, filtrando por campo "Activo" = Sí **y** "Mostrar en nuevos
     pedidos" = Sí, ordenados por "Orden en nuevos pedidos" (ascendente).
  7. Escribir los nombres de los productos en la columna A, uno por fila,
     empezando en A4.
  8. Inicializar las celdas de datos (cantidades) a 0 o vacío.
  9. Escribir en la columna "PEDIDOS" una fórmula de suma para cada fila de
     producto que sume todas las celdas de clientes de esa fila.
  10. Dejar la columna "STOCKS" vacía (se rellena manualmente por el operador en
      Google Sheets).
  11. Escribir en la columna "QUEDAN" una fórmula para cada fila de producto:
      `= STOCKS - PEDIDOS` (diferencia entre la celda de Stocks y la de Pedidos
      de esa misma fila).
- **RF-11:** Tras la creación y relleno del sheet, cargar y mostrar los datos
  resultantes en la tabla.

### Manejo de plantillas

- **RF-12:** Si la subcarpeta `plantillas/` no existe o está vacía, mostrar un
  error indicando que no se encontró ninguna plantilla.
- **RF-13:** Si existen múltiples archivos con el patrón `plantilla_vX`, el
  sistema debe seleccionar el de mayor X. Ejemplo: si existen `plantilla_v1`,
  `plantilla_v2` y `plantilla_v3`, se usa `plantilla_v3`.
- **RF-14:** El nombre de la plantilla puede tener o no extensión `.xlsx` en
  Google Drive (depende de si fue subida como archivo o creada como Google Sheet
  nativo). El sistema debe reconocer ambos formatos.

### Formato visual y fórmulas

- **RF-15:** Al crear el sheet del día, la copia de la plantilla debe conservar
  el formato visual base (bordes, colores de fondo, fuentes).
- **RF-16:** La columna "PEDIDOS" debe mantener el color de fondo definido en la
  plantilla (morado/lila según la captura de referencia).
- **RF-17:** La columna "QUEDAN" debe mantener su color de fondo base y además
  aplicar formato condicional en la fuente del valor:
  - **Rojo** si el valor es negativo (quedan menos unidades de las pedidas).
  - **Verde** si el valor es positivo o cero.
- **RF-18:** El formato condicional de la columna "QUEDAN" debe definirse como
  regla de formato condicional en el propio Google Sheet (no solo en la app), de
  modo que también sea visible cuando los operadores abren el sheet directamente
  en Google Sheets.

### Recarga y auto-refresh

- **RF-19:** Se debe mostrar un botón de recarga manual que permita al usuario
  volver a leer el sheet del día y actualizar los datos en pantalla.
- **RF-20:** La app debe implementar un mecanismo de auto-refresh basado en el
  campo `modifiedTime` del archivo en Google Drive:
  1. Al cargar el sheet, almacenar el `modifiedTime` actual.
  2. Periódicamente (polling), consultar el `modifiedTime` del archivo mediante
     la API de Google Drive.
  3. Si el `modifiedTime` ha cambiado respecto al almacenado, recargar
     automáticamente los datos del sheet y actualizar el timestamp de
     referencia.
- **RF-21:** El intervalo de polling debe ser configurable internamente
  (suposición: cada 30 segundos como valor por defecto razonable).
- **RF-22:** El polling debe detenerse cuando la pantalla no está visible (el
  usuario navega a otra sección) y reanudarse al volver.
- **RF-23:** Durante la carga del sheet o la creación del archivo se debe
  mostrar un indicador de carga (loading).
- **RF-24:** Si ocurre un error de red o de la API de Google durante cualquier
  operación, mostrar un mensaje de error descriptivo con opción de reintentar.

## 6) Criterios de aceptación

- **CA-01:** Dado que Google Drive está configurado y existe el sheet
  `historico/2026-05-07`, cuando el usuario accede a "Pedidos de hoy", entonces
  se muestra una tabla con los productos en filas y clientes en columnas.
- **CA-02:** Dado que el sheet tiene 6 productos y 5 clientes, la tabla muestra
  6 filas de datos y al menos 5+3=8 columnas (5 clientes + Pedidos + Stocks +
  Quedan), más la columna A de nombres de producto.
- **CA-03:** Dado que no existe el sheet `historico/2026-05-07`, cuando el
  usuario accede a la pantalla, se muestra un aviso "No hay pedidos para hoy"
  con un botón "Crear pedido de hoy".
- **CA-04:** Dado que existen `plantillas/plantilla_v1` y
  `plantillas/plantilla_v3`, cuando el usuario pulsa "Crear pedido de hoy", el
  sistema usa `plantilla_v3` como base.
- **CA-05:** Dado que se crea el sheet del día, la celda A3 contiene la fecha
  actual en formato legible (ej: "MIÉRCOLES, 7 MAYO").
- **CA-06:** Dado que hay 5 clientes activos con "Mostrar en nuevos pedidos" =
  Sí, la fila 3 del nuevo sheet contiene esos 5 nombres de cliente desde B3,
  seguidos de "PEDIDOS", "STOCKS", "QUEDAN".
- **CA-07:** Dado que hay 6 productos activos con "Mostrar en nuevos pedidos" =
  Sí, la columna A del nuevo sheet contiene esos 6 nombres de producto desde A4.
- **CA-08:** Dado que no existe `plantillas/` o no contiene ninguna plantilla
  válida, al pulsar "Crear pedido de hoy" se muestra un error indicando que
  falta la plantilla.
- **CA-09:** Dado que Google Drive no está configurado, al acceder a la pantalla
  se muestra un mensaje indicando que es necesario configurarlo.
- **CA-10:** Mientras se carga o crea el sheet, se muestra un indicador de
  loading.
- **CA-11:** Al pulsar el botón de recarga, el sistema relee el sheet del día y
  actualiza la tabla.
- **CA-12:** La fila 2 muestra números correlativos (1, 2, 3…) sobre cada
  columna de cliente.
- **CA-13:** Los productos se muestran en el orden definido por "Orden en nuevos
  pedidos" (ascendente).
- **CA-14:** Los clientes se muestran en el orden definido por "Orden en nuevos
  pedidos" (ascendente).
- **CA-15:** La columna A (nombres de producto) y la fila de cabecera (nombres
  de cliente) permanecen fijas al hacer scroll.
- **CA-16:** Dado que se crea un sheet con 5 clientes, la columna "PEDIDOS" de
  cada producto contiene una fórmula que suma las celdas B4:F4 (o el rango
  correspondiente a los 5 clientes).
- **CA-17:** La columna "STOCKS" de cada producto está vacía tras la creación
  del sheet.
- **CA-18:** La columna "QUEDAN" de cada producto contiene una fórmula
  `= H4 - G4` (Stock - Pedidos, con las referencias correspondientes).
- **CA-19:** Dado que un producto tiene STOCKS=355 y PEDIDOS=0, la celda QUEDAN
  muestra 355 en color verde.
- **CA-20:** Dado que un producto tiene STOCKS=10 y PEDIDOS=15, la celda QUEDAN
  muestra -5 en color rojo.
- **CA-21:** Si un operador modifica una celda del Google Sheet desde fuera de
  la app, el `modifiedTime` del archivo cambia y la app recarga automáticamente
  los datos en la próxima comprobación de polling.
- **CA-22:** El polling de `modifiedTime` se detiene al salir de la pantalla y
  se reanuda al volver.

## 7) Flujos y comportamiento esperado

### Flujo principal (sheet del día existe)

1. El usuario navega a "Pedidos de hoy".
2. El sistema verifica que Google Drive está configurado (tokens válidos +
   carpeta seleccionada).
3. El sistema busca en `historico/` un Google Sheet con nombre `YYYY-MM-DD`
   (fecha actual).
4. El sheet existe → se leen los datos mediante la API de Google Sheets.
5. Se presenta la tabla: columna A = productos, fila 3 = clientes, celdas =
   cantidades, últimas 3 columnas = Pedidos/Stocks/Quedan.
6. El usuario puede hacer scroll horizontal y vertical para ver todos los datos.
7. El usuario puede pulsar el botón de recarga en cualquier momento para
   refrescar.

### Flujo alternativo A (sheet del día no existe)

1. Pasos 1-3 del flujo principal.
2. El sheet no existe → se muestra estado vacío con icono, mensaje informativo y
   botón "Crear pedido de hoy".
3. El usuario pulsa el botón.
4. El sistema localiza `plantillas/` y lista los archivos con patrón
   `plantilla_vX`.
5. Se selecciona la versión con X más alto.
6. Se copia la plantilla a `historico/YYYY-MM-DD`.
7. Se leen los clientes activos y productos activos del spreadsheet
   `configuracion` (hojas `clientes` y `productos` respectivamente).
8. Se escribe en el nuevo sheet: fecha en A3, clientes en fila 3, números en
   fila 2, cabeceras de resumen, productos en columna A, celdas de datos
   inicializadas.
9. Se cargan y muestran los datos del sheet recién creado.

### Flujo alternativo B (Google Drive no configurado)

1. El usuario navega a "Pedidos de hoy".
2. El sistema detecta que Google Drive no está configurado.
3. Se muestra un mensaje orientativo indicando ir a Ajustes.

### Flujo alternativo C (plantilla no encontrada)

1. Pasos 1-4 del flujo alternativo A.
2. El sistema no encuentra `plantillas/` o no contiene archivos válidos con el
   patrón `plantilla_vX`.
3. Se muestra un mensaje de error indicando que no se encontró ninguna
   plantilla.

### Flujo alternativo D (spreadsheet configuracion no disponible)

1. El sheet del día no existe y el usuario pulsa "Crear pedido de hoy".
2. Se localiza y copia la plantilla correctamente.
3. Al intentar leer clientes o productos del spreadsheet `configuracion`, el
   sistema falla (no existe, error de red, etc.).
4. Se muestra un error indicando que no se pudo acceder a los datos de
   configuración y el sheet queda con la estructura base de la plantilla sin
   rellenar clientes ni productos.

### Estados especiales / excepciones

- **Estado loading:** Indicador de carga mientras se busca, lee o crea el sheet.
- **Estado vacío (sin sheet del día):** Icono informativo + mensaje + botón
  "Crear pedido de hoy".
- **Estado error (Drive no configurado):** Mensaje + orientación a Ajustes.
- **Estado error (plantilla no encontrada):** Mensaje descriptivo.
- **Estado error (configuracion no disponible):** Mensaje indicando que no se
  pudieron cargar clientes/productos.
- **Estado error (fallo de red/API):** Mensaje descriptivo con opción de
  reintentar.
- **Estado error (token expirado/revocado):** Derivar al flujo de
  re-autenticación definido en `google-drive-config`.

## 8) Edge cases

- **EC-01:** El sheet del día existe pero está vacío (sin filas de datos, solo
  estructura). Mostrar la tabla con cabeceras pero sin datos, o un mensaje "sin
  pedidos registrados".
- **EC-02:** El sheet del día existe pero no tiene la estructura esperada
  (faltan filas de cabecera, columnas inesperadas). Mostrar un error de formato
  inválido.
- **EC-03:** No hay clientes activos con "Mostrar en nuevos pedidos" = Sí. El
  sheet se crea solo con la columna A de productos y las 3 columnas de resumen,
  sin columnas de clientes.
- **EC-04:** No hay productos activos con "Mostrar en nuevos pedidos" = Sí. El
  sheet se crea solo con la fila de cabecera de clientes y las columnas de
  resumen, sin filas de productos. Mostrar aviso informativo.
- **EC-05:** El usuario accede a la pantalla justo a medianoche (cambia la fecha
  entre la carga y la visualización). Se usa la fecha capturada al inicio de la
  operación.
- **EC-06:** El nombre de un producto o cliente contiene caracteres especiales.
  Escribirlos tal cual en el sheet.
- **EC-07:** Existen celdas vacías o no numéricas en las cantidades de un sheet
  ya existente. Mostrar el valor tal cual o "0" si está vacío.
- **EC-08:** La subcarpeta `historico/` no existe en Google Drive. Crearla
  automáticamente antes de copiar la plantilla.
- **EC-09:** Existen múltiples archivos con el mismo nombre de fecha en
  `historico/` (duplicados). Usar el primero encontrado y no generar error.
- **EC-10:** La plantilla seleccionada tiene formato `.xlsx` (subida como
  archivo) en lugar de Google Sheet nativo. La API de Google Drive debe manejar
  la conversión al copiar.
- **EC-11:** El valor de X en `plantilla_vX` no es un número entero válido (ej:
  `plantilla_vbeta`). Ignorar ese archivo y considerar solo los que tengan un
  número entero válido.
- **EC-12:** Pérdida de conectividad durante la creación del sheet (entre la
  copia de la plantilla y la escritura de datos). El sheet puede quedar en
  estado parcial. Permitir al usuario reintentar o recargar.

## 9) Impacto funcional

- **Módulos afectados:**
  - **`orders_today`:** Se reemplaza el placeholder actual por la funcionalidad
    completa basada en Google Sheets.
  - **`settings` (Google Drive):** Se consume la configuración de Google Drive
    (tokens OAuth, ID de carpeta). Solo lectura, sin cambios en settings.
  - **Spreadsheet `configuracion`:** Se leen las hojas `clientes` y `productos`
    para poblar el sheet del día. Solo lectura.
- **Impacto en usuario:** El operador puede consultar los pedidos del día y
  crear automáticamente la hoja de trabajo diaria sin salir de la app ni
  copiar/pegar manualmente plantillas en Google Drive.
- **Impacto en experiencia de usuario:** La pantalla pasa de ser un placeholder
  inactivo a una vista funcional útil. La creación automática del sheet con
  clientes y productos precargados elimina un paso manual significativo cada
  día.

## 10) Suposiciones

- **S-01:** La configuración de Google Drive ya está implementada y funcional
  (análisis `google-drive-config`).
- **S-02:** El spreadsheet `configuracion` existe en la subcarpeta `interno/` y
  contiene las hojas `clientes` y `productos` con la estructura definida en los
  análisis `clients-data-enrichment` y `products-google-sheet-source`.
- **S-03:** Los campos "Activo" y "Mostrar en nuevos pedidos" en las hojas de
  clientes y productos usan los valores "Sí" / "No" (o equivalente booleano).
- **S-04:** El campo "Orden en nuevos pedidos" en clientes y productos es un
  valor numérico que define el orden de aparición en el sheet. Los registros sin
  valor de orden se colocan al final.
- **S-05:** La plantilla en `plantillas/` contiene la estructura visual base
  (formatos, colores, bordes) pero los datos de clientes y productos se
  sobreescriben dinámicamente al crear el sheet del día.
- **S-06:** La fila 1 del sheet está reservada (vacía o con metadatos internos).
  La fila 2 contiene los números de orden de los clientes. La fila 3 es la fila
  de cabecera principal.
- **S-07:** La columna "PEDIDOS" contiene una fórmula de suma de las celdas de
  clientes de cada fila. La columna "STOCKS" se rellena manualmente. La columna
  "QUEDAN" contiene una fórmula `= STOCKS - PEDIDOS`.
- **S-08:** La fecha en A3 se escribe en español y en mayúsculas, en el formato
  `DÍA_SEMANA, DD MES` (ej: "MIÉRCOLES, 7 MAYO"), coincidiendo con el formato
  observado en la plantilla de referencia.

## 11) Preguntas abiertas

_Todas las preguntas han sido resueltas e incorporadas como requisitos._

## 12) Notas para análisis técnico

- La fuente de datos ahora es exclusivamente Google Sheets API (no archivos
  locales). Se necesitan los scopes `spreadsheets` y `drive` de Google API.
- La operación de creación del sheet del día involucra múltiples llamadas a la
  API: copiar archivo (Drive API), escribir celdas (Sheets API), leer
  configuración (Sheets API). Considerar transaccionalidad y manejo de errores
  parciales.
- La selección de la plantilla requiere listar archivos en `plantillas/`,
  filtrar por patrón de nombre con regex, parsear el número de versión y ordenar
  descendentemente.
- El filtrado de clientes y productos activos + "Mostrar en nuevos pedidos" debe
  reutilizar la lógica/repositorios ya definidos en los análisis
  `clients-data-enrichment` y `products-google-sheet-source`.
- La columna A y la fila 3 deben funcionar como cabeceras fijas (frozen
  rows/columns) en la UI. Considerar `StickyHeader` o técnicas equivalentes.
- El formato de fecha en A3 está en español y mayúsculas. Utilizar localización
  `es_ES` para formatear.
- Las fórmulas de PEDIDOS y QUEDAN deben escribirse con la API de Sheets
  (`valueInputOption: USER_ENTERED`) para que Google Sheets las interprete.
- El formato condicional en QUEDAN (rojo si <0, verde si >=0) debe crearse
  mediante la API de Sheets (`addConditionalFormatRule`) para que persista en el
  sheet.
- El polling de `modifiedTime` usa `files.get` de Drive API (campo
  `modifiedTime`); es una llamada ligera que no lee el contenido del sheet.
- Considerar un intervalo de polling de ~30s. Detener el timer cuando la
  pantalla pierde el foco (`didChangeAppLifecycleState` / route observer).
- **Estado: Listo para análisis técnico**
