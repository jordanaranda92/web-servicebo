# Technical Analysis: Shipping Methods — Mobile Card Layout

- **Fecha:** 2026-05-12
- **Identificador:** shipping-methods-mobile-cards
- **Fuente:**
  docs/functional-analysis/2026-05-12-shipping-methods-mobile-cards.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Refactorizar `ShippingMethodsPage` para detectar el breakpoint mobile
(`≤ 768 px`) y bifurcar el layout entre desktop (actual, sin cambios) y mobile
(cards + SearchBar + FAB). Se crea un nuevo widget `ShippingMethodCard` y se
reorganizan los métodos del `State` para separar ambos layouts. Se adopta el
mismo patrón estructural ya validado en `ClientsPage`.

- **Áreas impactadas:** `ShippingMethodsPage` (refactor del build), nuevo widget
  `ShippingMethodCard`.
- **Riesgo general estimado:** Bajo — cambios aislados en capa de presentación,
  sin tocar lógica de negocio.

## 2) Contexto técnico observado

### Arquitectura y patrones detectados

- Clean Architecture feature-first:
  `lib/features/shipping_methods/{data,domain,presentation}`.
- BLoC/Cubit: `ShippingMethodsCubit` con estados
  `Initial | Loading | Loaded | Error`.
- El estado `ShippingMethodsLoaded` ya expone `methods` (getter sobre
  `filteredMethods`) y `allMethods`.
- El cubit ya tiene `filterByName(String)` para filtrado en tiempo real.
- Patrón responsive de referencia implementado en `ClientsPage`:
  - `isMobile` via
    `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.
  - Métodos `_buildMobileLayout()` / `_buildDesktopLayout()`.
  - `_buildMobileSearchBar()` con fondo `colorScheme.primary`.
  - `_buildSearchField()` compartido con parámetro `onPrimary`.
  - `_buildContent()` con parámetro `isMobile` que alterna entre card list y
    tabla.
  - FAB posicionado con `Stack` + `Positioned`.
  - Feedback: `SnackBar` en mobile, `FeedbackCubit` card inline en desktop.

### Módulos relevantes

| Módulo            | Ruta                                                                          |
| ----------------- | ----------------------------------------------------------------------------- |
| Página actual     | `lib/features/shipping_methods/presentation/pages/shipping_methods_page.dart` |
| Cubit             | `lib/features/shipping_methods/presentation/bloc/shipping_methods_cubit.dart` |
| States            | `lib/features/shipping_methods/presentation/bloc/shipping_methods_state.dart` |
| Entidad           | `lib/features/shipping_methods/domain/entities/shipping_method.dart`          |
| Referencia (page) | `lib/features/clients/presentation/pages/clients_page.dart`                   |
| Referencia (card) | `lib/features/clients/presentation/widgets/client_card.dart`                  |
| Design tokens     | `lib/app/theme/theme_constants.dart`                                          |

### Restricciones relevantes

- No existe directorio `widgets/` dentro de `presentation/` de shipping_methods;
  debe crearse.
- El `_runWithProgress` y `_showFeedback` actuales usan siempre `_feedbackCubit`
  (card inline). En mobile debe usarse `ScaffoldMessenger.showSnackBar`.
- Los diálogos (`_showAddDialog`, `_showEditDialog`, `_showDeleteConfirmation`)
  no requieren cambios; funcionan igual en ambos layouts.

### Dependencias

- No se introducen nuevas dependencias (packages).
- Se reutilizan: `AppSideMenu.mobileBreakpoint`, `AppSpacing`, `AppRadii`,
  `AppElevation`, `AppOpacity`, `AppIconSizes` de `theme_constants.dart`.

## 3) Objetivo técnico

- Que `ShippingMethodsPage` renderice un layout mobile (cards) o desktop (tabla)
  según el ancho de pantalla.
- Crear el widget `ShippingMethodCard` como unidad reutilizable.
- Que el feedback de operaciones use `SnackBar` en mobile y el card inline
  existente en desktop.
- Que el layout desktop permanezca idéntico al actual.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Replicar el patrón de `ClientsPage` en `ShippingMethodsPage`:

1. En `build()`, calcular `isMobile` y bifurcar con ternario.
2. Extraer el layout actual completo (PageHeader + searchbar row + feedback +
   tabla) a `_buildDesktopLayout()`.
3. Crear `_buildMobileLayout()` con `Stack` >
   `Column[SearchBar, Expanded(content)]` + `Positioned(FAB)`.
4. Extraer `_buildSearchField()` con parámetro `onPrimary` para reutilizar en
   ambos layouts.
5. Crear `_buildMobileSearchBar()` que envuelve el search field en un
   `Container` con fondo `primary`.
6. Crear `_buildContent()` con parámetro `isMobile` que delega a
   `_buildCardList()` o `_buildTable()`.
7. Añadir `_showFeedback()` que detecta `isMobile` y usa `SnackBar` o
   `_feedbackCubit`.
8. Sustituir las llamadas directas a `_feedbackCubit.show()` en
   `_runWithProgress` por `_showFeedback()`.

### Componentes / módulos / servicios afectados

| Componente                   | Cambio                                         |
| ---------------------------- | ---------------------------------------------- |
| `ShippingMethodsPage`        | Refactor del `build()` y extracción de métodos |
| `ShippingMethodCard` (nuevo) | Widget stateless para el card mobile           |

### Contratos e interfaces

**`ShippingMethodCard`** — widget stateless:

```
ShippingMethodCard({
  required ShippingMethod method,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
})
```

- Recibe la entidad y dos callbacks; no tiene dependencia directa del cubit.
- El padre (`ShippingMethodsPage`) conecta los callbacks con `_showEditDialog` y
  `_showDeleteConfirmation`.

### Flujo de datos o de control

```
build()
  └─ isMobile?
       ├─ true  → _buildMobileLayout()
       │           ├─ _buildMobileSearchBar() → _buildSearchField(onPrimary: true)
       │           ├─ _buildContent(isMobile: true)
       │           │    └─ ShippingMethodsLoaded → _buildCardList()
       │           │         └─ ListView.builder → ShippingMethodCard(...)
       │           └─ FAB → _showAddDialog()
       └─ false → _buildDesktopLayout()
                    ├─ PageHeader
                    ├─ SearchBar row + FilledButton + FeedbackCubit card
                    └─ _buildContent(isMobile: false)
                         └─ ShippingMethodsLoaded → _buildTable()
```

### Gestión de errores y validaciones

- Sin cambios. Los estados `ShippingMethodsError` y `ShippingMethodsLoading` se
  manejan en `_buildContent()` de forma compartida para ambos layouts.
- El widget `_buildError` ya existente se reutiliza tal cual.

### Consideraciones de compatibilidad o migración

- No hay migración. El cambio es puramente visual y solo afecta la capa de
  presentación.
- El redimensionamiento en caliente (ventana de escritorio) causa un rebuild que
  alterna entre layouts; el estado del cubit y el `TextEditingController` de
  búsqueda se preservan porque viven en el `State`.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                      | Propósito                                                                                |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `lib/features/shipping_methods/presentation/widgets/shipping_method_card.dart` | Widget `ShippingMethodCard` — card mobile con nombre, teléfono y botones editar/eliminar |

### Artefactos a modificar

| Artefacto                                                                     | Cambio esperado                                                                                                                                                                                                                                                                            |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/features/shipping_methods/presentation/pages/shipping_methods_page.dart` | Refactor de `build()`: detectar breakpoint, bifurcar layouts, extraer `_buildSearchField`, `_buildMobileSearchBar`, `_buildMobileLayout`, `_buildDesktopLayout`, `_buildContent`, `_buildCardList`, `_showFeedback`. Sustituir feedback directo en `_runWithProgress` por `_showFeedback`. |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Pasos ordenados

1. **Crear `ShippingMethodCard`** en
   `lib/features/shipping_methods/presentation/widgets/shipping_method_card.dart`.
   - Widget stateless.
   - Recibe `ShippingMethod method`, `VoidCallback onEdit`,
     `VoidCallback onDelete`.
   - Usa `Card` + `Padding` + `Row` con contenido a la izquierda (nombre +
     teléfono en `Column`) y acciones a la derecha (`IconButton` editar +
     eliminar).
   - Design tokens: `AppElevation.low`, `AppRadii.medium`, `AppSpacing.md`,
     `AppOpacity.medium`, `colorScheme.primaryContainer` /
     `colorScheme.errorContainer` para los botones.
   - Patrón visual alineado con `ClientCard` (margins, border, elevation).

2. **Extraer `_buildSearchField()`** como método privado en
   `_ShippingMethodsPageState`.
   - Parámetro `bool onPrimary = false`.
   - Variante `onPrimary: true`: `filled: true`,
     `fillColor: colorScheme.surface`, bordes transparentes, colores de
     texto/icono adaptados.
   - Variante `onPrimary: false`: estilo actual del TextField.
   - Reutiliza `_searchController` y `_cubit.filterByName`.

3. **Añadir `_showFeedback()`** al `State`.
   - Detecta `isMobile` con
     `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.
   - Mobile: `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))`.
   - Desktop: `_feedbackCubit.show(message, isSuccess: success)`.

4. **Modificar `_runWithProgress()`** para usar `_showFeedback()` en lugar de
   `_feedbackCubit.show()` directamente.

5. **Extraer `_buildDesktopLayout()`** — mover el `Column` actual del `build()`
   (PageHeader + search row + feedback + tabla) a este nuevo método.

6. **Crear `_buildMobileSearchBar()`** — `BlocBuilder` que muestra
   `Container(color: primary)` con `_buildSearchField(onPrimary: true)` cuando
   el estado es `ShippingMethodsLoaded`.

7. **Crear `_buildContent()`** con parámetro `isMobile`:
   - Contiene el `BlocBuilder` actual con los estados
     loading/error/loaded/empty.
   - Si `isMobile && loaded` → `_buildCardList(methods)`.
   - Si `!isMobile && loaded` → `_buildTable(methods, ...)`.

8. **Crear `_buildCardList()`** — `ListView.builder` que renderiza
   `ShippingMethodCard` para cada método. Padding inferior de 80 px para no
   tapar el FAB.

9. **Crear `_buildMobileLayout()`** — `Stack` con
   `Column[_buildMobileSearchBar, Expanded(_buildContent(isMobile: true))]` +
   `Positioned(FAB)`. El FAB solo se muestra cuando el estado es
   `ShippingMethodsLoaded`.

10. **Refactorizar `build()`** — calcular `isMobile`, bifurcar:
    `isMobile ? _buildMobileLayout() : _buildDesktopLayout()`.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

Cada paso es incrementalmente compilable si se conserva el `build()` original
hasta el paso 10.

### Dependencias entre pasos

- Paso 8 depende de paso 1 (necesita `ShippingMethodCard`).
- Paso 9 depende de pasos 6, 7, 8.
- Paso 10 depende de pasos 5 y 9.
- Pasos 2, 3, 4 son independientes entre sí pero prerequisitos para 5 y 6.

### Puntos delicados

- **`_runWithProgress`** actualmente cierra el diálogo de progreso y llama a
  `_feedbackCubit.show()`. Al cambiar a `_showFeedback()` hay que verificar que
  `mounted` siga siendo true y que `ScaffoldMessenger` esté accesible (en
  `ShippingMethodsPage` el `Scaffold` viene del `SideMenuShell` padre, por lo
  que `ScaffoldMessenger.of(context)` funcionará).
- **`PageHeader`** no debe renderizarse en mobile (el título lo muestra el
  `AppBar` del `SideMenuShell`). En `ClientsPage` desktop se incluye
  `PageHeader` pero en mobile no. Debe replicarse este comportamiento.
- **Preservación del `TextEditingController`**: El `_searchController` vive en
  el `State`, por lo que sobrevive a rebuilds por cambio de tamaño de ventana.

## 7) Estrategia de validación

### Verificación automática

- **Build limpio:** `flutter build web` / `flutter analyze` sin errores ni
  warnings nuevos.
- **Tests existentes:** ejecutar tests de la feature
  `test/features/shipping_methods/` para verificar que no hay regresiones.

### Verificación manual

- Abrir la app en un navegador y redimensionar la ventana por debajo y por
  encima de 768 px:
  - **≤ 768 px:** Verificar SearchBar con fondo primary, lista de cards, FAB
    visible, acciones editar/eliminar funcionales, SnackBar de feedback.
  - **> 768 px:** Verificar que la tabla se muestra idéntica al estado previo
    con card de feedback inline.
- Probar flujo completo: buscar, añadir, editar, eliminar en ambos layouts.
- Probar estados: loading (spinner), error (retry), vacío (mensaje).
- Probar edge cases: nombre largo (truncamiento), redimensionamiento en tiempo
  real, eliminar con filtro activo.

### Escenarios a cubrir

| Escenario                 | Layout  | Resultado esperado                                               |
| ------------------------- | ------- | ---------------------------------------------------------------- |
| Carga inicial             | Mobile  | Spinner centrado, luego cards                                    |
| Lista vacía               | Mobile  | Mensaje "No hay métodos de envío"                                |
| Error de red              | Mobile  | Icono error + mensaje + botón Reintentar                         |
| Buscar "GLS"              | Mobile  | Solo card de GLS visible                                         |
| Limpiar búsqueda          | Mobile  | Todos los cards visibles                                         |
| Añadir método             | Mobile  | FAB → diálogo → nuevo card aparece → SnackBar éxito              |
| Editar método             | Mobile  | Icono editar → diálogo → card actualizado → SnackBar éxito       |
| Eliminar método           | Mobile  | Icono eliminar → confirmación → card desaparece → SnackBar éxito |
| Resize ventana 600→900 px | Ambos   | Transición fluida de cards a tabla sin pérdida de estado         |
| Desktop sin cambios       | Desktop | Tabla + search row + feedback inline idénticos al actual         |

### Tests recomendables

- Widget test para `ShippingMethodCard`: verifica renderizado de nombre,
  teléfono, callbacks de editar y eliminar.
- Widget test para `ShippingMethodsPage` mobile: mock del cubit, verificar que
  en ancho ≤ 768 se renderiza card list y FAB.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                                | Probabilidad | Impacto |
| ------------------------------------------------------------------------------------- | ------------ | ------- |
| `ScaffoldMessenger` no accesible desde el contexto de `ShippingMethodsPage` en mobile | Baja         | Medio   |
| Overflow visual en cards con datos extremadamente largos                              | Baja         | Bajo    |
| Regresión en layout desktop al extraer métodos                                        | Baja         | Medio   |

### Impacto potencial

- Solo afecta la presentación de la pantalla de métodos de envío.
- No hay impacto en datos, lógica de negocio ni otras features.

### Mitigación

- Verificar accesibilidad de `ScaffoldMessenger` en el árbol de widgets mobile
  (el `Scaffold` del `SideMenuShell` lo proporciona).
- Usar `TextOverflow.ellipsis` y `maxLines: 1` en los textos del card.
- Comparar pixel-perfect el layout desktop antes y después del refactor.

### Plan de rollback

- Revertir el commit. Los cambios son auto-contenidos en dos archivos (uno
  nuevo, uno modificado).

## 9) Suposiciones

- El `Scaffold` del `SideMenuShell` envuelve la página y proporciona
  `ScaffoldMessenger` para SnackBars.
- En mobile, el título "Métodos de envío" se muestra en el `AppBar` del shell,
  por lo que `PageHeader` no se incluye en el layout mobile.
- El breakpoint `768 px` es el estándar del proyecto (confirmado en
  `theme_constants.dart`).
- No se necesitan strings i18n nuevas; se reutilizan todas las existentes
  (`shippingMethodsSearch`, `shippingMethodsAdd`, etc.).

## 10) Preguntas abiertas

Ninguna. El patrón de referencia (`ClientsPage`) está completo y validado en el
código actual.

## 11) Notas para implementación

- Respetar los design tokens de `theme_constants.dart` — no hardcodear colores,
  espaciados ni radios.
- El `ShippingMethodCard` debe ser un archivo independiente en
  `presentation/widgets/` para mantener la consistencia con el patrón de
  `ClientCard`.
- En el card, las acciones (editar/eliminar) van como `IconButton.filled` con
  los mismos estilos que los de la tabla desktop
  (`primaryContainer`/`errorContainer`) para mantener coherencia visual.
- Mantener `shrinkWrap: false` en el `ListView.builder` mobile (está dentro de
  `Expanded`, no necesita `shrinkWrap`).
- Añadir `padding: EdgeInsets.only(bottom: 80)` al `ListView` para que el último
  card no quede tapado por el FAB.
- **Estado: Listo para implementación**
