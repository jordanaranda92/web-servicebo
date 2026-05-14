# Functional Analysis: Pedidos de hoy

- **Fecha:** 2026-05-06
- **Identificador:** orders-today
- **Estado:** Ready for technical analysis

## 1) Resumen

Implementar la vista de "Pedidos de hoy" que cargue automáticamente un archivo
Excel correspondiente al día actual desde la subcarpeta `historico/` dentro de
la carpeta de trabajo configurada en ajustes. Si el archivo del día no existe,
se mostrará un aviso y un botón de acción para crearlo a partir de una plantilla
(`plantilla.xlsx`). Los datos se presentarán en formato tabla con clientes en
filas y productos en columnas (número dinámico de productos). La tabla incluirá
filas y columnas de totalización calculadas en la app (no persistidas en el
Excel). Se dispondrá de un botón para recargar los datos manualmente. Se
contempla un sistema de versionado que detecta cambios entre la plantilla actual
y el archivo del día, permitiendo al usuario actualizar la estructura del
archivo cuando la plantilla haya cambiado.

## 2) Contexto y objetivo

- **Qué se solicita:** Una pantalla funcional de pedidos diarios que reemplace
  el placeholder actual de `OrdersTodayPage`, capaz de leer y mostrar datos de
  un archivo Excel local.
- **Qué problema resuelve:** Actualmente no existe forma de visualizar los
  pedidos del día. El usuario necesita consultar y gestionar pedidos diarios
  desde la aplicación sin abrir manualmente archivos Excel.
- **Qué resultado funcional se espera:** Al acceder a la pantalla, el usuario ve
  una tabla con los pedidos del día (clientes × productos) o, si no existe el
  archivo, un aviso claro con la opción de crearlo desde la plantilla.

## 3) Alcance

### En alcance

- Lectura del archivo Excel del día actual (`yyyy-MM-dd.xlsx`) desde
  `<carpeta_trabajo>/historico/`
- Presentación de los datos en formato tabla (clientes en filas, productos
  dinámicos en columnas)
- Detección de ausencia del archivo del día y visualización de aviso informativo
- Botón de acción para crear el archivo del día a partir de
  `<carpeta_trabajo>/plantilla.xlsx`
- Validación de que la carpeta de trabajo está configurada antes de intentar
  cargar datos
- Scroll horizontal para soportar un número variable de columnas de productos
- Botón de recarga manual para refrescar los datos del Excel
- Fila de totales por producto y columna de total por cliente, calculadas en la
  app (no persistidas en el Excel)
- Sistema de versionado: detección de diferencias de estructura entre la
  plantilla actual y el archivo del día, con posibilidad de actualizar el
  archivo

### Fuera de alcance

- Edición o modificación de los datos del Excel desde la app
- Creación o gestión de la plantilla (`plantilla.xlsx`) — se asume que ya existe
- Configuración de la carpeta de trabajo (ya implementado en feature `settings`)
- Sincronización con servicios externos (Google Drive, etc.)
- Histórico de pedidos (feature `orders_history` separada)
- Impresión o exportación de los datos mostrados

## 4) Actores implicados

| Actor                     | Rol                                                                       |
| ------------------------- | ------------------------------------------------------------------------- |
| Usuario final (operador)  | Consulta los pedidos del día y puede crear el archivo diario si no existe |
| Sistema de archivos local | Almacena los archivos Excel (plantilla e histórico)                       |
| Feature `settings`        | Provee la ruta de la carpeta de trabajo configurada                       |

## 5) Requisitos funcionales

- **RF-01:** Al acceder a la pantalla "Pedidos de hoy", el sistema debe obtener
  la ruta de la carpeta de trabajo desde la configuración de ajustes.
- **RF-02:** Si la carpeta de trabajo no está configurada o no es válida, se
  debe mostrar un mensaje indicando que es necesario configurarla, con un enlace
  o indicación hacia ajustes.
- **RF-03:** El sistema debe buscar el archivo
  `<carpeta_trabajo>/historico/yyyy-MM-dd.xlsx` correspondiente a la fecha
  actual del dispositivo.
- **RF-04:** Si el archivo del día existe, se deben leer sus datos y mostrarlos
  en una tabla con:
  - Primera columna: nombre del cliente
  - Columnas siguientes: una por cada producto encontrado en la cabecera del
    Excel
  - Valores: cantidades numéricas por celda
- **RF-05:** La tabla debe soportar un número dinámico de columnas de productos
  (scroll horizontal si es necesario).
- **RF-06:** Si el archivo del día NO existe, se debe mostrar un estado
  informativo (icono + mensaje) indicando que no hay pedidos para hoy.
- **RF-07:** En el estado "sin archivo del día", se debe mostrar un botón de
  acción para crear el archivo del día.
- **RF-08:** Al pulsar el botón de crear, el sistema debe copiar
  `<carpeta_trabajo>/plantilla.xlsx` como
  `<carpeta_trabajo>/historico/yyyy-MM-dd.xlsx` y cargar los datos resultantes.
- **RF-09:** Si la plantilla (`plantilla.xlsx`) no existe en la carpeta de
  trabajo, el botón de crear debe mostrar un error indicando que falta la
  plantilla.
- **RF-10:** Durante la carga del archivo se debe mostrar un indicador de carga
  (loading).
- **RF-11:** Se debe mostrar un botón de recarga que permita al usuario volver a
  leer el archivo Excel del día y actualizar los datos en pantalla.
- **RF-12:** La tabla debe mostrar una fila final con los totales de cada
  producto (suma de las cantidades de todos los clientes por columna).
- **RF-13:** La tabla debe mostrar una columna final con el total por cliente
  (suma de las cantidades de todos los productos por fila).
- **RF-14:** Las totalizaciones (RF-12 y RF-13) se calculan exclusivamente en la
  app y no se escriben en el archivo Excel.
- **RF-15:** Al cargar el archivo del día, el sistema debe comparar las
  cabeceras de productos del archivo con las de la plantilla actual
  (`plantilla.xlsx`).
- **RF-16:** Si se detecta una diferencia de estructura (productos añadidos,
  eliminados o reordenados en la plantilla), se debe mostrar un aviso visual
  indicando que el archivo del día usa una versión anterior de la plantilla.
- **RF-17:** Junto al aviso de versión desactualizada, se debe ofrecer un botón
  de acción "Actualizar estructura" que permita al usuario sincronizar el
  archivo del día con la plantilla actual.
- **RF-18:** La actualización de estructura debe:
  - Añadir columnas nuevas (productos que están en la plantilla pero no en el
    archivo) con valores vacíos/cero
  - Conservar los datos existentes de productos que siguen en la plantilla
  - Eliminar columnas de productos que ya no están en la plantilla
  - Respetar el orden de productos definido en la plantilla actual
  - Persistir los cambios en el archivo Excel del día
- **RF-19:** Si la plantilla no existe al intentar la comparación de versiones,
  el sistema debe omitir la verificación y mostrar los datos del archivo tal
  cual, sin aviso de versión.

## 6) Criterios de aceptación

- **CA-01:** Dado que la carpeta de trabajo está configurada y existe el archivo
  `historico/2026-05-06.xlsx`, cuando el usuario accede a "Pedidos de hoy",
  entonces se muestra una tabla con los clientes y productos del Excel.
- **CA-02:** Dado que el Excel tiene 3 productos (Coreana, Americana, Tita),
  cuando se carga, entonces la tabla muestra exactamente 4 columnas (Cliente + 3
  productos).
- **CA-03:** Dado que el Excel tiene 10 productos, cuando se carga, entonces la
  tabla permite scroll horizontal para ver todas las columnas.
- **CA-04:** Dado que no existe el archivo `historico/2026-05-06.xlsx`, cuando
  el usuario accede a la pantalla, entonces se muestra un aviso de "no hay
  pedidos para hoy" y un botón "Crear pedido de hoy".
- **CA-05:** Dado que no existe el archivo del día y sí existe `plantilla.xlsx`,
  cuando el usuario pulsa "Crear pedido de hoy", entonces se crea el archivo
  `historico/2026-05-06.xlsx` como copia de la plantilla y se muestran los
  datos.
- **CA-06:** Dado que no existe ni el archivo del día ni `plantilla.xlsx`,
  cuando el usuario pulsa "Crear pedido de hoy", entonces se muestra un error
  indicando que falta la plantilla.
- **CA-07:** Dado que la carpeta de trabajo no está configurada, cuando el
  usuario accede a la pantalla, entonces se muestra un mensaje indicando que
  debe configurar la carpeta de trabajo.
- **CA-08:** Mientras se carga el archivo, se muestra un indicador de
  progreso/loading.
- **CA-09:** Dado que se muestran los datos de pedidos, cuando el usuario pulsa
  el botón de recarga, entonces el sistema vuelve a leer el archivo del día y
  actualiza la tabla con los datos actuales.
- **CA-10:** Dado que la tabla muestra 2 clientes con cantidades (Coreana:
  10+2=12, Americana: 5+10=15, Tita: 20+15=35), entonces la fila de totales
  muestra 12, 15 y 35 respectivamente.
- **CA-11:** Dado que un cliente tiene cantidades Coreana=10, Americana=5,
  Tita=20, entonces la columna de total para ese cliente muestra 35.
- **CA-12:** Las totalizaciones son de solo visualización y no modifican el
  archivo Excel.
- **CA-13:** Dado que la plantilla tiene productos [Coreana, Americana, Tita,
  Mexicana] y el archivo del día tiene [Coreana, Americana, Tita], entonces se
  muestra un aviso de "estructura desactualizada" y un botón "Actualizar
  estructura".
- **CA-14:** Dado el escenario de CA-13, cuando el usuario pulsa "Actualizar
  estructura", entonces el archivo del día se actualiza añadiendo la columna
  "Mexicana" con valores vacíos/cero, y se recargan los datos.
- **CA-15:** Dado que la plantilla ha eliminado el producto "Tita" y el archivo
  del día lo contiene con datos, cuando el usuario pulsa "Actualizar
  estructura", entonces la columna "Tita" se elimina del archivo y los datos de
  ese producto se pierden.
- **CA-16:** Dado que la plantilla y el archivo del día tienen exactamente las
  mismas cabeceras de productos en el mismo orden, entonces no se muestra ningún
  aviso de versionado.
- **CA-17:** Dado que la plantilla no existe pero sí el archivo del día,
  entonces se muestran los datos sin aviso de versión.

## 7) Flujos y comportamiento esperado

### Flujo principal (archivo del día existe)

1. El usuario navega a "Pedidos de hoy"
2. El sistema obtiene la ruta de la carpeta de trabajo desde ajustes
3. El sistema verifica que la carpeta es válida
4. El sistema busca `<carpeta>/historico/yyyy-MM-dd.xlsx`
5. El archivo existe → se leen los datos
6. Se presenta la tabla con clientes (filas) y productos (columnas)
7. Si hay muchos productos, el usuario puede hacer scroll horizontal
8. Se muestra una fila de totales por producto y una columna de total por
   cliente
9. El sistema compara las cabeceras del archivo con las de la plantilla actual
10. Si coinciden → se muestra la tabla sin avisos adicionales
11. Si difieren → se muestra un aviso de versión desactualizada con botón
    "Actualizar estructura"
12. El usuario puede pulsar el botón de recarga para refrescar los datos en
    cualquier momento

### Flujo alternativo D (actualización de estructura)

1. El usuario ve el aviso de versión desactualizada en la pantalla de pedidos
2. Pulsa el botón "Actualizar estructura"
3. El sistema lee la plantilla actual y obtiene las nuevas cabeceras de
   productos
4. El sistema reorganiza las columnas del archivo del día: añade las nuevas,
   elimina las obsoletas, reordena según la plantilla
5. Se conservan los datos de clientes para productos que permanecen
6. Se persisten los cambios en el archivo Excel
7. Se recarga y muestra la tabla actualizada sin aviso de versión

### Flujo alternativo A (archivo del día no existe)

1. Pasos 1-4 del flujo principal
2. El archivo no existe → se muestra estado vacío con icono, mensaje informativo
   y botón "Crear pedido de hoy"
3. El usuario pulsa el botón
4. El sistema verifica que `plantilla.xlsx` existe en la carpeta de trabajo
5. El sistema copia `plantilla.xlsx` → `historico/yyyy-MM-dd.xlsx`
6. Se crea la subcarpeta `historico/` si no existe
7. Se cargan y muestran los datos del archivo recién creado

### Flujo alternativo B (carpeta no configurada)

1. El usuario navega a "Pedidos de hoy"
2. El sistema detecta que no hay carpeta de trabajo configurada (o no es válida)
3. Se muestra un mensaje orientativo indicando ir a ajustes para configurarla

### Flujo alternativo C (plantilla no existe)

1. Pasos 1-3 del flujo alternativo A
2. El sistema detecta que `plantilla.xlsx` no existe
3. Se muestra un mensaje de error indicando que falta la plantilla en la carpeta
   de trabajo

### Estados especiales / excepciones

- **Estado loading:** Indicador de carga mientras se lee o se crea el archivo
- **Estado vacío (sin archivo):** Icono informativo + mensaje + botón de acción
- **Estado error (carpeta no configurada):** Mensaje + orientación a ajustes
- **Estado error (plantilla no encontrada):** Mensaje de error descriptivo
- **Estado error (fallo de lectura):** Si el archivo existe pero no se puede
  leer (corrupto, formato inesperado), mostrar mensaje de error genérico
- **Estado aviso (versión desactualizada):** Banner o aviso informativo + botón
  "Actualizar estructura", sin bloquear la visualización de los datos actuales

## 8) Edge cases

- **EC-01:** El archivo del día existe pero está vacío (sin filas de datos).
  Mostrar la tabla con las cabeceras de productos pero sin filas, o un mensaje
  "sin pedidos registrados".
- **EC-02:** El archivo del día existe pero no tiene la estructura esperada
  (falta la fila de cabecera, columnas inesperadas). Mostrar un error indicando
  formato inválido.
- **EC-03:** La subcarpeta `historico/` no existe dentro de la carpeta de
  trabajo. Crearla automáticamente al generar el archivo del día.
- **EC-04:** Permisos insuficientes sobre la carpeta de trabajo o los archivos.
  Mostrar un error indicando problema de permisos.
- **EC-05:** El usuario accede a la pantalla justo a medianoche (cambia la fecha
  entre la carga y la visualización). Se usa la fecha capturada al inicio de la
  carga.
- **EC-06:** El nombre de un producto en la cabecera contiene caracteres
  especiales o está vacío. Mostrarlo tal cual o ignorar columnas vacías.
- **EC-07:** Existen celdas vacías o no numéricas en las cantidades. Mostrar "0"
  o el valor en blanco según corresponda.
- **EC-08:** La plantilla cambia varias veces en el mismo día y el usuario
  actualiza la estructura múltiples veces. Cada actualización toma la plantilla
  actual como referencia; los datos de productos eliminados en actualizaciones
  anteriores no son recuperables.
- **EC-09:** La plantilla tiene 0 productos (solo la cabecera "Cliente" o está
  vacía). Mostrar la tabla sin columnas de productos o un aviso de plantilla
  inválida.
- **EC-10:** El archivo del día y la plantilla tienen los mismos productos pero
  en orden diferente. Se considera diferencia de versión y se ofrece actualizar
  para respetar el orden de la plantilla.

## 9) Impacto funcional

- **Módulos afectados:**
  - `orders_today` — se reemplaza el placeholder por la funcionalidad completa
  - `settings` — se consume la configuración de carpeta de trabajo (solo
    lectura, sin cambios en settings)
- **Impacto en usuario:** El usuario podrá consultar los pedidos del día
  directamente desde la app en lugar de navegar manualmente al sistema de
  archivos y abrir Excel.
- **Impacto en experiencia de usuario:** La pantalla pasa de ser un placeholder
  inactivo a una vista funcional útil. La creación automática del archivo reduce
  fricción operativa diaria.

## 10) Suposiciones

- **S-01:** La estructura del Excel sigue siempre el formato: primera columna =
  "Cliente", columnas siguientes = nombres de productos, filas = clientes con
  cantidades.
- **S-02:** La primera fila del Excel es la cabecera con los nombres de
  productos.
- **S-03:** La plantilla `plantilla.xlsx` ya existe en la raíz de la carpeta de
  trabajo y contiene únicamente la fila de cabecera con los nombres de los
  productos (sin clientes predefinidos).
- **S-04:** La fecha a usar es la fecha local del dispositivo.
- **S-05:** Los datos son de solo lectura en esta pantalla; la edición de
  cantidades no está en alcance.
- **S-06:** El formato de fecha para el nombre del archivo es `yyyy-MM-dd` (ISO
  8601).
- **S-07:** La app tiene permisos de lectura/escritura sobre la carpeta de
  trabajo configurada.

## 11) Preguntas abiertas

_Todas las preguntas han sido resueltas._

### Preguntas resueltas

- **PA-01 → RF-11:** Sí, botón de recarga manual para refrescar datos.
- **PA-02 → S-03:** La plantilla contiene solo cabeceras de productos, sin
  clientes predefinidos.
- **PA-03 → RF-12/RF-13/RF-14:** Sí, totales por producto (fila) y por cliente
  (columna), calculados solo en la app.

## 12) Notas para análisis técnico

- La feature `settings` ya expone `WorkFolderConfig` con `path` e `isValid` a
  través de `SettingsRepository.getWorkFolder()`
- El proyecto usa Clean Architecture feature-first: será necesario crear las
  capas `data/` y `domain/` dentro de `orders_today/` (actualmente solo tiene
  `presentation/`)
- Se necesitará una dependencia para lectura/escritura de archivos Excel en Dart
  (ej: paquete `excel` o `spreadsheet_decoder`)
- La copia de archivos se puede resolver con `dart:io` (`File.copy`)
- La tabla con scroll horizontal se puede implementar con `DataTable` +
  `SingleChildScrollView` horizontal o `Table`
- Los textos visibles al usuario deben estar internacionalizados (i18n) conforme
  a las convenciones del proyecto
- El versionado se basa en comparación directa de cabeceras (lista de
  productos): no requiere un campo de versión explícito en el Excel, simplemente
  se comparan las cabeceras del archivo del día con las de la plantilla actual
- La actualización de estructura implica lectura + modificación + escritura del
  archivo Excel del día
- **Estado: Listo para análisis técnico**
