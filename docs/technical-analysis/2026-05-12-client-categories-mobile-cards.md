# Technical Analysis: Categorías de clientes — Vista mobile con cards

- **Fecha:** 2026-05-12
- **Identificador:** client-categories-mobile-cards
- **Fuente:**
  docs/functional-analysis/2026-05-12-client-categories-mobile-cards.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Refactorizar `ClientCategoriesPage` para soportar un layout dual
  (mobile/desktop) usando el mismo patrón de `ClientsPage`: detección de
  `isMobile` vía `MediaQuery` + `AppSideMenu.mobileBreakpoint`.
- Crear un nuevo widget `ClientCategoryCard` para la vista de lista en mobile.
- Extraer un método `_buildSearchField` compartido (desktop/mobile) para
  eliminar duplicación del campo de búsqueda.
- Añadir un método `_showFeedback` que use `SnackBar` en mobile y
  `FeedbackCubit` en desktop.
- Principales áreas impactadas: capa de presentación de `client_categories`
  únicamente.
- Riesgo general estimado: **bajo** — no se modifica lógica de negocio, cubit,
  estados ni diálogos.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt y fpdart.
- La feature `client_categories` sigue la estructura `data/domain/presentation`
  con `ClientCategoriesCubit` gestionando estados reactivos via stream.
- Actualmente no existe carpeta `presentation/widgets/` en `client_categories`;
  los widgets están embebidos en la página.

### Patrón de referencia existente

- `ClientsPage` ya implementa el patrón dual mobile/desktop:
  - `build()` detecta `isMobile` y despacha a `_buildMobileLayout()` o
    `_buildDesktopLayout()`.
  - `_buildMobileLayout()` usa un `Stack` con la columna de contenido + FAB
    posicionado.
  - `_buildMobileSearchBar()` renderiza el searchbar sobre fondo
    `colorScheme.primary`.
  - `_buildSearchField()` es compartido y acepta parámetro `onPrimary` para
    cambiar colores.
  - `_buildContent()` acepta `isMobile` y despacha a `_buildCardList()` (cards)
    o `_buildTable()` (tabla).
  - `_showFeedback()` usa `SnackBar` en mobile y `FeedbackCubit` en desktop.

### Widgets reutilizables existentes

- `CategoryBadge` en
  `lib/features/clients/presentation/widgets/category_badge.dart` — renderiza un
  badge con color y nombre. Se puede reutilizar para mostrar el color de la
  categoría en el card.
- `_NoColorPainter` — clase privada en `client_categories_page.dart` que pinta
  un indicador "sin color". Permanece como clase privada de la página.

### Dependencias existentes (no cambian)

- `ClientCategoriesCubit` / `ClientCategoriesState` — ya soportan filtrado por
  nombre (`filterByName`), operaciones CRUD y estados loading/error/loaded.
- `FeedbackCubit` / `FeedbackState` — ya usado para feedback visual.
- `_clientCountByCategory` (Map<String, int>) — ya calculado en la página via
  `_watchClientCounts()`.
- Todos los diálogos (`_showAddCategoryDialog`, `_showEditDialog`,
  `_showDeleteConfirmation`, `_showAssociateClientsDialog`) — se reutilizan sin
  cambios.

### Constantes de tema relevantes

- `AppSideMenu.mobileBreakpoint = 768`
- `AppSpacing.*`, `AppRadii.*`, `AppElevation.*`, `AppOpacity.*` — tokens de
  diseño estándar.
- `AppDimensions.searchBoxWidth / searchBoxHeight` — solo usado en desktop, no
  en mobile.

## 3) Objetivo técnico

- **Qué debe cambiar:** La presentación de `ClientCategoriesPage` debe bifurcar
  su `build()` entre layout mobile (cards + searchbar + FAB) y layout desktop
  (tabla existente, sin cambios).
- **Qué resultado técnico se persigue:** Un layout mobile funcional sin
  overflow, consistente visualmente con `ClientsPage`, que reutilice toda la
  lógica existente.
- **Limitaciones a respetar:**
  - No modificar `ClientCategoriesCubit` ni `ClientCategoriesState`.
  - No modificar los diálogos existentes.
  - No crear nuevas traducciones (reutilizar las existentes).
  - No mover `_NoColorPainter` fuera de la página (mantener como clase privada).

## 4) Diseño técnico de la solución

### Enfoque propuesto

Replicar fielmente el patrón de `ClientsPage` adaptado a la información de
categorías:

1. **`build()`** — detecta `isMobile` y despacha a `_buildMobileLayout()` o
   `_buildDesktopLayout()`.
2. **`_buildDesktopLayout()`** — contiene el layout actual (PageHeader +
   searchbar inline + botón añadir + feedback card + tabla). Se extrae del
   `build()` actual sin modificar lógica.
3. **`_buildMobileLayout()`** — `Stack` con:
   - `Column` → `_buildMobileSearchBar()` + `Expanded` con
     `_buildContent(isMobile: true)`.
   - `Positioned` → FAB para añadir categoría (solo visible en estado
     `ClientCategoriesLoaded`).
4. **`_buildMobileSearchBar()`** — `Container` con fondo `colorScheme.primary` +
   `_buildSearchField(onPrimary: true)`.
5. **`_buildSearchField()`** — método compartido que acepta
   `{bool onPrimary = false}`. Sustituye el `ListenableBuilder` + `TextField`
   actual del desktop.
6. **`_buildContent()`** — método compartido que maneja estados
   (loading/error/loaded/empty) y despacha a `_buildCardList()` (mobile) o
   `_buildTable()` (desktop).
7. **`_buildCardList()`** — `ListView.builder` que renderiza
   `ClientCategoryCard` para cada categoría.
8. **`_showFeedback()`** — método que decide el mecanismo de feedback según
   `isMobile`.

### Componentes / módulos / servicios afectados

| Componente                                            | Tipo de cambio                                            |
| ----------------------------------------------------- | --------------------------------------------------------- |
| `ClientCategoriesPage` (`_ClientCategoriesPageState`) | Refactorización del `build()` + adición de métodos mobile |
| `ClientCategoryCard` (nuevo widget)                   | Creación                                                  |

### Contratos e interfaces

**`ClientCategoryCard`** — widget stateless:

```dart
class ClientCategoryCard extends StatelessWidget {
  final ClientCategory category;
  final int clientCount;
  final VoidCallback onEdit;
  final VoidCallback onAssociateClients;
  final VoidCallback onDelete;
}
```

No se modifican contratos de cubit, estados, repositorios ni use cases.

### Flujo de datos o de control

1. `build()` lee `MediaQuery.sizeOf(context).width` → determina `isMobile`.
2. Si mobile → `_buildMobileLayout()`:
   - Searchbar escucha `_searchController` y llama `_cubit.filterByName()`.
   - `BlocBuilder<ClientCategoriesCubit, ClientCategoriesState>` renderiza la
     lista de `ClientCategoryCard`.
   - Cada card recibe callbacks que invocan los diálogos existentes.
   - FAB invoca `_showAddCategoryDialog()`.
3. Si desktop → `_buildDesktopLayout()` (comportamiento actual sin cambios).
4. `_showFeedback()` centraliza la emisión de feedback: `SnackBar` (mobile) vs
   `FeedbackCubit` (desktop).

### Gestión de errores y validaciones

Sin cambios. Los estados de error (`ClientCategoriesError`) se renderizan igual
en mobile y desktop (ya que `_buildError` se reutiliza). Los diálogos mantienen
sus propias validaciones.

### Consideraciones de compatibilidad o migración

- No hay breaking changes. El layout desktop permanece idéntico.
- Los diálogos (`AlertDialog`) se adaptan automáticamente al tamaño de pantalla
  gracias al comportamiento estándar de Flutter.
- Si la ventana cambia de tamaño (p.ej. en web o desktop), el widget se
  reconstruye con el layout correcto gracias a `MediaQuery`.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                       | Propósito                                                                                                                                                   |
| ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/client_categories/presentation/widgets/client_category_card.dart` | Widget card para mostrar una categoría en la vista mobile. Muestra nombre, indicador de color, conteo de clientes, y acciones (editar, vincular, eliminar). |

### Artefactos a modificar

| Artefacto                                                                       | Cambio esperado                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/client_categories/presentation/pages/client_categories_page.dart` | Refactorizar `build()` para bifurcar en `_buildDesktopLayout()` / `_buildMobileLayout()`. Añadir métodos: `_buildMobileLayout()`, `_buildMobileSearchBar()`, `_buildSearchField()`, `_buildContent()`, `_buildCardList()`, `_showFeedback()`. Actualizar `_runWithProgress` y las llamadas a feedback para usar `_showFeedback()`. |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Pasos ordenados

1. **Crear `ClientCategoryCard`**
   - Crear
     `lib/features/client_categories/presentation/widgets/client_category_card.dart`.
   - Widget stateless con `Card` + `InkWell` (sin `onTap` de navegación) que
     contiene:
     - Fila superior: nombre de la categoría (`titleMedium`, `fontWeight.w600`,
       `maxLines: 1`, `ellipsis`).
     - Fila intermedia: indicador de color (badge con color o `_NoColorPainter`
       equivalente usando `CategoryBadge` o indicador inline) + conteo de
       clientes (label con icono `Icons.people_outline`).
     - Fila inferior: tres `IconButton.filled` para editar, vincular y eliminar
       (reutilizando los mismos estilos de `_buildCategoryActions`).
   - Seguir tokens de diseño: `AppElevation.low`, `AppRadii.medium`,
     `AppSpacing.*`, `AppOpacity.medium`.

2. **Refactorizar `build()` de `ClientCategoriesPage`**
   - Añadir detección `isMobile` con
     `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.
   - Mover el cuerpo actual del `build()` a `_buildDesktopLayout()`.
   - Crear `_buildMobileLayout()` con estructura `Stack` (columna + FAB).
   - En `build()`, despachar con operador ternario:
     `isMobile ? _buildMobileLayout(...) : _buildDesktopLayout(...)`.

3. **Extraer `_buildSearchField()` compartido**
   - Crear método que acepte `{bool onPrimary = false}` y renderice el
     `TextField` con estilos condicionales.
   - Usar `ListenableBuilder` (o `ValueListenableBuilder`) como ya existe en el
     desktop.
   - Reemplazar el `TextField` inline del desktop por llamada a este método.

4. **Implementar `_buildMobileSearchBar()`**
   - `Container` con `color: colorScheme.primary` y padding.
   - Solo visible cuando el estado es `ClientCategoriesLoaded`.
   - Renderiza `_buildSearchField(onPrimary: true)`.

5. **Implementar `_buildContent()` y `_buildCardList()`**
   - `_buildContent({required bool isMobile})` — maneja los estados del cubit y
     despacha a `_buildCardList()` o `_buildTable()`.
   - `_buildCardList()` — `ListView.builder` con `ClientCategoryCard`, pasando
     `_clientCountByCategory[category.id] ?? 0` y los callbacks de diálogos.

6. **Implementar `_showFeedback()`**
   - Detecta `isMobile` internamente con `MediaQuery`.
   - Mobile: `ScaffoldMessenger.of(context).showSnackBar(...)`.
   - Desktop: `_feedbackCubit.show(...)`.
   - Actualizar todas las llamadas en `_runWithProgress()` y
     `_showAssociateClientsDialog` para usar `_showFeedback()`.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6

### Dependencias entre pasos

- Paso 5 depende de paso 1 (el widget `ClientCategoryCard` debe existir).
- Pasos 3, 4 dependen de paso 2 (la estructura del build refactorizado).
- Paso 6 puede hacerse en paralelo con 3-5 ya que modifica un método
  independiente.

### Puntos delicados

- **Preservar `_NoColorPainter`:** Es una clase privada del archivo de la
  página. Si `ClientCategoryCard` necesita mostrar el indicador "sin color",
  puede usar un `Container` con un borde circular + línea diagonal como
  alternativa sencilla, o recibir un widget `colorIndicator` pre-construido
  desde la página. Alternativa más limpia: el card recibe el `category.color` y
  usa `CategoryBadge` (de `clients/presentation/widgets/`) que ya maneja el caso
  sin color. Si se necesita el indicador de círculo con diagonal (estilo tabla),
  se puede extraer `_NoColorPainter` a un archivo compartido o el card puede
  renderizar un círculo de color sin el painter.
- **Consistencia del searchbar mobile:** El hint del searchbar debe usar
  `l10n.clientCategoriesSearch` (no `l10n.clientsSearch`). El método
  `_buildSearchField()` debe parametrizar el hint text.
- **Padding bottom en `_buildCardList`:** Añadir `bottom: 80` en el padding del
  ListView para que el último card no quede tapado por el FAB (como hace
  `ClientsPage`).

## 7) Estrategia de validación

### Verificación automática

- `dart analyze` — sin errores ni warnings nuevos.
- `flutter test` — tests existentes deben seguir pasando (no se modifica lógica
  de negocio).

### Verificación manual

- **Mobile (ancho ≤ 768):**
  - No hay overflow horizontal.
  - Se muestra searchbar con fondo primario debajo del AppBar.
  - Las categorías se muestran como cards con nombre, color y conteo.
  - Las acciones (editar, vincular, eliminar) abren los diálogos correctos.
  - El FAB abre el diálogo de añadir categoría.
  - El feedback se muestra como SnackBar.
  - El clear (X) del searchbar restaura la lista completa.
  - Estados vacío, loading y error se renderizan correctamente.
- **Desktop (ancho > 768):**
  - La tabla se muestra exactamente igual que antes.
  - El feedback se muestra como card inline.
  - El botón "Añadir" sigue siendo un FilledButton inline.
- **Transición mobile ↔ desktop:**
  - Redimensionar la ventana cambia el layout sin perder estado (filtro, datos).

### Escenarios a cubrir

- Categoría con color asignado → badge de color visible.
- Categoría sin color → indicador "sin color" visible.
- Categoría con nombre largo → texto truncado con ellipsis.
- 0 categorías → estado vacío + FAB disponible.
- Búsqueda sin resultados → estado vacío.
- Operaciones CRUD → feedback correcto en SnackBar (mobile) o card (desktop).

### Tipo de pruebas recomendables

- Widget tests para `ClientCategoryCard` verificando renderizado de nombre,
  color, conteo y callbacks.
- No se requieren tests de cubit adicionales (no hay cambios en lógica).

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                       | Probabilidad | Impacto |
| ---------------------------------------------------------------------------- | ------------ | ------- |
| Diálogos existentes no se visualizan bien en pantallas muy pequeñas (<360px) | Baja         | Medio   |
| Regresión visual en desktop al extraer el layout actual                      | Baja         | Alto    |

### Impacto potencial

- Solo afecta la capa de presentación de `client_categories`.
- No afecta datos, integraciones ni otras features.

### Mitigación

- Extraer el layout desktop como un bloque intacto (cortar/pegar, no
  reescribir).
- Validar visualmente la tabla desktop después de la refactorización.
- Los diálogos usan `AlertDialog` estándar de Flutter que se adapta al viewport.

### Plan de rollback

- Revertir los cambios en `client_categories_page.dart` y eliminar
  `client_category_card.dart`.
- Un solo `git revert` del commit.

## 9) Suposiciones

- El breakpoint `AppSideMenu.mobileBreakpoint = 768` es correcto para la
  detección mobile en esta pantalla (consistente con `ClientsPage`).
- `CategoryBadge` es accesible desde `client_categories` sin restricciones de
  dependencia entre features (ya que está en `clients/presentation/widgets/` y
  `client_categories` ya importa entidades de `clients`).
- Los diálogos existentes funcionan correctamente en viewports mobile sin
  modificación.
- `ScaffoldMessenger` está disponible en el contexto de `ClientCategoriesPage`
  cuando se ejecuta en mobile (hay un `Scaffold` ancestro proporcionado por el
  shell/router).

## 10) Preguntas abiertas

- Ninguna. Las preguntas del análisis funcional se resolvieron con supuestos
  razonables que se mantienen.

## 11) Notas para implementación

- **No extraer `_NoColorPainter` a un archivo compartido** — mantenerlo privado
  en la página. Para el card, usar un indicador de color simple: un `Container`
  circular con el color si existe, o un widget con `_NoColorPainter` pasado como
  parámetro si se quiere consistencia exacta con la tabla.
- **El hint del searchbar mobile debe ser `l10n.clientCategoriesSearch`**, no
  `l10n.clientsSearch`.
- **Respetar el padding inferior** de `ListView.builder` (bottom ~80px) para
  evitar que el FAB tape el último card.
- **El `MultiBlocProvider`** debe mantenerse envolviendo tanto el layout mobile
  como el desktop.
- **No usar `setState` para el searchbar** — seguir el patrón de `ClientsPage`
  con `ValueListenableBuilder` o `ListenableBuilder`.
- **No romper la funcionalidad de `_runWithProgress`** — actualizar solo la
  llamada final de feedback para usar `_showFeedback()`.
- **Estado: Listo para implementación**
