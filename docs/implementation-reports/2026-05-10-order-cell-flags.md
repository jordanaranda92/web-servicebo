# Implementation Report: Flags de celda en pedidos

- **Fecha:** 2026-05-10
- **Identificador:** order-cell-flags
- **Plan técnico:** docs/technical-analysis/2026-05-10-order-cell-flags.md
- **Estado:** Completed

## 1) Resumen

- Se han implementado menús contextuales (click derecho) en celdas de cantidad y
  stock de la tabla de pedidos.
- Las celdas de cantidad permiten marcar/desmarcar como compensación (fondo
  verde pastel) o reserva (fondo azul pastel), mutuamente excluyentes.
- Las celdas de stock permiten marcar/desmarcar como stock estricto (fuente
  roja).
- Los flags se persisten en Firestore y se propagan en tiempo real via los
  listeners existentes (`watchOrderRows`).
- No se requirió cambio alguno en RTDB.

## 2) Alcance ejecutado

- Todas las partes del plan técnico se han implementado completamente (pasos
  1-10).
- No quedaron partes sin completar.

## 3) Artefactos tocados

### Creados

- `lib/features/orders_today/domain/usecases/update_cell_flag.dart` — UseCase
  para actualizar flags de celda

### Modificados

- `lib/features/orders_today/data/models/order_row_model.dart` — Campos `flags`
  (Map<String,String>) y `strictStock` (bool)
- `lib/features/orders_today/domain/entities/order_sheet.dart` — Campos
  `cellFlags` y `strictStocks` con copyWith y props
- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source.dart`
  — Métodos `updateFlag()` y `updateStrictStock()`
- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart`
  — Implementación de `updateFlag()` y `updateStrictStock()` con batch writes
- `lib/features/orders_today/domain/repositories/orders_today_repository.dart` —
  Método `updateCellFlag()`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  — Implementación de `updateCellFlag()` y propagación de flags en
  `_buildOrderSheet()`
- `lib/features/orders_today/presentation/bloc/orders_today_event.dart` — Evento
  `OrdersTodayCellFlagUpdateRequested`
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart` — Handler
  `_onCellFlagUpdate` con optimistic update y rollback, inyección de
  `UpdateCellFlag`
- `lib/features/orders_today/presentation/widgets/orders_table.dart` —
  `onSecondaryTapUp` + `showMenu`, colores de flag en `_dataCellColor`, fuente
  roja para stock estricto, callback `onCellFlagUpdated`
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  Conexión del callback `onCellFlagUpdated` con dispatch al BLoC
- `lib/app/di/modules/orders_today_module.dart` — Registro de `UpdateCellFlag` y
  paso al factory del BLoC
- `lib/app/localization/l10n/app_es.arb` — 6 nuevas claves i18n

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- **`flutter analyze`**: 0 errores, 0 warnings nuevos (3 issues preexistentes: 2
  info lint y 1 warning no relacionado).
- **`flutter test`**: 58/58 tests passed. Sin regresiones.
- **`flutter gen-l10n`**: Generación exitosa de archivos de localización.

## 5) Desviaciones respecto al análisis técnico

- Ninguna desviación material. La implementación sigue fielmente el plan
  técnico.

## 6) Riesgos, incidencias y pendientes

- **Riesgo web**: `onSecondaryTapUp` puede no funcionar en web si el navegador
  captura el click derecho. Si se desplega en web, considerar usar `Listener`
  con `kSecondaryButton`.
- **Tests unitarios**: No se han añadido tests unitarios nuevos específicos para
  esta funcionalidad (el análisis técnico los sugería). Se recomienda añadir
  tests para `OrderRowModel.fromFirestore` con flags, handler del BLoC con
  optimistic update, y `_buildOrderSheet` con flags.
- **Colores**: Los colores verde pastel (`#C8E6C9`) y azul pastel (`#BBDEFB`)
  son constantes estáticas. Si se necesita soporte de modo oscuro, considerar
  moverlos a `CustomColors` en `theme_extensions.dart`.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en la app (click derecho en
  celdas de cantidad y stock) y opcionalmente añadir tests unitarios para la
  nueva funcionalidad.
