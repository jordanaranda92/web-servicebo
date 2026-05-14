# Implementation Report: Migración sincronización RTDB → Firestore listeners

- **Fecha:** 2026-05-09
- **Identificador:** orders-realtime-firestore-listeners
- **Plan técnico:**
  docs/technical-analysis/2026-05-09-orders-realtime-firestore-listeners.md
- **Estado:** Completed with warnings

## 1) Resumen

Se ha migrado completamente la sincronización en tiempo real de `orders_today`
desde RTDB `today/cells/` a listeners nativos de Firestore. El BLoC ahora recibe
`OrderSheet` completos vía un stream combinado (`combineLatest2`) del documento
raíz y la subcolección `rows/`, eliminando la necesidad de broadcast de celdas
individuales por RTDB.

## 2) Alcance ejecutado

- ✅ Todos los 12 pasos del plan técnico se han implementado
- ✅ rxdart añadido como dependencia
- ✅ Listeners Firestore en datasource (`watchOrderDocument`, `watchOrderRows`)
- ✅ Stream combinado en repositorio (`watchTodayOrders`) con debounce 200ms y
  caché de nombres
- ✅ Nuevo evento `OrdersTodayRemoteOrderUpdated` + handler con deduplicación
- ✅ BLoC reescrito: eliminada dependencia de RTDB, añadida suscripción
  Firestore
- ✅ Page simplificada: eliminado polling/timer y lógica RTDB
- ✅ DI module actualizado: BLoC recibe `repository` en lugar de
  `rtdbDataSource`/`userId`
- ✅ RTDB datasource limpiado: eliminados `writeCell`, `onCellChanged`,
  `getAllCells`, `_cellsRef`
- ✅ DTO `cell_delta.dart` eliminado
- ✅ `OrdersTable.didUpdateWidget` limpia selecciones/edición ante cambios
  estructurales

## 3) Artefactos tocados

### Creados

- `docs/implementation-reports/2026-05-09-orders-realtime-firestore-listeners.md`

### Modificados

- `pubspec.yaml` — añadido `rxdart: ^0.28.0`
- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source.dart`
  — 2 métodos watch
- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart`
  — implementación watch
- `lib/features/orders_today/domain/repositories/orders_today_repository.dart` —
  `watchTodayOrders`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  — implementación stream combinado
- `lib/features/orders_today/presentation/bloc/orders_today_event.dart` — nuevo
  evento, eliminados obsoletos
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart` —
  reescritura completa de sync
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  eliminado polling/RTDB init
- `lib/app/di/modules/orders_today_module.dart` — BLoC recibe `repository`
- `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source.dart`
  — eliminados métodos cells
- `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source_impl.dart`
  — eliminados métodos cells
- `lib/features/orders_today/presentation/widgets/orders_table.dart` —
  `didUpdateWidget` limpia selecciones

### Retirados o reemplazados

- `lib/features/orders_today/data/dto/cell_delta.dart` — eliminado

## 4) Validación ejecutada

| Validación          | Resultado          |
| ------------------- | ------------------ |
| `dart analyze lib/` | ✅ No issues found |
| `flutter test`      | ⚠️ 49 pass, 2 fail |

Los 2 tests que fallan son **preexistentes** y no relacionados con esta
migración:

- `side_menu_cubit_test.dart` — error de compilación por cambio de constructor
  de `SideMenuCubit`
- `settings_repository_impl_test.dart` — error de carga del isolate

Ningún test de `orders_today` falla.

## 5) Desviaciones respecto al análisis técnico

- **`cell_key_utils.dart` no eliminado**: El plan técnico indicaba eliminarlo,
  pero `OrdersTable` aún lo usa para generar claves de lock (presencia RTDB). Se
  mantiene porque sigue siendo necesario para la funcionalidad de locks.
- **Impacto:** Ninguno. El archivo solo contiene utilidades de generación de
  claves para locks, que siguen activos.

## 6) Riesgos, incidencias y pendientes

- **Tests del BLoC**: No existen tests unitarios del `OrdersTodayBloc` que
  validen el nuevo flujo de suscripción Firestore. Se recomienda crearlos.
- **Tests preexistentes rotos**: 2 tests fallan por causas ajenas a esta
  migración.
- **Validación manual**: Se recomienda probar en dispositivo/emulador la edición
  colaborativa en tiempo real para confirmar que los cambios de un usuario se
  reflejan en otro sin polling.

## 7) Resultado final

- Estado final: ⚠️ Completado con warnings
- Siguiente paso recomendado: validación manual de edición colaborativa +
  creación de tests unitarios para el nuevo flujo de suscripción en el BLoC
