# Functional Analysis: Shipping Methods — Mobile Card Layout

- **Fecha:** 2026-05-12
- **Identificador:** shipping-methods-mobile-cards
- **Estado:** Ready for technical analysis

## 1) Resumen

Adaptar la pantalla "Métodos de envío" para que sea responsive en dispositivos
móviles (≤ 768 px). En lugar de la tabla actual se mostrará una lista de cards
con las acciones de editar y eliminar integradas. Se añadirá un SearchBar debajo
del AppBar siguiendo el patrón ya implementado en la pantalla de Clientes
(`ClientsPage`).

## 2) Contexto y objetivo

- **Qué se solicita:** Rediseño del layout mobile de la pantalla
  `ShippingMethodsPage` para sustituir la tabla por cards y mover la barra de
  búsqueda debajo del AppBar con el estilo de la pantalla de Clientes.
- **Qué problema resuelve:** Actualmente la pantalla usa un layout de tabla con
  `Row` + `Expanded` que no se adapta bien a pantallas pequeñas. El buscador y
  el botón "Añadir" están en una fila horizontal que se desborda (visible en el
  banner "OVERFLOWED BY 149 PIXELS" de la captura).
- **Resultado funcional esperado:** En pantallas ≤ 768 px el usuario ve una
  lista de cards scrollable con las mismas funcionalidades (búsqueda, añadir,
  editar, eliminar) pero adaptadas al espacio reducido.

## 3) Alcance

### En alcance

- Detección de breakpoint mobile (≤ `AppSideMenu.mobileBreakpoint`, 768 px) en
  `ShippingMethodsPage`.
- Layout mobile: SearchBar debajo del AppBar con fondo `primary` (patrón
  `_buildMobileSearchBar` de `ClientsPage`).
- Layout mobile: lista de cards en lugar de tabla para mostrar los métodos de
  envío.
- Cada card muestra: nombre del método y teléfono (si existe).
- Cada card incluye acciones de **Editar** y **Eliminar** accesibles
  directamente (iconos o botones dentro del card).
- FAB (FloatingActionButton) para "Añadir método de envío" en mobile (reemplaza
  el `FilledButton` que se desborda).
- Feedback en mobile mediante `SnackBar` en lugar del `Card` inline (patrón de
  `ClientsPage._showFeedback`).
- El layout desktop permanece **sin cambios**.

### Fuera de alcance

- Cambios en la lógica de negocio (cubit, repositorio, datasource).
- Cambios en la entidad `ShippingMethod`.
- Modificaciones al layout desktop existente.
- Cambios en las cadenas i18n (se reutilizan las existentes).
- Navegación a pantalla de detalle (no existe un detalle de método de envío).

## 4) Actores implicados

- **Usuario final:** Operador que gestiona los métodos de envío desde un
  dispositivo móvil o ventana de navegador estrecha.

## 5) Requisitos funcionales

- **RF-01:** Si el ancho de pantalla es ≤ 768 px, la página debe renderizar el
  layout mobile; en caso contrario, el layout desktop (sin cambios).
- **RF-02:** En mobile, se muestra un SearchBar debajo del AppBar con fondo
  `colorScheme.primary` y campo de texto con fondo blanco/surface, siguiendo el
  patrón de `ClientsPage._buildMobileSearchBar`.
- **RF-03:** En mobile, los métodos de envío se muestran como una lista vertical
  de cards (`ListView.builder`).
- **RF-04:** Cada card muestra el nombre del método de envío como título y el
  teléfono (o "—" si está vacío) como subtítulo/detalle.
- **RF-05:** Cada card contiene dos acciones visibles: un botón/icono de
  **Editar** y un botón/icono de **Eliminar**.
- **RF-06:** Al pulsar Editar se abre el mismo diálogo de edición actual
  (`_showEditDialog`).
- **RF-07:** Al pulsar Eliminar se abre el mismo diálogo de confirmación actual
  (`_showDeleteConfirmation`).
- **RF-08:** En mobile, un FAB permite añadir un nuevo método de envío,
  invocando `_showAddDialog`.
- **RF-09:** En mobile, el feedback de operaciones (añadir/editar/eliminar) se
  muestra como `SnackBar` en lugar del `Card` inline de desktop.
- **RF-10:** La búsqueda en mobile filtra la lista de cards en tiempo real,
  reutilizando `ShippingMethodsCubit.filterByName`.

## 6) Criterios de aceptación

- **CA-01:** En un dispositivo con ancho ≤ 768 px, la pantalla muestra cards en
  lugar de tabla.
- **CA-02:** El SearchBar aparece debajo del AppBar con fondo del color primary
  del tema.
- **CA-03:** Cada card muestra nombre y teléfono del método de envío.
- **CA-04:** Pulsar el icono de editar en un card abre el diálogo de edición y
  permite modificar el método.
- **CA-05:** Pulsar el icono de eliminar en un card abre el diálogo de
  confirmación y permite eliminar el método.
- **CA-06:** El FAB "+" es visible en la esquina inferior derecha y abre el
  diálogo de añadir.
- **CA-07:** Al buscar texto en el SearchBar, la lista de cards se filtra
  mostrando solo los métodos cuyo nombre coincida.
- **CA-08:** Al limpiar el campo de búsqueda, se muestran todos los métodos.
- **CA-09:** Los estados de carga, error y vacío se renderizan correctamente en
  mobile.
- **CA-10:** El layout desktop no sufre cambios visibles.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario abre la pantalla "Métodos de envío" en un dispositivo móvil.
2. Se muestra el AppBar con el título, debajo un SearchBar con fondo primary.
3. Los métodos de envío se cargan y se muestran como cards en una lista
   scrollable.
4. El usuario visualiza nombre y teléfono de cada método con iconos de editar y
   eliminar.
5. Un FAB "+" está visible en la esquina inferior derecha.

### Flujos alternativos

- **Buscar:** El usuario escribe en el SearchBar → la lista se filtra en tiempo
  real → al pulsar "X" se limpia y se muestran todos.
- **Añadir:** El usuario pulsa el FAB → se abre diálogo de añadir → introduce
  nombre → confirma → el método aparece en la lista → SnackBar de confirmación.
- **Editar:** El usuario pulsa el icono de editar en un card → se abre diálogo
  de edición → modifica nombre/teléfono → confirma → el card se actualiza →
  SnackBar de confirmación.
- **Eliminar:** El usuario pulsa el icono de eliminar → se abre diálogo de
  confirmación → confirma → el card desaparece → SnackBar de confirmación.

### Estados especiales / excepciones

- **Estado vacío:** Se muestra texto centrado "No hay métodos de envío"
  (reutiliza `l10n.shippingMethodsEmpty`).
- **Estado loading:** Se muestra `CircularProgressIndicator` centrado.
- **Estado error:** Se muestra icono de error + mensaje + botón "Reintentar"
  (misma lógica actual de `_buildError`).
- **Búsqueda sin resultados:** La lista queda vacía, se muestra el mensaje de
  vacío.

## 8) Edge cases

- **EC-01:** El nombre del método de envío es muy largo → el texto debe
  truncarse con `TextOverflow.ellipsis` dentro del card.
- **EC-02:** Redimensionamiento de ventana en tiempo real (escritorio ↔ mobile)
  → la UI debe alternar entre tabla y cards sin perder estado de búsqueda ni
  datos.
- **EC-03:** Operación de eliminar mientras hay un filtro activo → el card
  desaparece de la lista filtrada y del listado completo.
- **EC-04:** Lista con muchos métodos (> 50) → el `ListView.builder` debe
  manejar el scroll eficientemente (lazy rendering).

## 9) Impacto funcional

- **Módulos afectados:** Solo `ShippingMethodsPage` (presentación). No hay
  cambios en capas data/domain.
- **Impacto en usuario:** Mejora significativa de usabilidad en mobile; elimina
  el desbordamiento visual actual.
- **Impacto en experiencia de usuario:** Consistencia con el patrón mobile ya
  establecido en la pantalla de Clientes.

## 10) Suposiciones

- Se reutiliza el breakpoint existente `AppSideMenu.mobileBreakpoint` (768 px).
- El widget `ClientCard` sirve solo como referencia de patrón visual; se creará
  un widget específico `ShippingMethodCard` ya que los datos y acciones son
  diferentes.
- Los diálogos de añadir, editar y eliminar permanecen sin cambios (modales
  `AlertDialog`).
- El diseño del card sigue los design tokens del tema (colores, espaciados,
  radios del `theme_constants.dart`).

## 11) Preguntas abiertas

- Ninguna. La petición es clara y el patrón de referencia (`ClientsPage` mobile)
  está bien definido en el código existente.

## 12) Notas para análisis técnico

- Reutilizar el patrón `isMobile ? _buildMobileLayout() : _buildDesktopLayout()`
  de `ClientsPage`.
- Crear widget `ShippingMethodCard` en
  `lib/features/shipping_methods/presentation/widgets/`.
- El card debe incluir las acciones inline (editar/eliminar) en lugar de navegar
  a un detalle.
- Extraer `_buildSearchField` como método compartido con variante `onPrimary`
  para el fondo del SearchBar mobile.
- Usar `FloatingActionButton` posicionado con `Stack` + `Positioned` (mismo
  patrón que `ClientsPage._buildMobileLayout`).
- Cambiar feedback en mobile a `ScaffoldMessenger.showSnackBar` (patrón
  `ClientsPage._showFeedback`).
- No se requieren cambios en BLoC, use cases, repositorio ni datasource.
- **Estado: Listo para análisis técnico**
