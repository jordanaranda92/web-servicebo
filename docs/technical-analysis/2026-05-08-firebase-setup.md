# Technical Analysis: Firebase RTDB — Concurrencia en Pedidos de Hoy

- **Fecha:** 2026-05-08
- **Identificador:** firebase-setup
- **Fuente:** docs/functional-analysis/2026-05-08-firebase-setup-v3.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- **Enfoque:** Añadir `firebase_core` + `firebase_database` al proyecto. Crear
  un datasource RTDB dentro de `orders_today/data/datasources/remote/` que
  gestione locks, cells y cursors. Introducir un nuevo BLoC/Cubit de presencia
  (`OrdersPresenceCubit`) separado del `OrdersTodayBloc` existente para la capa
  de locks y cursores. Extender el flujo del BLoC actual para recibir deltas
  remotos vía streams RTDB. Añadir gestión de identidad de usuario en `settings`
  (generación de código de 6 letras, edición en pantalla de Ajustes).
- **Áreas impactadas:** `pubspec.yaml`, `lib/main.dart`, `lib/app/config/`,
  `lib/app/di/`, `lib/features/orders_today/` (todas las capas),
  `lib/features/settings/` (identidad de usuario), plataforma macOS/Windows.
- **Riesgo general:** Medio — la integración de Firebase desktop es madura para
  RTDB; el riesgo principal es el soporte de `onDisconnect` en la implementación
  Dart-only.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con capas `data/`, `domain/`,
  `presentation/` por feature.
- **State management:** BLoC (`flutter_bloc` 9.x). `OrdersTodayBloc` usa eventos
  sealed y estados sealed.
- **DI:** GetIt con módulos por feature en `lib/app/di/modules/`.
- **Navegación funcional:** fpdart (`Either<Failure, T>`),
  `UseCase<Type, Params>`.
- **Logging:** `AppLogger` (wrapper de `dart:developer`).

### Módulos relevantes

- `orders_today`: BLoC con `OrdersTodayLoadRequested`, `CellUpdateRequested`,
  `CheckModifiedRequested`; datasource remoto (`OrdersSheetDataSource`) contra
  Google Sheets API; repositorio que mapea DTO → entidad `OrderSheet`.
- `settings`: `SettingsLocalDataSource` con `SharedPreferences` +
  `FlutterSecureStorage`; secciones de Google Drive y FacturaDirecta en la UI;
  `SettingsRepository`.
- `core`: `AppLogger`, `GoogleAuthService`, `GoogleSheetsDataSource`,
  `NavigationGuard`, Dio, SharedPreferences.

### Polling actual

- `_OrdersTodayContentState` crea `Timer.periodic` que emite
  `OrdersTodayCheckModifiedRequested` → el BLoC relee todo el sheet de Google
  Sheets y compara `modifiedTime`.

### Edición actual (optimista)

- `OrdersTodayCellUpdateRequested` → `_applyOptimisticUpdate` (local) +
  `_updateOrderCell` (Google Sheets background). Soporta tanto cantidades como
  stocks (detecta `isStocksCol` con `clientCol == numClients + 1`).

### Restricciones técnicas

- macOS entitlements: `com.apple.security.network.client` ya habilitado (ambos
  entitlements).
- Plataformas: solo macOS y Windows (desktop).
- No Firebase Auth (se usa Google OAuth propio vía `googleapis_auth`).
- Identidad de usuario: no existe actualmente, se debe crear.

## 3) Objetivo técnico

- **Qué debe cambiar:** La fuente de verdad en tiempo real para las celdas de la
  hoja de pedidos pasa de Google Sheets (polling) a Firebase RTDB (listeners
  push). Google Sheets se mantiene como backup persistente.
- **Qué resultado técnico se persigue:** Edición concurrente con locks
  transaccionales, propagación de deltas en ~100ms, presencia y cursores
  remotos, indicador de usuarios conectados.
- **Limitaciones:** No usar Firebase Auth. No introducir Cloud Functions.
  Mantener compatibilidad con flujo actual como fallback si Firebase no está
  disponible.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Dividir el trabajo en 4 ejes verticales:

1. **Firebase bootstrap** — dependencias, inicialización, configuración.
2. **Identidad de usuario** — generación, persistencia, edición en Ajustes.
3. **RTDB datasource + dominio** — nuevo datasource, entidades de dominio,
   extensión del repositorio.
4. **Presentación** — refactor del BLoC, nuevo Cubit de presencia, cambios en la
   tabla para locks/cursores.

### Componentes / módulos / servicios afectados

| Componente                     | Capa                                                 | Cambio                                                                         |
| ------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------ |
| `firebase_options.dart`        | `lib/app/config/`                                    | Nuevo — generado por `flutterfire configure`                                   |
| `main.dart`                    | `lib/`                                               | Modificar `_initializeServices`                                                |
| `core_module.dart`             | `lib/app/di/modules/`                                | Registrar `FirebaseDatabase.instance`                                          |
| `settings_module.dart`         | `lib/app/di/modules/`                                | Registrar servicio de identidad de usuario                                     |
| `orders_today_module.dart`     | `lib/app/di/modules/`                                | Registrar RTDB datasource, nuevos use cases, Cubit de presencia                |
| `SettingsLocalDataSource`      | `lib/features/settings/data/`                        | Nuevos métodos: `getUserName`, `saveUserName`                                  |
| `SettingsRepository`           | `lib/features/settings/domain/`                      | Nuevo método: `getUserName`, `saveUserName`                                    |
| `SettingsPage`                 | `lib/features/settings/presentation/`                | Nueva sección UI para nombre de usuario                                        |
| `OrdersRtdbDataSource` (nuevo) | `lib/features/orders_today/data/datasources/remote/` | Interfaz + impl para RTDB                                                      |
| `CellLock` (nuevo)             | `lib/features/orders_today/domain/entities/`         | Entidad de lock                                                                |
| `RemoteCursor` (nuevo)         | `lib/features/orders_today/domain/entities/`         | Entidad de cursor remoto                                                       |
| `OrdersTodayRepository`        | `lib/features/orders_today/domain/repositories/`     | Nuevos métodos RTDB                                                            |
| `OrdersTodayRepositoryImpl`    | `lib/features/orders_today/data/repositories/`       | Implementar métodos RTDB                                                       |
| `OrdersTodayBloc`              | `lib/features/orders_today/presentation/bloc/`       | Nuevos eventos para deltas remotos; suscripción a streams RTDB                 |
| `OrdersPresenceCubit` (nuevo)  | `lib/features/orders_today/presentation/bloc/`       | Cubit para locks, cursores, presencia                                          |
| `OrdersTodayPage`              | `lib/features/orders_today/presentation/pages/`      | Eliminar `Timer.periodic`, añadir `OrdersPresenceCubit`, indicador de usuarios |
| `OrdersTable`                  | `lib/features/orders_today/presentation/widgets/`    | Renderizar locks y cursores remotos                                            |

### Contratos e interfaces

#### `OrdersRtdbDataSource` (nueva interfaz)

```dart
abstract class OrdersRtdbDataSource {
  /// Lee la fecha actual del nodo today.
  Future<String?> getTodayDate();
  
  /// Resetea atómicamente el nodo today para una nueva fecha.
  Future<void> resetToday(String date);
  
  /// Intenta adquirir un lock. Retorna true si se adquiere.
  Future<bool> acquireLock(String cellKey, String userId);
  
  /// Libera un lock.
  Future<void> releaseLock(String cellKey);
  
  /// Escribe un valor de celda.
  Future<void> writeCell(String cellKey, num value, String userId);
  
  /// Stream de cambios en cells (deltas individuales).
  Stream<CellDelta> onCellChanged();
  
  /// Stream de cambios en locks.
  Stream<LockUpdate> onLockChanged();
  
  /// Stream de cambios en cursors.
  Stream<CursorUpdate> onCursorChanged();
  
  /// Registra/actualiza mi cursor.
  Future<void> updateMyCursor(String userId, int row, int col, String color);
  
  /// Registra onDisconnect para limpiar cursor.
  Future<void> setupDisconnectCleanup(String userId);
  
  /// Elimina locks expirados (ts > 60s).
  Future<void> cleanExpiredLocks();
  
  /// Obtiene snapshot actual de todas las cells.
  Future<Map<String, CellDelta>> getAllCells();
  
  /// Obtiene snapshot actual de todos los locks.
  Future<Map<String, LockInfo>> getAllLocks();
  
  /// Obtiene snapshot actual de todos los cursors.
  Future<Map<String, CursorInfo>> getAllCursors();
  
  /// Limpia recursos (suscripciones).
  void dispose();
}
```

#### DTOs de RTDB (data layer)

```dart
class CellDelta { String key; num value; String user; int timestamp; }
class LockUpdate { String key; LockInfo? lock; bool removed; }
class LockInfo { String user; int timestamp; }
class CursorUpdate { String userId; CursorInfo? cursor; bool removed; }
class CursorInfo { int row; int col; String color; String? userName; }
```

#### Entidades de dominio (nuevas)

```dart
class CellLock extends Equatable { String cellKey; String user; DateTime timestamp; bool get isExpired; }
class RemoteCursor extends Equatable { String userId; int row; int col; Color color; }
```

#### Extensión de `SettingsLocalDataSource`

```dart
// Nuevos métodos
String? getUserName();
Future<void> saveUserName(String name);
```

### Flujo de datos o de control

#### Inicialización

```
main.dart → _initializeServices(config)
  ├─ Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
  │   └─ try/catch → si falla, log + continuar (flag _firebaseAvailable = false)
  ├─ initDI(config)
  │   ├─ core_module: FirebaseDatabase.instance (si disponible)
  │   ├─ settings_module: UserIdentityService (genera/lee userId)
  │   └─ orders_today_module: OrdersRtdbDataSource
  └─ runApp(...)
```

#### Apertura de Pedidos de Hoy (con RTDB)

```
OrdersTodayBloc recibe OrdersTodayLoadRequested
  │
  ├─ 1. Leer userId de SettingsLocalDataSource
  ├─ 2. rtdbDataSource.getTodayDate()
  │     ├─ null o ≠ hoy → rtdbDataSource.resetToday(hoy)
  │     └─ == hoy → continuar
  ├─ 3. sheetDataSource.readTodaySheet(...) → OrderSheet base
  ├─ 4. rtdbDataSource.getAllCells() → aplicar deltas sobre OrderSheet base
  ├─ 5. emit OrdersTodayLoaded(orderSheet combinado)
  ├─ 6. Iniciar suscripción a rtdbDataSource.onCellChanged() → eventos internos
  └─ 7. rtdbDataSource.cleanExpiredLocks()

OrdersPresenceCubit se inicializa en paralelo
  ├─ 1. setupDisconnectCleanup(userId)
  ├─ 2. updateMyCursor(userId, 0, 0, color)
  ├─ 3. Suscribirse a onLockChanged() → emitir estado con locks
  ├─ 4. Suscribirse a onCursorChanged() → emitir estado con cursors + conteo
  └─ 5. cleanExpiredLocks()
```

#### Edición de celda (con RTDB)

```
Usuario toca celda → OrdersTable consulta OrdersPresenceCubit
  │
  ├─ presenceCubit.acquireLock(cellKey) → true/false
  │     ├─ false → mostrar "Bloqueada por {user}"
  │     └─ true → abrir editor
  │
  ▼
Usuario confirma valor
  │
  ├─ OrdersTodayBloc.add(CellUpdateRequested)
  │     ├─ _applyOptimisticUpdate local → emit
  │     ├─ rtdbDataSource.writeCell(key, value, userId) → propaga a remotos
  │     ├─ presenceCubit.releaseLock(cellKey)
  │     └─ sheetDataSource.updateCell(...) background (fire-and-forget)
```

#### Recepción de delta remoto

```
rtdbDataSource.onCellChanged() emite CellDelta
  │
  └─ OrdersTodayBloc handler:
      ├─ Si delta.user == yo → ignorar
      ├─ Parsear key:
      │   ├─ "stock_{r}" → stocks[r] = delta.value
      │   └─ "{r}_{c}" → quantities[r][c] = delta.value
      ├─ Recalcular pedidos[r] y quedan[r]
      └─ emit OrdersTodayLoaded(updated)
```

### Gestión de errores y validaciones

| Escenario                                        | Manejo                                                                             |
| ------------------------------------------------ | ---------------------------------------------------------------------------------- |
| Firebase no inicializa                           | Log error, `_firebaseAvailable = false`, app continúa sin RTDB, polling reactivado |
| Lock transacción falla                           | Retornar `false` al caller, UI muestra "celda bloqueada"                           |
| RTDB listener pierde conexión                    | Firebase SDK gestiona reconexión automática; offline persistence mantiene cache    |
| Escritura a Google Sheets falla                  | Log warning, dato seguro en RTDB, sin impacto en UX                                |
| userId no existe (primera vez)                   | Generar código de 6 letras, persistir en SharedPreferences                         |
| Lock expirado (>60s)                             | Cualquier cliente lo borra al detectarlo                                           |
| Hot restart (`Firebase.initializeApp` duplicado) | Verificar si ya existe app default: `Firebase.apps.isNotEmpty`                     |

### Consideraciones de compatibilidad o migración

- **Flutter SDK:** El proyecto usa SDK `^3.10.8` — compatible con FlutterFire
  actual.
- **Rollback transparente:** Si se revierte Firebase, basta con eliminar las
  dependencias y el `Firebase.initializeApp`; el polling se puede reactivar
  restaurando `Timer.periodic` y `CheckModifiedRequested`.
- **No breaking changes en `OrderSheet`:** La entidad no cambia. Los deltas RTDB
  se aplican sobre la misma estructura.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                             | Propósito                                                 |
| ------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `lib/app/config/firebase_options.dart`                                                | Opciones de Firebase generadas por FlutterFire CLI        |
| `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source.dart`      | Interfaz del datasource RTDB                              |
| `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source_impl.dart` | Implementación del datasource RTDB                        |
| `lib/features/orders_today/data/dto/cell_delta.dart`                                  | DTO para deltas de celdas desde RTDB                      |
| `lib/features/orders_today/data/dto/lock_info.dart`                                   | DTO para locks desde RTDB                                 |
| `lib/features/orders_today/data/dto/cursor_info.dart`                                 | DTO para cursores desde RTDB                              |
| `lib/features/orders_today/domain/entities/cell_lock.dart`                            | Entidad de dominio para lock de celda                     |
| `lib/features/orders_today/domain/entities/remote_cursor.dart`                        | Entidad de dominio para cursor remoto                     |
| `lib/features/orders_today/presentation/bloc/orders_presence_cubit.dart`              | Cubit de presencia: locks, cursores, conteo de conectados |
| `lib/features/orders_today/presentation/bloc/orders_presence_state.dart`              | Estado del cubit de presencia                             |
| `lib/features/settings/presentation/widgets/user_identity_section.dart`               | Widget de sección de Ajustes para nombre de usuario       |

### Artefactos a modificar

| Artefacto                                                                           | Cambio esperado                                                                                                                   |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `pubspec.yaml`                                                                      | Añadir `firebase_core`, `firebase_database`                                                                                       |
| `lib/main.dart`                                                                     | Añadir `Firebase.initializeApp` en `_initializeServices`, import `firebase_options.dart`                                          |
| `lib/app/di/modules/core_module.dart`                                               | Registrar `FirebaseDatabase.instance` (condicional a disponibilidad)                                                              |
| `lib/app/di/modules/orders_today_module.dart`                                       | Registrar `OrdersRtdbDataSource`, `OrdersPresenceCubit`, actualizar dependencias del BLoC                                         |
| `lib/app/di/modules/settings_module.dart`                                           | No cambio directo (el datasource local ya está registrado)                                                                        |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`      | Añadir `getUserName()`, `saveUserName(String)`                                                                                    |
| `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart` | Implementar `getUserName`, `saveUserName` con `SharedPreferences`                                                                 |
| `lib/features/settings/domain/repositories/settings_repository.dart`                | Añadir `getUserName()`, `saveUserName(String)`                                                                                    |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`             | Implementar nuevos métodos de identidad                                                                                           |
| `lib/features/settings/presentation/pages/settings_page.dart`                       | Añadir `UserIdentitySection` en la lista de secciones                                                                             |
| `lib/features/orders_today/domain/repositories/orders_today_repository.dart`        | Añadir métodos RTDB: `acquireLock`, `releaseLock`, `writeCell`, streams                                                           |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`     | Implementar métodos RTDB delegando al datasource                                                                                  |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`                | Añadir eventos para deltas remotos; suscripción a stream RTDB; eliminar `_onCheckModified`                                        |
| `lib/features/orders_today/presentation/bloc/orders_today_event.dart`               | Nuevos eventos: `RemoteCellUpdateReceived`, `RtdbSubscriptionStarted`                                                             |
| `lib/features/orders_today/presentation/bloc/orders_today_state.dart`               | Sin cambios en `OrdersTodayLoaded` (misma estructura); posible nuevo estado `OrdersTodayRealtimeDisabled`                         |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`               | Eliminar `Timer.periodic` y `_startPolling`; añadir `BlocProvider` para `OrdersPresenceCubit`; indicador de usuarios conectados   |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`                  | Recibir locks y cursores como parámetros; pintar celdas bloqueadas; verificar lock antes de abrir editor; pintar cursores remotos |

### Artefactos a retirar o reemplazar

| Artefacto                                    | Motivo                                                                      |
| -------------------------------------------- | --------------------------------------------------------------------------- |
| `OrdersTodayCheckModifiedRequested` (evento) | Reemplazado por listeners RTDB push; ya no se necesita polling              |
| `_onCheckModified` (handler en BLoC)         | Mismo motivo                                                                |
| `modifiedTimePollInterval` en `AppConfig`    | Ya no se usa para polling (se puede dejar por retrocompatibilidad/fallback) |

## 6) Estrategia de implementación

### Pasos ordenados

1. **Paso 1 — Firebase bootstrap**
   - Añadir dependencias en `pubspec.yaml`: `firebase_core`,
     `firebase_database`.
   - Ejecutar `flutterfire configure` para generar `firebase_options.dart`.
   - Modificar `_initializeServices` en `main.dart` para llamar a
     `Firebase.initializeApp` con try/catch.
   - Registrar `FirebaseDatabase.instance` en `core_module.dart`.
   - Verificar compilación en macOS y Windows.

2. **Paso 2 — Identidad de usuario**
   - Extender `SettingsLocalDataSource` / impl con `getUserName` /
     `saveUserName`.
   - Generar código de 6 letras en la primera lectura si no existe.
   - Extender `SettingsRepository` / impl.
   - Crear widget `UserIdentitySection` para la pantalla de Ajustes.
   - Añadir la sección en `SettingsPage`.
   - Añadir strings i18n necesarios.

3. **Paso 3 — RTDB datasource**
   - Crear DTOs: `CellDelta`, `LockInfo`, `CursorInfo`.
   - Crear interfaz `OrdersRtdbDataSource`.
   - Crear implementación `OrdersRtdbDataSourceImpl` con `FirebaseDatabase`:
     - `getTodayDate`, `resetToday` (transacción).
     - `acquireLock` (runTransaction), `releaseLock`.
     - `writeCell`.
     - `onCellChanged` (onChildAdded/Changed/Removed en `today/cells`).
     - `onLockChanged` (onChildAdded/Changed/Removed en `today/locks`).
     - `onCursorChanged` (onChildAdded/Changed/Removed en `today/cursors`).
     - `updateMyCursor`, `setupDisconnectCleanup`.
     - `cleanExpiredLocks`.
     - `getAllCells`, `getAllLocks`, `getAllCursors`.
   - Registrar en `orders_today_module.dart`.

4. **Paso 4 — Entidades de dominio**
   - Crear `CellLock` y `RemoteCursor` en `domain/entities/`.

5. **Paso 5 — Extensión del repositorio**
   - Añadir métodos RTDB a `OrdersTodayRepository` (interfaz).
   - Implementar en `OrdersTodayRepositoryImpl`, delegando al datasource RTDB.

6. **Paso 6 — OrdersPresenceCubit**
   - Crear `OrdersPresenceState` con: `Map<String, CellLock> locks`,
     `Map<String, RemoteCursor> cursors`, `int connectedUsers`.
   - Crear `OrdersPresenceCubit`:
     - Recibe `OrdersRtdbDataSource` + `userId`.
     - En `init`: suscribirse a locks y cursors; registrar cursor propio +
       onDisconnect; limpiar locks expirados.
     - Métodos: `acquireLock(cellKey)`, `releaseLock(cellKey)`,
       `updateMyPosition(row, col)`.
     - En `close`: cancelar suscripciones, limpiar cursor propio.

7. **Paso 7 — Refactor del OrdersTodayBloc**
   - Añadir `OrdersRtdbDataSource` como dependencia.
   - Nuevo evento `RtdbSubscriptionStarted` — se emite internamente después de
     cargar el sheet base.
   - Nuevo evento `RemoteCellUpdateReceived(CellDelta delta)` — handler que
     aplica el delta si `user ≠ myUserId`.
   - Modificar `_onLoad`:
     1. Leer `today/date`, resetear si necesario.
     2. Cargar sheet base de Google Sheets.
     3. Obtener `getAllCells()` → aplicar deltas sobre sheet base.
     4. Emit `OrdersTodayLoaded`.
     5. Iniciar suscripción a `onCellChanged()` → mapear a
        `RemoteCellUpdateReceived`.
   - Modificar `_onCellUpdate`:
     1. `_applyOptimisticUpdate` (existente).
     2. `rtdbDataSource.writeCell(...)`.
     3. `sheetDataSource.updateCell(...)` fire-and-forget (no esperar
        resultado).
   - Eliminar `_onCheckModified` y `OrdersTodayCheckModifiedRequested`.
   - En `close`: cancelar suscripción al stream RTDB.

8. **Paso 8 — Cambios en presentación**
   - `OrdersTodayPage`:
     - Eliminar `Timer.periodic` y `_startPolling`.
     - Añadir `BlocProvider<OrdersPresenceCubit>` junto al `OrdersTodayBloc`.
     - Añadir indicador de usuarios conectados en el header.
   - `OrdersTable`:
     - Recibir `Map<String, CellLock> locks` y `List<RemoteCursor> cursors` como
       parámetros (o consumir `OrdersPresenceCubit` directamente).
     - Antes de abrir editor: consultar `presenceCubit.acquireLock()`. Si falla
       → mostrar snackbar/tooltip "Bloqueada por {user}".
     - Pintar overlay de color en celdas con lock de otro usuario.
     - Pintar indicadores de cursor remoto (borde de color en la celda + label
       con nombre).
     - Al navegar/seleccionar celdas:
       `presenceCubit.updateMyPosition(row, col)`.

9. **Paso 9 — Degradación graceful (fallback)**
   - Si Firebase no se inicializó (`_firebaseAvailable == false`):
     - No registrar `OrdersRtdbDataSource` en DI (o registrar un stub que
       no-op).
     - `OrdersTodayBloc` opera como antes: sin RTDB, sin suscripciones.
     - Reactivar `Timer.periodic` en `OrdersTodayPage`.
     - `OrdersPresenceCubit` emite estado vacío (sin locks, sin cursores, 0
       conectados).

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

### Dependencias entre pasos

- Paso 1 es prerrequisito de todos los demás.
- Paso 2 es prerrequisito de Paso 6 (el cubit necesita el userId).
- Paso 3 es prerrequisito de Pasos 5, 6, 7.
- Paso 4 es prerrequisito de Pasos 5, 6.
- Pasos 5 y 6 son prerrequisitos de Paso 7.
- Paso 7 es prerrequisito de Paso 8.
- Paso 9 puede hacerse en paralelo con Paso 8.

### Puntos delicados

- **Transacciones RTDB para locks:** Deben ser atómicas.
  `DatabaseReference.runTransaction` es la API correcta. Verificar que funciona
  correctamente en implementación Dart-only (desktop).
- **Suscripciones a streams en BLoC:** El BLoC debe gestionar
  `StreamSubscription` y cancelarla en `close()`. Usar `emit.forEach` de
  `flutter_bloc` o suscripción manual con `add(event)`.
- **Recálculo de `pedidos` y `quedan`:** La lógica de `_applyOptimisticUpdate`
  ya existe en el BLoC y debe reutilizarse para deltas remotos.
- **Key parsing:** La función que convierte `"3_5"` ↔ `(row: 3, col: 5)` y
  `"stock_3"` ↔ `(stockRow: 3)` debe ser robusta y estar en un lugar compartido.
- **`onDisconnect()` en desktop:** Verificar que Firebase Dart SDK soporta
  `onDisconnect` correctamente en plataformas desktop.

## 7) Estrategia de validación

### Verificación automática (tests)

- **Tests unitarios del datasource RTDB:** Mock de `FirebaseDatabase` (usando
  mocktail). Verificar: `acquireLock` retorna `true/false` correctamente;
  `writeCell` invoca `ref.set`; `cleanExpiredLocks` borra locks viejos.
- **Tests unitarios del `OrdersPresenceCubit`:** Mock del datasource. Verificar:
  streams de locks/cursores actualizan el estado; `acquireLock` delega al
  datasource; `close` cancela suscripciones.
- **Tests unitarios del `OrdersTodayBloc` (refactorizado):** Mock del datasource
  RTDB y del repositorio existente. Verificar: `RemoteCellUpdateReceived` aplica
  delta y recalcula; deltas con `user == myUserId` son ignorados; `_onLoad`
  aplica deltas iniciales sobre sheet base.
- **Tests de identidad de usuario:** Verificar generación de 6 letras,
  persistencia, lectura.

### Verificación manual

- Abrir dos instancias de la app en el mismo equipo (o en dos equipos).
- Verificar que un cambio en celda (3,5) por usuario A aparece en usuario B en
  <2s.
- Verificar que la celda se bloquea visualmente mientras A edita.
- Verificar que el cursor de A es visible para B.
- Verificar que el indicador de usuarios conectados muestra 2.
- Verificar que al cerrar una instancia, su cursor desaparece.
- Verificar que al abrir al día siguiente, el nodo RTDB se resetea.
- Verificar que las ediciones se persisten en Google Sheets.

### Escenarios a cubrir

- Lock adquirido → edición → commit → lock liberado.
- Lock adquirido → cancelación → lock liberado.
- Lock de otro usuario → rechazo.
- Lock huérfano → limpieza tras 60s.
- Delta remoto de celda de cantidad → recalcular pedidos/quedan.
- Delta remoto de celda de stock → recalcular quedan.
- Firebase no disponible → fallback a polling.
- Cambio de nombre de usuario en Ajustes → reflejado en locks/cursores.

### Tipos de pruebas recomendables

- Unit tests (BLoC, Cubit, datasource, repositorio).
- Widget tests (sección de identidad en Ajustes; verificar que la tabla
  renderiza locks).
- Integration test manual (dos instancias concurrentes).

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                            | Probabilidad | Impacto | Mitigación                                                                                         |
| ----------------------------------------------------------------- | ------------ | ------- | -------------------------------------------------------------------------------------------------- |
| `onDisconnect` no funciona en Dart-only SDK (desktop)             | Media        | Medio   | Implementar limpieza de cursores por TTL (similar a locks) como alternativa                        |
| Latencia RTDB en redes lentas                                     | Baja         | Bajo    | Firebase gestiona offline; UX no se bloquea                                                        |
| Conflicto de transacciones en lock (alta concurrencia)            | Baja         | Bajo    | La transacción se reintenta automáticamente por Firebase                                           |
| Tests existentes rompen por `Firebase.initializeApp`              | Media        | Medio   | No llamar a Firebase en tests; mock del datasource; el BLoC actual no invoca Firebase directamente |
| Tamaño del nodo `today` crece mucho (muchos productos × clientes) | Baja         | Bajo    | Solo un día activo; se resetea cada día; listeners granulares en children                          |

### Impacto potencial

- **Positivo:** Eliminación completa del polling, UX de edición colaborativa,
  consistencia de datos en tiempo real.
- **Negativo potencial:** Dependencia de nuevo servicio externo (Firebase). Si
  Firebase tiene downtime, se degrada a polling.

### Mitigación

- Flag `_firebaseAvailable` para fallback.
- Polling como modo degradado.
- `onDisconnect` + TTL para limpieza de presencia.

### Plan de rollback

1. Eliminar `Firebase.initializeApp` de `main.dart`.
2. Eliminar registros de RTDB datasource y `OrdersPresenceCubit` de DI.
3. Restaurar `Timer.periodic` y `CheckModifiedRequested` en la página y el BLoC.
4. Eliminar dependencias de Firebase de `pubspec.yaml`.
5. El resto del código (identidad de usuario en settings) puede quedarse sin
   impacto.

## 9) Suposiciones

- Firebase Dart SDK (`firebase_core`, `firebase_database`) funciona
  correctamente en macOS y Windows desktop en sus versiones actuales.
- `DatabaseReference.runTransaction` está disponible y funcional en la
  implementación Dart-only.
- La latencia típica de RTDB en una red normal es <500ms.
- El número de productos × clientes es del orden de cientos (no miles), por lo
  que el nodo `today` es manejable.
- `flutterfire configure` puede generar configuración para desktop.
- No se requiere encriptar datos en RTDB (información de cantidades de pedidos,
  no datos sensibles).

## 10) Preguntas abiertas

Ninguna. Todas las decisiones funcionales están resueltas en el análisis
funcional v3.

## 11) Notas para implementación

- **No romper el flujo actual:** Implementar la integración RTDB como capa
  adicional, no sustitutiva. El BLoC debe seguir soportando el flujo sin RTDB
  (fallback). Solo eliminar el polling cuando RTDB esté confirmado como
  funcional.
- **Reutilizar `_applyOptimisticUpdate`:** La lógica de recálculo de `pedidos` y
  `quedan` ya existe en el BLoC. Extraerla a un método compartido y reutilizarla
  para deltas remotos.
- **Key parsing centralizado:** Crear una utilidad simple (funciones top-level o
  extension) para `cellKey(row, col)` → `"{row}_{col}"`, `stockKey(row)` →
  `"stock_{row}"`, y sus inversas.
- **i18n:** Añadir al menos: label "Nombre de usuario" en Ajustes, "Celda
  bloqueada por {user}", "{n} usuarios conectados".
- **Color de cursor:** Asignar un color derivado del hash del userId (ej:
  `Colors.primaries[userId.hashCode % Colors.primaries.length]`).
- **Secuencia sugerida:** Implementar Pasos 1-2 primero y verificar compilación.
  Luego 3-5 como capa de datos. Finalmente 6-8 como capa de presentación. Paso 9
  en paralelo.
- **Estado: Listo para implementación.**
