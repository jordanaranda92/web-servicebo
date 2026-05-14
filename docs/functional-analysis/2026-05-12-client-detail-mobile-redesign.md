# Functional Analysis: Rediseño de vista detalle de cliente en modo mobile

- **Fecha:** 2026-05-12
- **Identificador:** client-detail-mobile-redesign
- **Estado:** Ready for technical analysis

## 1) Resumen

Modificar la vista de detalle de un cliente (`ClientDetailPage`) cuando se
muestra en modo mobile (≤ 768 px) para:

1. Reemplazar el icono de hamburguesa del AppBar por un botón de retroceso que
   vuelva al listado de clientes.
2. Establecer el título del AppBar como "Detalle de cliente".
3. Colocar un botón de editar (icono de lápiz) en la zona derecha del AppBar.
4. Añadir una nueva sección **"Datos del cliente"** con los campos **Nombre** y
   **Categoría**, posicionada encima de la sección existente "Datos de Factura
   Directa".

## 2) Contexto y objetivo

### Qué se solicita

Actualmente, la vista de detalle de un cliente en mobile hereda el AppBar del
`SideMenuShell`, que muestra el icono de hamburguesa y el título genérico
"Clientes". Los datos del cliente (nombre y categoría) se muestran dentro del
`PageHeader` del body, junto con el botón de edición. Esta disposición no es
óptima para mobile porque:

- El usuario pierde el contexto de que está viendo un detalle y no el listado.
- El botón de retroceso queda dentro del contenido del body, no en la posición
  estándar de navegación (AppBar).
- El botón de editar ocupa espacio en el body en lugar de aprovechar el AppBar.

### Qué problema resuelve

Mejorar la usabilidad y la experiencia de navegación en dispositivos móviles,
alineando la vista de detalle con las convenciones estándar de navegación mobile
(back arrow en el leading del AppBar, acciones en el trailing).

### Qué resultado funcional se espera

En pantallas ≤ 768 px, la vista detalle de un cliente muestra:

- AppBar con flecha de retroceso a la izquierda → navega al listado de clientes.
- Título "Detalle de cliente" centrado o alineado en el AppBar.
- Icono de lápiz (editar) a la derecha del AppBar → navega a la pantalla de
  edición del cliente.
- En el body, antes de "Datos de Factura Directa", una nueva sección "Datos del
  cliente" con Nombre y Categoría.

## 3) Alcance

### En alcance

- Cambio del AppBar en modo mobile para la ruta de detalle de cliente
  (`/clients/:id/detail`).
- Sustitución del leading del AppBar: de hamburguesa a flecha de retroceso.
- Cambio del título del AppBar a "Detalle de cliente".
- Adición de acción en el AppBar: botón de editar (icono lápiz).
- Nueva sección "Datos del cliente" en el body con campos Nombre y Categoría,
  antes de "Datos de Factura Directa".
- Internacionalización de los nuevos textos ("Detalle de cliente", "Datos del
  cliente").

### Fuera de alcance

- Cambios en la vista de detalle en modo desktop (se mantiene tal cual con
  `PageHeader`).
- Cambios en la pantalla de edición del cliente.
- Cambios en el listado de clientes.
- Cambios en el modelo de datos o en la lógica de negocio.
- Cambios en otras rutas/páginas del `SideMenuShell`.

## 4) Actores implicados

- **Usuario final (operador):** navega al detalle de un cliente desde el listado
  en un dispositivo móvil o ventana estrecha.

## 5) Requisitos funcionales

- **RF-01:** En modo mobile (ancho ≤ 768 px), el AppBar de la vista de detalle
  de cliente debe mostrar un icono de flecha hacia atrás (←) en la posición
  leading, en lugar del icono de hamburguesa.
- **RF-02:** Al pulsar la flecha de retroceso, el usuario debe navegar al
  listado de clientes (`/clients`).
- **RF-03:** El título del AppBar en modo mobile debe ser "Detalle de cliente"
  (i18n).
- **RF-04:** En la posición trailing (derecha) del AppBar, debe mostrarse un
  botón con solo icono de lápiz (editar), sin texto. Al pulsarlo, se navega a la
  pantalla de edición del cliente (`/clients/:id/edit`).
- **RF-05:** En el body de la vista, inmediatamente antes de la sección "Datos
  de Factura Directa", debe aparecer una nueva sección titulada "Datos del
  cliente" (i18n).
- **RF-06:** La sección "Datos del cliente" debe contener dos campos de solo
  lectura:
  - **Nombre:** muestra `client.name`.
  - **Categoría:** muestra `client.categoryName` como badge con color de fondo
    (`client.categoryColor`), igual que en el header actual. Si no tiene
    categoría asignada, muestra un indicador de "Sin categoría" o un guión (—).
- **RF-07:** La presentación visual de la sección "Datos del cliente" debe
  seguir el mismo estilo de card y filas utilizado en "Datos de Factura Directa"
  (consistencia visual).
- **RF-08:** En modo desktop (ancho > 768 px), la vista detalle no cambia; sigue
  usando el `PageHeader` actual con nombre, categoría, botón de retroceso y
  botón de editar en el body.

## 6) Criterios de aceptación

- **CA-01:** En una pantalla de ancho ≤ 768 px, el AppBar muestra una flecha de
  retroceso en lugar de la hamburguesa.
- **CA-02:** Pulsar la flecha de retroceso navega al listado de clientes
  (`/clients`).
- **CA-03:** El título del AppBar muestra "Detalle de cliente" (localizado).
- **CA-04:** El AppBar contiene un icono de lápiz a la derecha. Pulsarlo navega
  a `/clients/:id/edit`.
- **CA-05:** Antes de "Datos de Factura Directa" aparece la sección "Datos del
  cliente" con el nombre del cliente y su categoría.
- **CA-06:** Si el cliente no tiene categoría, el campo Categoría muestra "—" o
  un texto equivalente de "Sin categoría".
- **CA-07:** La sección "Datos del cliente" tiene el mismo estilo visual (card
  con borde, filas con icono-label-valor) que la sección de "Datos de Factura
  Directa".
- **CA-08:** En pantalla > 768 px, la vista de detalle permanece sin cambios (se
  usa `PageHeader` como hasta ahora).
- **CA-09:** Todos los textos nuevos están internacionalizados (no
  hardcodeados).

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario accede al listado de clientes en un dispositivo mobile.
2. Pulsa sobre un cliente para ver su detalle.
3. Se muestra la pantalla de detalle con:
   - AppBar: flecha atrás | "Detalle de cliente" | 🖊 (editar)
   - Body: Sección "Datos del cliente" (Nombre, Categoría) → Sección "Datos de
     Factura Directa" → Sección "Métodos de envío" (si aplica).
4. El usuario pulsa la flecha de retroceso → vuelve al listado.
5. Alternativa: el usuario pulsa el lápiz → navega a la edición del cliente.

### Flujos alternativos

- **FA-01:** El usuario accede al detalle via deep link (`/clients/:id/detail`)
  en mobile. El AppBar muestra igualmente la flecha de retroceso. Al pulsarla,
  navega a `/clients`.
- **FA-02:** El usuario redimensiona la ventana de ancho > 768 px a ≤ 768 px
  mientras ve el detalle → la vista cambia al layout mobile (AppBar con back
  arrow, sección "Datos del cliente" en el body, `PageHeader` se oculta o se
  sustituye).

### Estados especiales / excepciones

- **Estado loading:** Mientras se carga el cliente, se muestra spinner centrado.
  El AppBar mobile puede mostrarse con el título "Detalle de cliente" y la
  flecha de retroceso, pero sin el botón de editar hasta que se resuelva el
  cliente.
- **Estado error / no encontrado:** Se muestra el estado actual de "cliente no
  encontrado" con botón de volver. El AppBar mobile con flecha de retroceso
  sigue disponible.
- **Sin categoría:** El campo Categoría de la sección "Datos del cliente"
  muestra "—" o texto localizado "Sin categoría".

## 8) Edge cases

- **EC-01:** Cliente con nombre muy largo — el campo Nombre en "Datos del
  cliente" debe truncar o hacer wrap, sin romper el layout.
- **EC-02:** Cliente con nombre de categoría muy largo — mismo tratamiento de
  overflow.
- **EC-03:** Cambio dinámico de tamaño de ventana (responsive) — la transición
  entre layout desktop y mobile debe ser fluida, sin perder estado ni datos
  cargados.
- **EC-04:** Navegación rápida: el usuario pulsa back antes de que se carguen
  los datos de FD — no debe producirse error; la navegación hacia atrás es
  inmediata.

## 9) Impacto funcional

- **Módulos afectados:**
  - `ClientDetailPage`: requiere layout condicional mobile/desktop.
  - `SideMenuShell`: el AppBar mobile deberá adaptarse cuando la ruta sea de
    detalle de cliente (o la página deberá gestionar su propio AppBar
    sobreescribiendo el del shell).
  - Archivos de i18n (`.arb`): nuevas claves de traducción.
- **Impacto en usuario:** mejora la navegación mobile al seguir convenciones
  estándar de retroceso y acciones en AppBar.
- **Impacto en UX:** la información del cliente (nombre y categoría) se presenta
  de forma estructurada en una sección propia, separada de los datos de Factura
  Directa, mejorando la legibilidad.

## 10) Suposiciones

- Se asume que el breakpoint mobile sigue siendo ≤ 768 px
  (`AppSideMenu.mobileBreakpoint`).
- Se asume que la categoría a mostrar en "Datos del cliente" es
  `client.categoryName` con el badge de color `client.categoryColor`, análogo a
  cómo se muestra actualmente en el `PageHeader`.
- Se asume que el botón de editar en el AppBar mobile navega a la misma ruta que
  el botón actual (`/clients/:id/edit`).
- Se asume que en mobile el `PageHeader` actual (que contiene nombre, categoría,
  back arrow y botón editar) se omite o se reemplaza, ya que esa información se
  redistribuye entre el AppBar y la nueva sección "Datos del cliente".

## 11) Preguntas abiertas

_Todas las preguntas han sido resueltas._

### Decisiones tomadas

- **PA-01 → Resuelta:** La categoría se muestra como **badge con color de
  fondo**, igual que en el header actual.
- **PA-02 → Resuelta:** El botón de editar en el AppBar es **solo icono**
  (lápiz), sin texto.

## 12) Notas para análisis técnico

- La implementación actual de `SideMenuShell` aplica un AppBar con hamburguesa a
  todas las rutas hijas del `ShellRoute`. Para el detalle de cliente en mobile,
  se necesitará un mecanismo para que la página sobreescriba el leading, el
  título y las acciones del AppBar del shell, o bien que la página gestione su
  propio Scaffold/AppBar en mobile.
- La entidad `Client` ya expone `name`, `categoryName` y `categoryColor`, por lo
  que no se necesitan cambios en el modelo.
- Se requieren nuevas claves i18n: título del AppBar mobile ("Detalle de
  cliente"), título de sección ("Datos del cliente"), labels de los campos
  ("Nombre", "Categoría"), y posiblemente texto para "Sin categoría".
- La sección "Datos del cliente" puede reutilizar el widget `_FdDataRow` ya
  existente en `ClientDetailPage`.
- **Estado: Listo para análisis técnico**
