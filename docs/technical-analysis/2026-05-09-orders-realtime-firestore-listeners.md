# Technical Analysis: Migración de sincronización en tiempo real de RTDB a Firestore listeners

- **Fecha:** 2026-05-09
- **Identificador:** orders-realtime-firestore-listeners
- **Fuente:**
  docs/functional-analysis/2026-05-09-orders-realtime-firestore-listeners.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Reemplazar la suscripción RTDB `today/cells/` por dos listeners Firestore
  (`DocumentSnapshot` sobre `orders/{date}` y `QuerySnapshot` sobre
  `orders/{date}/rows`) combinados con `Rx.combineLatest2` en un nuevo método
  del repositorio.
- Eliminar del datasource RTDB: `writeCell`, `onCellChanged`, `getAllCells`, y
  la limpieza de `cells/` en `resetToday`.
- Eliminar del BLoC: `_onRemoteCell`, `_onRtdbSubscription`, `_cellSub`, y el
  write a RTDB en `_onCellUpdate`. Sustituirlos por un nuevo handler
  `_onRemoteOrderUpdate` que reciba `OrderSheet` completos desde el stream de
  Firestore.
- Eliminar DTOs: `CellDelta`, `cell_key_utils.dart`. Eliminar eventos:
  `OrdersTodayRemoteCellReceived`, `OrdersTodayRtdbSubscriptionStarted`.
- Añadir nuevo evento `OrdersTodayRemoteOrderUpdated` y nuevo método
  `watchTodayOrders(DateTime)` en repositorio/datasource.
- Principales áreas impactadas: datasource Firestore, datasource RTDB,
  repositorio, BLoC, eventos, página, DI module.
- Riesgo general estimado: **medio** — el cambio toca la capa de sincronización
  en tiempo real que es central para la UX colaborativa, pero no modifica el
  modelo de datos ni la UI.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con BLoC, GetIt (DI), fpdart (Either).
- Capas: `data/datasources/remote/` → `data/repositories/` → `domain/usecases/`
  → `presentation/bloc/` → `presentation/pages/`.

### Módulos relevantes

| Capa       | Artefacto                            | Rol actual                                                                      |
| ---------- | ------------------------------------ | ------------------------------------------------------------------------------- |
| Datasource | `OrderFirestoreDataSourceImpl`       | CRUD Firestore (reads one-shot, no streams)                                     |
| Datasource | `OrdersRtdbDataSourceImpl`           | Cells broadcast + locks + cursors vía RTDB                                      |
| Repository | `OrdersTodayRepositoryImpl`          | Coordina Firestore DS + client/product DS para construir `OrderSheet`           |
| BLoC       | `OrdersTodayBloc`                    | Gestiona estado, optimistic updates, suscripción RTDB cells, debounce Firestore |
| BLoC       | `OrdersPresenceCubit`                | Locks + cursors vía RTDB (NO se toca)                                           |
| Eventos    | `OrdersTodayRemoteCellReceived`      | Recibe un delta de celda individual desde RTDB                                  |
| Eventos    | `OrdersTodayRtdbSubscriptionStarted` | Inicia la suscripción RTDB                                                      |
| DTOs       | `CellDelta`, `cell_key_utils.dart`   | Parsing de claves RTDB de celdas                                                |
| Page       | `_OrdersTodayContentState`           | Decide si usar RTDB push o polling fallback                                     |
| DI         | `orders_today_module.dart`           | Registra RTDB DS, BLoC con `rtdbDataSource` param                               |

### Restricciones relevantes

- El debounce de 500ms para escrituras a Firestore se mantiene (decisión
  confirmada PA-01).
- Las selecciones se limpian ante cambios estructurales remotos (decisión
  confirmada PA-02).
- `PresenceCubit` + RTDB locks/cursors no se modifican.
- Los name maps y order maps de clientes/productos son necesarios para
  `_buildOrderSheet` — deben estar disponibles para el listener.

### Dependencias

- `cloud_firestore` → `DocumentReference.snapshots()`,
  `CollectionReference.snapshots()`
- `firebase_database` → se mantiene para presencia
- `rxdart` → `Rx.combineLatest2` para fusionar los dos streams (verificar si ya
  está en el proyecto, si no, añadir)

## 3) Objetivo técnico

- **Qué debe cambiar**: el canal de sincronización entre usuarios pasa de RTDB
  `cells/` a Firestore `snapshots()` para datos de pedidos.
- **Qué resultado se persigue**: cualquier cambio (celda, estructura) se propaga
  automáticamente a todos los usuarios via Firestore listeners, eliminando la
  dual-write y el gap de cambios estructurales.
- **Limitaciones a respetar**:
  - No modificar el modelo de datos Firestore.
  - No modificar la UI.
  - No modificar presencia (locks/cursors) en RTDB.
  - Mantener optimistic update local para el usuario que edita.
  - Mantener debounce 500ms.

## 4) Diseño técnico de la solución

### Enfoque propuesto

**Dos listeners Firestore** fusionados en un solo stream de `OrderSheet`:

```
Stream<OrderSheet> watchTodayOrders(date)
  ├─ orderDoc.snapshots()   → cambios en clientIds/productIds/lastModifiedAt
  ├─ rowsCollection.snapshots() → cambios en quantities/stock
  └─ Rx.combineLatest2 → _buildOrderSheet() → OrderSheet
```

El stream se crea a nivel de **datasource Firestore** (raw snapshots) y se
transforma a `OrderSheet` en el **repositorio** (que tiene acceso a name/order
maps).

El **BLoC** se suscribe al stream del repositorio y emite `OrdersTodayLoaded`
cuando recibe un nuevo `OrderSheet`, con lógica de deduplicación para evitar
re-renders del propio usuario.

### Componentes / módulos / servicios afectados

1. **`OrderFirestoreDataSource`** (contrato + impl) — añadir métodos de watch
2. **`OrdersTodayRepository`** (contrato + impl) — añadir `watchTodayOrders`
3. **`OrdersTodayBloc`** — nuevo handler, eliminar RTDB cell logic
4. **`OrdersTodayEvent`** — nuevo evento, eliminar 2 eventos
5. **`OrdersRtdbDataSource`** (contrato + impl) — eliminar 3 métodos de cells
6. **`orders_today_page.dart`** — simplificar init (no más RTDB subscription
   check)
7. **`orders_today_module.dart`** — ajustar DI (BLoC ya no necesita
   `rtdbDataSource`)
8. **DTOs** — eliminar `cell_delta.dart`, `cell_key_utils.dart`

### Contratos e interfaces

#### Nuevo en `OrderFirestoreDataSource`

```dart
/// Stream of the root order document changes.
Stream<OrderDocumentModel?> watchOrderDocument(String date);

/// Stream of all row subdocument changes.
Stream<List<OrderRowModel>> watchOrderRows(String date);
```

#### Nuevo en `OrdersTodayRepository`

```dart
/// Stream that emits a new OrderSheet whenever the order data changes
/// (structure or cell values).
Stream<OrderSheet?> watchTodayOrders(DateTime date);
```

#### Nuevo evento

```dart
final class OrdersTodayRemoteOrderUpdated extends OrdersTodayEvent {
  const OrdersTodayRemoteOrderUpdated({required this.orderSheet});
  final OrderSheet orderSheet;
}
```

#### Eliminados

- `OrdersTodayRemoteCellReceived` (evento)
- `OrdersTodayRtdbSubscriptionStarted` (evento)
- `OrdersRtdbDataSource.writeCell` (método)
- `OrdersRtdbDataSource.onCellChanged` (método)
- `OrdersRtdbDataSource.getAllCells` (método)
- `CellDelta` (DTO)
- `cell_key_utils.dart` (utilidad)

### Flujo de datos o de control

```
[Firestore]
  orders/{date} doc  ──snapshots()──► Stream<OrderDocumentModel?>
  orders/{date}/rows ──snapshots()──► Stream<List<OrderRowModel>>
                                          │
                                          ▼
                              Rx.combineLatest2
                                          │
                                          ▼
                        Repository: _buildOrderSheet()
                        + name/order maps (cacheados)
                                          │
                                          ▼
                              Stream<OrderSheet?>
                                          │
                                          ▼
                        BLoC: _onRemoteOrderUpdate
                        (dedup via Equatable / hasPendingWrites)
                                          │
                                          ▼
                           emit OrdersTodayLoaded
```

**Flujo de edición de celda (usuario local)**:

```
User edits cell
  ├─ BLoC: optimistic update → emit OrdersTodayLoaded (instant)
  └─ BLoC: debounced Firestore write (500ms)
       └─ Firestore write completes
            └─ Own listener fires
                 └─ BLoC: detects sheet == current state → NO re-emit
```

**Flujo de cambio estructural (usuario remoto)**:

```
Remote user adds client
  └─ Firestore doc changes (clientIds[])
       └─ Local listener fires
            └─ Repository builds new OrderSheet (new column)
                 └─ BLoC: detects sheet != current → emit OrdersTodayLoaded
                      └─ UI: table rebuilt with new column
                           └─ Selections cleared (PA-02)
```

### Gestión de errores y validaciones

- **Listener error**: Firestore `snapshots()` puede emitir errors. El stream en
  el repositorio debe `handleError` logueando y emitiendo un failure/null sin
  romper la suscripción.
- **Name/order maps stale**: si un cliente/producto cambia de nombre después de
  cachear, el nombre se verá desactualizado hasta el próximo re-read. Impacto
  bajo; se puede re-leer periódicamente o al detectar IDs desconocidos.
- **Snapshot sin doc**: si el documento raíz se borra (caso extremo), el stream
  emite `null` → el BLoC puede emitir `OrdersTodayNoFile`.

### Consideraciones de compatibilidad o migración

- **Sin migración de datos**: no hay cambios en el modelo Firestore.
- **rxdart**: verificar si ya está en `pubspec.yaml`. Si no, añadirlo.
- **RTDB cells node existente**: los datos en `today/cells/` quedan huérfanos
  pero no causan problemas. Se pueden limpiar manualmente o ignorar (se
  sobrescriben en cada `resetToday`).
- **Rollback**: si se revierte, basta con restaurar los archivos modificados. No
  hay migración de datos que deshacer.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                | Propósito |
| -------------------------------------------------------- | --------- |
| Ninguno — solo se añaden métodos a artefactos existentes | —         |

### Artefactos a modificar

| Artefacto                                                       | Cambio esperado                                                                                                                                                                            |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `data/datasources/remote/order_firestore_data_source.dart`      | Añadir `watchOrderDocument()` y `watchOrderRows()` al contrato                                                                                                                             |
| `data/datasources/remote/order_firestore_data_source_impl.dart` | Implementar los dos métodos watch con `snapshots()`                                                                                                                                        |
| `data/datasources/remote/orders_rtdb_data_source.dart`          | Eliminar `writeCell`, `onCellChanged`, `getAllCells` del contrato                                                                                                                          |
| `data/datasources/remote/orders_rtdb_data_source_impl.dart`     | Eliminar implementaciones de los 3 métodos + `_cellsRef`, simplificar `resetToday`                                                                                                         |
| `domain/repositories/orders_today_repository.dart`              | Añadir `watchTodayOrders(DateTime)` al contrato                                                                                                                                            |
| `data/repositories/orders_today_repository_impl.dart`           | Implementar `watchTodayOrders` con `combineLatest2`, cachear name/order maps                                                                                                               |
| `presentation/bloc/orders_today_event.dart`                     | Añadir `OrdersTodayRemoteOrderUpdated`; eliminar `OrdersTodayRemoteCellReceived` y `OrdersTodayRtdbSubscriptionStarted`                                                                    |
| `presentation/bloc/orders_today_bloc.dart`                      | Añadir `_onRemoteOrderUpdate`; eliminar `_onRemoteCell`, `_onRtdbSubscription`, `_cellSub`, RTDB write en `_onCellUpdate`; eliminar parámetro `rtdbDataSource`; añadir stream subscription |
| `presentation/pages/orders_today_page.dart`                     | Eliminar lógica de RTDB subscription/polling fallback en `_OrdersTodayContentState.initState`                                                                                              |
| `app/di/modules/orders_today_module.dart`                       | Quitar `rtdbDataSource` del BLoC constructor; mantener RTDB DS registration solo para `PresenceCubit`                                                                                      |

### Artefactos a retirar o reemplazar

| Artefacto                      | Motivo                                                   |
| ------------------------------ | -------------------------------------------------------- |
| `data/dto/cell_delta.dart`     | Solo lo usaba el broadcast RTDB de celdas                |
| `data/dto/cell_key_utils.dart` | Solo lo usaba el BLoC para parsear claves RTDB de celdas |

## 6) Estrategia de implementación

### Pasos ordenados

1. **Verificar rxdart en pubspec.yaml** — si no existe, añadirlo como
   dependencia.

2. **Datasource Firestore — añadir watch methods** — implementar
   `watchOrderDocument` y `watchOrderRows` en contrato e implementación. Estos
   son métodos puros que devuelven `Stream<T>` mapeando `snapshots()`.

3. **Repository — implementar `watchTodayOrders`** — usar `Rx.combineLatest2`
   sobre los dos streams del datasource, aplicar `_buildOrderSheet` con
   name/order maps cacheados, añadir debounce de ~200ms al stream combinado para
   agrupar ráfagas.

4. **Eventos — crear `OrdersTodayRemoteOrderUpdated`** — nuevo evento sealed
   class.

5. **BLoC — integrar stream del repositorio** — añadir
   `StreamSubscription<OrderSheet?>`, handler `_onRemoteOrderUpdate` con
   deduplicación, iniciar suscripción tras `_loadOrders` exitoso. Eliminar RTDB
   write en `_onCellUpdate`. Eliminar `_onRemoteCell`, `_onRtdbSubscription`,
   `_cellSub`.

6. **Page — simplificar initState** — eliminar la lógica condicional de
   `rtdbDataSource != null` vs polling. El BLoC ahora gestiona internamente su
   suscripción Firestore.

7. **DI module — ajustar BLoC** — quitar `rtdbDataSource` param del constructor
   del BLoC. RTDB DS se mantiene registrado solo para `PresenceCubit`.

8. **Datasource RTDB — limpiar cells** — eliminar `writeCell`, `onCellChanged`,
   `getAllCells` del contrato e impl. Simplificar `resetToday` (ya no necesita
   limpiar `cells/`). Eliminar `_cellsRef`.

9. **Eliminar eventos obsoletos** — quitar `OrdersTodayRemoteCellReceived` y
   `OrdersTodayRtdbSubscriptionStarted`.

10. **Eliminar DTOs obsoletos** — borrar `cell_delta.dart` y
    `cell_key_utils.dart`.

11. **Limpiar selecciones ante cambios estructurales** — en `OrdersTable`,
    cuando el `OrderSheet` cambia de estructura (distinto número de
    clients/products), limpiar `_selectedColumns`, `_selectedRows`, y cancelar
    edición activa si existe.

12. **Validar** — `dart analyze lib/`, ejecutar tests existentes.

### Orden recomendado

```
[2] Datasource watch → [3] Repository stream → [4] Nuevo evento
  → [5] BLoC integración → [6] Page simplificación → [7] DI ajuste
    → [8] RTDB cleanup → [9] Eventos obsoletos → [10] DTOs obsoletos
      → [11] Selecciones → [12] Validación
```

Paso [1] (rxdart) se hace primero si es necesario.

### Dependencias entre pasos

- Paso 3 depende de 2 (datasource watch methods)
- Paso 5 depende de 3 y 4 (repository stream + nuevo evento)
- Paso 6 depende de 5 (BLoC ya gestiona internamente)
- Pasos 8-10 son independientes entre sí pero dependen de 5 (para no romper
  compilación)
- Paso 11 es independiente de 8-10

### Puntos delicados

- **Deduplicación de optimistic updates**: el BLoC debe comparar el `OrderSheet`
  recibido del listener con el estado actual. Si son iguales (por `Equatable`),
  no debe emitir. Esto evita el re-render cuando el propio usuario genera el
  cambio.
- **Cache de name/order maps**: `_buildOrderSheet` necesita maps de nombres y
  orden. En el stream, no podemos hacer `await getAll()` en cada snapshot (sería
  costoso). Solución: cachear los maps al iniciar el watch y re-leerlos solo
  cuando cambia la lista de IDs (cambio estructural), detectado comparando
  `clientIds`/`productIds` del snapshot anterior.
- **hasPendingWrites**: Firestore emite snapshots con
  `metadata.hasPendingWrites == true` para escrituras locales aún no
  confirmadas. Se puede usar como señal adicional de deduplicación, pero la
  comparación por `Equatable` ya es suficiente.
- **Cancelación del stream**: el stream debe cancelarse en `BLoC.close()` y
  también si el pedido se elimina (estado → `OrdersTodayNoFile`).
- **Edición activa + cambio estructural remoto**: si el usuario está editando la
  celda (3, 2) y un cambio remoto elimina la columna 1, la columna 2 ahora es
  otra. Hay que cancelar la edición activa cuando la estructura cambia.

## 7) Estrategia de validación

### Verificación automática

- `dart analyze lib/` — 0 errores, 0 warnings.
- Tests unitarios existentes del BLoC y repositorio — deben pasar (algunos
  necesitarán adaptación por cambio de API).
- Buscar referencias huérfanas a artefactos eliminados (`CellDelta`,
  `cell_key_utils`, `RemoteCellReceived`, `RtdbSubscriptionStarted`,
  `writeCell`, `onCellChanged`, `getAllCells`) — grep para confirmar 0
  resultados.

### Validación manual

- **Escenario 1**: Abrir app en 2 dispositivos/ventanas. Editar una celda en uno
  → verificar que el otro la ve actualizada en ≤1s.
- **Escenario 2**: En dispositivo A, añadir un cliente. Verificar que
  dispositivo B ve la nueva columna sin refrescar.
- **Escenario 3**: En dispositivo A, eliminar un producto. Verificar que
  dispositivo B ve la fila desaparecer.
- **Escenario 4**: Editar una celda rápidamente (cambiar valor 3 veces
  seguidas). Verificar que no hay parpadeos en el dispositivo que edita.
- **Escenario 5**: Con una edición activa (celda en modo edición), que otro
  dispositivo elimine una columna. Verificar que la edición se cancela
  limpiamente.
- **Escenario 6**: Verificar que cursores y locks siguen funcionando (RTDB no
  roto).

### Tipos de pruebas recomendables

- **Unit tests**: mock de Firestore streams para repositorio y BLoC. Verificar
  deduplicación, cambios estructurales, errores.
- **Integration test manual**: 2 instancias de la app en paralelo contra
  Firestore real.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                               | Probabilidad | Impacto | Mitigación                                                                                                                                                                                                                                 |
| ---------------------------------------------------- | ------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Latencia de Firestore snapshots mayor de lo esperado | Baja         | Medio   | Aceptable según RF-01 (≤1s). Si es problemático, reducir debounce del stream de 200ms a 100ms                                                                                                                                              |
| Re-renders excesivos si la deduplicación falla       | Media        | Bajo    | `Equatable` en `OrderSheet` + test unitario de deduplicación                                                                                                                                                                               |
| Name/order maps desactualizados si cambian entidades | Baja         | Bajo    | Re-leer maps cuando cambia la estructura (IDs distintos)                                                                                                                                                                                   |
| rxdart no presente en el proyecto                    | Baja         | Bajo    | Se verifica y se añade como primer paso                                                                                                                                                                                                    |
| `PresenceCubit` depende de métodos RTDB eliminados   | Nula         | Alto    | `PresenceCubit` solo usa `onLockChanged`, `onCursorChanged`, `acquireLock`, `releaseLock`, `updateMyCursor`, `setupDisconnectCleanup`, `cleanExpiredLocks`, `getAllLocks`, `getAllCursors`, `removeMyCursor` — ninguno de estos se elimina |

### Impacto potencial

- **Usuarios**: mejora — ven cambios estructurales en tiempo real (antes no
  podían).
- **Performance**: neutro a ligeramente mejor — se elimina una escritura (RTDB
  fire-and-forget) por cada edición.
- **Costes**: reducción de uso de RTDB (menos datos, solo presencia). Aumento
  marginal de Firestore reads por snapshots (compensado por eliminación del
  polling de `modifiedTime`).

### Plan de rollback

- Git revert de todos los commits del cambio. No hay migración de datos que
  deshacer.
- El nodo `today/cells/` de RTDB seguirá existiendo (no se borra) y el código
  antiguo puede volver a usarlo.

## 9) Suposiciones

- `rxdart` se puede añadir al proyecto sin conflictos de versiones.
- `Equatable` en `OrderSheet` funciona correctamente para comparar listas
  anidadas (quantities matrix). Si no, se añade un `listEquals` profundo.
- Los snapshots de Firestore en subcollecciones notifican solo los documentos
  que cambiaron, no toda la colección (comportamiento estándar de
  `QuerySnapshot`).
- El volumen de datos (típicamente ≤50 productos × ≤30 clientes) es
  suficientemente pequeño para que `_buildOrderSheet` en cada snapshot sea
  negligible en tiempo.
- `cell_key_utils.dart` no es usado fuera del BLoC y los eventos RTDB.

## 10) Preguntas abiertas

- Ninguna. Todas las decisiones necesarias están resueltas.

## 11) Notas para implementación

- **Restricción clave**: no modificar `OrdersPresenceCubit` ni su relación con
  RTDB. Solo se eliminan los métodos de RTDB relacionados con `cells/`.
- **Secuencia sugerida**: empezar por los pasos de adición (watch methods,
  stream, nuevo evento) antes de los de eliminación (RTDB cleanup, borrar DTOs),
  para mantener el código compilable en cada paso intermedio.
- **Cache de maps**: cachear `clientNameMap`, `productNameMap`,
  `clientOrderMap`, `productOrderMap` como estado del repositorio o como
  variable del stream builder. Invalidar cuando cambian los IDs del documento.
- **Debounce del stream combinado**: usar
  `.debounceTime(Duration(milliseconds: 200))` de rxdart sobre el
  `combineLatest2` para evitar reconstrucciones múltiples ante ráfagas.
- **Limpieza de selecciones**: en `OrdersTable`, comparar
  `widget.orderSheet.clients.length` y `widget.orderSheet.products.length` con
  los valores anteriores en `didUpdateWidget`. Si difieren, limpiar selecciones
  y cancelar edición activa.
- **No romper comportamiento existente**: el flujo de creación de pedido
  (`createTodaySheet`) no cambia. Tras crear el pedido, el listener lo detectará
  automáticamente y emitirá el estado cargado.
- **Estado: Listo para implementación**
