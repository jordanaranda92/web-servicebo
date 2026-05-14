# Technical Analysis: Productos – Vista Mobile con Cards

- **Fecha:** 2026-05-12
- **Identificador:** products-mobile-cards
- **Fuente:** docs/functional-analysis/2026-05-12-products-mobile-cards.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Refactorizar `ProductsPage` para detectar el breakpoint mobile
  (`AppSideMenu.mobileBreakpoint = 768`) y renderizar condicionalmente un layout
  mobile o desktop, siguiendo el patrón exacto de `ClientsPage`.
- Crear widget `ProductCard` en `presentation/widgets/product_card.dart` con
  acciones inline (Vincular, Editar, Eliminar).
- Crear widget `ProductEditDialog` en
  `presentation/widgets/product_edit_dialog.dart` con campos de nombre y switch
  activo/inactivo.
- Extraer el search bar a un método compartido `_buildSearchField` reutilizable
  entre ambos layouts.
- Refactorizar el método `_showFeedback` para usar `SnackBar` en mobile y
  `FeedbackCubit` en desktop.
- **Áreas impactadas:** `products_page.dart`, nueva `product_card.dart`, nueva
  `product_edit_dialog.dart`.
- **Riesgo general estimado:** bajo — es un patrón ya probado en `ClientsPage` y
  `ShippingMethodsPage`.

## 2) Contexto técnico observado

### Arquitectura y patrones detectados

- **Clean Architecture feature-first** con capas `domain/`, `data/`,
  `presentation/`.
- **BLoC/Cubit** para gestión de estado (`ProductsCubit` + `ProductsState`).
- **Patrón responsive** ya implementado en `ClientsPage` y
  `ShippingMethodsPage`:
  - Detección via
    `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.
  - Métodos `_buildDesktopLayout` / `_buildMobileLayout`.
  - `_buildContent` compartido con parámetro `isMobile`.
  - `_buildMobileSearchBar` con fondo `colorScheme.primary`.
  - `_buildSearchField` con parámetro `onPrimary`.
  - Widget card separado en `presentation/widgets/`.
  - FAB para acción principal en mobile.
  - Feedback via `SnackBar` en mobile, `FeedbackCubit` card en desktop.

### Módulos relevantes

- `lib/features/products/presentation/pages/products_page.dart` — archivo
  principal (~1100 líneas), contiene toda la UI actual con tabla.
- `lib/features/products/presentation/bloc/products_cubit.dart` — lógica
  existente: `filterByName`, `saveBatchChanges`, `addProduct`, `deleteProduct`,
  `linkFdProduct`, `unlinkFdProduct`, `fetchFdProducts`.
- `lib/features/products/presentation/widgets/` — actualmente solo
  `fd_product_selector_dialog.dart` y `product_reorder_dialog.dart`.
- `lib/features/products/domain/entities/product.dart` — entidad `Product` con
  `id`, `name`, `facturaDirectaUuid`, `isActive`, `color`, `order`.
- `lib/features/products/domain/entities/fd_product.dart` — entidad `FdProduct`
  con `uuid`, `name`, `salesPrice`, `currency`.

### Restricciones

- No modificar `ProductsCubit`, `ProductsState` ni capas de dominio/datos.
- No introducir nuevas dependencias.
- Reutilizar diálogos existentes (`FdProductSelectorDialog`, confirmación de
  borrado, diálogo de añadir).
- Respetar design tokens (`AppSpacing`, `AppRadii`, `AppElevation`,
  `AppOpacity`, `AppIconSizes`).
- i18n obligatorio — no hardcodear textos; reutilizar claves existentes
  (`productsEdit`, `productsSelectFdProduct`, `productsUnlinkFdProduct`,
  `productsDelete`, etc.).

## 3) Objetivo técnico

- **Qué debe cambiar:** La estructura del método `build` de `ProductsPage` debe
  bifurcarse en layout desktop (existente) y layout mobile (nuevo con cards).
- **Resultado técnico:** En pantallas ≤ 768 px se renderiza `_buildMobileLayout`
  con search bar + lista de `ProductCard` + FAB. En desktop se mantiene la tabla
  actual sin cambios.
- **Limitaciones:** No se incluye reordenación (drag & drop) en mobile. Los
  controladores de nombre inline (`_nameControllers`) solo se usan en desktop.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Replicar el patrón de `ClientsPage` / `ShippingMethodsPage` dentro de
`ProductsPage`:

1. En `build()`, detectar `isMobile` y renderizar `_buildMobileLayout` o
   `_buildDesktopLayout`.
2. Extraer el contenido de tabla actual al método `_buildDesktopLayout` (con
   `PageHeader`, barra de búsqueda desktop, botones, feedback card, tabla).
3. Crear `_buildMobileLayout` con `Stack` → `Column` (search bar + content) +
   `Positioned` FAB.
4. Crear `_buildMobileSearchBar` con fondo primary y campo
   `_buildSearchField(onPrimary: true)`.
5. Extraer `_buildSearchField` como método compartido con parámetro `onPrimary`
   (igual que en `ClientsPage`).
6. Crear `_buildContent` compartido con parámetro `isMobile` que delega a
   `_buildCardList` o `_buildTable`.
7. Crear `_buildCardList` que renderiza `ListView.builder` de `ProductCard`.
8. Crear `_showFeedback` con lógica `isMobile ? SnackBar : FeedbackCubit`.

### Componentes / módulos / servicios afectados

| Componente                 | Tipo de cambio                                                            |
| -------------------------- | ------------------------------------------------------------------------- |
| `products_page.dart`       | Refactorización mayor — reestructurar `build()` en desktop/mobile layouts |
| `product_card.dart`        | **Nuevo** — widget `ProductCard`                                          |
| `product_edit_dialog.dart` | **Nuevo** — diálogo de edición (nombre + activo)                          |

### Contratos e interfaces

#### `ProductCard`

```dart
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.fdProduct,           // FdProduct vinculado, nullable
    required this.onLink,     // Abrir FdProductSelectorDialog
    required this.onUnlink,   // Desvincular FD (solo si hay vínculo)
    required this.onEdit,     // Abrir ProductEditDialog
    required this.onDelete,   // Confirmar y eliminar
  });
}
```

#### `ProductEditDialog`

```dart
class ProductEditDialog extends StatefulWidget {
  final Product product;
  const ProductEditDialog({super.key, required this.product});
  // Retorna ({String name, bool isActive})? al hacer pop
}
```

### Flujo de datos o de control

1. `ProductsPage.build()` → detecta `isMobile` → delega a `_buildMobileLayout` o
   `_buildDesktopLayout`.
2. `_buildMobileLayout` → `_buildMobileSearchBar` +
   `_buildContent(isMobile: true)` + FAB.
3. `_buildContent(isMobile: true)` → `BlocBuilder<ProductsCubit>` → si datos
   cargados → `_buildCardList`.
4. `_buildCardList` → `ListView.builder` → cada item es
   `ProductCard(product, fdProduct, callbacks)`.
5. Callbacks del card:
   - `onLink` → llama `_showFdProductSelector(product)` existente (ya usa
     `showDialog`).
   - `onUnlink` → llama `_unlinkFdProduct(product)` existente, pero usa
     `_showFeedback` para mobile.
   - `onEdit` → muestra `ProductEditDialog` → recibe `({name, isActive})` →
     llama `_saveField`.
   - `onDelete` → llama `_showDeleteConfirmation` existente.
6. Feedback → `_showFeedback(message, success)` → mobile: `SnackBar`, desktop:
   `FeedbackCubit`.

### Gestión de errores y validaciones

- `ProductEditDialog`: validación de nombre no vacío (`TextFormField` con
  `validator`).
- El switch de activo/inactivo no requiere validación.
- Los errores de operaciones (save, link, delete) se gestionan con el mismo
  patrón existente: dialog de progreso + feedback.
- En mobile, el feedback se muestra via `SnackBar` en lugar del card inline.

### Consideraciones de compatibilidad o migración

- No hay breaking changes. El layout desktop se mantiene idéntico.
- La refactorización de `build()` reorganiza el código existente sin cambiar
  comportamiento.
- Los `_nameControllers` (edición inline) siguen activos solo en desktop; en
  mobile se usa el diálogo.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                             | Propósito                                                                |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `lib/features/products/presentation/widgets/product_card.dart`        | Widget card para visualización mobile de un producto con acciones inline |
| `lib/features/products/presentation/widgets/product_edit_dialog.dart` | Diálogo de edición con campo nombre y switch activo/inactivo             |

### Artefactos a modificar

| Artefacto                                                     | Cambio esperado                                                                                                                                                                                                                                             |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/products/presentation/pages/products_page.dart` | Reestructurar `build()` en `_buildDesktopLayout` / `_buildMobileLayout`; añadir `_buildMobileSearchBar`, `_buildSearchField`, `_buildContent`, `_buildCardList`, `_showFeedback`; refactorizar feedback de operaciones existentes para usar `_showFeedback` |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo |
| --------- | ------ |
| Ninguno   | —      |

## 6) Estrategia de implementación

### Paso 1: Crear `ProductCard`

- Crear `lib/features/products/presentation/widgets/product_card.dart`.
- Seguir el patrón de `ShippingMethodCard` (acciones visibles como
  `IconButton.filled` en fila).
- Contenido del card:
  - **Fila superior:** Nombre del producto (texto con ellipsis) + indicador
    visual de activo/inactivo (punto de color o chip).
  - **Fila inferior (opcional):** Nombre del producto FD vinculado + precio. Si
    no hay vínculo, texto "Sin vincular" en estilo atenuado.
  - **Columna de acciones (derecha):** Tres `IconButton.filled`:
    - Vincular (`Icons.link` / `Icons.check_circle_rounded`): `primaryContainer`
      style.
    - Editar (`Icons.edit_outlined`): `primaryContainer` style.
    - Eliminar (`Icons.delete_outline_rounded`): `errorContainer` style.
  - Si hay vínculo FD, añadir un cuarto botón de desvincular (`Icons.link_off`):
    `errorContainer` style.
- Todos los textos i18n.

### Paso 2: Crear `ProductEditDialog`

- Crear `lib/features/products/presentation/widgets/product_edit_dialog.dart`.
- `StatefulWidget` con `TextEditingController` para nombre (inicializado con
  `product.name`).
- `Switch` para activo/inactivo (inicializado con `product.isActive`).
- Botones Cancelar / Guardar.
- Validación: nombre no puede estar vacío.
- Retorna `({String name, bool isActive})?` — `null` si cancela, record con
  valores si confirma (solo si hay cambios).

### Paso 3: Refactorizar `ProductsPage` — estructura

1. En `build()`:
   - Añadir detección
     `isMobile = MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.
   - Renderizar `isMobile ? _buildMobileLayout(…) : _buildDesktopLayout(…)`.
2. Mover contenido actual de `build()` (Column con PageHeader + barra búsqueda +
   tabla) al método `_buildDesktopLayout`.
3. Crear `_buildMobileLayout` siguiendo patrón de `ClientsPage`:
   - `Stack` con `Column` (search bar + content) y `Positioned` FAB.
   - FAB con `Icons.add_rounded` que llama a `_showAddProductDialog`.
4. Crear `_buildMobileSearchBar`:
   - `Container` con `color: colorScheme.primary`.
   - Dentro: `_buildSearchField(l10n, colorScheme, onPrimary: true)`.
   - Solo visible si estado es `ProductsLoaded`.
5. Crear `_buildSearchField` compartido con parámetro `onPrimary`:
   - Extraer del search field desktop actual.
   - Con soporte `ValueListenableBuilder`, estilos onPrimary, botón clear.
6. Crear `_buildContent(…, {required bool isMobile})`:
   - `BlocBuilder` que muestra loading / error / empty / (isMobile ?
     `_buildCardList` : `_buildTable`).
   - El check de `!_fdLoaded` se mantiene para ambos layouts.
7. Crear `_buildCardList`:
   - `ListView.builder` con padding bottom 80 (para no tapar FAB).
   - Cada item: `ProductCard` con los callbacks adecuados.

### Paso 4: Refactorizar feedback

1. Crear método `_showFeedback(String message, {required bool success})`:
   - Detectar `isMobile` con `MediaQuery.sizeOf(context).width`.
   - Mobile → `ScaffoldMessenger.of(context).showSnackBar(…)`.
   - Desktop → `_feedbackCubit.show(message, isSuccess: success)`.
2. Reemplazar llamadas directas a `_feedbackCubit.show(…)` en los métodos de
   operación (`_saveField`, `_unlinkFdProduct`, `_deleteProduct`,
   `_showFdProductSelector`, `_addProduct`, `_showReorderDialog`) por
   `_showFeedback(…)`.

### Paso 5: Integrar `ProductEditDialog` en callbacks

- En `_buildCardList`, el callback `onEdit` del card:
  1. Muestra `showDialog<({String name, bool isActive})>` con
     `ProductEditDialog(product: product)`.
  2. Si el resultado no es null, llama a
     `_saveField(product.id, name: result.name, isActive: result.isActive)`
     (solo si hay cambios reales respecto al producto original).

### Orden recomendado

1. `ProductCard` (sin dependencias, se puede probar aislado)
2. `ProductEditDialog` (sin dependencias, se puede probar aislado)
3. Refactorización de `ProductsPage` (depende de 1 y 2)

### Dependencias entre pasos

- Pasos 1 y 2 son independientes entre sí.
- Paso 3 depende de 1 y 2.
- Paso 4 se puede hacer dentro de paso 3.
- Paso 5 se puede hacer dentro de paso 3.

### Puntos delicados

- **Reorganización de `build()`:** El actual `build()` es un único `Column` con
  todo inline. Al extraer a `_buildDesktopLayout`, hay que asegurar que la barra
  de búsqueda desktop, feedback card y tabla siguen exactamente igual.
- **`_nameControllers` en desktop:** Los controladores de texto para edición
  inline solo deben crearse/usarse en el layout desktop (`_buildTable` /
  `_buildRow`). En mobile no se usan.
- **`_savePendingChanges` en `dispose`:** Este método solo aplica a cambios
  pendientes en controladores de nombre (desktop). En mobile los cambios se
  guardan inmediatamente vía diálogo, así que no hay impacto.
- **`_cachedFdProducts`:** Se carga en `initState` y se comparte. Ambos layouts
  acceden a esta caché para resolver el `FdProduct` vinculado.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze` — verificar que no hay errores ni warnings.
- Tests unitarios existentes del cubit no requieren cambios.
- Tests de widget para `ProductCard` y `ProductEditDialog` (recomendable crear).

### Validación manual

- En navegador/emulador, redimensionar ventana para cruzar breakpoint 768 px y
  verificar cambio de layout.
- En mobile layout:
  - Verificar search bar con fondo primary filtra correctamente.
  - Verificar cards muestran nombre, estado, producto FD.
  - Verificar acción Vincular abre `FdProductSelectorDialog` y guarda
    correctamente.
  - Verificar acción Desvincular (solo visible con vínculo) desvincula y muestra
    SnackBar.
  - Verificar acción Editar abre diálogo con nombre y switch, guarda cambios.
  - Verificar acción Eliminar muestra confirmación y elimina.
  - Verificar FAB añade producto.
  - Verificar SnackBar de feedback en todas las operaciones.
  - Verificar estados: loading, error (con retry), vacío.
- En desktop: verificar que la tabla sigue funcionando idénticamente.

### Escenarios edge case a probar

- Producto con nombre muy largo → ellipsis en card.
- Producto inactivo → diferenciación visual.
- Producto sin vínculo FD → texto atenuado, sin botón desvincular.
- Lista vacía → mensaje centrado.
- Redimensionar ventana cruzando breakpoint → transición fluida.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Bajo:** Refactorización de `build()` podría romper el layout desktop si no
  se extrae correctamente.
- **Bajo:** Inconsistencia visual si `ProductCard` no sigue exactamente los
  tokens de diseño.

### Impacto potencial

- Solo afecta la capa de presentación de products. No hay cambios en dominio,
  datos, ni otros features.
- Mejora significativa de UX en mobile.

### Mitigación

- Seguir estrictamente el patrón de `ClientsPage` y `ShippingMethodsPage` que ya
  están probados.
- Verificar layout desktop después de la refactorización.

### Plan de rollback

- Revertir los 3 archivos modificados/creados. No hay cambios en estado, datos
  ni configuración.

## 9) Suposiciones

- Se reutiliza `AppSideMenu.mobileBreakpoint` (768 px) como umbral.
- Se reutilizan todas las claves i18n existentes (`productsEdit`,
  `productsSelectFdProduct`, `productsUnlinkFdProduct`, `productsDelete`,
  `productsColumnName`, `productsColumnActive`, etc.).
- No se necesitan nuevas claves i18n (se reutilizan las existentes).
- El indicador visual de activo/inactivo en el card será un punto/chip de color
  (verde/rojo) usando los colores del tema (`CustomColors.success` /
  `colorScheme.error`).

## 10) Preguntas abiertas

- Ninguna. Todos los requisitos están definidos y el patrón de referencia está
  probado.

## 11) Notas para implementación

- Seguir estrictamente el patrón de `ClientsPage` para la estructura del layout
  mobile.
- Seguir estrictamente el patrón de `ShippingMethodCard` para el diseño del card
  (acciones como `IconButton.filled` en fila a la derecha).
- Usar `record type` `({String name, bool isActive})` como retorno de
  `ProductEditDialog` — disponible en Dart 3.
- No crear lógica nueva en el cubit; todas las operaciones ya existen.
- En `_buildCardList`, resolver el `FdProduct` vinculado con
  `_cachedFdProducts?.where((fd) => fd.uuid == product.facturaDirectaUuid).firstOrNull`.
- En `ProductEditDialog`, solo retornar resultado si hay cambios reales
  (`name != product.name || isActive != product.isActive`); si no hay cambios,
  retornar `null` para evitar saves innecesarios.
- La refactorización del feedback (paso 4) es importante para que operaciones
  como `_unlinkFdProduct` y `_deleteProduct` usen SnackBar en mobile.
  Actualmente llaman directamente a `_feedbackCubit.show()`.
- **Estado: Listo para implementación**
