# Implementation Report: Color en categorías de cliente

- **Fecha:** 2026-05-11
- **Identificador:** client-category-color
- **Fuente:** docs/technical-analysis/2026-05-11-client-category-color.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado el campo `color` (String?, hexadecimal) en las categorías de
cliente, propagándolo a través de todas las capas de la arquitectura Clean
Architecture (entidad → data source → repositorio → use cases → cubit → UI). Los
badges de categoría en la tabla de clientes y detalle de cliente ahora muestran
el color de la categoría con cálculo automático de contraste de texto. Los
diálogos de crear y editar categoría incluyen un selector visual de 10 colores
predefinidos y un botón "Quitar color".

## 2) Alcance ejecutado

- Todas las partes del plan técnico se han implementado completamente.
- No hay partes sin completar.

## 3) Artefactos tocados

### Creados

- `lib/core/utils/category_color_utils.dart` — constantes de paleta (10
  colores), función `tryParseHex()` y función `contrastTextColor()`.

### Modificados

- `lib/features/clients/domain/entities/client_category.dart` — añadido campo
  `String? color`.
- `lib/features/client_categories/data/datasources/client_category_firestore_data_source.dart`
  — añadido `String? color` a `add()` y `update()`.
- `lib/features/client_categories/data/datasources/client_category_firestore_data_source_impl.dart`
  — lectura y escritura de `color` en Firestore.
- `lib/features/client_categories/domain/repositories/client_categories_repository.dart`
  — añadido `String? color` a `addCategory()` y `updateCategory()`.
- `lib/features/client_categories/data/repositories/client_categories_repository_impl.dart`
  — propagación de `color` al data source.
- `lib/features/client_categories/domain/usecases/add_client_category.dart` —
  `AddClientCategoryParams` con `String? color`.
- `lib/features/client_categories/domain/usecases/update_client_category.dart` —
  `UpdateClientCategoryParams` con `String? color`.
- `lib/features/client_categories/presentation/bloc/client_categories_cubit.dart`
  — `addCategory()` y `updateCategory()` con `{String? color}`.
- `lib/features/clients/domain/entities/client.dart` — añadido campo
  `String? categoryColor` al constructor, `copyWith` y `props`.
- `lib/features/clients/data/models/client_model.dart` — `toEntity()` con
  parámetro `String? categoryColor`.
- `lib/features/clients/data/repositories/clients_repository_impl.dart` —
  resolución de `categoryColor` mediante mapa `id→color` en `getClients()` y
  `watchClients()`.
- `lib/features/client_categories/presentation/pages/client_categories_page.dart`
  — columna "Color" en tabla, selector de color en diálogos de añadir y editar,
  botón "Quitar color" en edición.
- `lib/features/clients/presentation/pages/clients_page.dart` — badge con color
  dinámico de categoría y contraste automático de texto.
- `lib/features/clients/presentation/pages/client_detail_page.dart` — badge con
  color dinámico de categoría y contraste automático de texto.
- `lib/app/localization/l10n/app_es.arb` — claves `clientCategoriesColumnColor`,
  `clientCategoriesColorLabel`, `clientCategoriesRemoveColor`.

### Retirados o reemplazados

- Ninguno.

## 4) Validación ejecutada

- **Análisis estático (`dart analyze lib/`):** 0 errores, 2 info preexistentes
  (no relacionados con este cambio).
- **Tests (`flutter test`):** 35 tests, todos pasando, 0 fallos.
- **Generación i18n (`flutter gen-l10n`):** Exitosa, getters generados
  correctamente.
- **Sin regresiones detectadas.**

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** En la tabla de categorías, la columna "Color" muestra
  siempre un círculo coloreado (usando `colorScheme.primary` como fallback si no
  hay color asignado), en lugar de un indicador vacío. Se eligió esta opción por
  coherencia visual.
  - **Justificación:** Mejor experiencia visual al no dejar celdas vacías.
  - **Impacto:** Ninguno funcional.

## 6) Riesgos, incidencias y pendientes

- **Riesgos:** Ninguno nuevo detectado durante la implementación.
- **Incidencias:** Se detectó código huérfano tras el reemplazo del diálogo de
  edición (brackets duplicados del cierre original). Corregido inmediatamente
  antes del reporte.
- **TODOs pendientes:** Ninguno.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en dispositivo/emulador para
  verificar la experiencia visual de los selectores de color y badges.
