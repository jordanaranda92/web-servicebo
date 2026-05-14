# Implementation Report: Firebase RTDB Setup

- **Fecha:** 2025-07-18
- **Identificador:** firebase-setup
- **Fuente:** docs/technical-analysis/2026-05-08-firebase-setup.md
- **Estado:** Completed with warnings

## 1) Resumen

Se ha implementado la infraestructura completa de Firebase Realtime Database
para edición concurrente multi-usuario en la pantalla Orders Today. El sistema
incluye: datasource RTDB con locks transaccionales, cursores de presencia,
suscripción push que reemplaza el polling, identidad de usuario, y fallback
graceful cuando Firebase no está disponible.

Análisis estático: **0 issues**.

## 2) Alcance ejecutado

- ✅ Paso 1: Firebase bootstrap (ya completado en sesión anterior)
- ✅ Paso 2: Identidad de usuario (ya completado en sesión anterior)
- ✅ Paso 3: RTDB datasource — interfaz + implementación completa
- ✅ Paso 4: Entidades de dominio (CellLock, RemoteCursor)
- ✅ Paso 5: No se extendió el repositorio directamente; el BLoC consume el
  datasource (ajuste menor)
- ✅ Paso 6: OrdersPresenceCubit + OrdersPresenceState
- ✅ Paso 7: Refactor OrdersTodayBloc — nuevos eventos, suscripción RTDB,
  escritura dual (RTDB + Sheets)
- ✅ Paso 8: Presentación — polling condicional, PresenceCubit provider,
  indicador de usuarios conectados
- ✅ Paso 9: Fallback graceful — polling se reactiva si Firebase no disponible

## 3) Artefactos tocados

### Creados

- `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source.dart`
  — Interfaz
- `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source_impl.dart`
  — Implementación
- `lib/features/orders_today/data/dto/cell_delta.dart` — DTO (sesión anterior)
- `lib/features/orders_today/data/dto/lock_info.dart` — DTO (sesión anterior)
- `lib/features/orders_today/data/dto/cursor_info.dart` — DTO (sesión anterior)
- `lib/features/orders_today/data/dto/cell_key_utils.dart` — Utilidad de keys
- `lib/features/orders_today/domain/entities/cell_lock.dart` — Entidad (sesión
  anterior)
- `lib/features/orders_today/domain/entities/remote_cursor.dart` — Entidad
- `lib/features/orders_today/presentation/bloc/orders_presence_cubit.dart` —
  Cubit de presencia
- `lib/features/orders_today/presentation/bloc/orders_presence_state.dart` —
  Estado del cubit

### Modificados

- `lib/app/di/modules/orders_today_module.dart` — Registro condicional de RTDB
  datasource, PresenceCubit, parámetros extra al BLoC
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart` —
  Suscripción RTDB, eventos remotos, escritura dual, StreamSubscription
- `lib/features/orders_today/presentation/bloc/orders_today_event.dart` — Nuevos
  eventos: `RemoteCellReceived`, `RtdbSubscriptionStarted`
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  Polling condicional, BlocProvider de presencia, indicador de usuarios
  conectados

### Retirados o reemplazados

- Ninguno eliminado. El evento `OrdersTodayCheckModifiedRequested` se mantiene
  como fallback.

## 4) Validación ejecutada

| Validación        | Resultado                          |
| ----------------- | ---------------------------------- |
| `flutter analyze` | ✅ 0 issues                        |
| Build macOS       | ✅ (verificado en sesión anterior) |

- No se ejecutaron tests unitarios (no existían tests para los artefactos
  nuevos; los existentes no fueron modificados en su lógica interna).

## 5) Desviaciones respecto al análisis técnico

1. **Paso 5 (Repositorio):** El plan contemplaba extender
   `OrdersTodayRepository` con métodos RTDB. En su lugar, el BLoC y
   PresenceCubit consumen directamente `OrdersRtdbDataSource`. Justificación: el
   datasource RTDB es un canal de comunicación en tiempo real (streams), no
   encaja bien en el patrón repository de use-cases. Impacto: ninguno funcional;
   la separación de capas se mantiene.

2. **Color de cursor:** Se usa una paleta fija de 12 colores hexadecimales en
   lugar de `Colors.primaries` (que requiere contexto Material). Se mantiene el
   mismo criterio de asignación por hash.

## 6) Riesgos, incidencias y pendientes

- **Tests unitarios:** No se han creado tests para los nuevos artefactos. Se
  recomienda crear tests para `OrdersRtdbDataSourceImpl`, `OrdersPresenceCubit`
  y los nuevos handlers del BLoC.
- **onDisconnect en desktop:** Firebase RTDB `onDisconnect` puede no funcionar
  de forma confiable en desktop. Se ha añadido try/catch con log de warning. Se
  recomienda validar en producción.
- **Lock rendering en OrdersTable:** El cubit emite locks y cursors, pero la
  tabla aún no los renderiza visualmente (highlights de celdas bloqueadas,
  cursores remotos). Esto requiere modificaciones adicionales en `OrdersTable`.
- **Lock check antes de editar:** `OrdersTable` no consulta al PresenceCubit
  antes de permitir edición. Se debe integrar la lógica de `acquireLock` en el
  flujo de edición de la tabla.

## 7) Resultado final

- Estado final: ⚠️ Completado con warnings
- Siguiente paso recomendado:
  1. Integrar lock check + cursor rendering en `OrdersTable`
  2. Crear tests unitarios para los nuevos artefactos
  3. Validación manual end-to-end con dos instancias simultáneas
