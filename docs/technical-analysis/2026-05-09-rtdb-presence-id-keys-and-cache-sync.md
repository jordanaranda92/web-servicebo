# Technical Analysis: Migración de presencia RTDB a claves por ID e invalidación reactiva de caché

- **Fecha:** 2026-05-09
- **Identificador:** rtdb-presence-id-keys-and-cache-sync
- **Fuente:**
  docs/functional-analysis/2026-05-09-rtdb-presence-id-keys-and-cache-sync.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Migrar las claves de locks y cursors en RTDB de índices posicionales
  (`"row_col"`, `{r, c}`) a claves semánticas basadas en IDs de Firestore
  (`"productId_clientId"`, `{productId, clientId}`).
- Suscribir `OrdersTodayRepositoryImpl` a los streams `watchAll()` existentes de
  `ClientFirestoreDataSource` y `ProductFirestoreDataSource` para invalidar el
  caché in-memory de catálogos de forma reactiva.
- Detectar locks huérfanos en la UI cuando la estructura de la tabla cambia y
  liberar/limpiar automáticamente.
- Áreas impactadas: DTOs de presencia, utilidades de cell-key, entidades de
  dominio, `OrdersPresenceCubit`, `orders_table.dart`, repositorio, DI module.
- Riesgo general estimado: **bajo** — los datos de presencia en RTDB son
  efímeros (locks TTL 60s, cursors cleanup en desconexión) y no requieren
  migración. Los streams `watchAll()` ya existen.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC, GetIt (DI), fpdart.

### Módulos relevantes

- `lib/features/orders_today/data/dto/` — `cell_key_utils.dart`,
  `cursor_info.dart`, `lock_info.dart`
- `lib/features/orders_today/data/datasources/remote/` —
  `orders_rtdb_data_source.dart` (contrato), `orders_rtdb_data_source_impl.dart`
  (implementación)
- `lib/features/orders_today/domain/entities/` — `cell_lock.dart`,
  `remote_cursor.dart`
- `lib/features/orders_today/presentation/bloc/` — `orders_presence_cubit.dart`,
  `orders_presence_state.dart`
- `lib/features/orders_today/presentation/widgets/` — `orders_table.dart`
- `lib/features/orders_today/data/repositories/` —
  `orders_today_repository_impl.dart`
- `lib/app/di/modules/orders_today_module.dart`

### Restricciones relevantes

- Los IDs de Firestore son alfanuméricos de 20 caracteres, no contienen `_`.
- Las claves de child en Firebase RTDB no permiten `.`, `$`, `#`, `[`, `]`, `/`.
  El separador `_` es seguro.
- Los datasources de clientes y productos ya exponen `watchAll()` que retorna
  `Stream<List<ClientModel>>` / `Stream<List<ProductModel>>` vía
  `_collection.snapshots()`.
- `OrderSheet` ya contiene `clientIds` y `productIds` (implementado en la
  optimización anterior).
- Los cursors remotos actualmente almacenan `row`/`col` pero la UI solo usa
  `userName` y `color` (para el footer de usuarios conectados). Los campos
  `row`/`col` no se acceden en la renderización.

### Dependencias

- `ClientFirestoreDataSource.watchAll()` — ya implementado en
  `client_firestore_data_source_impl.dart`.
- `ProductFirestoreDataSource.watchAll()` — ya implementado en
  `product_firestore_data_source_impl.dart`.
- No se introducen nuevas dependencias externas.

## 3) Objetivo técnico

- **Qué debe cambiar**: El formato de identificación de celdas en RTDB pasa de
  índices posicionales a IDs de entidad. El caché de catálogos pasa de
  invalidación manual a invalidación reactiva por stream.
- **Resultado técnico**: Locks y cursors estables ante cambios de estructura.
  Caché siempre actualizado.
- **Limitaciones**: No se modifican las pantallas de gestión de
  clientes/productos. No se implementa `resetToday`.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Dividir el cambio en dos bloques independientes:

**Bloque 1 — Locks y cursors basados en IDs (P1, P2, P3)**

La cadena de cambios fluye desde abajo (DTOs/utils) hacia arriba (UI):

1. `cell_key_utils.dart` — Cambiar funciones para operar con `String`
   (productId, clientId) en vez de `int` (row, col).
2. `CursorInfo` — Reemplazar `int row`/`int col` por
   `String? productId`/`String? clientId`.
3. `RemoteCursor` — Reemplazar `int row`/`int col` por
   `String? productId`/`String? clientId`.
4. `OrdersRtdbDataSource` / `Impl` — Cambiar firma de `updateMyCursor` de
   `(userId, row, col, color, userName)` a
   `(userId, productId, clientId, color, userName)`.
5. `OrdersPresenceCubit` — Cambiar `updateMyPosition(row, col)` a
   `updateMyPosition(productId, clientId)`.
6. `orders_table.dart` — Construir claves de lock y cursors usando IDs de
   `OrderSheet.productIds[idx]` / `OrderSheet.clientIds[idx]`. En
   `didUpdateWidget`, detectar locks huérfanos y liberar.

**Bloque 2 — Invalidación reactiva del caché (P5)**

7. `OrdersTodayRepositoryImpl` — Añadir suscripciones a `watchAll()` de clientes
   y productos. Cada emisión ejecuta `_invalidateCache()` parcial (solo el campo
   correspondiente). Añadir método `dispose()` para cancelar suscripciones.
8. `OrdersTodayRepository` (contrato) — Añadir `void dispose()`.
9. `orders_today_module.dart` — Actualizar la creación del repositorio para
   registrar dispose con `registerLazySingleton` + `dispose` callback.

### Componentes / módulos / servicios afectados

| Componente                          | Capa         | Cambio                                       |
| ----------------------------------- | ------------ | -------------------------------------------- |
| `cell_key_utils.dart`               | Data/DTO     | Firmas `String` en vez de `int`              |
| `cursor_info.dart`                  | Data/DTO     | `productId`/`clientId` en vez de `r`/`c`     |
| `lock_info.dart`                    | Data/DTO     | Sin cambios (ya usa `String key` genérico)   |
| `remote_cursor.dart`                | Domain       | `productId`/`clientId` en vez de `row`/`col` |
| `cell_lock.dart`                    | Domain       | Sin cambios (ya usa `String cellKey`)        |
| `orders_rtdb_data_source.dart`      | Data/DS      | Firma `updateMyCursor`                       |
| `orders_rtdb_data_source_impl.dart` | Data/DS      | Impl `updateMyCursor`                        |
| `orders_presence_cubit.dart`        | Presentation | `updateMyPosition` con IDs                   |
| `orders_presence_state.dart`        | Presentation | Sin cambios                                  |
| `orders_table.dart`                 | Presentation | Cell keys por IDs, lock huérfano             |
| `orders_today_repository_impl.dart` | Data         | Suscripciones `watchAll`, `dispose`          |
| `orders_today_repository.dart`      | Domain       | Añadir `dispose()`                           |
| `orders_today_module.dart`          | App/DI       | `disposingFunction` en registro              |

### Contratos e interfaces

**`cell_key_utils.dart`** — nuevas firmas:

```dart
String cellKey(String productId, String clientId);     // "{productId}_{clientId}"
String stockKey(String productId);                      // "stock_{productId}"
bool isStockKey(String key);                            // sin cambio
({String productId, String? clientId}) parseCellKey(String key);
```

**`CursorInfo`** — nuevos campos:

```dart
class CursorInfo {
  final String? productId;
  final String? clientId;  // null = stock column
  final String color;
  final String? userName;
  // fromMap: 'pid' / 'cid' (cortos para minimizar payload RTDB)
  // toMap: {'pid': ..., 'cid': ..., 'color': ..., 'name': ...}
}
```

**`RemoteCursor`** — nuevos campos:

```dart
class RemoteCursor {
  final String userId;
  final String userName;
  final String? productId;
  final String? clientId;
  final Color color;
}
```

**`OrdersRtdbDataSource.updateMyCursor`** — nueva firma:

```dart
Future<void> updateMyCursor(
  String userId,
  String? productId,
  String? clientId,
  String color,
  String userName,
);
```

**`OrdersPresenceCubit.updateMyPosition`** — nueva firma:

```dart
Future<void> updateMyPosition(String productId, String? clientId);
```

**`OrdersTodayRepository`** — método añadido:

```dart
void dispose();
```

### Flujo de datos — Lock acquisition

```
UI (orders_table)
  → productId = orderSheet.productIds[filteredIndices[rowIdx]]
  → clientId  = isStock ? null : orderSheet.clientIds[col]
  → key       = cellKey(productId, clientId) | stockKey(productId)
  → cubit.acquireLock(key)
  → cubit.updateMyPosition(productId, clientId)
  → RTDB: locks/{productId}_{clientId} = {user, ts}
  → RTDB: cursors/{userId} = {pid, cid, color, name}
```

### Flujo de datos — Caché invalidation

```
Firestore: clients collection change
  → ClientFirestoreDataSource.watchAll() emits
  → OrdersTodayRepositoryImpl._clientsSub receives
  → _cachedClients = null
  → Next _getClients() call fetches fresh data
```

### Gestión de errores y validaciones

- Si `productId` está fuera de rango (índice inválido en `productIds`), la UI no
  genera lock/cursor → misma protección que la actual.
- Si un lock key de RTDB refiere a un ID no presente en el sheet actual,
  `parseCellKey` lo parsea correctamente pero la UI lo ignora al no encontrar el
  ID en `clientIds`/`productIds`.
- Si el stream `watchAll()` emite error, se loguea y el caché no se invalida (se
  mantiene el dato anterior). Los errores de stream no deben crashear el
  repositorio.

### Consideraciones de compatibilidad o migración

- **No se requiere migración de datos RTDB**: Los locks expiran en 60s y los
  cursors se eliminan al desconectar. Un despliegue simplemente producirá claves
  con el nuevo formato; las claves antiguas expirarán naturalmente.
- **Compatibilidad temporal (deploy incremental)**: Si dos usuarios ejecutan
  versiones diferentes simultáneamente, las claves de lock serán incompatibles
  (uno usa `"3_2"`, otro usa `"prodABC_cliXYZ"`). No se bloquearán mutuamente,
  pero tampoco se verán los locks. Aceptable dado que es una ventana temporal
  muy corta y el impacto es menor (pérdida temporal de protección de locks, no
  corrupción de datos).

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno.

### Artefactos a modificar

| Artefacto                                                                             | Cambio esperado                                                                                                      |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/data/dto/cell_key_utils.dart`                              | Firmas de `int` a `String` para productId/clientId; `parseCellKey` devuelve `({String productId, String? clientId})` |
| `lib/features/orders_today/data/dto/cursor_info.dart`                                 | `row`/`col` → `productId`/`clientId`; claves RTDB `r`/`c` → `pid`/`cid`                                              |
| `lib/features/orders_today/domain/entities/remote_cursor.dart`                        | `row`/`col` → `productId`/`clientId`                                                                                 |
| `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source.dart`      | Firma `updateMyCursor` con `String? productId, String? clientId`                                                     |
| `lib/features/orders_today/data/datasources/remote/orders_rtdb_data_source_impl.dart` | Impl `updateMyCursor` escribe `pid`/`cid` en lugar de `r`/`c`                                                        |
| `lib/features/orders_today/presentation/bloc/orders_presence_cubit.dart`              | `updateMyPosition(String, String?)`; mapping en `_onCursorUpdate` y `init`                                           |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`                    | `_cellKeyForEditing` usa IDs; `_startEditing`/`_commitAndMove` pasan IDs; `didUpdateWidget` libera locks huérfanos   |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`       | Suscripciones `watchAll()`, `dispose()`                                                                              |
| `lib/features/orders_today/domain/repositories/orders_today_repository.dart`          | Añadir `void dispose()` al contrato                                                                                  |
| `lib/app/di/modules/orders_today_module.dart`                                         | `registerLazySingleton` con `dispose: (repo) => repo.dispose()`                                                      |

### Artefactos a retirar o reemplazar

Ninguno. Los artefactos existentes se modifican in-place.

## 6) Estrategia de implementación

1. **Paso 1 — `cell_key_utils.dart`**: Cambiar firmas de `cellKey`, `stockKey` y
   `parseCellKey` para operar con `String` (IDs) en lugar de `int` (índices).

2. **Paso 2 — `cursor_info.dart`**: Reemplazar `int row`/`int col` por
   `String? productId`/`String? clientId`. Actualizar `fromMap`/`toMap` con
   claves `pid`/`cid`.

3. **Paso 3 — `remote_cursor.dart`**: Reemplazar `int row`/`int col` por
   `String? productId`/`String? clientId`. Actualizar `props`.

4. **Paso 4 — `orders_rtdb_data_source.dart` (contrato)**: Cambiar firma de
   `updateMyCursor`.

5. **Paso 5 — `orders_rtdb_data_source_impl.dart`**: Implementar nueva firma de
   `updateMyCursor` escribiendo `pid`/`cid`.

6. **Paso 6 — `orders_presence_cubit.dart`**: Adaptar
   `updateMyPosition(String, String?)`, `init()` y `_onCursorUpdate`.

7. **Paso 7 — `orders_table.dart`**: Adaptar `_cellKeyForEditing` para usar IDs
   de `OrderSheet`. Adaptar `_startEditing` y `_commitAndMove` para pasar IDs al
   cubit. En `didUpdateWidget`, detectar si `_lockedCellKey` referencia un ID
   ausente y liberar.

8. **Paso 8 — `orders_today_repository.dart` (contrato)**: Añadir
   `void dispose()`.

9. **Paso 9 — `orders_today_repository_impl.dart`**: Añadir suscripciones a
   `_clientFirestore.watchAll()` y `_productFirestore.watchAll()` en el
   constructor. Implementar `dispose()` cancelando las suscripciones.

10. **Paso 10 — `orders_today_module.dart`**: Actualizar el registro del
    repositorio para invocar `dispose` con
    `registerLazySingleton(..., dispose: (repo) => repo.dispose())`.

11. **Paso 11 — Validar**: Ejecutar `dart analyze lib/` y `flutter test`.

### Orden recomendado

Seguir los pasos 1→11 en orden secuencial. Los pasos 1-7 (Bloque 1) son una
cadena de dependencias ascendente (DTOs → datasource → cubit → UI). Los pasos
8-10 (Bloque 2) son independientes del Bloque 1 y podrían ejecutarse en
paralelo, pero se recomienda hacerlos después para validar todo junto.

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (usa `parseCellKey` indirectamente).
- Paso 3 depende de Paso 2 (mismos campos).
- Paso 5 depende de Paso 4 (implementa el contrato).
- Paso 6 depende de Pasos 2, 3, 5.
- Paso 7 depende de Pasos 1, 6.
- Paso 9 depende de Paso 8.
- Paso 10 depende de Paso 9.

### Puntos delicados

- **`_cellKeyForEditing` en `orders_table.dart`**: Actualmente recibe
  `(int productIdx, int col)` donde `productIdx` ya es el índice real (no
  filtrado). Hay que traducir a `OrderSheet.productIds[productIdx]` y
  `OrderSheet.clientIds[col]`. Asegurar que los bounds checks están antes de la
  traducción.
- **`_commitAndMove`**: Calcula `newProductIdx` y `effectiveCol` y luego genera
  la clave. Hay que traducir igual que en `_cellKeyForEditing`.
- **`didUpdateWidget` — lock huérfano**: Hay que comprobar si `_lockedCellKey`
  parsea a IDs que siguen presentes en el nuevo
  `widget.orderSheet.productIds`/`clientIds`.
- **`dispose()` del repositorio**: Es `registerLazySingleton` en GetIt — GetIt
  soporta `dispose` callback. Verificar que no se invoca antes de que el
  repositorio deje de usarse.

## 7) Estrategia de validación

### Verificación automática

- `dart analyze lib/` — sin errores ni warnings nuevos.
- `flutter test` — todos los tests existentes pasan (49 OK, 2 fallos
  preexistentes).

### Verificación manual

- Abrir la tabla de pedidos con dos usuarios.
- Usuario A edita una celda → verificar que el lock funciona.
- Usuario B elimina un cliente → verificar que el lock de A no se desplaza (si
  editaba otra columna) o se libera (si editaba la columna eliminada).
- Usuario B cambia el orden de productos desde la pantalla de productos → volver
  a la tabla → verificar que las ediciones van al producto correcto.
- Usuario B añade un cliente → verificar que los locks existentes no se
  desplazan.

### Escenarios de test recomendables

- Unit test para `cellKey()` / `stockKey()` / `parseCellKey()` con IDs.
- Unit test para `CursorInfo.fromMap` / `toMap` con nuevo formato.
- Unit test para invalidación de caché en `OrdersTodayRepositoryImpl` al emitir
  `watchAll()`.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                    | Probabilidad | Impacto                                                                                                                  | Mitigación                                |
| --------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| Deploy incremental: dos versiones coexisten temporalmente | Baja         | Bajo — locks no se ven entre versiones distintas durante unos minutos                                                    | Ventana corta; no hay corrupción de datos |
| `watchAll()` produce lecturas Firestore adicionales       | Baja         | Bajo — una lectura de colección `clients` + `products` se mantiene abierta como listener, cuenta como 1 lectura + deltas | Monitorizamos reads en consola Firebase   |
| Race condition: invalidación de caché durante escritura   | Muy baja     | Ninguno — la escritura ya resolvió los IDs antes de la invalidación                                                      | Diseño lazy garantiza esto                |

### Impacto potencial

- Funcional: Ningún cambio visible en el flujo normal del usuario.
- Rendimiento: Dos listeners Firestore adicionales (colecciones `clients` y
  `products`), coste marginal.
- Compatibilidad: Sin cambio en API de Firestore. Solo cambia el formato de
  datos en RTDB (efímero).

### Plan de rollback

- Revertir los commits del Bloque 1 y Bloque 2.
- Los datos de RTDB con formato nuevo expirarán solos en <60s (locks) o al
  desconectar (cursors).
- No hay datos persistentes que revertir.

## 9) Suposiciones

- Los IDs de Firestore no contienen `_` (confirmado por el usuario).
- Los datos de presencia en RTDB son efímeros y no requieren migración.
- `OrderSheet.clientIds` y `OrderSheet.productIds` están correctamente poblados
  y en el mismo orden que `clients`/`products` (implementado en la optimización
  anterior).
- `ClientFirestoreDataSource.watchAll()` y
  `ProductFirestoreDataSource.watchAll()` funcionan correctamente y emiten ante
  cualquier cambio en las colecciones.
- GetIt `registerLazySingleton` soporta el parámetro `dispose`.

## 10) Preguntas abiertas

Ninguna. Todas las preguntas funcionales fueron resueltas (PA-01, PA-02).

## 11) Notas para implementación

- **Restricciones técnicas**:
  - No usar `.` ni `/` como separador de cell keys (prohibidos en RTDB).
  - Usar `_` como separador (seguro según PA-01).
  - Los campos en RTDB para cursors deben ser cortos (`pid`, `cid`) para
    minimizar payload, ya que RTDB cobra por bytes transferidos.
- **Secuencia sugerida**: Implementar Bloque 1 primero (pasos 1-7), luego Bloque
  2 (pasos 8-10), luego validar (paso 11).
- **Consideraciones para no romper comportamiento existente**:
  - `didUpdateWidget` ya limpia edición y locks cuando cambia la longitud de
    clientes/productos. Solo hay que añadir la verificación de IDs huérfanos al
    cambio de estructura, lo cual se integra naturalmente en el bloque
    existente.
  - El footer de usuarios conectados solo usa `cursor.userName` y `cursor.color`
    — los campos `productId`/`clientId` del cursor no afectan la renderización
    del footer.
  - La limpieza de lock huérfano en `didUpdateWidget` debe ser silenciosa (sin
    snackbar), según PA-02.
- **Estado: Listo para implementación**
