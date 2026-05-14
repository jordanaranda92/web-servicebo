# Implementation Report: Categorías de clientes — Vista mobile con cards

- **Fecha:** 2026-05-12
- **Identificador:** client-categories-mobile-cards
- **Fuente:**
  docs/technical-analysis/2026-05-12-client-categories-mobile-cards.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado el layout responsive dual (mobile/desktop) para la pantalla
de Categorías de clientes, siguiendo fielmente el patrón de `ClientsPage`. En
mobile (ancho ≤ 768px), la tabla se reemplaza por una lista de cards con un
searchbar sobre fondo primario y un FAB para crear categorías. El layout desktop
permanece inalterado.

## 2) Alcance ejecutado

- Creado widget `ClientCategoryCard` para la vista mobile.
- Refactorizado `build()` de `ClientCategoriesPage` para bifurcar en
  `_buildDesktopLayout()` y `_buildMobileLayout()`.
- Extraído `_buildSearchField()` compartido con soporte `onPrimary` para
  mobile/desktop.
- Implementado `_buildMobileSearchBar()` con fondo primario.
- Implementado `_buildContent()` compartido con despacho a `_buildCardList()`
  (mobile) o `_buildTable()` (desktop).
- Implementado `_showFeedback()` que usa `SnackBar` en mobile y `FeedbackCubit`
  en desktop.
- Actualizado `_runWithProgress()` y `_showAssociateClientsDialog()` para usar
  `_showFeedback()`.

## 3) Artefactos tocados

### Creados

- `lib/features/client_categories/presentation/widgets/client_category_card.dart`

### Modificados

- `lib/features/client_categories/presentation/pages/client_categories_page.dart`

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- `dart analyze lib/features/client_categories/presentation/` → **No issues
  found**
- `dart analyze lib/` → **No issues found**
- Sin regresiones detectadas en análisis estático del proyecto completo.
- Verificación manual pendiente: confirmar visualmente el layout mobile y
  desktop en la app.

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** El card usa un círculo de color simple (`Container` con
  `BoxDecoration` circular) en lugar de `CategoryBadge` o `_NoColorPainter` para
  el indicador de color. Cuando la categoría no tiene color, simplemente no se
  muestra el indicador (el nombre ocupa todo el ancho).
  - **Justificación:** Más limpio y evita la dependencia de `_NoColorPainter`
    (clase privada de la página) en el widget externo. El nombre de la categoría
    ya es suficiente información sin el indicador "sin color".
  - **Impacto:** Ninguno funcional. El card muestra el color cuando existe y el
    nombre siempre.

## 6) Riesgos, incidencias y pendientes

- **Pendiente:** Verificación visual manual en dispositivo/emulador mobile para
  confirmar que el layout no presenta overflow y que las acciones funcionan
  correctamente.
- **Pendiente:** Verificación visual manual del layout desktop para confirmar
  que no hay regresión visual.
- **Riesgo bajo:** Los diálogos existentes (`AlertDialog`) podrían no verse
  óptimos en pantallas muy pequeñas (<360px), pero este escenario ya existía y
  está fuera del alcance.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual visual en mobile y desktop
