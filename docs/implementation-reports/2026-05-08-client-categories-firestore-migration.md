# Implementation Report: Migración de Categorías de Clientes a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** client-categories-firestore-migration
- **Plan técnico:**
  docs/technical-analysis/2026-05-08-client-categories-firestore-migration.md
- **Estado:** Completed with warnings

## 1) Resumen

Se migró el almacenamiento de categorías de clientes de Google Sheets a Cloud
Firestore. Se creó un datasource Firestore, se reescribió el repositorio
eliminando toda dependencia de Sheets, se adaptaron los tipos de ID de `int` a
`String` en toda la cadena (entity → datasource → repository → use cases →
cubits → pages), y se actualizó el DI.

## 2) Alcance ejecutado

- ✅ Registro de `FirebaseFirestore` en DI (`core_module.dart`)
- ✅ Cambio de `ClientCategory.id` de `int` a `String`
- ✅ Creación de `ClientCategoryFirestoreDataSource` (interfaz + implementación)
- ✅ Actualización de contratos domain en `client_categories` (repository + 3
  use cases)
- ✅ Reescritura completa de `ClientCategoriesRepositoryImpl` (ahora solo
  depende de Firestore)
- ✅ Actualización del DI de `client_categories`
- ✅ Adaptación de `ClientCategoriesCubit` y `ClientCategoriesPage`
- ✅ Adaptación de `ClientSheetDto.categoryId` a `String?`
- ✅ Adaptación de `ClientsRepositoryImpl` (carga categorías desde Firestore)
- ✅ Adaptación de contratos y use cases en feature `clients`
- ✅ Adaptación de `ClientsCubit` y `ClientsPage`
- ✅ Actualización del DI de `clients` (5 dependencias)
- ✅ Corrección de `ClientCategorySheetDto` para compilar con `String` id

## 3) Artefactos tocados

### Creados

- `lib/features/client_categories/data/datasources/client_category_firestore_data_source.dart`
- `lib/features/client_categories/data/datasources/client_category_firestore_data_source_impl.dart`

### Modificados

- `pubspec.yaml` — añadido `cloud_firestore: ^5.6.12`
- `lib/app/di/modules/core_module.dart` — registro de
  `FirebaseFirestore.instance`
- `lib/app/di/modules/client_categories_module.dart` — datasource Firestore + 1
  dependencia
- `lib/app/di/modules/clients_module.dart` — 5 dependencias para
  `ClientsRepositoryImpl`
- `lib/features/clients/domain/entities/client_category.dart` — `id: int` →
  `id: String`
- `lib/features/client_categories/domain/repositories/client_categories_repository.dart`
- `lib/features/client_categories/domain/usecases/update_client_category.dart`
- `lib/features/client_categories/domain/usecases/toggle_client_category.dart`
- `lib/features/client_categories/domain/usecases/delete_client_category.dart`
- `lib/features/client_categories/data/repositories/client_categories_repository_impl.dart`
  — reescrito completo
- `lib/features/client_categories/presentation/bloc/client_categories_cubit.dart`
- `lib/features/client_categories/presentation/pages/client_categories_page.dart`
- `lib/features/clients/data/dto/client_sheet_dto.dart` — `categoryId` a
  `String?`
- `lib/features/clients/data/dto/client_category_sheet_dto.dart` — `.toString()`
  para compilar
- `lib/features/clients/data/repositories/clients_repository_impl.dart` — carga
  categorías desde Firestore
- `lib/features/clients/domain/repositories/clients_repository.dart`
- `lib/features/clients/domain/usecases/update_client_category.dart`
- `lib/features/clients/domain/usecases/save_clients_batch.dart`
- `lib/features/clients/presentation/bloc/clients_cubit.dart`
- `lib/features/clients/presentation/pages/clients_page.dart`

### Retirados o reemplazados

- Ninguno eliminado. `ClientCategorySheetDto` queda como código muerto (sin
  imports).

## 4) Validación ejecutada

| Validación          | Resultado              |
| ------------------- | ---------------------- |
| `dart analyze lib/` | ✅ No issues found     |
| `flutter test`      | ⚠️ 57 passed, 1 failed |

- El test fallido
  (`SideMenuCubit selectItem does not emit for index out of range`) es
  **preexistente** y no tiene relación con esta migración.

## 5) Desviaciones respecto al análisis técnico

| Desviación                                                                         | Justificación                                                                              | Impacto                                               |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| `cloud_firestore: ^5.6.12` en lugar de `^6.3.0`                                    | La versión 6.x requiere `firebase_core ^4.7.0`, incompatible con el `^3.13.0` del proyecto | Ninguno funcional; la API de Firestore es equivalente |
| `ClientCategorySheetDto` no eliminado                                              | Se corrigió para que compile en lugar de eliminarlo, evitando acción destructiva           | Queda como código muerto inofensivo                   |
| Import del datasource usa ruta cross-feature (`../../../clients/domain/entities/`) | La entity `ClientCategory` está definida en `clients` feature, no en `client_categories`   | Patrón ya usado en el proyecto                        |

## 6) Riesgos, incidencias y pendientes

- **Pendiente:** Eliminar `client_category_sheet_dto.dart` si se confirma que no
  se necesitará
- **Pendiente:** Crear la colección `client_categories` en Firestore con datos
  iniciales (migración de datos desde Google Sheets)
- **Pendiente:** Actualizar tests unitarios existentes de `client_categories` y
  `clients` para reflejar los nuevos tipos y datasource
- **Riesgo:** La versión de `cloud_firestore` podría necesitar actualización
  cuando se suba `firebase_core`
- **Nota:** El test fallido de `SideMenuCubit` debería investigarse por separado

## 7) Resultado final

- Estado final: ⚠️ Completado con warnings
- Siguiente paso recomendado: migración de datos de Sheets a Firestore +
  actualización de tests unitarios
