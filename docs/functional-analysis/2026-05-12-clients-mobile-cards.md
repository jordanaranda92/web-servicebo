# Functional Analysis: Clientes — Vista mobile con cards y corrección de layout

- **Fecha:** 2026-05-12
- **Identificador:** clients-mobile-cards
- **Estado:** Ready for technical analysis

## 1) Resumen

Adaptar la pantalla de listado de clientes para vista móvil: reemplazar la tabla
por tarjetas (cards), eliminar el título duplicado y reorganizar la barra de
búsqueda como subheader fijo bajo el AppBar.

## 2) Contexto y objetivo

- **Qué se solicita:** Tres cambios en la página `ClientsPage` cuando se
  visualiza en dispositivos móviles:
  1. Sustituir la tabla de clientes por un listado de cards.
  2. Eliminar el título duplicado "Clientes" (actualmente aparece en el `AppBar`
     del `SideMenuShell` y en el `PageHeader` interno de la página).
  3. Mostrar un subheader con un searchbox (campo de búsqueda) fijo debajo del
     AppBar.
- **Qué problema resuelve:** En pantalla estrecha, las cabeceras de la tabla se
  renderizan de forma vertical e ilegible (como se ve en la captura adjunta),
  los datos quedan truncados y la experiencia de búsqueda es pobre. El título
  duplicado consume espacio y genera confusión visual.
- **Resultado funcional esperado:** Una experiencia de listado de clientes
  usable y legible en dispositivos móviles, manteniendo la funcionalidad actual
  (búsqueda, navegación a detalle/edición).

## 3) Alcance

### En alcance

- Renderizado condicional por breakpoint: cards en mobile, tabla en
  desktop/tablet.
- Eliminación del `PageHeader` (título + divider) en vista mobile para evitar
  duplicidad con el AppBar.
- Subheader fijo bajo el AppBar con campo de búsqueda de clientes en mobile.
- Cada card debe mostrar la información clave del cliente y las acciones
  disponibles (ver, editar).
- El botón de "Añadir desde FacturaDirecta" debe mantenerse accesible en mobile.
- Los estados vacío, loading y error deben seguir funcionando igual en mobile.

### Fuera de alcance

- Rediseño de la vista desktop/tablet (se mantiene la tabla actual).
- Cambios en la lógica de negocio, cubit o dominio.
- Cambios en las pantallas de detalle o edición de cliente.
- Nuevos campos o datos en la card que no existan ya en la tabla.
- Funcionalidad de paginación o scroll infinito.
- Cambios en el AppBar del `SideMenuShell`.

## 4) Actores implicados

- **Usuario final:** Operador que consulta y gestiona clientes desde un
  dispositivo móvil.

## 5) Requisitos funcionales

- **RF-01:** En vista mobile (ancho < breakpoint mobile), el listado de clientes
  se renderiza como una lista vertical de cards en lugar de tabla.
- **RF-02:** En vista mobile, el `PageHeader` (título "Clientes" + divider) no
  se muestra, ya que el título aparece en el AppBar del shell.
- **RF-03:** En vista mobile, se muestra un subheader fijo (no scrollable con el
  contenido) que contiene un campo de búsqueda.
- **RF-03b:** En vista mobile, el botón "Añadir desde FacturaDirecta" se muestra
  como un FAB (Floating Action Button).
- **RF-04:** Cada card de cliente muestra: NIF/CIF (fiscal ID), nombre del
  cliente, nombre en FacturaDirecta, categoría (con badge de color si aplica).
- **RF-05:** Cada card incluye las acciones de "Ver detalle" y "Editar"
  (equivalentes a las de la tabla actual).
- **RF-06:** La búsqueda en el searchbox del subheader filtra los clientes en
  tiempo real (mismo comportamiento que la búsqueda actual).
- **RF-07:** En vista desktop/tablet, el comportamiento actual (PageHeader +
  tabla + searchbox inline) se mantiene sin cambios.
- **RF-08:** Los estados de loading, error y vacío se muestran correctamente en
  ambas vistas (mobile y desktop).

## 6) Criterios de aceptación

- **CA-01:** En un dispositivo con ancho inferior al breakpoint mobile, la tabla
  de clientes NO se renderiza; en su lugar aparece una lista de cards.
- **CA-02:** En vista mobile, solo existe UN título "Clientes" visible (el del
  AppBar). No aparece el `PageHeader`.
- **CA-03:** Debajo del AppBar en mobile se muestra un subheader fijo con un
  searchbox funcional.
- **CA-03b:** En mobile, un FAB (Floating Action Button) permite acceder a
  "Añadir desde FacturaDirecta".
- **CA-04:** Al escribir en el searchbox móvil, la lista de cards se filtra en
  tiempo real por nombre, nombre FD o NIF/CIF.
- **CA-05:** Cada card muestra al menos: NIF/CIF, nombre del cliente, nombre
  FacturaDirecta, categoría (con color badge si tiene), y botones de ver/editar.
- **CA-06:** Al pulsar "Ver" en una card se navega al detalle del cliente. Al
  pulsar "Editar" se navega a la edición.
- **CA-07:** En vista desktop, la pantalla se renderiza exactamente como antes
  (tabla + PageHeader + searchbox inline).
- **CA-08:** Los estados de carga, error y lista vacía se muestran correctamente
  en mobile.
- **CA-09:** El FAB "Añadir desde FacturaDirecta" está visible y accesible en
  vista mobile.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario abre la pantalla de Clientes en un dispositivo móvil.
2. El AppBar muestra "Clientes" como título.
3. Debajo del AppBar se muestra un subheader fijo con un campo de búsqueda. 3b.
   Un FAB (Floating Action Button) está visible para "Añadir desde
   FacturaDirecta".
4. Debajo del subheader se renderiza una lista scrollable de cards, una por
   cliente.
5. Cada card muestra la información del cliente (NIF/CIF, nombre, nombre FD,
   categoría) y las acciones (ver, editar).
6. El usuario puede hacer scroll vertical en la lista de cards.
7. El usuario puede escribir en el searchbox para filtrar la lista en tiempo
   real.

### Flujos alternativos

- **FA-01 — Búsqueda sin resultados:** El usuario escribe un término que no
  coincide con ningún cliente → se muestra el estado vacío con mensaje
  apropiado.
- **FA-02 — Limpiar búsqueda:** El usuario borra el texto del searchbox o pulsa
  el botón de limpiar → se restaura la lista completa de clientes.
- **FA-03 — Navegar a detalle:** El usuario pulsa el botón "Ver" en una card →
  se navega a `ClientDetailPage`.
- **FA-04 — Navegar a edición:** El usuario pulsa el botón "Editar" en una card
  → se navega a `ClientEditPage`.
- **FA-05 — Añadir desde FD:** El usuario pulsa el FAB de añadir desde
  FacturaDirecta → se ejecuta el flujo actual de `_addFromFd`.

### Estados especiales / excepciones

- **Estado loading:** Se muestra un indicador de carga centrado (comportamiento
  actual).
- **Estado error:** Se muestra el widget de error con mensaje y botón de
  reintentar (comportamiento actual).
- **Estado vacío:** Se muestra mensaje "No hay clientes" centrado
  (comportamiento actual).
- **Cliente sin NIF/CIF:** La card muestra "—" en lugar del NIF/CIF (igual que
  la tabla).
- **Cliente sin categoría:** La card no muestra badge de categoría (igual que la
  tabla).

## 8) Edge cases

- **EC-01:** Pantalla en orientación landscape en móvil — debe seguir mostrando
  cards si el ancho está por debajo del breakpoint, o tabla si lo supera.
- **EC-02:** Transición de tamaño (p.ej. redimensionar ventana en web) — debe
  cambiar automáticamente entre cards y tabla según el breakpoint.
- **EC-03:** Cliente con nombre muy largo — el texto debe truncarse con ellipsis
  en la card (igual que en la tabla).
- **EC-04:** Lista con muchos clientes — la lista de cards debe ser scrollable y
  performante (uso de `ListView.builder` o equivalente).
- **EC-05:** Feedback toast (éxito/error tras añadir desde FD) — debe mostrarse
  correctamente en layout mobile.

## 9) Impacto funcional

- **Módulos afectados:** `ClientsPage` (presentación). No se afecta lógica de
  negocio ni dominio.
- **Impacto en usuario:** Mejora significativa de usabilidad en dispositivos
  móviles. Actualmente la tabla es ilegible en pantallas estrechas.
- **Impacto en UX:** Eliminación de título duplicado mejora la limpieza visual.
  El subheader con searchbox facilita la búsqueda en mobile.

## 10) Suposiciones

- El breakpoint mobile ya existe en la app: `AppSideMenu.mobileBreakpoint = 768`
  (usado en `SideMenuShell` y `HomePage`).
- Se asume que la información mostrada en la card es la misma que la de la tabla
  (no se añaden ni quitan campos).
- Se asume que el diseño visual de las cards seguirá los design tokens del tema
  actual de la app (colores, tipografía, radios, espaciados).
- El botón "Añadir desde FacturaDirecta" se mostrará como un FAB (Floating
  Action Button) en vista mobile.

## 11) Preguntas abiertas

- Todas las preguntas han sido resueltas.

## 12) Notas para análisis técnico

- El `SideMenuShell` ya diferencia layout mobile vs desktop (ver
  `_buildMobileLayout`) usando `AppSideMenu.mobileBreakpoint` (768px).
  Reutilizar el mismo criterio.
- El `PageHeader` se usa en múltiples páginas; la solución debe ser condicional
  solo para mobile en `ClientsPage`, no modificar el widget compartido.
- El `ClientsCubit` y su estado `ClientsLoaded` ya contienen toda la información
  necesaria para las cards (nombre, NIF/CIF vía `fiscalIdsByUuid`, categoría,
  etc.).
- El searchbox actual está dentro del `BlocBuilder` de la tabla; en mobile se
  debe reubicar al subheader sin duplicar lógica de filtrado.
- Considerar crear un widget `ClientCard` separado para mantener limpio el
  código.
- El feedback toast actual (éxito/error) está integrado en el Row del searchbox
  desktop; en mobile se necesita un approach alternativo (SnackBar o similar).
- **Estado: Listo para análisis técnico**
