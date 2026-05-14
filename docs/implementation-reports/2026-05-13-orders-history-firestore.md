# Implementation Report: Orders History — Conexión a Firestore

- **Fecha:** 2026-05-13
- **Identificador:** orders-history-firestore
- **Plan técnico:**
  docs/technical-analysis/2026-05-13-orders-history-firestore.md
- **Estado:** Completed

## 1) Resumen

Se ha conectado la feature `orders_history` a Firestore, sustituyendo la capa de
datos stub por una implementación real que reutiliza los datasources existentes
(`OrderFirestoreDataSource`, `ClientFirestoreDataSource`,
`ProductFirestoreDataSource`). La pantalla de historial ahora lista fechas con
conteo de clientes/productos y muestra el detalle en modo lectura.

## 2) Alcance ejecutado

- Creación de entidad `OrderDateInfo` para transportar metadatos de fecha
- Extracción de `buildOrderSheet` a helper compartido entre `orders_today` y
  `orders_history`
- Ampliación del datasource de pedidos con `getAllOrderDocuments()`
- Reescritura del repositorio de historial con implementación Firestore real
- Adaptación de BLoC, estados, widgets y cadenas i18n
- Actualización del módulo DI con dependencias reales
- Tests unitarios completos para repositorio y BLoC

## 3) Artefactos tocados

### Creados

- `lib/features/orders_history/domain/entities/order_date_info.dart`
- `lib/features/orders_today/data/helpers/order_sheet_builder.dart`

### Modificados

- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source.dart`
- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
- `lib/features/orders_history/domain/repositories/orders_history_repository.dart`
- `lib/features/orders_history/domain/usecases/get_available_dates.dart`
- `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart`
- `lib/features/orders_history/presentation/bloc/orders_history_bloc.dart`
- `lib/features/orders_history/presentation/bloc/orders_history_state.dart`
- `lib/features/orders_history/presentation/widgets/history_date_list.dart`
- `lib/features/orders_history/presentation/widgets/history_error_state.dart`
- `lib/app/di/modules/orders_history_module.dart`
- `lib/app/localization/l10n/app_es.arb`
- `test/features/orders_history/data/repositories/orders_history_repository_impl_test.dart`
- `test/features/orders_history/presentation/bloc/orders_history_bloc_test.dart`

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

| Validación                                                | Resultado                                |
| --------------------------------------------------------- | ---------------------------------------- |
| `dart analyze` (archivos modificados)                     | ✅ No issues found                       |
| Tests repositorio (`orders_history_repository_impl_test`) | ✅ 8/8 passed                            |
| Tests BLoC (`orders_history_bloc_test`)                   | ✅ 11/11 passed                          |
| Tests `orders_today`                                      | N/A — no existen tests para esta feature |

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** Se eliminaron los tipos de error `fileSystemError` e
  `invalidFormat` del enum `OrdersHistoryErrorType` y se sustituyeron por
  `serverError`, ya que la capa de datos ahora usa Firestore exclusivamente.
  - **Justificación:** Coherencia con la nueva fuente de datos.
  - **Impacto:** Ninguno — los valores anteriores correspondían a la
    implementación stub.

- **Desviación 2:** El método privado `_sortIdsByOrder` se mantuvo también en
  `OrdersTodayRepositoryImpl` (además de existir en el helper compartido) porque
  se usa en `removeProducts`.
  - **Justificación:** Minimizar cambios en `orders_today` fuera de alcance.
  - **Impacto:** Duplicación menor; puede unificarse en un refactor posterior.

## 6) Riesgos, incidencias y pendientes

- **Riesgo:** No existen tests para `orders_today`. El refactor de
  `_buildOrderSheet` a helper compartido no tiene cobertura de regresión
  automatizada.
- **Pendiente:** Validación manual en dispositivo/emulador para confirmar que la
  UI muestra correctamente el listado y el detalle.
- **Pendiente:** Considerar añadir tests para `orders_today` feature.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en dispositivo
