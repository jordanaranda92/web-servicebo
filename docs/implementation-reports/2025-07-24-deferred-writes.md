# Implementation Report: Escritura diferida de cambios en tabla de pedidos

- **Fecha:** 2025-07-24
- **Identificador:** deferred-writes
- **Fuente:** Petición directa del usuario (sin análisis técnico formal previo)
- **Estado:** Completed

## 1) Resumen

Se ha implementado un modelo de persistencia diferida: las modificaciones en la
tabla de pedidos (editar celdas, renombrar clientes, añadir/eliminar filas) se
mantienen en memoria hasta que el usuario pulse "Guardar excel". Se ha añadido
una guarda de navegación que avisa al usuario cuando intenta abandonar la página
con cambios sin guardar, y una confirmación al sincronizar.

## 2) Alcance ejecutado

- Mutaciones en memoria en el BLoC (cell, rename, add, delete)
- Flag `hasUnsavedChanges` en el estado `OrdersTodayLoaded`
- Nuevo método `writeExcel` en datasource para escribir un `OrderSheet` completo
  a disco
- Nuevo caso de uso `SaveOrders` (datasource → repo → usecase → DI → BLoC)
- Evento `OrdersTodaySaveRequested` para persistir cambios al pulsar "Guardar
  excel"
- Guarda de navegación al cambiar de página con cambios sin guardar
- Confirmación al sincronizar si hay cambios sin guardar
- Claves i18n para los nuevos diálogos

## 3) Artefactos tocados

### Creados

- `lib/features/orders_today/domain/usecases/save_orders.dart`

### Modificados

- `lib/features/orders_today/data/datasources/local/excel_local_data_source.dart`
  — añadido `writeExcel`
- `lib/features/orders_today/data/datasources/local/excel_local_data_source_impl.dart`
  — implementación de `writeExcel`
- `lib/features/orders_today/domain/repositories/orders_today_repository.dart` —
  añadido `saveOrders`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  — implementación de `saveOrders`
- `lib/features/orders_today/presentation/bloc/orders_today_state.dart` —
  `hasUnsavedChanges` en `OrdersTodayLoaded`
- `lib/features/orders_today/presentation/bloc/orders_today_event.dart` —
  añadido `OrdersTodaySaveRequested`
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart` —
  mutaciones in-memory + handler de save
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` — guarda
  de navegación + sync warning + onSave
- `lib/app/di/modules/orders_today_module.dart` — registro de `SaveOrders`,
  eliminación de use cases individuales no usados
- `lib/app/localization/l10n/app_es.arb` — 6 nuevas claves i18n

### Retirados o reemplazados

- Los use cases `UpdateCellValue`, `RenameClient`, `AddRow`, `DeleteRows` ya no
  se inyectan en el BLoC ni se registran en el DI (los archivos siguen
  existiendo pero no se usan)

## 4) Validación ejecutada

- `dart analyze lib/` — 0 errores, 0 warnings (3 info pre-existentes en
  `side_menu.dart`)
- `flutter gen-l10n` — generación correcta de localizaciones

## 5) Desviaciones respecto al análisis técnico

- No existía análisis técnico formal. Se implementó directamente desde la
  petición del usuario.
- Se eliminaron del DI los use cases individuales (`UpdateCellValue`,
  `RenameClient`, `AddRow`, `DeleteRows`) porque el BLoC ya no los necesita. Los
  archivos fuente no se han eliminado por si se necesitan en el futuro.

## 6) Riesgos, incidencias y pendientes

- **Riesgo:** Los archivos de use cases no usados (`update_cell_value.dart`,
  `rename_client.dart`, `add_row.dart`, `delete_rows.dart`) siguen en el
  proyecto. Se pueden eliminar si se confirma que no se reutilizan en otro
  contexto.
- **Pendiente:** Tests unitarios para las mutaciones in-memory del BLoC y el
  nuevo `SaveOrders` use case.
- **Pendiente:** Si hay tests existentes que dependan de los use cases
  eliminados del BLoC, necesitarán actualizarse.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: crear tests unitarios para el nuevo flujo de
  guardado diferido
