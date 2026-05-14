# Technical Analysis: Clientes — Vista mobile con cards y corrección de layout

- **Fecha:** 2026-05-12
- **Identificador:** clients-mobile-cards
- **Fuente:** docs/functional-analysis/2026-05-12-clients-mobile-cards.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Refactorizar `ClientsPage` para detectar el breakpoint mobile
  (`AppSideMenu.mobileBreakpoint <= 768`) y renderizar condicionalmente:
  - **Mobile:** subheader fijo con searchbox + lista de cards + FAB para "Añadir
    desde FD".
  - **Desktop:** layout actual sin cambios (PageHeader + searchbox inline +
    tabla).
- Ocultar el `PageHeader` en mobile (el título ya lo aporta el `AppBar` del
  `SideMenuShell`).
- Extraer un nuevo widget `ClientCard` para las tarjetas mobile.
- Adaptar el feedback (éxito/error tras añadir desde FD) a `SnackBar` en mobile
  (ya usado en otras features).
- **Áreas impactadas:** solo capa de presentación de `clients`.
- **Riesgo general:** bajo — cambios puramente de UI, sin tocar dominio ni
  datos.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt, fpdart.
- `ClientsPage` es un `StatefulWidget` que consume `ClientsCubit` y
  `FeedbackCubit`.

### Patrón responsive existente

- `SideMenuShell` ya diferencia `isMobile` usando
  `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint` (768px).
- `HomePage` aplica el mismo patrón: `if (!isMobile) _buildDateHeader(context)`
  para ocultar el header en mobile.
- El breakpoint vive en `AppSideMenu.mobileBreakpoint` dentro de
  `theme_constants.dart`.

### Widgets relevantes

- `PageHeader` — widget compartido (`core/presentation/widgets/`). Renderiza
  título + divider. Se usa en múltiples páginas. **No se debe modificar.**
- `FeedbackCubit` / `FeedbackState` — sistema de feedback temporal inline (Card
  embebido en el Row del searchbox). En desktop funciona bien, pero en mobile no
  hay espacio para el inline Card.
- `ScaffoldMessenger.showSnackBar` — ya usado como patrón de feedback en
  `settings`, `orders_today` y `products`.

### Estructura actual de `ClientsPage.build()`

```
Column
├── PageHeader(title: l10n.menuClients)          ← título duplicado en mobile
├── BlocBuilder (searchbox + botón FD + feedback inline)  ← Row fijo
└── Expanded
    └── BlocBuilder (loading / error / empty / _buildTable)
```

### Entidad `Client`

Campos disponibles para la card: `id`, `name`, `facturaDirectaUuid`,
`facturaDirectaName`, `clientCategoryId`, `categoryName`, `categoryColor`,
`shippingMethodsByDay`. El NIF/CIF se obtiene de
`ClientsLoaded.fiscalIdsByUuid[client.facturaDirectaUuid]`.

### Design tokens disponibles

`AppSpacing`, `AppRadii`, `AppIconSizes`, `AppElevation`, `AppDimensions`,
`AppOpacity` — usar exclusivamente estos; no hardcodear valores.

## 3) Objetivo técnico

- **Qué debe cambiar:** La UI de `ClientsPage` debe renderizar un layout
  diferente en mobile vs desktop, basándose en el breakpoint existente.
- **Resultado:** En mobile, el usuario ve cards con la información de cada
  cliente, un searchbox fijo como subheader y un FAB para añadir desde FD.
- **Limitaciones:**
  - No modificar `PageHeader` (widget compartido).
  - No modificar `ClientsCubit`, `ClientsState` ni ninguna capa de
    dominio/datos.
  - No introducir nuevas dependencias.
  - No cambiar el comportamiento desktop.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Introducir detección de `isMobile` en el `build()` de `ClientsPage` (mismo
patrón que `HomePage`) y bifurcar el árbol de widgets:

```
build()
├── isMobile?
│   ├── true  → _buildMobileLayout()
│   └── false → layout actual (sin cambios)
```

### Componentes / módulos / servicios afectados

| Componente                          | Tipo de cambio                                      |
| ----------------------------------- | --------------------------------------------------- |
| `ClientsPage` (`clients_page.dart`) | Refactorizar `build()` para bifurcar mobile/desktop |
| `ClientCard` (nuevo widget)         | Crear widget para renderizar una tarjeta de cliente |

### Detalle del layout mobile (`_buildMobileLayout`)

```
Scaffold (solo para tener floatingActionButton)
├── floatingActionButton: FAB "Añadir desde FD"
└── body: Column
    ├── _buildMobileSearchBar()   ← subheader fijo con searchbox
    └── Expanded
        └── BlocBuilder (loading / error / empty / _buildCardList)
```

**Nota sobre Scaffold:** `ClientsPage` vive dentro del `Scaffold` del
`SideMenuShell` en mobile. Para usar `floatingActionButton`, se necesita un
`Scaffold` propio o bien posicionar el FAB manualmente con `Stack` +
`Positioned`. Se recomienda usar `Stack` + `Positioned` para evitar anidar
Scaffolds.

Layout mobile corregido:

```
Stack
├── Column
│   ├── _buildMobileSearchBar()   ← subheader fijo con searchbox (Padding con TextField)
│   └── Expanded
│       └── BlocBuilder (loading / error / empty / _buildCardList)
└── Positioned (bottom-right)
    └── FloatingActionButton "Añadir desde FD"
```

### Widget `ClientCard`

Archivo: `lib/features/clients/presentation/widgets/client_card.dart`

Diseño de la card:

```
Card (elevation: AppElevation.low, border radius: AppRadii.medium)
└── Padding
    └── Column
        ├── Row: nombre del cliente (titleMedium, bold) + acciones (ver, editar)
        ├── SizedBox(height: AppSpacing.xs)
        ├── Text: NIF/CIF (bodySmall, onSurfaceVariant) — o "—" si no tiene
        ├── SizedBox(height: AppSpacing.xs)
        ├── Text: nombre FacturaDirecta (bodySmall, secondary)
        ├── SizedBox(height: AppSpacing.sm)
        └── Categoría: badge con color (si tiene) — reutilizar la misma lógica de `_buildRow`
```

Props del widget:

- `Client client`
- `String? fiscalId`
- `VoidCallback onView`
- `VoidCallback onEdit`

### Subheader mobile (`_buildMobileSearchBar`)

Un `Padding` con un `TextField` que ocupa todo el ancho disponible, con la misma
decoración y comportamiento que el searchbox actual, pero sin width fijo
(`AppDimensions.searchBoxWidth` → expandido). Sin botón FD inline (se mueve al
FAB).

### FAB "Añadir desde FD"

- `FloatingActionButton` con icono `Icons.person_add_rounded`.
- `onPressed` → `_addFromFd(l10n)`.
- Posicionado con `Positioned(bottom: AppSpacing.md, right: AppSpacing.md)`.
- Solo visible cuando `state is ClientsLoaded` (misma condición que el searchbox
  actual).

### Feedback en mobile

En mobile, el feedback inline Card no tiene espacio. Se propone:

- **En mobile**, usar `ScaffoldMessenger.of(context).showSnackBar(...)` (patrón
  ya usado en `settings`, `orders_today`, `products`).
- **En desktop**, mantener el `FeedbackCubit` + inline Card actual.
- La detección se hace con un flag `_isMobile` calculado en `build()` y pasado a
  `_showFeedback`, que decide entre `FeedbackCubit.show()` (desktop) o
  `ScaffoldMessenger.showSnackBar()` (mobile).

### Contratos e interfaces

No hay cambios en contratos. El `ClientCard` es un widget stateless puro que
recibe datos y callbacks.

### Flujo de datos o de control

Sin cambios. `ClientsCubit` sigue emitiendo `ClientsLoaded` con
`filteredClients` y `fiscalIdsByUuid`. La UI simplemente renderiza de forma
diferente.

### Gestión de errores y validaciones

Sin cambios. Los estados `ClientsLoading`, `ClientsError` y empty se renderizan
igual en ambas vistas (centrados, sin dependencia del layout de tabla/cards).

### Consideraciones de compatibilidad o migración

No aplica. Es un cambio puramente visual. Si se redimensiona la ventana (web),
el `MediaQuery` reactualiza `isMobile` y se renderiza el layout correspondiente
automáticamente.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                    | Propósito                                                              |
| ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `lib/features/clients/presentation/widgets/client_card.dart` | Widget `ClientCard` para renderizar la tarjeta de un cliente en mobile |

### Artefactos a modificar

| Artefacto                                                   | Cambio esperado                                                                                                                                                                                  |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/features/clients/presentation/pages/clients_page.dart` | Añadir detección `isMobile`, bifurcar `build()` en mobile/desktop, añadir `_buildMobileLayout`, `_buildMobileSearchBar`, `_buildCardList`. Adaptar `_showFeedback` para usar SnackBar en mobile. |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Paso 1: Crear `ClientCard`

Crear el widget `ClientCard` en
`lib/features/clients/presentation/widgets/client_card.dart`. Widget stateless
que recibe `Client`, `String? fiscalId`, `VoidCallback onView`,
`VoidCallback onEdit` y renderiza la card según el diseño descrito.

### Paso 2: Refactorizar `ClientsPage.build()`

1. Calcular `isMobile` con
   `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.
2. Envolver el body del `MultiBlocProvider.child` en una bifurcación:
   `isMobile ? _buildMobileLayout(...) : _buildDesktopLayout(...)`.
3. Mover el layout actual (PageHeader + searchbox Row + Expanded con tabla) a un
   método `_buildDesktopLayout()` sin modificarlo.
4. Crear `_buildMobileLayout()` que renderiza el Stack con Column (searchbar +
   card list) + FAB posicionado.

### Paso 3: Implementar `_buildMobileSearchBar`

TextField expandido con la misma decoración y lógica de filtrado, sin botón FD
ni feedback inline.

### Paso 4: Implementar `_buildCardList`

`ListView.builder` con `ClientCard` por cada cliente filtrado.

### Paso 5: Implementar FAB

`FloatingActionButton` posicionado con `Positioned` dentro del `Stack`, visible
solo cuando `state is ClientsLoaded`.

### Paso 6: Adaptar feedback para mobile

Modificar `_showFeedback` para que en mobile use
`ScaffoldMessenger.of(context).showSnackBar(...)` en lugar de `FeedbackCubit`.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6

### Dependencias entre pasos

- Paso 4 depende de Paso 1 (necesita `ClientCard`).
- Pasos 3, 4, 5, 6 dependen de Paso 2 (estructura mobile en su sitio).
- Paso 1 es independiente y puede hacerse primero.

### Puntos delicados

- **Scaffold anidado:** No crear un segundo `Scaffold`. Usar `Stack` +
  `Positioned` para el FAB, ya que `ClientsPage` ya vive dentro del Scaffold de
  `SideMenuShell`.
- **Feedback SnackBar en mobile:** El `Scaffold` ancestor que recibe el SnackBar
  es el de `SideMenuShell`. `ScaffoldMessenger.of(context)` lo encontrará
  correctamente porque `ClientsPage` está dentro de su `body`.
- **MediaQuery rebuild:** `MediaQuery.sizeOf(context)` en `build()` hará que el
  widget se reconstruya al cambiar el tamaño de pantalla (deseado para EC-02).
- **`_searchController` compartido:** El mismo `TextEditingController` se usa en
  ambos layouts. Como nunca se muestran los dos a la vez, no hay conflicto.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze` — sin errores ni warnings.
- Tests de widget existentes siguen pasando.

### Verificación manual

- En un emulador móvil (o ventana < 768px): verificar que se ven cards, no
  tabla; que el searchbox filtra; que el FAB dispara el flujo de añadir desde
  FD; que el feedback aparece como SnackBar; que el título no se duplica.
- En ventana > 768px: verificar que se mantiene la tabla, PageHeader, searchbox
  inline y feedback inline sin cambios.
- Redimensionar ventana pasando el breakpoint: verificar transición automática
  entre layouts.
- Probar con lista vacía, loading y error en ambos tamaños.

### Escenarios a cubrir

- Lista con múltiples clientes → scroll vertical en cards.
- Cliente sin NIF/CIF → card muestra "—".
- Cliente sin categoría → card no muestra badge.
- Búsqueda con resultados → lista filtrada.
- Búsqueda sin resultados → estado vacío.
- Limpiar búsqueda → lista completa.
- Navegar a detalle/edición desde card.
- Añadir desde FD vía FAB → dialogs + feedback SnackBar.
- Orientación landscape en móvil → respetar breakpoint.

### Tests recomendables

- Test de widget para `ClientCard` (renderiza datos correctos, callbacks se
  ejecutan).
- Test de widget para `ClientsPage` en modo mobile (verifica que renderiza cards
  en vez de tabla cuando el ancho <= 768).

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Riesgo bajo:** El feedback inline Card en desktop depende de
  `FeedbackCubit`. En mobile se usará SnackBar. Ambos caminos deben funcionar
  sin interferencia.
- **Riesgo bajo:** La posición del FAB podría solaparse con la última card si la
  lista es larga. Mitigación: padding bottom en la lista para dejar espacio al
  FAB.

### Impacto potencial

- Solo afecta la UI de `ClientsPage`. No hay impacto en otras features, rutas ni
  lógica de negocio.

### Mitigación

- Mantener el layout desktop completamente intacto (extraer a método sin
  modificar).
- Padding bottom en la lista de cards para evitar oclusión con el FAB.

### Plan de rollback

- Revertir el commit. No hay migraciones de datos ni cambios de esquema.

## 9) Suposiciones

- El `Scaffold` de `SideMenuShell` está disponible como ancestor para
  `ScaffoldMessenger.of(context)`.
- El breakpoint de 768px es adecuado para esta página (mismo que el shell y la
  home).
- No se requieren nuevas claves de i18n; todos los textos necesarios ya existen
  en las traducciones.

## 10) Preguntas abiertas

- Ninguna.

## 11) Notas para implementación

- Usar `MediaQuery.sizeOf(context).width` (no
  `MediaQuery.of(context).size.width`) para optimizar rebuilds — es el patrón ya
  usado en el proyecto.
- Usar exclusivamente design tokens de `theme_constants.dart` — no hardcodear
  colores, radios ni espaciados.
- El `ClientCard` debe usar `Theme.of(context)` para colores y tipografía.
- Reutilizar la lógica del badge de categoría existente en `_buildRow` (con
  `tryParseHex` y `contrastTextColor` de `category_color_utils.dart`).
- El `_searchController` ya existe en `_ClientsPageState`; reutilizarlo en el
  searchbar mobile.
- Añadir `padding: EdgeInsets.only(bottom: 80)` (o similar usando tokens) al
  `ListView.builder` de cards para que el último elemento no quede oculto bajo
  el FAB.
- **Estado: Listo para implementación**
