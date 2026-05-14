# Implementation Report: Productos – Vista Mobile con Cards

- **Fecha:** 2026-05-12
- **Identificador:** products-mobile-cards
- **Plan técnico:** docs/technical-analysis/2026-05-12-products-mobile-cards.md
- **Estado:** Completed

## 1) Resumen

Se implementó el layout mobile responsive para la pantalla de Productos,
replicando el patrón ya probado en `ClientsPage` y `ShippingMethodsPage`. En
pantallas ≤ 768 px se muestra una lista de cards con acciones inline (Vincular,
Desvincular, Editar, Eliminar), un search bar con fondo primary y un FAB para
añadir productos. El layout desktop (tabla) permanece sin cambios.

## 2) Alcance ejecutado

- Detección responsive por breakpoint `AppSideMenu.mobileBreakpoint` (768 px)
- Layout mobile con `_buildMobileLayout`, `_buildMobileSearchBar`,
  `_buildCardList`
- Layout desktop extraído a `_buildDesktopLayout` (sin cambios funcionales)
- `_buildContent` compartido con parámetro `isMobile`
- `_buildSearchField` compartido con parámetro `onPrimary`
- Widget `ProductCard` con acciones inline
- Widget `ProductEditDialog` con campo nombre y switch activo/inactivo
- Método `_showFeedback` para feedback adaptativo (SnackBar en mobile,
  FeedbackCubit en desktop)
- Todas las operaciones existentes refactorizadas para usar `_showFeedback`

## 3) Artefactos tocados

### Creados

- `lib/features/products/presentation/widgets/product_card.dart`
- `lib/features/products/presentation/widgets/product_edit_dialog.dart`

### Modificados

- `lib/features/products/presentation/pages/products_page.dart`

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- `flutter analyze lib/features/products/presentation/` → **No issues found**
- Verificación de que no queda ninguna llamada directa a `_feedbackCubit.show()`
  fuera de `_showFeedback` → Confirmado
- Verificación de imports correctos de los nuevos widgets → Confirmado

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** No se creó una clave i18n nueva para "Sin vincular". En su
  lugar se reutiliza `productsSelectFdProduct` ("Vincular producto") como texto
  para el estado no vinculado en el card, con estilo atenuado e itálica.
- **Justificación:** Evita crear una nueva clave i18n innecesaria, reutilizando
  la existente que transmite la misma información.
- **Impacto:** Ninguno funcional.

## 6) Riesgos, incidencias y pendientes

- **Pendiente:** Tests de widget para `ProductCard` y `ProductEditDialog`
  (recomendable pero fuera de alcance del plan).
- **Pendiente:** Validación manual en dispositivo/emulador para verificar UX
  táctil.
- No se detectaron incidencias durante la implementación.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en dispositivo móvil / ventana
  estrecha
