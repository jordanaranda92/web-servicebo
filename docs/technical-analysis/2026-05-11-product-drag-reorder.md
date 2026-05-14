# Technical Analysis: Reordenación de productos por drag & drop

- **Fecha:** 2026-05-11
- **Identificador:** product-drag-reorder
- **Fuente:** docs/functional-analysis/2026-05-11-product-drag-reorder.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Crear un nuevo widget `ProductReorderDialog` con `ReorderableListView`
  (Flutter SDK, sin dependencias nuevas).
- Añadir un botón "Ordenar productos" en la barra de acciones de `ProductsPage`.
- Eliminar la columna "Orden" (header + celda `TextField` + `_orderControllers`)
  de la tabla.
- Reutilizar `ProductsCubit.saveBatchChanges(orderChanges: ...)` — sin cambios
  en domain ni data.
- Añadir 3 claves i18n al ARB y regenerar.
- Riesgo general estimado: **bajo**. Cambio aislado en capa presentation, sin
  impacto en modelo ni backend.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC (Cubit), GetIt, fpdart. Convención
estricta de capas: `domain/` → `data/` → `presentation/`.

### Módulos relevantes

- `lib/features/products/domain/entities/product.dart` — entidad `Product` con
  campo `order: int?`.
- `lib/features/products/data/models/product_model.dart` — serialización
  Firestore, campo `order` ya mapeado.
- `lib/features/products/data/repositories/products_repository_impl.dart` —
  `saveProductsBatch` ya soporta `orderChanges` como `Map<String, int>` y hace
  `batchUpdate`.
- `lib/features/products/domain/usecases/save_products_batch.dart` — use case
  existente, sin cambios.
- `lib/features/products/presentation/bloc/products_cubit.dart` —
  `saveBatchChanges()` ya expone `orderChanges`.
- `lib/features/products/presentation/bloc/products_state.dart` —
  `ProductsLoaded` con `allProducts` y `filteredProducts`.
- `lib/features/products/presentation/pages/products_page.dart` — tabla con
  columna "Orden" (input numérico inline, `_orderControllers`).
- `lib/features/products/presentation/widgets/fd_product_selector_dialog.dart` —
  patrón de referencia para diálogos en esta feature.

### Restricciones

- Solo existe locale `es` (un único ARB: `app_es.arb`). Las clases
  `app_localizations.dart` y `app_localizations_es.dart` se regeneran con
  `flutter gen-l10n`.
- No hay dependencias de drag & drop externas; `ReorderableListView` es nativo
  de Flutter SDK.
- El stream de Firestore (`watchProductsStream`) refresca la tabla
  automáticamente tras persistir cambios.

## 3) Objetivo técnico

- **Qué debe cambiar:** Reemplazar el mecanismo de edición de orden por campo
  numérico inline por un diálogo de reordenación con drag & drop.
- **Resultado técnico:** Un `ProductReorderDialog` stateful que trabaja con una
  copia snapshot de la lista de productos, permite reordenar por drag y persiste
  solo los deltas.
- **Limitaciones:** No alterar capas domain ni data. No añadir dependencias
  externas.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear un diálogo `StatefulWidget` que reciba `List<Product>` como snapshot.
Internamente mantiene una copia mutable que se reordena con
`ReorderableListView`. Al confirmar, calcula el diff entre el orden original y
el nuevo, y devuelve un `Map<String, int>` de cambios. `ProductsPage` recibe el
resultado y llama a `saveBatchChanges`.

### Componentes / módulos / servicios afectados

| Capa                  | Artefacto                                             | Impacto                                                            |
| --------------------- | ----------------------------------------------------- | ------------------------------------------------------------------ |
| Presentation - Widget | `product_reorder_dialog.dart` (nuevo)                 | Widget completo del diálogo                                        |
| Presentation - Page   | `products_page.dart`                                  | Añadir botón, eliminar columna orden, eliminar `_orderControllers` |
| i18n                  | `app_es.arb`                                          | 3 claves nuevas                                                    |
| i18n (generado)       | `app_localizations.dart`, `app_localizations_es.dart` | Regenerar con `flutter gen-l10n`                                   |

### Contratos e interfaces

**Entrada del diálogo:**

```dart
class ProductReorderDialog extends StatefulWidget {
  final List<Product> products; // snapshot ordenado
  const ProductReorderDialog({super.key, required this.products});
}
```

**Salida del diálogo (vía `Navigator.pop`):**

```dart
// null → cancelado / sin cambios
// Map<String, int> → {productId: newOrder} solo los que cambiaron
Map<String, int>? result = await showDialog<Map<String, int>>(...)
```

**Invocación desde `ProductsPage`:**

```dart
void _showReorderDialog(BuildContext context, List<Product> allProducts) async {
  final sorted = _sortForReorder(allProducts);
  final result = await showDialog<Map<String, int>>(
    context: context,
    builder: (_) => ProductReorderDialog(products: sorted),
  );
  if (result != null && result.isNotEmpty) {
    // mostrar progress, llamar saveBatchChanges, feedback
  }
}
```

### Flujo de datos o de control

1. `ProductsPage` lee `state.allProducts` del `ProductsLoaded`.
2. Ordena la lista: productos con `order != null` ascendente primero,
   `order == null` al final (dentro de cada grupo, orden estable del stream).
3. Pasa la lista ordenada como snapshot a `ProductReorderDialog`.
4. El diálogo copia la lista a un `List<Product>` local mutable.
5. Cada operación de drag actualiza la lista local con
   `onReorder(oldIndex, newIndex)`.
6. Al confirmar:
   - Itera la lista local; asigna `order = index + 1` a cada posición.
   - Compara con el orden original recibido.
   - Retorna un `Map<String, int>` con solo los productos cuyo `order` difiere.
7. `ProductsPage` recibe el map, muestra diálogo de progreso y llama a
   `_cubit.saveBatchChanges(orderChanges: result)`.
8. El stream de Firestore actualiza la tabla automáticamente.

### Gestión de errores y validaciones

- Si `saveBatchChanges` retorna `false`, se muestra el feedback de error
  existente (reutiliza `_feedbackMessage` / `_feedbackSuccess`).
- No se necesita validación de entrada: el drag & drop garantiza posiciones
  válidas.
- Si la lista está vacía, el botón "Ordenar productos" se desactiva (misma
  lógica que ya existe para comprobar `hasProducts`).

### Consideraciones de compatibilidad o migración

- El campo `order` en Firestore sigue siendo `int?`. Los productos que ya tenían
  orden manual conservan valores compatibles.
- Los productos con `order == null` recibirán un valor por primera vez al
  confirmar la reordenación. Esto es deseable y normaliza la base de datos.
- No hay breaking change en modelo, repositorio ni use case.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                | Propósito                                                                  |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| `lib/features/products/presentation/widgets/product_reorder_dialog.dart` | Diálogo con `ReorderableListView` para reordenar productos por drag & drop |

### Artefactos a modificar

| Artefacto                                                        | Cambio esperado                                                                                                                                                                                                                            |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/features/products/presentation/pages/products_page.dart`    | Añadir botón "Ordenar productos" + método `_showReorderDialog`. Eliminar `_orderControllers`, columna "Orden" del header, celda orden del `_buildRow`, lógica de order en `_savePendingChanges` y limpieza en `dispose` / `_deleteProduct` |
| `lib/app/localization/l10n/app_es.arb`                           | Añadir claves: `productsReorder`, `productsReorderTitle`, `productsReorderSaved`                                                                                                                                                           |
| `lib/app/localization/l10n/app_localizations.dart` (generado)    | Regenerar con `flutter gen-l10n`                                                                                                                                                                                                           |
| `lib/app/localization/l10n/app_localizations_es.dart` (generado) | Regenerar con `flutter gen-l10n`                                                                                                                                                                                                           |

### Artefactos a retirar o reemplazar

| Artefacto                                        | Motivo                                                                           |
| ------------------------------------------------ | -------------------------------------------------------------------------------- |
| Columna "Orden" en tabla de `products_page.dart` | Reemplazada por diálogo de reordenación                                          |
| `_orderControllers` en `_ProductsPageState`      | Ya no necesario                                                                  |
| Clave i18n `productsColumnOrder` en ARB          | Ya no usada tras eliminar columna. Puede dejarse por compatibilidad o eliminarse |

## 6) Estrategia de implementación

### Pasos ordenados

1. **Paso 1 — i18n:** Añadir las 3 claves nuevas al ARB (`productsReorder`,
   `productsReorderTitle`, `productsReorderSaved`). Ejecutar `flutter gen-l10n`.

2. **Paso 2 — Widget `ProductReorderDialog`:** Crear el archivo en
   `presentation/widgets/`. Implementar:
   - Constructor recibe `List<Product>`.
   - Estado local: copia mutable de la lista.
   - `ReorderableListView.builder` con tiles que muestran: drag handle, color
     indicator, nombre, badge activo/inactivo (opacidad para inactivos).
   - Botones: "Cancelar" (`Navigator.pop(context)`) y "Guardar"
     (`Navigator.pop(context, orderChanges)`).
   - Ancho fijo del diálogo ~480px, alto limitado con `ConstrainedBox`.

3. **Paso 3 — Integrar en `ProductsPage`:**
   - Añadir método `_showReorderDialog` que ordena `allProducts`, abre el
     diálogo, recibe resultado y llama a `saveBatchChanges` con progress +
     feedback (reutilizar patrón de `_saveField`).
   - Añadir botón `OutlinedButton.icon` con `Icons.swap_vert_rounded` y texto
     i18n a la derecha de "Añadir producto".

4. **Paso 4 — Eliminar columna orden de la tabla:**
   - Eliminar `_orderControllers` (declaración, dispose, limpieza en
     `_deleteProduct`).
   - Eliminar la columna "Orden" del header en `_buildTable`.
   - Eliminar la celda `SizedBox(width: 80)` con el `TextField` de orden en
     `_buildRow`.
   - Eliminar las líneas de `_orderControllers` en `_savePendingChanges`.
   - Eliminar import de `package:flutter/services.dart` si ya no se usa
     `FilteringTextInputFormatter`.

5. **Paso 5 — Verificar y probar:** Ejecutar `flutter analyze`,
   `flutter gen-l10n`, comprobar manualmente.

### Orden recomendado

1 → 2 → 3 → 4 → 5 (secuencial, cada paso depende del anterior).

### Dependencias entre pasos

- Paso 2 necesita las claves i18n del paso 1.
- Paso 3 necesita el widget del paso 2.
- Paso 4 puede hacerse en paralelo con paso 3, pero es más seguro tras integrar
  el nuevo botón.

### Puntos delicados

- **`_savePendingChanges`:** Actualmente guarda cambios de nombre y orden
  pendientes al hacer `dispose`. Tras eliminar `_orderControllers`, solo
  quedarán `_nameControllers`. Verificar que la lógica restante sigue compilando
  sin la parte de order.
- **`_deleteProduct`:** Contiene
  `_orderControllers.remove(product.id)?.dispose()`. Debe eliminarse esa línea.
- **Import `services.dart`:** `FilteringTextInputFormatter` se importa desde
  `package:flutter/services.dart`. Si la columna orden era el único uso, el
  import puede eliminarse. Verificar antes de borrar.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze` — sin warnings ni errores.
- `flutter gen-l10n` — generación exitosa de localizaciones.
- Tests unitarios existentes del cubit y repositorio no deben romperse (no se
  modifica nada en domain/data).

### Validación manual

- Abrir la página de productos con productos existentes (con y sin orden).
- Pulsar "Ordenar productos" → comprobar que el diálogo muestra todos los
  productos en el orden correcto.
- Arrastrar un producto de la posición 5 a la 1 → comprobar actualización
  visual.
- Pulsar "Guardar" → comprobar spinner de progreso, feedback de éxito, y que la
  tabla refleja el nuevo orden.
- Pulsar "Cancelar" → comprobar que no hay escritura a Firestore.
- Reabrir diálogo → comprobar que el orden persistido se mantiene.
- Verificar que la columna "Orden" con input numérico ya no aparece en la tabla.

### Escenarios a cubrir

| Escenario               | Resultado esperado                                            |
| ----------------------- | ------------------------------------------------------------- |
| Sin productos           | Botón deshabilitado                                           |
| Todos sin orden previo  | Diálogo muestra en orden del stream; al guardar asigna 1,2,3… |
| Reordenar y guardar     | Solo deltas se escriben a Firestore                           |
| Cancelar tras arrastrar | Sin escritura                                                 |
| Error de red al guardar | Feedback de error                                             |

### Pruebas recomendables

- Test unitario (opcional): función pura que calcula el diff `Map<String, int>`
  dados lista original y lista reordenada.
- Widget test (recomendado): verificar que `ProductReorderDialog` retorna el map
  correcto al reordenar y confirmar.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                    | Probabilidad | Impacto                                                   |
| ------------------------------------------------------------------------- | ------------ | --------------------------------------------------------- |
| `ReorderableListView` tiene scroll issues en web con listas largas        | Baja         | Medio — mitigable con `scrollController` y altura acotada |
| Pérdida de orden inline si el usuario esperaba seguir editando por número | Baja         | Bajo — el nuevo UX es estrictamente superior              |

### Impacto potencial

- Solo afecta la feature de productos en capa presentation.
- No afecta pedidos, clientes ni otras features.
- No cambia esquema de Firestore ni modelo de datos.

### Mitigación

- Acotar la altura del diálogo con `ConstrainedBox(maxHeight: 500)` para evitar
  problemas de scroll en listas largas.
- Si `ReorderableListView` presentara issues en web, se puede reemplazar por
  `ReorderableListView.builder` con `proxyDecorator` para feedback visual
  mejorado.

### Plan de rollback

- Revertir el commit. La columna "Orden" vuelve a aparecer en la tabla y los
  `_orderControllers` se restauran. No hay migración de datos que deshacer (el
  campo `order` sigue existiendo con los mismos valores, ahora secuenciales).

## 9) Suposiciones

- La lista de productos es lo suficientemente pequeña (decenas, no miles) para
  que `ReorderableListView` funcione bien sin virtualización avanzada.
- `ReorderableListView` de Flutter funciona correctamente en web/desktop con
  ratón (confirmado por la documentación oficial).
- El patrón de diálogos de la feature (ver `FdProductSelectorDialog`) se puede
  replicar para mantener consistencia visual.
- Las claves i18n existentes de guardado (`productsSaving`,
  `productsSuccessSaved`, `productsErrorSaving`) se reutilizan; solo se
  necesitan 3 nuevas.

## 10) Preguntas abiertas

_Sin preguntas abiertas._

## 11) Notas para implementación

- **No crear use cases nuevos.** `saveBatchChanges` ya cubre el caso.
- **Seguir el patrón de `FdProductSelectorDialog`** para estructura del widget
  (StatefulWidget, constructor con datos, dialog actions).
- **Usar `ReorderableListView.builder`** en vez de `ReorderableListView` para
  mejor rendimiento con listas medianas.
- **Cada tile debe tener `key: ValueKey(product.id)`** — requisito obligatorio
  de `ReorderableListView`.
- **No olvidar eliminar el import de `services.dart`** si
  `FilteringTextInputFormatter` ya no se usa en `products_page.dart`.
- **Secuencia sugerida:** i18n → widget → integración en page → limpieza de
  columna → verificación.
- **Estado: Listo para implementación**
