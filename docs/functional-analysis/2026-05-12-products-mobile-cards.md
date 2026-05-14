# Functional Analysis: Productos – Vista Mobile con Cards

- **Fecha:** 2026-05-12
- **Identificador:** products-mobile-cards
- **Estado:** Ready for technical analysis

## 1) Resumen

Adaptar la pantalla de **Productos** para que en dispositivos móviles (ancho ≤
768 px) reemplace la tabla actual por una lista de **cards**, siguiendo el mismo
patrón responsive ya implementado en la pantalla de Clientes. Cada card mostrará
la información del producto y ofrecerá las acciones de **Vincular (a producto de
FacturaDirecta)**, **Editar** y **Eliminar**. Se incluirá un **search bar**
debajo del AppBar para filtrar productos por nombre.

## 2) Contexto y objetivo

- **Qué se solicita:** Un layout mobile-first para la pantalla de Productos que
  utilice cards en lugar de la tabla de escritorio, con un search bar prominente
  y acciones accesibles.
- **Qué problema resuelve:** Actualmente la pantalla de Productos solo tiene
  layout de tabla, que es ilegible e incómodo en pantallas pequeñas. Se necesita
  la misma experiencia responsiva que ya existe en la pantalla de Clientes.
- **Resultado funcional esperado:** En pantallas ≤ 768 px, el usuario ve una
  lista scrollable de cards con las acciones necesarias, y puede buscar
  productos fácilmente desde el search bar.

## 3) Alcance

### En alcance

- Detección responsive por breakpoint `AppSideMenu.mobileBreakpoint` (768 px)
  igual que en Clientes.
- Construcción de layout mobile alternativo (`_buildMobileLayout`) para la
  pantalla de Productos.
- Search bar debajo del AppBar (sobre fondo `colorScheme.primary`) para filtrar
  productos, reutilizando la lógica de `filterByName` ya existente en
  `ProductsCubit`.
- Widget `ProductCard` que muestre:
  - Nombre del producto.
  - Estado activo/inactivo (indicador visual).
  - Nombre del producto de FD vinculado (si existe) y precio.
- Acciones dentro de cada card:
  - **Vincular / Cambiar vínculo FD:** Abre el diálogo `FdProductSelectorDialog`
    existente.
  - **Desvincular FD:** Solo visible si hay un vínculo; desvincula el producto.
  - **Editar:** Abre un diálogo con campos para modificar el **nombre** y el
    **toggle activo/inactivo** del producto.
  - **Eliminar:** Muestra confirmación y elimina el producto.
- FAB (FloatingActionButton) para añadir un nuevo producto, sustituyendo el
  botón `FilledButton` de escritorio.
- Feedback vía `SnackBar` en mobile (igual que en Clientes).
- El layout de escritorio (tabla) permanece sin cambios.

### Fuera de alcance

- Reordenación de productos en mobile (drag & drop); se mantiene solo en
  escritorio.
- Botón de "Reordenar" en mobile.
- Cambios en la lógica de negocio, cubit o estados.
- Modificaciones a la pantalla de Clientes u otras pantallas.
- Edición de campos adicionales más allá de nombre y activo/inactivo en mobile.

## 4) Actores implicados

- **Usuario final:** Operador que gestiona productos desde dispositivo móvil o
  ventana estrecha.

## 5) Requisitos funcionales

- **RF-01:** Si el ancho de pantalla es ≤ `AppSideMenu.mobileBreakpoint` (768
  px), mostrar el layout mobile; si no, mostrar la tabla de escritorio actual.
- **RF-02:** El layout mobile debe incluir un search bar debajo del AppBar
  (fondo primary, texto claro) que filtre productos por nombre en tiempo real.
- **RF-03:** Los productos se muestran como una lista vertical de cards
  scrollable.
- **RF-04:** Cada card muestra: nombre del producto, indicador de
  activo/inactivo, producto FD vinculado (nombre + precio) o indicación de "sin
  vincular".
- **RF-05:** Cada card ofrece las acciones: Vincular (o cambiar vínculo FD),
  Editar (nombre + activo/inactivo), Eliminar.
- **RF-06:** Si el producto tiene un vínculo FD, se mostrará una opción
  adicional de Desvincular.
- **RF-07:** Un FAB con icono "+" permite añadir un nuevo producto.
- **RF-08:** El feedback en mobile se muestra como `SnackBar` (no como el card
  inline del desktop).
- **RF-09:** Los estados de carga, error y lista vacía deben gestionarse igual
  que en el layout desktop (loading spinner, mensaje de error con retry, mensaje
  de vacío).
- **RF-10:** El botón de "Reordenar" no se muestra en mobile.

## 6) Criterios de aceptación

- **CA-01:** En una pantalla de ancho ≤ 768 px, la pantalla de Productos muestra
  cards en lugar de tabla.
- **CA-02:** El search bar aparece debajo del AppBar con fondo primary y permite
  filtrar productos; limpiar el campo restablece la lista completa.
- **CA-03:** Cada card muestra nombre, estado activo/inactivo, y datos del
  producto FD vinculado (si aplica).
- **CA-04:** Desde un card se puede vincular/cambiar producto FD, desvincular,
  editar (nombre y activo/inactivo) y eliminar.
- **CA-05:** Al pulsar el FAB se muestra el diálogo de añadir producto.
- **CA-06:** Tras una operación (vincular, editar, eliminar), se muestra un
  SnackBar con resultado.
- **CA-07:** Con lista vacía, se muestra el mensaje `productsEmpty`.
- **CA-08:** Con error, se muestra el widget de error con botón de reintentar.
- **CA-09:** En desktop (> 768 px), la tabla se muestra sin cambios.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario abre la pantalla de Productos en un dispositivo móvil.
2. Se muestra el search bar debajo del AppBar.
3. Se carga la lista de productos y se muestran como cards.
4. El usuario puede hacer scroll para ver todos los productos.
5. El usuario toca un card para ver las acciones disponibles (mediante botones
   visibles en el card o un menú contextual).

### Flujos alternativos

- **Buscar:** El usuario escribe en el search bar → la lista se filtra en tiempo
  real. Al limpiar el campo, se restaura la lista completa.
- **Vincular a FD:** El usuario pulsa "Vincular" en un card → se abre
  `FdProductSelectorDialog` → selecciona producto FD → se guarda y muestra
  SnackBar de éxito/error.
- **Desvincular FD:** El usuario pulsa "Desvincular" → se desvincula y muestra
  SnackBar.
- **Editar:** El usuario pulsa "Editar" → se abre un diálogo con un campo de
  texto para el nombre y un switch para activo/inactivo → al confirmar se
  guardan los cambios → SnackBar de resultado.
- **Eliminar:** El usuario pulsa "Eliminar" → se muestra diálogo de confirmación
  → confirma → se elimina → SnackBar de resultado.
- **Añadir producto:** El usuario pulsa el FAB → se muestra el diálogo de añadir
  → introduce nombre → se crea el producto.

### Estados especiales / excepciones

- **Estado vacío:** Mensaje centrado `productsEmpty` (sin cards, sin search
  bar).
- **Estado loading:** Spinner centrado.
- **Estado error:** Icono de error + mensaje + botón "Reintentar".
- **Productos FD no cargados:** Si `_cachedFdProducts` es null, el botón de
  vincular muestra SnackBar de error.

## 8) Edge cases

- **EC-01:** El usuario redimensiona la ventana pasando del breakpoint → el
  layout cambia dinámicamente entre cards y tabla.
- **EC-02:** Producto con nombre muy largo → truncar con `TextOverflow.ellipsis`
  en el card.
- **EC-03:** Producto inactivo → mostrar visualmente diferenciado (opacidad
  reducida o indicador).
- **EC-04:** Producto sin vínculo FD → mostrar texto "Sin vincular" o similar;
  no mostrar precio.
- **EC-05:** Lista con un solo producto → el card se muestra correctamente sin
  problemas de layout.
- **EC-06:** Se elimina el último producto → se muestra el estado vacío.

## 9) Impacto funcional

- **Módulos afectados:** `features/products/presentation/` — se modifica
  `products_page.dart` y se crea un nuevo widget `product_card.dart`.
- **Impacto en usuario:** Mejora significativa de la experiencia en mobile para
  gestión de productos.
- **Impacto en experiencia de usuario:** Consistencia con la pantalla de
  Clientes que ya usa cards en mobile.

## 10) Suposiciones

- Se reutiliza el breakpoint existente `AppSideMenu.mobileBreakpoint` (768 px)
  como umbral mobile/desktop.
- Se reutiliza el patrón de `ClientsPage` (layout condicional
  `isMobile ? _buildMobileLayout : _buildDesktopLayout`).
- Las acciones en el card se mostrarán como botones/iconos directamente visibles
  (similar al patrón de la imagen adjunta de "Métodos de envío" con iconos de
  editar y eliminar), no ocultas en un menú.
- La edición en mobile se hará mediante un diálogo que incluye campo de nombre y
  switch de activo/inactivo (no inline como en la tabla desktop), para mejor UX
  táctil.

## 11) Preguntas abiertas

- Sin preguntas abiertas pendientes.

## 12) Notas para análisis técnico

- Seguir el patrón exacto de `ClientsPage`: detección `isMobile`, método
  `_buildMobileLayout`, `_buildMobileSearchBar`, y widget `ProductCard` separado
  en `presentation/widgets/product_card.dart`.
- El widget `ProductCard` recibirá: `Product`, `FdProduct?` (vinculado), y
  callbacks para vincular, editar (nombre + activo), eliminar.
- Se creará un diálogo `ProductEditDialog` (o similar) con `TextFormField` para
  nombre y `Switch` para activo/inactivo.
- El feedback en mobile debe usar `ScaffoldMessenger.of(context).showSnackBar()`
  como hace `ClientsPage._showFeedback`.
- Los diálogos existentes (`FdProductSelectorDialog`, `ProductReorderDialog`,
  confirmación de borrado, diálogo de añadir) se reutilizan sin cambios.
- La carga de productos FD (`_cachedFdProducts`) se comparte entre ambos
  layouts.
- No se requieren cambios en `ProductsCubit` ni en la capa de dominio/datos.
- **Estado: Listo para análisis técnico**
