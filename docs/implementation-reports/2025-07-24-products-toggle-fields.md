# Implementation Report: Toggle Activo / Mostrar en pedidos en Productos

- **Fecha:** 2025-07-24
- **Identificador:** products-toggle-fields
- **Fuente:** docs/technical-analysis/2025-07-23-products-google-sheet.md
  (extensión funcional)
- **Estado:** Completed

## 1) Resumen

Se han implementado toggles (Switch) en las columnas "Activo" y "Mostrar en
pedidos" de la tabla de Productos, permitiendo modificar dichos valores
directamente desde la UI y persistirlos en el Google Sheet de configuración. Se
sigue el mismo patrón que la tabla de Categorías de clientes.

## 2) Alcance ejecutado

- Contrato del repositorio extendido con `toggleProductField`
- Implementación del repositorio con lógica de búsqueda de fila/columna y
  escritura en Sheet
- Use case `ToggleProductField`
- Cubit actualizado con métodos `toggleActive` y `toggleShowInNewOrders`
- Estado `ProductsLoaded` extendido con `isSaving`
- UI: columnas Activo y Mostrar en pedidos reemplazadas de Text a Switch (scale
  0.7, colores green/error)
- Diálogo de progreso (`_runWithProgress`) con SnackBar de resultado
- Claves i18n añadidas: `productsProgressSaving`, `productsSuccessToggled`,
  `productsErrorOperation`
- Registro DI de `ToggleProductField` y actualización de `ProductsCubit`

## 3) Artefactos tocados

### Creados

- `lib/features/products/domain/usecases/toggle_product_field.dart`

### Modificados

- `lib/features/products/domain/repositories/products_repository.dart`
- `lib/features/products/data/repositories/products_repository_impl.dart`
- `lib/features/products/presentation/bloc/products_cubit.dart`
- `lib/features/products/presentation/bloc/products_state.dart`
- `lib/features/products/presentation/pages/products_page.dart`
- `lib/app/di/modules/products_module.dart`
- `lib/app/localization/l10n/app_es.arb`

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- `flutter gen-l10n`: generación de localizaciones correcta
- `flutter analyze lib/features/products/ lib/app/di/modules/products_module.dart`:
  0 errores, 0 infos, 1 warning pre-existente (`_buildColorIndicator` no
  utilizado — no relacionado con este cambio)

## 5) Desviaciones respecto al análisis técnico

- No hay análisis técnico formal independiente para esta extensión; se
  implementó como extensión natural del trabajo previo de migración a Google
  Sheet.
- El patrón de toggle replica fielmente el de `ClientCategoriesRepositoryImpl` y
  `ClientCategoriesPage`.

## 6) Riesgos, incidencias y pendientes

- El warning de `_buildColorIndicator` sin usar se mantiene; puede limpiarse en
  un refactor futuro.
- No se han añadido tests unitarios para `toggleProductField` en esta iteración.
  Se recomienda añadir tests para el cubit y el repositorio.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en la app para confirmar que los
  toggles persisten correctamente en el Google Sheet. Opcionalmente, añadir
  tests unitarios para el flujo de toggle.
