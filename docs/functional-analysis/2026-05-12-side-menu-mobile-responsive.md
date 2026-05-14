# Functional Analysis: Side Menu responsivo en pantallas pequeñas

- **Fecha:** 2026-05-12
- **Identificador:** side-menu-mobile-responsive
- **Estado:** Ready for technical analysis

## 1) Resumen

Modificar el comportamiento del side menu para que en pantallas pequeñas (vista
mobile) esté **oculto por defecto** y solo se muestre cuando el usuario pulse un
botón dedicado. Actualmente el side menu siempre está visible (expandido o
colapsado), ocupando espacio horizontal incluso en dispositivos con pantalla
reducida.

## 2) Contexto y objetivo

- **Qué se solicita:** Cambiar la lógica de visibilidad del side menu según el
  tamaño de pantalla. En pantallas pequeñas, el menú debe desaparecer
  completamente y mostrarse solo bajo demanda del usuario (patrón
  drawer/overlay).
- **Qué problema resuelve:** En dispositivos móviles o ventanas estrechas, el
  side menu (72 px colapsado / 240 px expandido) consume un porcentaje
  significativo del ancho disponible, reduciendo el espacio útil para el
  contenido principal.
- **Resultado funcional esperado:** En pantallas pequeñas, el área de contenido
  ocupa el 100 % del ancho; el usuario puede abrir/cerrar el menú de navegación
  mediante un botón, y el menú se superpone al contenido sin desplazarlo.

## 3) Alcance

### En alcance

- Definir un breakpoint de ancho de pantalla que distinga "pantalla pequeña" de
  "pantalla normal".
- Ocultar el side menu por defecto cuando el ancho está por debajo del
  breakpoint.
- Proveer un botón (hamburguesa o similar) visible en pantalla pequeña para
  abrir el menú.
- El menú en pantallas pequeñas se muestra como overlay/drawer sobre el
  contenido.
- Al seleccionar un elemento del menú en modo mobile, el menú se cierra
  automáticamente.
- Tocar fuera del menú (en el overlay/scrim) cierra el menú.
- El comportamiento actual en pantallas grandes (side menu fijo con toggle
  expandir/colapsar) se mantiene sin cambios.

### Fuera de alcance

- Rediseño visual del side menu (iconos, colores, tipografía, logo).
- Navegación bottom tab bar para mobile (no se solicita).
- Cambios en la estructura de rutas o páginas de destino.
- Animaciones personalizadas más allá de la transición estándar de
  apertura/cierre.
- Soporte de gestos de swipe para abrir/cerrar el drawer.

## 4) Actores implicados

- **Usuario final:** Interactúa con la aplicación en dispositivos con pantallas
  de diferentes tamaños (desktop, tablet, mobile o ventana redimensionada).

## 5) Requisitos funcionales

- **RF-01:** Definir un umbral de ancho de pantalla (breakpoint) de **768 px**
  que determine cuándo activar el modo "mobile" del side menu. Este valor debe
  ser **configurable** (constante centralizada) para poder ajustarse en el
  futuro.
- **RF-02:** Cuando el ancho de pantalla sea ≤ breakpoint, el side menu NO debe
  mostrarse en el layout principal. El contenido debe ocupar el 100 % del ancho
  disponible.
- **RF-03:** En modo mobile, debe mostrarse un botón con icono hamburguesa en la
  **esquina superior izquierda** de la pantalla que permita abrir el menú.
- **RF-04:** Al pulsar el botón, el side menu debe aparecer como un panel
  superpuesto (drawer/overlay) con un scrim semitransparente detrás.
- **RF-05:** Al seleccionar un ítem del menú en modo mobile, el drawer debe
  cerrarse automáticamente y la navegación debe ejecutarse.
- **RF-06:** Al tocar el scrim (área fuera del menú), el drawer debe cerrarse
  sin navegar.
- **RF-07:** Cuando el ancho de pantalla sea > breakpoint, el side menu debe
  comportarse exactamente como lo hace actualmente (fijo en el layout, con
  toggle expandir/colapsar).
- **RF-08:** Si el usuario redimensiona la ventana cruzando el breakpoint, el
  menú debe adaptarse dinámicamente al modo correspondiente (sin necesidad de
  recargar la página).
- **RF-09:** La funcionalidad del `NavigationGuard` (diálogo de cambios sin
  guardar) debe seguir funcionando correctamente en modo mobile antes de
  ejecutar la navegación.

## 6) Criterios de aceptación

- **CA-01:** En una pantalla de 768 px o menos de ancho, el side menu no es
  visible al cargar la página y el contenido ocupa todo el ancho.
- **CA-02:** En una pantalla de 768 px o menos, un botón hamburguesa en la
  esquina superior izquierda es visible y permite abrir el side menu como
  overlay.
- **CA-03:** Al seleccionar un ítem del menú en modo mobile, el drawer se cierra
  y la navegación se ejecuta correctamente.
- **CA-04:** Al tocar el scrim/fondo del drawer, este se cierra sin efectos
  colaterales.
- **CA-05:** En una pantalla superior a 768 px, el side menu se muestra fijo en
  el layout con el comportamiento actual (expandir/colapsar).
- **CA-06:** Al redimensionar la ventana de >768 px a ≤768 px (o viceversa), la
  vista se adapta correctamente sin errores.
- **CA-07:** El diálogo de cambios sin guardar (`NavigationGuard`) se muestra
  correctamente en modo mobile antes de navegar si hay cambios pendientes.
- **CA-08:** El ítem activo del menú sigue resaltado correctamente en modo
  mobile.

## 7) Flujos y comportamiento esperado

### Flujo principal — Abrir menú y navegar (mobile)

1. El usuario abre la app en un dispositivo con pantalla ≤ 768 px.
2. La pantalla muestra solo el contenido y un botón hamburguesa.
3. El usuario pulsa el botón hamburguesa.
4. El side menu se despliega como overlay con scrim semitransparente.
5. El usuario pulsa un ítem del menú.
6. El drawer se cierra.
7. La app navega a la página correspondiente.

### Flujos alternativos

- **FA-01 — Cerrar sin navegar:** El usuario abre el drawer y pulsa el scrim o
  el botón de cierre → el drawer se cierra y permanece en la página actual.
- **FA-02 — Cambios sin guardar:** El usuario tiene cambios sin guardar, abre el
  drawer y selecciona otro ítem → se muestra el diálogo de `NavigationGuard`. Si
  elige "Quedarse", el drawer permanece abierto. Si elige "Descartar", el drawer
  se cierra y navega.
- **FA-03 — Redimensionamiento cruzando breakpoint:** El usuario está en modo
  desktop con side menu fijo → redimensiona la ventana a ≤ 768 px → el side menu
  desaparece del layout y aparece el botón hamburguesa. El drawer está cerrado
  por defecto tras la transición.
- **FA-04 — Seleccionar el ítem ya activo (mobile):** El usuario abre el drawer
  y pulsa el ítem de la página actual → el drawer se cierra, no se produce
  navegación.

### Estados especiales / excepciones

- **Estado initial (mobile):** Side menu oculto, botón hamburguesa visible,
  contenido a ancho completo.
- **Estado drawer abierto:** Side menu superpuesto con scrim, contenido debajo
  no interactivo.
- **Estado transición de breakpoint:** Si el drawer estaba abierto en modo
  mobile y el usuario amplía la ventana a >600 px, el drawer se cierra y el side
  menu pasa a modo fijo.

## 8) Edge cases

- **EC-01:** El usuario cambia la orientación del dispositivo (portrait ↔
  landscape) cruzando el breakpoint → el menú debe adaptarse sin errores.
- **EC-02:** El usuario hace doble tap rápido en el botón hamburguesa → no debe
  abrirse/cerrarse de forma errática; solo una transición a la vez.
- **EC-03:** Ancho de pantalla exactamente en el breakpoint (768 px) → debe
  tratarse como modo mobile (≤ 768 px).
- **EC-04:** El usuario navega con URL directa (deep link) en pantalla pequeña →
  el side menu debe estar oculto y el ítem correcto marcado como activo si se
  abre el drawer.

## 9) Impacto funcional

- **Módulos afectados:** `SideMenuShell`, `SideMenu`,
  `SideMenuCubit`/`SideMenuState`.
- **Impacto en usuario:** Mejora significativa de la usabilidad en dispositivos
  móviles al liberar espacio de contenido.
- **Impacto en experiencia de usuario:** Patrón de navegación coherente con las
  convenciones de apps móviles (menú hamburguesa + drawer). Sin impacto en la
  experiencia desktop.

## 10) Suposiciones

- El breakpoint de 768 px es el valor inicial, definido como constante
  configurable.
- No se requiere bottom navigation bar como alternativa; el patrón drawer es
  suficiente.
- No se soporta gesto de swipe para abrir/cerrar el drawer.
- El botón hamburguesa se ubica en la esquina superior izquierda del área de
  contenido (no en un AppBar global), ya que actualmente no existe un AppBar en
  el `SideMenuShell`.
- El side menu en modo drawer muestra los mismos ítems y el mismo aspecto visual
  que en modo expandido.

## 11) Preguntas abiertas

- Todas las preguntas han sido resueltas:
  - Breakpoint: **768 px**, configurable como constante.
  - Swipe: **No** se soporta.
  - Botón hamburguesa: **Esquina superior izquierda**.

## 12) Notas para análisis técnico

- El `SideMenuShell` usa un `Row` con el `SideMenu` fijo a la izquierda. En modo
  mobile, deberá reemplazarse o complementarse con un `Drawer` o panel overlay.
- El `SideMenuCubit` actualmente gestiona solo `isExpanded`. Necesitará un nuevo
  estado o propiedad para controlar la visibilidad del drawer en mobile.
- El breakpoint (768 px) debe definirse como constante configurable en
  `theme_constants.dart` (ej. dentro de `AppSideMenu`).
- El breakpoint puede detectarse con `MediaQuery.sizeOf(context).width` o
  `LayoutBuilder`.
- La preferencia persistida en `SharedPreferences` para `isExpanded` solo aplica
  a modo desktop; en mobile el drawer siempre inicia cerrado.
- El `NavigationGuard` debe integrarse en el flujo del drawer igual que en el
  modo actual.
- Considerar usar el widget `Drawer` nativo de Flutter dentro de un `Scaffold` o
  implementar un drawer personalizado con `AnimatedContainer` + scrim para
  mantener la estética actual del side menu.
- **Estado: Listo para análisis técnico**
