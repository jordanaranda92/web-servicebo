# Implementation Report: Menú contextual para clientes y productos

- **Fecha:** 2026-05-10
- **Identificador:** context-menu-client-product
- **Plan técnico:**
  docs/technical-analysis/2026-05-10-context-menu-client-product.md
- **Estado:** Completed

## 1) Resumen

Se han reemplazado los botones de eliminación (✕) de clientes y productos en la
tabla de pedidos por menús contextuales invocados con click derecho. La
implementación sigue fielmente el plan técnico, reutilizando el patrón existente
de `showMenu` + `PopupMenuItem` y los callbacks ya conectados.

## 2) Alcance ejecutado

- ✅ Nuevas claves i18n añadidas al ARB y regeneradas
- ✅ Método `_showResetConfirmation` creado
- ✅ Método `_showClientContextMenu` creado con 5 entradas (2 disabled +
  divider + 2 activas)
- ✅ Método `_showProductContextMenu` creado con 1 entrada
- ✅ Botón ✕ eliminado de cabeceras de clientes en `_buildHeaderCell`
- ✅ Botón ✕ eliminado de filas de productos en `_buildProductCell`
- ✅ `GestureDetector.onSecondaryTapDown` añadido en ambos builders

## 3) Artefactos tocados

### Creados

Ninguno.

### Modificados

- `lib/app/localization/l10n/app_es.arb` — 5 nuevas claves:
  `ordersTodayContextMenuGenerateOrderSheet`,
  `ordersTodayContextMenuGenerateProvisionalInvoice`,
  `ordersTodayContextMenuResetOrder`, `ordersTodayContextMenuDeleteClient`,
  `ordersTodayContextMenuDeleteProduct`
- `lib/app/localization/l10n/app_localizations.dart` — regenerado
  automáticamente
- `lib/app/localization/l10n/app_localizations_es.dart` — regenerado
  automáticamente
- `lib/features/orders_today/presentation/widgets/orders_table.dart` —
  eliminados botones ✕, añadidos 3 métodos nuevos (`_showResetConfirmation`,
  `_showClientContextMenu`, `_showProductContextMenu`), envueltos builders en
  `GestureDetector`

### Retirados o reemplazados

- Botón `Icons.cancel` + `GestureDetector` en cabecera de cliente → reemplazado
  por `GestureDetector.onSecondaryTapDown` envolviendo todo el `SizedBox`
- `IconButton` con `Icons.cancel` en `_buildProductCell` → reemplazado por
  `GestureDetector.onSecondaryTapDown` envolviendo el `Container`

## 4) Validación ejecutada

- `dart analyze orders_table.dart` → **No issues found**
- `flutter gen-l10n` → sin errores
- `flutter test` → **58 tests passed**, todos verdes
- No hay errores de compilación

## 5) Desviaciones respecto al análisis técnico

- **i18n:** El plan mencionaba 4 claves nuevas; se añadieron 5 (se incluyó
  `ordersTodayContextMenuDeleteProduct` como clave propia en lugar de reutilizar
  una existente). Justificación: mantener consistencia de nomenclatura con el
  resto de claves del menú contextual. Impacto: ninguno.
- **_buildProductCell:** Se simplificó el `Row` con `Expanded` + `IconButton` a
  un `Align` + `Text` directo, ya que al eliminar el `IconButton` el `Row` con
  un solo hijo era innecesario. Impacto: ninguno funcional, simplifica el widget
  tree.

## 6) Riesgos, incidencias y pendientes

- **Pendiente conocido:** El callback `onResetOrders` en `OrdersTodayPage` tiene
  `// TODO: implement reset orders`. La opción «Restablecer pedido» del menú
  invocará el callback pero no producirá efecto hasta que se implemente la
  lógica en el BLoC/repositorio. No es bloqueante para este cambio.
- Sin incidencias durante la implementación.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en la aplicación (click derecho
  sobre clientes y productos), e implementación futura del callback
  `onResetOrders` en `OrdersTodayPage`.
