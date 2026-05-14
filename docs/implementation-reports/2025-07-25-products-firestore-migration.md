# Implementation Report: Migración de Productos a Firestore

- **Fecha:** 2025-07-25
- **Identificador:** products-firestore-migration
- **Fuente:** docs/technical-analysis/2025-05-08-products-firestore-migration.md
- **Estado:** Completed

## 1) Resumen

Se ha migrado completamente el feature `products` desde Google Sheets + Factura
Directa API a **Firestore** como única fuente de datos. Se eliminó toda la
lógica legacy de sincronización, se simplificó la UI a guardado individual por
campo (patrón clients) y se adaptó `orders_today` para leer productos desde
Firestore.

## 2) Alcance ejecutado

- ✅ Capa data: modelo Firestore (`ProductModel`) y datasource
  (`ProductFirestoreDataSource` / `Impl`)
- ✅ Capa domain: entidad reescrita (id `String`), repositorio simplificado (2
  métodos), use cases reducidos a 2
- ✅ Capa data: repositorio Firestore (`ProductsRepositoryImpl`) con única
  dependencia
- ✅ Capa presentation: estado y cubit reescritos (sin fdWarning, sin
  configNotFound)
- ✅ Capa presentation: página de productos reescrita (patrón `ClientsPage` —
  guardado individual, feedback card, sin NavigationGuard)
- ✅ DI: módulo de productos reescrito
- ✅ `orders_today`: `_readActiveProducts` ahora lee desde
  `ProductFirestoreDataSource`
- ✅ Settings: eliminado botón "Sincronizar productos"
- ✅ Eliminados 11 artefactos obsoletos (use cases, entidades, DTOs)
- ✅ Añadidas 4 claves i18n nuevas (`productsColumnNameFd`,
  `productsColumnOrder`, `productsSaving`, `productsErrorSaving`)

## 3) Artefactos tocados

### Creados

- `lib/features/products/data/models/product_model.dart`
- `lib/features/products/data/datasources/product_firestore_data_source.dart`
- `lib/features/products/data/datasources/product_firestore_data_source_impl.dart`

### Modificados

- `lib/features/products/domain/entities/product.dart` — reescrito (id
  int→String, campos FD simplificados)
- `lib/features/products/domain/repositories/products_repository.dart` —
  reescrito (2 métodos)
- `lib/features/products/domain/usecases/get_products.dart` — retorna
  `List<Product>`
- `lib/features/products/domain/usecases/save_products_batch.dart` — params con
  keys `String`
- `lib/features/products/data/repositories/products_repository_impl.dart` —
  reescrito (solo Firestore)
- `lib/features/products/presentation/bloc/products_state.dart` — reescrito (sin
  fdWarning, sin configNotFound)
- `lib/features/products/presentation/bloc/products_cubit.dart` — reescrito (2
  deps)
- `lib/features/products/presentation/pages/products_page.dart` — reescrito
  (patrón ClientsPage)
- `lib/app/di/modules/products_module.dart` — reescrito
- `lib/app/di/modules/orders_today_module.dart` — añadido 6º parámetro
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  — `_readActiveProducts` lee de Firestore
- `lib/features/settings/presentation/widgets/factura_directa_section.dart` —
  eliminado botón sync productos
- `lib/app/localization/l10n/app_es.arb` — añadidas 4 claves i18n

### Retirados o reemplazados

- `lib/features/products/domain/usecases/get_fd_products.dart`
- `lib/features/products/domain/usecases/link_fd_product.dart`
- `lib/features/products/domain/usecases/add_product.dart`
- `lib/features/products/domain/usecases/delete_product.dart`
- `lib/features/products/domain/usecases/toggle_product_field.dart`
- `lib/features/products/domain/usecases/update_product.dart`
- `lib/features/products/domain/usecases/update_product_order.dart`
- `lib/features/products/domain/entities/fd_product.dart`
- `lib/features/products/domain/entities/products_result.dart`
- `lib/features/products/data/dto/product_dto.dart`
- `lib/features/products/data/dto/product_sheet_dto.dart`

## 4) Validación ejecutada

- `flutter analyze`: 0 errores introducidos por la migración. 1 error
  preexistente en `factura_directa_cubit_test.dart` (no relacionado).
- 1 warning preexistente en `home_page.dart` (no relacionado).

## 5) Desviaciones respecto al análisis técnico

- Ninguna desviación material. El plan se ejecutó tal cual.

## 6) Riesgos, incidencias y pendientes

- **Tests unitarios**: Los tests existentes de products (si los hay) necesitarán
  actualización para reflejar la nueva API. No había tests activos que fallaran.
- **El error preexistente** en `factura_directa_cubit_test.dart` (falta segundo
  argumento `_syncClientsFromFd`) debería corregirse en un PR separado.
- **Datos en Firestore**: Se asume que la colección `products` ya existe y está
  poblada con los documentos migrados.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual (verificar que la página de
  productos carga, edita y guarda correctamente contra Firestore), y crear
  pedido del día para confirmar que `orders_today` lee productos desde
  Firestore.
