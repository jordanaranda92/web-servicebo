# Functional Analysis: Filtros avanzados y vista mobile en Facturas

- **Fecha:** 2026-05-12
- **Identificador:** invoices-filters-mobile
- **Estado:** Ready for technical analysis

## 1) Resumen

Se solicita añadir un sistema de filtros avanzados a la pantalla de Facturas
(botón de filtro + dialog + chips + botón limpiar filtros), cambiar la carga por
defecto a rango de fechas (última semana), sustituir la paginación clásica por
carga progresiva (infinite scroll / botón "Cargar más") para manejar el límite
de 500 resultados por petición de la API, y diseñar un layout mobile con cards
siguiendo el patrón establecido en Productos y Clientes.

## 2) Contexto y objetivo

- **Qué se solicita:** Transformar la pantalla de Facturas para incorporar
  filtrado avanzado multidimensional (estado, clientes, rango de fechas) y
  adaptarla a dispositivos móviles.
- **Qué problema resuelve:** Actualmente la pantalla carga todas las facturas
  sin filtros (hasta 500), con paginación, y sin layout mobile. El usuario
  necesita localizar facturas rápidamente por estado, cliente o período, y
  consultar desde dispositivos móviles.
- **Resultado funcional esperado:** Una pantalla de facturas con filtros
  intuitivos, carga inicial optimizada (solo última semana) y experiencia mobile
  equivalente a la de Productos y Clientes.

## 3) Alcance

### En alcance

- Botón "Filtrar" junto al search TextField (desktop y mobile)
- Dialog de filtros con los campos: estado, clientes (selector múltiple), fecha
  desde y fecha hasta
- Chips de filtros activos debajo de la línea del search TextField, con opción
  de eliminar individualmente (×)
- Filtro por defecto al entrar: fecha desde = hace 7 días, fecha hasta = hoy
- Sustitución de la paginación clásica por carga progresiva (infinite scroll /
  botón "Cargar más") cuando la API devuelve el máximo de 500 resultados
- Botón "Limpiar filtros" en el dialog para resetear todos los filtros de una
  vez
- Las fechas por defecto pueden eliminarse (no son obligatorias)
- Layout mobile responsive (cards) siguiendo el patrón de Productos y Clientes
- Integración con la API existente de Factura Directa (`getInvoicesByDateRange`)

### Fuera de alcance

- Filtrado server-side por estado o contacto (la API de Factura Directa no
  soporta estos filtros; se aplicarán client-side)
- Persistencia de filtros entre sesiones (cookies/local storage)
- Exportación de facturas filtradas
- Detalle de factura (pantalla individual)
- Ordenación de columnas
- Nuevas funcionalidades de creación/edición de facturas

## 4) Actores implicados

- **Usuario final (operador):** Consulta y filtra facturas desde desktop o móvil
- **API Factura Directa (sistema externo):** Proveedor de datos de facturas con
  soporte de filtrado por rango de fechas

## 5) Requisitos funcionales

- **RF-01:** Al cargar la pantalla de Facturas, se debe aplicar automáticamente
  un filtro de fecha desde = 7 días atrás y fecha hasta = fecha actual,
  invocando `getInvoicesByDateRange` en lugar de `getInvoices`.
- **RF-02:** Se debe mostrar un botón de "Filtrar" (icono `filter_list`) junto
  al search TextField existente. En desktop aparece al lado del campo de
  búsqueda; en mobile aparece integrado en la barra de búsqueda.
- **RF-03:** Al pulsar el botón de Filtrar se abre un Dialog con los siguientes
  campos:
  - **Estado:** Selector múltiple con las opciones: Pagada (`paid`), Pendiente
    (`pending`), Vencida (`overdue`), Borrador (`draft`), Anulada (`voided`).
    Los valores se basan en los estados reconocidos en el widget
    `InvoiceStatusChip`.
  - **Clientes:** Selector múltiple que muestra los nombres de clientes
    extraídos de las facturas actualmente cargadas (valores únicos de
    `contactName`).
  - **Fecha desde:** Selector de fecha (date picker).
  - **Fecha hasta:** Selector de fecha (date picker).
- **RF-04:** El dialog muestra los valores actuales de los filtros activos al
  abrirse. Al confirmar ("Aplicar"), los filtros se aplican. Al cancelar, no se
  modifica nada. El dialog incluye un botón "Limpiar filtros" que resetea todos
  los campos (estados, clientes, fechas) a vacío.
- **RF-05:** Cuando hay filtros activos (distintos al default), se muestran como
  chips debajo de la línea del search TextField. Cada chip muestra el nombre
  descriptivo del filtro y un botón × para eliminarlo individualmente.
- **RF-06:** Al eliminar un chip de fecha (desde o hasta), se limpia ese filtro
  de fecha. Al eliminar un chip de estado o cliente, se elimina ese valor
  concreto del filtro múltiple.
- **RF-07:** Cuando se modifican los filtros de fecha (desde/hasta), se realiza
  una nueva llamada a la API con `getInvoicesByDateRange`. Si se eliminan ambas
  fechas, se llama a `getInvoices` (sin rango).
- **RF-08:** Los filtros de estado y cliente se aplican client-side sobre los
  datos devueltos por la API.
- **RF-09:** La paginación clásica (footer con páginas) se elimina. Si la API
  devuelve exactamente 500 resultados (el límite), se muestra un mecanismo de
  carga progresiva (infinite scroll en mobile, botón "Cargar más" en desktop)
  que solicita la siguiente página de resultados a la API y los acumula a los ya
  mostrados. Si devuelve menos de 500, se asume que no hay más datos.
- **RF-10:** El search TextField existente sigue funcionando como filtro de
  texto libre (búsqueda en número de factura, cliente, subtotal, total) y se
  combina con los filtros avanzados.
- **RF-11:** En pantallas ≤ 768 px (breakpoint `AppSideMenu.mobileBreakpoint`),
  las facturas se muestran como cards en lugar de tabla, siguiendo el mismo
  patrón visual que `ProductCard` y `ClientCard`.
- **RF-12:** La card de factura mobile debe mostrar: número de factura, fecha,
  nombre de cliente, chip de estado, subtotal y total.

## 6) Criterios de aceptación

- **CA-01:** Al abrir la pantalla de Facturas, solo se muestran facturas de los
  últimos 7 días. Los chips de "Desde: [fecha]" y "Hasta: [fecha]" son visibles
  por defecto.
- **CA-02:** Al pulsar el botón Filtrar, se abre un dialog con los 4 campos de
  filtro correctamente inicializados con los valores activos.
- **CA-03:** Al seleccionar uno o varios estados y pulsar Aplicar, la
  tabla/cards solo muestra facturas con esos estados. Aparecen chips
  correspondientes.
- **CA-04:** Al seleccionar uno o varios clientes y pulsar Aplicar, solo se
  muestran las facturas de esos clientes. Aparecen chips correspondientes.
- **CA-05:** Al cambiar las fechas desde/hasta y pulsar Aplicar, se realiza una
  nueva petición a la API con el rango indicado. Los resultados se actualizan.
- **CA-06:** Al pulsar × en un chip de filtro, ese filtro se elimina y los
  resultados se actualizan inmediatamente.
- **CA-07:** No existe footer de paginación clásica. Si hay más de 500 facturas,
  se ofrece carga progresiva (infinite scroll en mobile / botón "Cargar más" en
  desktop).
- **CA-08:** En un viewport ≤ 768 px, las facturas se muestran como cards con la
  información requerida (RF-12).
- **CA-09:** El campo de búsqueda de texto libre funciona combinado con los
  filtros avanzados (intersección).
- **CA-10:** Si la API devuelve error al cambiar el rango de fechas, se muestra
  la pantalla de error existente con opción de reintentar.

## 7) Flujos y comportamiento esperado

### Flujo principal — Carga inicial

1. El usuario navega a la pantalla de Facturas.
2. El sistema calcula fecha desde = hoy - 7 días, fecha hasta = hoy.
3. Se llama a `getInvoicesByDateRange(minDate, maxDate)`.
4. Se muestran los resultados en tabla (desktop) o cards (mobile).
5. Los chips de "Desde" y "Hasta" aparecen debajo del search TextField.

### Flujo principal — Aplicar filtros

1. El usuario pulsa el botón Filtrar.
2. Se abre el dialog con los filtros actuales precargados.
3. El usuario selecciona estados, clientes y/o modifica fechas.
4. El usuario pulsa "Aplicar".
5. Si las fechas cambiaron, se realiza nueva petición a la API.
6. Se aplican filtros de estado y cliente client-side.
7. La tabla/cards se actualiza. Los chips reflejan los filtros activos.

### Flujo alternativo — Eliminar filtro desde chip

1. El usuario pulsa × en un chip (ej: estado "Pendiente").
2. Se elimina ese valor del filtro correspondiente.
3. Si se eliminó una fecha, se re-evalúa si se necesita nueva llamada API.
4. Los resultados se actualizan inmediatamente.

### Flujo alternativo — Sin resultados

1. La combinación de filtros no produce resultados.
2. Se muestra el mensaje vacío existente (`invoicesEmpty`).

### Flujo alternativo — Limpiar todos los filtros

1. El usuario pulsa "Limpiar filtros" en el dialog, o elimina todos los chips
   uno a uno.
2. Al limpiar desde el dialog: todos los campos se resetean a vacío y al pulsar
   "Aplicar" se ejecuta sin filtros.
3. Si se eliminan ambas fechas, se llama a `getInvoices()` (carga completa,
   máximo 500).
4. Si elimina solo estados/clientes, se mantiene el rango de fechas activo.

### Flujo alternativo — Carga progresiva (más de 500 resultados)

1. La API devuelve exactamente 500 facturas.
2. Se muestra un indicador de que hay más resultados disponibles.
3. En desktop: botón "Cargar más" al final de la tabla. En mobile: infinite
   scroll al llegar al final de la lista.
4. Al activar la carga, se solicita la siguiente página (offset/cursor) a la API
   con los mismos filtros de fecha.
5. Los nuevos resultados se acumulan a los existentes y se aplican los filtros
   client-side (estado, cliente, texto).
6. Si la siguiente página devuelve menos de 500, se oculta el mecanismo de carga
   progresiva.

## 8) Estados especiales / excepciones

- **Estado loading:** Se muestra `CircularProgressIndicator` mientras se
  obtienen datos de la API (al cambiar rango de fechas).
- **Estado error:** Se reutiliza la pantalla de error existente (`_buildError`)
  con botón de reintentar.
- **Estado vacío:** Se muestra el mensaje `invoicesEmpty` cuando los filtros no
  producen resultados.
- **Sin conectividad:** Error de red se captura y muestra como error
  recuperable.

## 8) Edge cases

- **EC-01:** El usuario selecciona fecha desde posterior a fecha hasta → El
  dialog debe validar que fecha desde ≤ fecha hasta antes de permitir Aplicar.
- **EC-02:** El usuario elimina todas las fechas → Se llama a `getInvoices()`
  sin rango (carga completa, limitada a 500 por petición; se activa carga
  progresiva si aplica).
- **EC-03:** La lista de clientes en el selector depende de los datos cargados.
  Si se cambia el rango de fechas y se recargan datos, la lista de clientes
  disponibles en el selector puede cambiar.
- **EC-04:** Un cliente aparece con nombre `null` o vacío en alguna factura →
  Mostrar como "—" o excluir del selector de clientes.
- **EC-05:** La API devuelve 0 facturas para el rango de fechas por defecto
  (semana actual) → Mostrar estado vacío con los chips de fecha activos.
- **EC-06:** Facturas con estado no reconocido (no es `paid`, `pending`,
  `overdue`, `draft` ni `voided`) → No aparecen en el selector de estados del
  dialog pero siguen visibles si no se filtra por estado.
- **EC-07:** En mobile, chips de filtros deben ser scrollables horizontalmente
  si hay muchos activos para no empujar el contenido.

## 9) Impacto funcional

- **Módulos afectados:**
  - `invoices/presentation/pages/invoices_page.dart` — Cambios en layout, añadir
    botón filtro, chips, eliminar paginación, layout mobile
  - `invoices/presentation/bloc/invoices_cubit.dart` — Nuevos métodos de
    filtrado, cambio de carga inicial a rango de fechas, eliminar lógica de
    paginación
  - `invoices/presentation/bloc/invoices_state.dart` — Nuevos campos para
    filtros activos, eliminar campos de paginación
  - Nuevo widget: card de factura mobile (`InvoiceCard`)
  - Nuevo widget: dialog de filtros (`InvoiceFiltersDialog`)
- **Impacto en usuario:** Mejora significativa en la capacidad de búsqueda y
  consulta de facturas. La carga inicial será más rápida al limitar a 7 días.
- **Impacto en experiencia mobile:** La pantalla de Facturas pasa de no ser
  usable en mobile a tener una experiencia equivalente a Productos y Clientes.
- **Widgets eliminados:** `PaginationFooter` deja de usarse en esta pantalla.
- **Nuevo comportamiento:** Carga progresiva (infinite scroll / "Cargar más")
  cuando la API alcanza el límite de 500 por petición.

## 10) Suposiciones

- **S-01:** Los estados de factura válidos son los 5 reconocidos en
  `InvoiceStatusChip`: `paid`, `pending`, `overdue`, `draft`, `voided`. Se asume
  que estos son los únicos estados que devuelve la API de Factura Directa.
- **S-02:** La API de Factura Directa no soporta filtrado server-side por estado
  ni por contacto en el endpoint de listado de facturas. Solo soporta
  `minDate`/`maxDate` y `contact` (este último junto con rango de fechas en
  `getInvoicesByContact`).
- **S-03:** El selector de clientes se construye dinámicamente con los
  `contactName` únicos de las facturas ya cargadas, no con el listado completo
  de clientes del sistema.
- **S-04:** 7 días es el rango confirmado como filtro por defecto.
- **S-05:** Los chips de fecha por defecto (Desde/Hasta de la semana) se
  muestran al cargar, pero el usuario puede eliminarlos.
- **S-06:** La API de Factura Directa devuelve un máximo de 500 resultados por
  petición. Se necesita paginación por offset o cursor para obtener más.

## 11) Preguntas abiertas

- ~~**PA-01:** ¿El rango de 7 días por defecto es adecuado?~~ → **Resuelto: Sí,
  7 días confirmado.**
- ~~**PA-02:** ¿Debe existir un botón "Limpiar todos los filtros"?~~ →
  **Resuelto: Sí, incluir botón en el dialog.**
- ~~**PA-03:** ¿Los filtros de fecha son obligatorios?~~ → **Resuelto: No, deben
  poder eliminarse.**
- **PA-04:** ¿La API de Factura Directa soporta paginación por offset
  (`start`/`limit`) o por cursor? Verificar el parámetro de paginación
  disponible para implementar carga progresiva.

## 12) Notas para análisis técnico

- La API ya dispone de `getInvoicesByDateRange` en el repositorio y data source;
  se debe reutilizar.
- El `InvoicesCubit` actualmente usa `getInvoices` (sin rango). Se debe cambiar
  la carga inicial a `getInvoicesByDateRange` y añadir métodos para gestionar
  los filtros client-side (estado, cliente).
- La paginación clásica (`currentPage`, `pageSize`, `totalPages`, `pageItems`)
  en `InvoicesState` y `InvoicesCubit` debe eliminarse y sustituirse por lógica
  de carga progresiva (acumulación de páginas de 500).
- Investigar si la API soporta el parámetro `start` (offset) además de `limit`
  para paginar. Actualmente se usa `limit: 500`.
- El patrón mobile (breakpoint, `_buildMobileLayout`, `_buildMobileSearchBar`,
  card widget) está consolidado en `ProductsPage` y `ClientsPage` y debe
  seguirse fielmente.
- Las claves i18n necesarias para labels del dialog de filtros, chips y textos
  del card mobile deben identificarse en el análisis técnico.
- Considerar extraer `_buildSearchField` como widget compartido (patrón usado en
  Productos y Clientes).
- **Estado: Listo para análisis técnico**
