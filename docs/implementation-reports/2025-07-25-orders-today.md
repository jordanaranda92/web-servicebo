# Implementation Report: Pedidos de hoy — Migración a Google Sheets API

- **Fecha:** 2025-07-25
- **Identificador:** orders-today
- **Fuente:** docs/technical-analysis/2026-05-07-orders-today.md
- **Estado:** Completed with warnings

## 1) Resumen

Se ha implementado la migración completa de la pantalla "Pedidos de hoy" desde
un flujo basado en descarga/parseo/subida de archivos `.xlsx` a una integración
directa con Google Sheets API y Drive API. La pantalla es ahora de solo lectura,
con auto-refresco por polling de `modifiedTime` (~30s).

## 2) Alcance ejecutado

- ✅ DTO para datos crudos de Google Sheets (`OrderSheetData`)
- ✅ Datasource contract y implementación (`OrdersSheetDataSource` /
  `OrdersSheetDataSourceImpl`)
- ✅ Rediseño de entidad `OrderSheet` (transpuesta: productos en filas, clientes
  en columnas)
- ✅ Simplificación del contrato del repositorio (de 9 a 3 métodos)
- ✅ Implementación del nuevo repositorio con lectura de configuración
- ✅ Simplificación del BLoC (eliminados handlers de edición, añadido
  `CheckModified`)
- ✅ Rediseño de presentación (página read-only con polling, tabla transpuesta,
  toolbar simplificado)
- ✅ Actualización del módulo DI
- ✅ Eliminación de 15 artefactos obsoletos
- ✅ Adaptación de código dependiente (`ExcelParserServiceImpl`,
  `DashboardRepositoryImpl`, `HistoryOrdersTable`, `main.dart`)
- ✅ Corrección de tests existentes afectados por el cambio de modelo

## 3) Artefactos tocados

### Creados

- `lib/features/orders_today/data/dto/order_sheet_data.dart`
- `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source.dart`
- `lib/features/orders_today/data/datasources/remote/orders_sheet_data_source_impl.dart`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  (reescrito)

### Modificados

- `lib/features/orders_today/domain/entities/order_sheet.dart`
- `lib/features/orders_today/domain/repositories/orders_today_repository.dart`
- `lib/features/orders_today/domain/usecases/create_today_file.dart`
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`
- `lib/features/orders_today/presentation/bloc/orders_today_event.dart`
- `lib/features/orders_today/presentation/bloc/orders_today_state.dart`
- `lib/features/orders_today/presentation/pages/orders_today_page.dart`
- `lib/features/orders_today/presentation/widgets/orders_table.dart`
- `lib/features/orders_today/presentation/widgets/orders_toolbar.dart`
- `lib/features/orders_today/presentation/widgets/orders_error_state.dart`
- `lib/app/di/modules/orders_today_module.dart`
- `lib/app/localization/l10n/app_es.arb` (añadida clave
  `ordersTodayColumnProduct`)
- `lib/core/services/excel_parser_service_impl.dart` (adaptado al nuevo
  `OrderSheet`)
- `lib/features/home/data/repositories/dashboard_repository_impl.dart`
  (adaptado)
- `lib/features/orders_history/presentation/widgets/history_orders_table.dart`
  (adaptado)
- `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart`
  (adaptado)
- `lib/main.dart` (eliminada referencia a `OrdersViewPage` y `tryRunSubWindow`)
- `lib/main_local.dart` (eliminada llamada a `tryRunSubWindow`)
- `lib/main_pro.dart` (eliminada llamada a `tryRunSubWindow`)
- `test/features/home/data/repositories/dashboard_repository_impl_test.dart`
- `test/features/orders_history/data/repositories/orders_history_repository_impl_test.dart`
- `test/features/orders_history/presentation/bloc/orders_history_bloc_test.dart`

### Retirados o reemplazados

- `lib/features/orders_today/domain/entities/order_row.dart`
- `lib/features/orders_today/domain/entities/version_check_result.dart`
- `lib/features/orders_today/domain/usecases/update_cell_value.dart`
- `lib/features/orders_today/domain/usecases/rename_client.dart`
- `lib/features/orders_today/domain/usecases/add_row.dart`
- `lib/features/orders_today/domain/usecases/delete_rows.dart`
- `lib/features/orders_today/domain/usecases/save_orders.dart`
- `lib/features/orders_today/domain/usecases/save_as_new_excel.dart`
- `lib/features/orders_today/domain/usecases/update_file_structure.dart`
- `lib/features/orders_today/presentation/widgets/version_warning_banner.dart`
- `lib/features/orders_today/presentation/widgets/orders_footer.dart`
- `lib/features/orders_today/presentation/pages/orders_view_page.dart`
- `lib/features/orders_today/data/datasources/local/excel_local_data_source.dart`
- `lib/features/orders_today/data/datasources/local/excel_local_data_source_impl.dart`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl_old.dart`
  (backup temporal, eliminado)

## 4) Validación ejecutada

- `flutter analyze` — 0 errores (compilación limpia)
- `flutter test` — 57 passed, 1 failed
  - El test fallido
    (`SideMenuCubit selectItem does not emit for index out of range`) es
    **preexistente** y no está relacionado con estos cambios
- `flutter gen-l10n` — regeneración exitosa con nueva clave ARB

## 5) Desviaciones respecto al análisis técnico

1. **Adaptación de `ExcelParserServiceImpl`**: El análisis técnico indicaba no
   modificar este servicio core. Sin embargo, al cambiar la estructura de
   `OrderSheet` (eliminando `rows`/`OrderRow`), fue necesario adaptar
   `parseExcelBytes()` y `encodeOrderSheet()` para que generen y consuman el
   nuevo formato transpuesto. Se mantiene compatibilidad funcional completa.

2. **Adaptación de features dependientes**: `dashboard_repository_impl` y
   `history_orders_table` usaban `sheet.rows` del modelo antiguo. Se adaptaron
   al nuevo formato (`sheet.clients`, `sheet.quantities`).

3. **Eliminación de `tryRunSubWindow` y `OrdersViewPage`**: Al eliminar
   `OrdersViewPage` (ventana multi-window para vista de solo lectura), se
   eliminaron también las llamadas a `tryRunSubWindow` en los tres entry points
   (`main.dart`, `main_local.dart`, `main_pro.dart`). La funcionalidad de
   ventana secundaria ya no es necesaria al ser la pantalla principal de solo
   lectura.

4. **CheckModified simplificado**: En lugar de usar `getSheetModifiedTime`
   (método separado del repositorio), el handler `_onCheckModified` del BLoC
   re-lee el sheet completo y compara `modifiedTime`. Esto simplifica la lógica
   y evita un use case adicional, a costa de un request extra de datos cuando
   hay cambios.

## 6) Riesgos, incidencias y pendientes

- **Riesgo**: El repositorio lee clientes/productos de la hoja "configuracion"
  buscando columnas por nombre en lowercase (`nombre`, `activo`,
  `mostrar en nuevos pedidos`, `orden`). Si los nombres de columna cambian en la
  hoja real, la lectura fallará silenciosamente devolviendo listas vacías.
- **Pendiente**: No se han creado tests unitarios nuevos para el datasource,
  repositorio ni BLoC de `orders_today`. Los tests existentes del feature fueron
  eliminados junto con los use cases obsoletos.
- **Pendiente**: El color verde hardcodeado (`Color(0xFF2E7D32)`) en la columna
  QUEDAN debería idealmente venir del tema. Se dejó así para coherencia con el
  formato condicional de Google Sheets.
- **Pendiente**: Validación manual end-to-end con una cuenta Google Drive real.

## 7) Resultado final

- Estado final: ⚠️ Completado con warnings
- Siguiente paso recomendado: validación manual end-to-end con Google Drive +
  creación de tests unitarios para el nuevo datasource y repositorio
