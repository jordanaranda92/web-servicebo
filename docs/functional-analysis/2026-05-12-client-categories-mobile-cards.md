# Functional Analysis: Categorías de clientes — Vista mobile con cards

- **Fecha:** 2026-05-12
- **Identificador:** client-categories-mobile-cards
- **Estado:** Ready for technical analysis

## 1) Resumen

Adaptar la pantalla "Categorías de clientes" para que sea funcional y
visualmente correcta en dispositivos móviles (pantalla pequeña). La vista actual
utiliza una tabla que desborda horizontalmente en mobile. Se reemplazará la
tabla por una lista de cards que contengan la información y acciones de cada
categoría, siguiendo el patrón ya implementado en la pantalla de Clientes
(`ClientsPage`).

## 2) Contexto y objetivo

- **Qué se solicita:** Implementar un layout responsive mobile para la pantalla
  de Categorías de clientes.
- **Qué problema resuelve:** La tabla actual genera overflow horizontal
  (~102-160 píxeles) en pantallas pequeñas, haciendo la pantalla inutilizable en
  mobile. Las columnas (Nombre, Clientes, Color, Acciones) no caben en el
  viewport.
- **Qué resultado funcional se espera:** En pantallas con ancho ≤
  `AppSideMenu.mobileBreakpoint`, la pantalla muestra cards en lugar de tabla,
  con un searchbar integrado debajo del AppBar y un FAB para añadir categorías.
  En desktop, el layout actual con tabla se mantiene sin cambios.

## 3) Alcance

### En alcance

- Detección responsive (mobile vs. desktop) basada en el breakpoint existente
  (`AppSideMenu.mobileBreakpoint`)
- Layout mobile: searchbar debajo del AppBar, lista de cards scrollable
- Card de categoría: muestra nombre, color y número de clientes asociados
- Acciones dentro del card: Editar, Vincular clientes, Eliminar
- FAB para añadir nueva categoría (reemplaza el botón inline del desktop)
- Feedback en mobile via `SnackBar` (en lugar de la card de feedback inline del
  desktop)
- Estados: vacío, loading, error — adaptados a mobile

### Fuera de alcance

- Cambios en la lógica de negocio (cubit, use cases, repositorio, data source)
- Cambios en la vista desktop (tabla existente)
- Cambios en los diálogos existentes (añadir, editar, eliminar, asociar
  clientes) — se reutilizan tal cual
- Creación de nuevas traducciones (se reutilizan las existentes)
- Cambios en la entidad `ClientCategory` o su modelo de datos

## 4) Actores implicados

- **Usuario final:** Operador que gestiona categorías de clientes desde un
  dispositivo móvil o pantalla pequeña.

## 5) Requisitos funcionales

- **RF-01:** Cuando el ancho de pantalla es ≤ `AppSideMenu.mobileBreakpoint`, se
  muestra el layout mobile con cards; en caso contrario, se muestra la tabla
  existente (desktop).
- **RF-02:** El layout mobile incluye un searchbar fijo debajo del AppBar (sobre
  fondo `colorScheme.primary`, con campo de texto relleno
  `colorScheme.surface`), idéntico en estilo al de la pantalla de Clientes.
- **RF-03:** Cada categoría se representa como un card que muestra:
  - Nombre de la categoría (texto principal)
  - Indicador de color de la categoría (badge o círculo con el color asignado;
    si no tiene color, indicador "sin color")
  - Número de clientes asociados a esa categoría
- **RF-04:** Cada card incluye acciones accesibles directamente (sin necesidad
  de navegar a otra pantalla):
  - **Editar:** Abre el diálogo de edición existente (`_showEditDialog`)
  - **Vincular clientes:** Abre el diálogo de asociación existente
    (`_showAssociateClientsDialog`)
  - **Eliminar:** Abre el diálogo de confirmación de eliminación existente
    (`_showDeleteConfirmation`)
- **RF-05:** Un FAB (Floating Action Button) permite crear una nueva categoría,
  invocando el diálogo de creación existente (`_showAddCategoryDialog`).
- **RF-06:** El searchbar filtra las categorías por nombre en tiempo real
  (reutiliza `_cubit.filterByName`).
- **RF-07:** El feedback de operaciones (crear, editar, eliminar, asociar) se
  muestra con `SnackBar` en mobile (no la card inline del desktop).

## 6) Criterios de aceptación

- **CA-01:** En un dispositivo con ancho ≤ breakpoint mobile, la pantalla de
  Categorías de clientes muestra cards en lugar de tabla, sin overflow
  horizontal.
- **CA-02:** El searchbar se muestra debajo del AppBar con fondo del color
  primario, y filtra las categorías al escribir.
- **CA-03:** Al pulsar el icono de limpiar (X) en el searchbar, se restaura la
  lista completa de categorías.
- **CA-04:** Cada card muestra: nombre de la categoría, indicador de color y
  conteo de clientes.
- **CA-05:** Desde cada card se puede acceder a Editar, Vincular clientes y
  Eliminar; cada acción abre el diálogo correspondiente.
- **CA-06:** El FAB "+" permite crear una nueva categoría.
- **CA-07:** Tras crear, editar, eliminar o asociar clientes, el feedback se
  muestra como `SnackBar` en la parte inferior.
- **CA-08:** Los estados de loading, error y lista vacía se muestran
  correctamente en mobile.
- **CA-09:** La vista desktop (tabla) permanece inalterada.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario abre la pantalla "Categorías de clientes" en un dispositivo móvil.
2. Se muestra el searchbar debajo del AppBar y la lista de cards con las
   categorías existentes.
3. Cada card muestra nombre, color y clientes asociados, con iconos/botones de
   acción.
4. El usuario puede buscar categorías escribiendo en el searchbar.
5. El usuario puede editar, vincular clientes o eliminar desde cada card.
6. El usuario puede crear una nueva categoría pulsando el FAB.

### Flujos alternativos

- **FA-01 — Búsqueda sin resultados:** El searchbar tiene texto pero no hay
  categorías que coincidan → se muestra el mensaje de lista vacía.
- **FA-02 — Limpieza de búsqueda:** El usuario pulsa la X en el searchbar → se
  limpia el filtro y se muestran todas las categorías.

### Estados especiales / excepciones

- **Estado vacío:** No hay categorías creadas → se muestra el texto
  `clientCategoriesEmpty` centrado, con el FAB disponible para crear la primera
  categoría.
- **Estado loading:** Se muestra un `CircularProgressIndicator` centrado.
- **Estado error:** Se muestra el mensaje de error correspondiente
  (configNotFound, network, server, unknown) con botón de reintentar (excepto
  configNotFound).
- **Sin conexión / error de red:** Estado error genérico con posibilidad de
  reintentar.

## 8) Edge cases

- **EC-01:** Categoría con nombre muy largo → el texto se trunca con
  `TextOverflow.ellipsis` dentro del card.
- **EC-02:** Categoría sin color asignado → se muestra el indicador "sin color"
  (icono o painter existente `_NoColorPainter`).
- **EC-03:** Categoría con 0 clientes asociados → se muestra "0" como conteo.
- **EC-04:** Rotación de pantalla o cambio de tamaño de ventana (desktop →
  mobile y viceversa) → el layout se adapta dinámicamente al breakpoint sin
  perder el estado (filtro de búsqueda, datos cargados).
- **EC-05:** Se elimina la última categoría visible por filtro → la lista queda
  vacía mostrando el estado vacío.

## 9) Impacto funcional

- **Módulos afectados:** Solo la capa de presentación de `client_categories`
  (`ClientCategoriesPage`). Potencialmente se crea un nuevo widget
  `ClientCategoryCard`.
- **Impacto en usuario:** Los usuarios móviles podrán gestionar categorías de
  clientes correctamente, sin overflow ni UI rota.
- **Impacto en experiencia de usuario:** Experiencia consistente con la pantalla
  de Clientes, que ya sigue este patrón card-based para mobile.

## 10) Suposiciones

- Se reutiliza el mismo breakpoint (`AppSideMenu.mobileBreakpoint`) que usa
  `ClientsPage` para determinar si es mobile.
- Los diálogos existentes (añadir, editar, eliminar, asociar clientes) funcionan
  correctamente en pantallas pequeñas sin modificación.
- Las constantes de tema y spacing (`AppSpacing`, `AppRadii`, `AppElevation`,
  `AppOpacity`) son las mismas usadas en `ClientCard`.
- La estructura del card sigue el patrón visual de `ClientCard` adaptado a la
  información de categorías (nombre + color + conteo en lugar de nombre +
  categoría + fiscal ID).

## 11) Preguntas abiertas

- **PA-01:** ¿Las acciones dentro del card deben mostrarse como iconos siempre
  visibles (fila de iconos al pie del card), como un menú popup (tres puntos) o
  como acciones deslizables (swipe)? **Supuesto asumido:** Iconos siempre
  visibles en una fila dentro del card, consistente con la experiencia directa
  actual de la tabla.
- **PA-02:** ¿Se requiere poder navegar a un detalle de categoría al tocar el
  card (como los clientes navegan a detalle), o basta con las tres acciones?
  **Supuesto asumido:** No hay pantalla de detalle de categoría; el tap en el
  card no navega a ningún sitio; solo se usan los botones de acción.

## 12) Notas para análisis técnico

- **Patrón de referencia:** Seguir exactamente la estructura de `ClientsPage` —
  detección `isMobile` con `MediaQuery`, método `_buildMobileLayout` con `Stack`
  (contenido + FAB posicionado), método `_buildMobileSearchBar` con fondo
  primario.
- **Widget card:** Crear `ClientCategoryCard` en
  `lib/features/client_categories/presentation/widgets/` siguiendo el patrón de
  `ClientCard`.
- **Feedback mobile:** Reutilizar patrón `_showFeedback` de `ClientsPage` que
  usa `SnackBar` en mobile vs `FeedbackCubit` en desktop.
- **Datos del card:** El card necesita: `ClientCategory`, `int clientCount`, y
  callbacks para las tres acciones (editar, vincular, eliminar).
- **Sin cambios en cubit/estado:** No se requieren cambios en
  `ClientCategoriesCubit` ni en `ClientCategoriesState`; toda la lógica de
  filtrado y operaciones ya existe.
- **Dependencia de datos:** `_clientCountByCategory` ya se calcula en el state
  de la página; se pasa al card como parámetro.
- **Estado: Listo para análisis técnico**
