# Implementation Report: Clientes — Vista mobile con cards

- **Fecha:** 2026-05-12
- **Identificador:** clients-mobile-cards
- **Plan técnico:** docs/technical-analysis/2026-05-12-clients-mobile-cards.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la vista responsive de la pantalla de clientes: en mobile
(≤768px) se muestran cards en lugar de tabla, se elimina el título duplicado, se
añade un subheader fijo con searchbox y un FAB para "Añadir desde
FacturaDirecta". La vista desktop permanece intacta.

## 2) Alcance ejecutado

- Todas las partes del plan se han implementado:
  - Nuevo widget `ClientCard`.
  - Bifurcación mobile/desktop en `ClientsPage.build()`.
  - Subheader mobile con searchbox expandido.
  - Lista de cards con `ListView.builder` y padding bottom para el FAB.
  - FAB posicionado con `Stack` + `Positioned` (evitando Scaffold anidado).
  - Feedback mobile con `ScaffoldMessenger.showSnackBar`.
  - Extracción de `_buildSearchField` como widget compartido entre ambos
    layouts.

## 3) Artefactos tocados

### Creados

- `lib/features/clients/presentation/widgets/client_card.dart`

### Modificados

- `lib/features/clients/presentation/pages/clients_page.dart`

### Retirados o reemplazados

- Ninguno.

## 4) Validación ejecutada

| Validación                                    | Resultado                        |
| --------------------------------------------- | -------------------------------- |
| `dart analyze` (archivos modificados)         | ✅ No issues found               |
| `flutter test` (todos los tests del proyecto) | ✅ 28/28 tests passed            |
| Errores de compilación (IDE)                  | ✅ Sin errores en ambos archivos |

## 5) Desviaciones respecto al análisis técnico

- **Extracción de `_buildSearchField`:** Se ha extraído el `TextField` de
  búsqueda a un método compartido `_buildSearchField()` para evitar duplicar la
  decoración entre desktop y mobile. En desktop se envuelve con
  `SizedBox(width: AppDimensions.searchBoxWidth)`, en mobile se expande a todo
  el ancho.
  - **Justificación:** Reduce duplicación de código sin cambiar comportamiento.
  - **Impacto:** Ninguno, mismo output visual.

- **Extracción de `_buildContent`:** Se ha creado un método `_buildContent()`
  parametrizado con `isMobile` que centraliza la lógica de estados
  (loading/error/empty/loaded) y elige entre `_buildCardList` y `_buildTable`.
  - **Justificación:** Evita duplicar el `BlocBuilder` con la misma lógica de
    estados en ambos layouts.
  - **Impacto:** Ninguno, misma lógica.

## 6) Riesgos, incidencias y pendientes

- **Riesgo mitigado:** Padding bottom de 80px en la lista de cards para evitar
  que el FAB oculte la última card.
- **Pendiente:** No existen tests de widget para la feature clients. Se
  recomienda crear tests para `ClientCard` y para `ClientsPage` verificando el
  renderizado condicional por breakpoint.
- **Sin incidencias durante la implementación.**

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: verificación manual en emulador móvil y web
  (redimensionando ventana).
