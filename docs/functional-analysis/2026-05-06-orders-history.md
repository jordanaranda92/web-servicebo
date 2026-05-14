# Functional Analysis: Historial de pedidos

- **Fecha:** 2026-05-06
- **Identificador:** orders-history
- **Estado:** Ready for technical analysis

## 1) Resumen

Implementar la vista de **Historial de pedidos** dentro de la aplicación
Servicebo. Esta vista sustituirá el placeholder actual y permitirá consultar los
pedidos registrados en días anteriores al día en curso, utilizando los archivos
Excel almacenados en la carpeta `historico/` del directorio de trabajo
configurado.

## 2) Contexto y objetivo

- **Qué se solicita:** Dotar de funcionalidad real a la página "Historial de
  pedidos" (`OrdersHistoryPage`), que actualmente muestra solo un placeholder.
- **Qué problema resuelve:** El usuario no tiene forma de consultar los pedidos
  de días anteriores desde la aplicación; actualmente solo puede ver los del día
  en curso a través de la vista "Pedidos de hoy".
- **Qué resultado funcional se espera:** El usuario puede seleccionar una fecha
  pasada y visualizar los pedidos de ese día en una tabla de solo lectura, con
  la misma estructura de información que la vista de pedidos de hoy (clientes ×
  productos × cantidades).

## 3) Alcance

### En alcance

- Listado de fechas disponibles basado en los archivos `.xlsx` existentes en
  `{workFolder}/historico/`.
- Selección de una fecha para visualizar los pedidos de ese día.
- Visualización de los pedidos en formato tabular (clientes, productos,
  cantidades) en modo solo lectura.
- Estados especiales: vacío (sin archivos históricos), carga, error, carpeta de
  trabajo no configurada.
- Búsqueda/filtrado de clientes dentro de la vista de un día seleccionado.
- Filtrado por rango de fechas en el listado de históricos.
- Visualización de totales por producto y total general (consistente con la
  vista de pedidos de hoy).

### Fuera de alcance

- Edición, creación o eliminación de pedidos históricos desde esta vista.
- Exportación a PDF o a nuevo Excel desde esta vista (contemplado para una
  iteración futura).
- Comparativa entre días o informes agregados multi-día.
- Fusión o consolidación de archivos históricos.

## 4) Actores implicados

- **Usuario final (operador):** Persona que gestiona los pedidos diarios y
  necesita consultar el historial para referencia, verificación o seguimiento.

## 5) Requisitos funcionales

- **RF-01:** La vista debe listar las fechas para las cuales existen archivos de
  pedidos en la carpeta `historico/` del directorio de trabajo configurado.
- **RF-02:** Las fechas deben mostrarse ordenadas de más reciente a más antigua.
- **RF-03:** El día actual (hoy) debe excluirse del listado, ya que sus pedidos
  se gestionan en "Pedidos de hoy".
- **RF-04:** Al seleccionar una fecha, la vista debe cargar y mostrar los
  pedidos de ese día en una tabla con columnas de cliente, productos y
  cantidades.
- **RF-05:** La tabla de pedidos históricos debe ser de solo lectura (sin
  posibilidad de editar celdas, añadir filas ni eliminar filas).
- **RF-06:** Se debe mostrar una fila de totales por producto y un total
  general, igual que en la vista de pedidos de hoy.
- **RF-07:** Se debe ofrecer un campo de búsqueda para filtrar clientes por
  nombre dentro de la fecha seleccionada.
- **RF-08:** Si la carpeta de trabajo no está configurada, se debe mostrar un
  estado informativo con opción de ir a Ajustes (consistente con el
  comportamiento de "Pedidos de hoy").
- **RF-09:** Si no existen archivos históricos, se debe mostrar un estado vacío
  descriptivo.
- **RF-10:** Se debe ofrecer un mecanismo de filtrado por rango de fechas (fecha
  inicio – fecha fin) para acotar el listado de históricos.
- **RF-11:** La lista de fechas y datos debe recargarse automáticamente cada vez
  que el usuario navegue a la sección desde el menú lateral (no se requiere
  botón de recarga explícito).

## 6) Criterios de aceptación

- **CA-01:** Al navegar a "Historial de pedidos" con una carpeta de trabajo
  válida, se muestra una lista de fechas disponibles extraídas de los archivos
  `YYYY-MM-DD.xlsx` en `historico/`.
- **CA-02:** La fecha del día actual no aparece en el listado.
- **CA-03:** Las fechas se muestran de más reciente a más antigua.
- **CA-04:** Al seleccionar una fecha, se carga la tabla de pedidos
  correspondiente en modo solo lectura.
- **CA-05:** La tabla muestra los mismos datos que `OrderSheet`: columnas de
  productos, filas de clientes con sus cantidades, fila de totales y total
  general.
- **CA-06:** El campo de búsqueda filtra las filas visibles por nombre de
  cliente.
- **CA-07:** Si la carpeta de trabajo no está configurada, se muestra un mensaje
  con botón para navegar a Ajustes.
- **CA-08:** Si no hay archivos históricos (o la carpeta `historico/` está
  vacía), se muestra un estado vacío con mensaje explicativo.
- **CA-09:** Si un archivo `.xlsx` no se puede leer o tiene formato inválido, se
  muestra un estado de error sin romper la vista general.
- **CA-10:** La vista usa i18n para todos los textos visibles al usuario y
  design tokens del tema para estilos visuales.
- **CA-11:** El usuario puede establecer un rango de fechas (inicio y fin) y el
  listado se filtra mostrando solo las fechas dentro de ese rango.
- **CA-12:** Al navegar a la sección desde el menú lateral, la lista de fechas
  se recarga automáticamente reflejando el estado actual de la carpeta
  `historico/`.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario selecciona "Historial de pedidos" en el menú lateral.
2. El sistema verifica que la carpeta de trabajo esté configurada.
3. El sistema escanea la carpeta `{workFolder}/historico/` y obtiene la lista de
   archivos `.xlsx` cuyo nombre sigue el patrón `YYYY-MM-DD.xlsx`, excluyendo el
   del día actual.
4. Se muestra el listado de fechas disponibles, ordenadas de más reciente a más
   antigua.
5. (Opcional) El usuario filtra por rango de fechas para acotar el listado.
6. El usuario selecciona una fecha.
7. El sistema lee el archivo Excel correspondiente y muestra los pedidos en una
   tabla de solo lectura.
8. El usuario puede buscar clientes por nombre usando el campo de búsqueda.

### Flujos alternativos

- **FA-01 — Carpeta de trabajo no configurada:** Se muestra estado informativo
  con botón "Ir a Ajustes", igual que en "Pedidos de hoy".
- **FA-02 — Sin archivos históricos:** Se muestra estado vacío (icono + mensaje
  descriptivo indicando que no hay pedidos anteriores).
- **FA-03 — Archivo corrupto o con formato inválido:** Se muestra un error
  asociado a esa fecha específica sin afectar la navegación general. El usuario
  puede volver al listado y seleccionar otra fecha.
- **FA-04 — El usuario vuelve al listado de fechas:** Desde la vista de detalle
  de una fecha, el usuario puede volver al listado para seleccionar otra fecha.

### Estados especiales / excepciones

- **Estado vacío:** Sin archivos en `historico/` (excluyendo hoy). Mostrar
  icono + texto "No hay pedidos anteriores registrados" o equivalente.
- **Estado loading:** Mostrar indicador de carga mientras se escanea la carpeta
  o se lee un archivo Excel.
- **Estado error:** Si falla la lectura de un archivo, mostrar mensaje de error
  con opción de reintentar o volver al listado.
- **Sin carpeta configurada:** Mismo patrón que "Pedidos de hoy" — mensaje +
  botón a Ajustes.

## 8) Edge cases

- **EC-01:** La carpeta `historico/` no existe dentro del directorio de trabajo
  → Tratar como estado vacío (sin archivos históricos).
- **EC-02:** Existen archivos `.xlsx` con nombres que no siguen el patrón
  `YYYY-MM-DD.xlsx` → Ignorarlos silenciosamente.
- **EC-03:** El archivo del día actual existe en `historico/` → Excluirlo del
  listado (se gestiona en "Pedidos de hoy").
- **EC-04:** Un archivo histórico tiene una estructura de columnas diferente a
  la plantilla actual → Mostrarlo tal como está (las columnas se determinan por
  el contenido del archivo, no por la plantilla).
- **EC-05:** Se elimina o añade un archivo mientras la vista está abierta → No
  se requiere actualización en tiempo real; la lista se recarga al volver a
  navegar a la sección.
- **EC-06:** Un archivo tiene 0 filas de clientes (solo cabeceras) → Mostrar
  tabla vacía con las cabeceras de productos pero sin filas de datos.

## 9) Impacto funcional

- **Módulos o procesos afectados:**
  - `orders_history` — feature principal a implementar (actualmente solo tiene
    un placeholder).
  - Reutilización del datasource Excel existente (`ExcelLocalDataSource`) y la
    entidad `OrderSheet`/`OrderRow` de `orders_today`.
  - No se modifica la lógica de "Pedidos de hoy" ni de otras features.
- **Impacto en usuario o negocio:** El operador tendrá acceso a la consulta de
  históricos directamente desde la aplicación, eliminando la necesidad de abrir
  manualmente archivos Excel.
- **Impacto en experiencia de usuario:** Navegación coherente con la vista de
  "Pedidos de hoy" — mismos patrones visuales, misma tabla, mismos estados
  especiales. Se reduce la curva de aprendizaje.

## 10) Suposiciones

- **S-01:** Los archivos históricos siguen el mismo formato Excel que los
  generados por "Pedidos de hoy" (`OrderSheet` con productos como cabeceras y
  clientes como filas).
- **S-02:** La convención de nombres de archivo es `YYYY-MM-DD.xlsx` dentro de
  la carpeta `historico/`, según se observa en
  `OrdersTodayRepositoryImpl._buildHistoricoPath`.
- **S-03:** La carpeta de trabajo y su subcarpeta `historico/` se configuran en
  Ajustes y son las mismas que usa "Pedidos de hoy".
- **S-04:** No se requiere paginación del listado de fechas en esta primera
  iteración (se asume un volumen razonable de archivos históricos).
- **S-05:** La vista es de solo lectura; no se contempla edición de datos
  históricos.

## 11) Preguntas abiertas

_Todas las preguntas han sido resueltas._

| #     | Pregunta                                | Respuesta                                                                                                    |
| ----- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| PA-01 | ¿Filtrado por rango de fechas?          | Sí. Se incluye filtro por rango de fechas (inicio–fin). Incorporado en RF-10 y CA-11.                        |
| PA-02 | ¿Botón de recarga o recarga al navegar? | Recarga automática al navegar a la sección. No se requiere botón explícito. Incorporado en RF-11 y CA-12.    |
| PA-03 | ¿Exportación futura (PDF/Excel)?        | Sí, se contempla para una iteración futura. Fuera de alcance actual pero el diseño técnico debe facilitarlo. |

## 12) Notas para análisis técnico

- La feature `orders_history` ya tiene la carpeta `presentation/pages/` con un
  placeholder. Falta crear las capas `data/` y `domain/`, o bien reutilizar
  directamente el datasource y entidades de `orders_today`.
- El `ExcelLocalDataSource` de `orders_today` ya expone `readExcel(filePath)` y
  `fileExists(filePath)`, que son las operaciones necesarias para lectura de
  históricos.
- La entidad `OrderSheet` y `OrderRow` de `orders_today/domain/entities/` son
  reutilizables directamente.
- El patrón de ruta de archivos está en
  `OrdersTodayRepositoryImpl._buildHistoricoPath`:
  `{workFolder}/historico/{YYYY-MM-DD}.xlsx`.
- Para el listado de fechas se necesitará un nuevo método que escanee el
  directorio `historico/` y devuelva las fechas disponibles.
- La arquitectura debe seguir Clean Architecture feature-first con BLoC,
  consistente con `orders_today`.
- Widgets reutilizables de `orders_today` (como la tabla) podrían moverse a
  `core/` o duplicarse con adaptaciones (solo lectura, sin checkboxes de
  selección).
- La carpeta de trabajo se obtiene vía `SettingsRepository.getWorkFolder()`.
- El diseño técnico debe facilitar la incorporación futura de exportación
  (PDF/Excel) desde la vista de historial.
- La recarga del listado debe dispararse al navegar a la sección (mismo patrón
  que `OrdersTodayPage` con `_onMenuChanged`).
- **Estado: Listo para análisis técnico**
