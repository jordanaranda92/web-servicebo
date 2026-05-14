# Technical Analysis: Menú contextual para clientes y productos

- **Fecha:** 2026-05-10
- **Identificador:** context-menu-client-product
- **Fuente:** docs/functional-analysis/2026-05-10-context-menu-client-product.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Reemplazar los controles de eliminación (botones ✕) en cabeceras de cliente y
  filas de producto por menús contextuales invocados con click derecho
  (`onSecondaryTapDown` + `showMenu`).
- El patrón de `showMenu` con `PopupMenuEntry` ya se usa en el widget para los
  flags de celdas (`_showCellContextMenu`), por lo que se reutiliza el mismo
  enfoque.
- Los callbacks `onDeleteClients`, `onDeleteProducts` y `onResetOrders` ya
  existen en `OrdersTable` y están conectados desde `OrdersTodayPage`. No se
  necesitan cambios en la interfaz pública del widget ni en capas superiores.
- Se necesitan 4 nuevas claves i18n para las opciones de menú.
- Principales artefactos impactados: `orders_table.dart`, `app_es.arb`
- Riesgo general estimado: **bajo** — cambio contenido en la capa de
  presentación, sin impacto en datos ni lógica de negocio.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first. Feature `orders_today` con capas `data/`,
  `domain/`, `presentation/`.
- El widget `OrdersTable` en `presentation/widgets/orders_table.dart` es un
  `StatefulWidget` que construye una tabla con scroll sincronizado, columnas
  congeladas y edición inline.

### Patrón de menú contextual existente

- Ya existe `_showCellContextMenu` (línea ~1052) que usa
  `GestureDetector.onSecondaryTapUp` para capturar la posición y
  `showMenu<String>()` para mostrar opciones con `PopupMenuItem<String>`.
- El menú se posiciona con `RelativeRect.fromLTRB` a partir del `globalPosition`
  del evento.
- Se usa un `then()` con `switch` para despachar la acción seleccionada.

### Controles actuales a reemplazar

1. **Cliente (cabecera de columna):** Dentro del builder de headers
   (`_buildHeaderCell`), línea ~705-726: un `GestureDetector` con `onTap` que
   muestra `Icons.cancel` y dispara
   `_showDeleteConfirmation([col], 1, isProducts: false)`.
2. **Producto (fila):** En `_buildProductCell`, línea ~835-845: un `IconButton`
   con `Icons.cancel` que dispara
   `_showDeleteConfirmation([productIdx], 1, isProducts: true)`.

### Diálogos de confirmación existentes

- `_showDeleteConfirmation` (línea ~1226): acepta `sortedIndices`,
  `selectedCount` e `isProducts`. Reutilizable para eliminación de cliente y
  producto desde el menú.
- Strings i18n ya disponibles: `ordersTodayDeleteConfirmTitle`,
  `ordersTodayDeleteConfirmMessage`, `ordersTodayDeleteProductsConfirmTitle`,
  `ordersTodayDeleteProductsConfirmMessage`, `ordersTodayResetConfirmTitle`,
  `ordersTodayResetConfirmMessage`, `ordersTodayResetConfirm`.

### Callback de reset

- `onResetOrders` está declarado en `OrdersTable` (línea 54) como
  `void Function(List<int> clientIndices)?`.
- En `OrdersTodayPage` (línea 226) está conectado pero con
  `// TODO: implement reset orders`. El callback existe en la interfaz pero la
  implementación en la page está pendiente. Este análisis **no** aborda esa
  implementación (fuera de alcance del análisis funcional).

### i18n

- Archivo ARB: `lib/app/localization/l10n/app_es.arb`.
- Generación automática con `flutter gen-l10n` (archivo `l10n.yaml` en raíz).
- Clase generada: `AppLocalizations` en
  `lib/app/localization/l10n/app_localizations.dart`.

## 3) Objetivo técnico

- **Qué cambia:** La interacción de eliminación/reset de clientes y productos
  pasa de botones ✕ inline a menú contextual (click derecho).
- **Resultado esperado:** El widget `OrdersTable` muestra menús contextuales al
  click derecho sobre cabeceras de cliente y celdas de producto, sin botones ✕
  visibles.
- **Restricciones:** No se modifican callbacks, BLoC, repositorio, ni capa de
  datos. No se añaden dependencias. Se respetan los patrones existentes de menú
  contextual y diálogos de confirmación.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear dos métodos privados en `_OrdersTableState`:

1. **`_showClientContextMenu(Offset globalPosition, int col)`** — Muestra un
   `showMenu` con 5 entradas:
   - `PopupMenuItem` disabled: «Generar hoja de pedido» (con icono
     `Icons.receipt_long_outlined`)
   - `PopupMenuItem` disabled: «Generar factura provisional» (con icono
     `Icons.description_outlined`)
   - `PopupMenuDivider`
   - `PopupMenuItem` «Restablecer pedido» (con icono `Icons.restart_alt`, color
     error)
   - `PopupMenuItem` «Eliminar cliente» (con icono `Icons.delete_outline`, color
     error)

2. **`_showProductContextMenu(Offset globalPosition, int productIdx)`** —
   Muestra un `showMenu` con 1 entrada:
   - `PopupMenuItem` «Eliminar producto» (con icono `Icons.delete_outline`,
     color error)

Modificar los widgets existentes:

3. En `_buildHeaderCell` (sección `isClient`): Envolver el widget completo del
   cliente en un `GestureDetector` con `onSecondaryTapDown` para capturar
   posición. Eliminar el bloque del `GestureDetector` + `Icons.cancel` +
   `Divider` asociado.

4. En `_buildProductCell`: Envolver el `Container` en un `GestureDetector` con
   `onSecondaryTapDown`. Eliminar el `IconButton` con `Icons.cancel`.

5. Para la confirmación de reset: Crear
   `_showResetConfirmation(List<int> clientIndices, int count)` que usa las
   strings i18n existentes (`ordersTodayResetConfirmTitle`,
   `ordersTodayResetConfirmMessage`, `ordersTodayResetConfirm`) y delega en
   `widget.onResetOrders`.

### Componentes / módulos / servicios afectados

| Componente                    | Capa                  | Cambio                                 |
| ----------------------------- | --------------------- | -------------------------------------- |
| `_OrdersTableState`           | Presentation / Widget | Añadir 3 métodos, modificar 2 builders |
| `app_es.arb`                  | i18n                  | 4 nuevas claves                        |
| `AppLocalizations` (generado) | i18n                  | Regenerado automáticamente             |

### Contratos e interfaces

No se modifican. Los callbacks públicos de `OrdersTable` (`onDeleteClients`,
`onDeleteProducts`, `onResetOrders`) se mantienen idénticos.

### Flujo de datos o de control

```
Click derecho en cabecera cliente
  → GestureDetector.onSecondaryTapDown captura Offset
  → _showClientContextMenu(offset, col)
    → showMenu<String>() muestra PopupMenuItems
    → Usuario selecciona opción
      → 'reset_order'  → _showResetConfirmation([col], 1)
                          → confirmado → widget.onResetOrders!([col])
      → 'delete_client' → _showDeleteConfirmation([col], 1, isProducts: false)
                          → confirmado → widget.onDeleteClients!([col])
      → null (disabled/cerrado) → no-op

Click derecho en celda producto
  → GestureDetector.onSecondaryTapDown captura Offset
  → _showProductContextMenu(offset, productIdx)
    → showMenu<String>() muestra PopupMenuItem
    → Usuario selecciona 'delete_product'
      → _showDeleteConfirmation([productIdx], 1, isProducts: true)
        → confirmado → widget.onDeleteProducts!([productIdx])
```

### Gestión de errores y validaciones

- No se necesita validación adicional. Los callbacks ya gestionan errores en
  capas superiores.
- Se verifica `widget.onDeleteClients != null`,
  `widget.onDeleteProducts != null` y `widget.onResetOrders != null` antes de
  incluir las opciones correspondientes en el menú (consistente con la
  verificación actual de los botones ✕).
- Si todos los callbacks relevantes son `null`, no se registra el listener
  `onSecondaryTapDown` (no hay menú que mostrar).

### Consideraciones de compatibilidad o migración

- Ninguna. Cambio puramente visual/interactivo en un widget de presentación.
- El comportamiento funcional (eliminación, reset) es idéntico al anterior.

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno.

### Artefactos a modificar

| Artefacto                                                          | Cambio esperado                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/presentation/widgets/orders_table.dart` | Eliminar botones ✕ de `_buildHeaderCell` y `_buildProductCell`. Añadir `GestureDetector.onSecondaryTapDown` en ambos. Añadir métodos `_showClientContextMenu`, `_showProductContextMenu` y `_showResetConfirmation`.                                                                                             |
| `lib/app/localization/l10n/app_es.arb`                             | Añadir 4 claves: `ordersTodayContextMenuGenerateOrderSheet`, `ordersTodayContextMenuGenerateProvisionalInvoice`, `ordersTodayContextMenuResetOrder`, `ordersTodayContextMenuDeleteClient`. La clave para «Eliminar producto» puede reutilizar strings existentes o añadir `ordersTodayContextMenuDeleteProduct`. |
| `lib/app/localization/l10n/app_localizations*.dart` (generados)    | Regenerados automáticamente con `flutter gen-l10n`.                                                                                                                                                                                                                                                              |

### Artefactos a retirar o reemplazar

Ninguno (se modifican in-place).

## 6) Estrategia de implementación

### Pasos ordenados

1. **Paso 1 — Añadir claves i18n:** Agregar las nuevas claves al archivo
   `app_es.arb` y regenerar con `flutter gen-l10n`.

2. **Paso 2 — Crear `_showResetConfirmation`:** Método en `_OrdersTableState`
   que muestra el diálogo de confirmación para reset, usando las strings
   existentes `ordersTodayResetConfirmTitle` / `ordersTodayResetConfirmMessage`
   / `ordersTodayResetConfirm`, y que al confirmar invoca
   `widget.onResetOrders!`.

3. **Paso 3 — Crear `_showClientContextMenu`:** Método que recibe `Offset` y
   `int col`, construye las 5 entradas del menú (2 disabled + divider + 2
   activas) y despacha según la selección.

4. **Paso 4 — Crear `_showProductContextMenu`:** Método que recibe `Offset` y
   `int productIdx`, construye 1 entrada de menú y despacha a
   `_showDeleteConfirmation`.

5. **Paso 5 — Modificar `_buildHeaderCell` (sección `isClient`):** Envolver el
   `SizedBox` retornado en un `GestureDetector` con `onSecondaryTapDown`.
   Eliminar el bloque condicional `if (widget.onDeleteClients != null) ...[...]`
   que contiene el `GestureDetector` con `Icons.cancel` y su `Divider` superior.

6. **Paso 6 — Modificar `_buildProductCell`:** Envolver el `Container` en un
   `GestureDetector` con `onSecondaryTapDown`. Eliminar el bloque condicional
   `if (widget.onDeleteProducts != null)` que contiene el `IconButton` con
   `Icons.cancel`.

### Orden recomendado

- Paso 1 primero (las claves i18n son dependencia de los pasos 3 y 4).
- Pasos 2, 3, 4 son independientes entre sí.
- Pasos 5 y 6 dependen de pasos 3 y 4 respectivamente.

### Dependencias entre pasos

- Pasos 3-4 requieren paso 1 (claves i18n).
- Pasos 5-6 requieren pasos 3-4 (métodos de menú).
- Paso 5 requiere paso 2 si se quiere que «Restablecer pedido» funcione.

### Puntos delicados

- **Posicionamiento del `GestureDetector` en la cabecera de cliente:** La
  cabecera es una estructura `Column` compleja con número de orden, nombre
  rotado, etc. El `GestureDetector` con `onSecondaryTapDown` debe envolver todo
  el `SizedBox` principal (no solo una parte) para que el click derecho funcione
  en cualquier zona de la cabecera.
- **Índices en `_buildProductCell`:** El `productIdx` se obtiene de
  `_filteredIndices[rowIdx]`. Este es el índice real del producto en
  `orderSheet.products`, no el índice visual. El menú contextual debe pasar
  `productIdx` (no `rowIdx`) al callback, consistente con el comportamiento
  actual del botón ✕.
- **`enabled: false` en `PopupMenuItem`:** Las opciones placeholder deben usar
  `enabled: false` para que Flutter las renderice grayed out y no sean
  seleccionables.

## 7) Estrategia de validación

### Verificación automática

- `flutter gen-l10n` sin errores.
- `flutter analyze` sin warnings/errors.
- Tests existentes de `orders_table` siguen pasando.

### Validación manual

- Click derecho sobre cabecera de cliente → aparece menú con 5 elementos.
- Las 2 primeras opciones están visualmente deshabilitadas y no son
  interactivas.
- «Restablecer pedido» muestra diálogo y al confirmar resetea cantidades.
- «Eliminar cliente» muestra diálogo y al confirmar elimina la columna.
- Click derecho sobre nombre de producto → aparece menú con 1 opción.
- «Eliminar producto» muestra diálogo y al confirmar elimina la fila.
- No hay botones ✕ visibles en cabeceras ni filas.
- Click izquierdo sobre cabecera/producto no abre menú contextual.
- El menú se cierra al pulsar Escape o click fuera.

### Escenarios a cubrir

- Cliente con pedidos existentes → reset pone a cero.
- Producto filtrado por búsqueda → menú contextual usa el índice correcto.
- Cancelar en diálogo de confirmación → no ocurre nada.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Bajo:** El callback `onResetOrders` en `OrdersTodayPage` tiene
  `// TODO: implement reset orders`. La opción «Restablecer pedido» del menú
  invocará el callback pero no producirá efecto hasta que se implemente.

### Impacto potencial

- Cambio UX: el usuario necesita conocer la interacción de click derecho. Sin
  indicadores visuales que sugieran la disponibilidad del menú.

### Mitigación

- El riesgo del callback `onResetOrders` no implementado es aceptable: la opción
  está en el menú pero el efecto es no-op. Se puede documentar como pendiente.
- Para discoverability, se puede considerar un tooltip o indicador visual en
  futuras iteraciones (fuera de alcance).

### Plan de rollback

- Revertir los cambios en `orders_table.dart` y `app_es.arb`. Regenerar i18n.
  Los botones ✕ vuelven a aparecer.

## 9) Suposiciones

- El patrón de `showMenu` + `PopupMenuItem` existente es el correcto para estos
  menús contextuales (consistencia con `_showCellContextMenu`).
- `enabled: false` en `PopupMenuItem` produce el efecto visual grayed out
  esperado.
- Los strings i18n existentes para confirmación de eliminación y reset son los
  correctos para reutilizar en los diálogos del menú contextual.
- La implementación real del callback `onResetOrders` se realizará en una tarea
  separada.

## 10) Preguntas abiertas

- Ninguna.

## 11) Notas para implementación

- Reutilizar exactamente el patrón de `_showCellContextMenu` para
  posicionamiento y estructura del menú.
- Los `PopupMenuItem` disabled deben usar `enabled: false`, NO un callback
  vacío.
- Mantener la convención de `value` como strings tipo `'reset_order'`,
  `'delete_client'`, `'delete_product'` para el switch de despacho.
- El bloque de botones ✕ a eliminar en `_buildHeaderCell` incluye el `Divider`
  superior y el `GestureDetector` — todo el bloque
  `if (widget.onDeleteClients != null) ...[...]`.
- En `_buildProductCell`, el bloque a eliminar es el
  `if (widget.onDeleteProducts != null)` completo con su `SizedBox` +
  `IconButton`.
- Al envolver la cabecera del cliente en `GestureDetector`, no interferir con
  otros gestos existentes (no hay otros `onSecondaryTap` en esa zona).
- **Estado: Listo para implementación**
