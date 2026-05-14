# Technical Analysis: Optimización de lecturas/escrituras Firestore en pedidos de hoy

- **Fecha:** 2026-05-09
- **Identificador:** orders-firestore-reads-optimization
- **Fuente:**
  docs/functional-analysis/2026-05-09-orders-firestore-reads-optimization.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Introducir caché in-memory de catálogos (clientes/productos) en
  `OrdersTodayRepositoryImpl`, reutilizado en todas las operaciones y el stream
  watcher (OPT-1).
- Cambiar `updateCell` en repositorio, use case y BLoC para que solo escriba en
  Firestore sin re-leer — devuelve `Either<Failure, Unit>` en vez de
  `Either<Failure, OrderSheet>` (OPT-2).
- Ampliar `OrderSheet` con `clientIds` y `productIds`, cambiar
  `UpdateOrderCellParams` de índices a IDs, y mover la traducción índice→ID al
  BLoC (OPT-3).
- Eliminar `OrdersTodayCheckModifiedRequested`, su handler y
  `getSheetModifiedTime` del contrato y repositorio (OPT-4).
- Principales áreas impactadas: entidad `OrderSheet`, contrato e implementación
  del repositorio, use case `UpdateOrderCell`, BLoC, eventos.
- Riesgo general estimado: **bajo** — todos los cambios son internos a
  `orders_today`, no hay cambio en modelo de datos Firestore ni en UI.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first: `data/datasources/` → `data/repositories/` →
`domain/usecases/` → `presentation/bloc/` → `presentation/pages/`.

### Módulos relevantes

| Capa         | Artefacto                                    | Estado actual                                           |
| ------------ | -------------------------------------------- | ------------------------------------------------------- |
| Domain       | `OrderSheet`                                 | Entidad Equatable con nombres pero **sin IDs**          |
| Domain       | `OrdersTodayRepository`                      | Contrato con `updateCell` que devuelve `OrderSheet`     |
| Domain       | `UpdateOrderCell` / `UpdateOrderCellParams`  | Use case con `productRow`/`clientCol` (índices)         |
| Data         | `OrdersTodayRepositoryImpl`                  | 7× `getAll()` clientes + 7× productos, sin caché        |
| Data         | `OrdersTodayRepositoryImpl.updateCell`       | Lee doc + catálogos + re-lee post-write = **132 reads** |
| Data         | `OrdersTodayRepositoryImpl.watchTodayOrders` | Caché local al closure del stream (no compartido)       |
| Presentation | `OrdersTodayBloc._onCellUpdate`              | Optimistic update + debounced write, ignora resultado   |
| Presentation | `OrdersTodayBloc._onCheckModified`           | Handler muerto — nadie lo invoca                        |

### Restricciones

- El repositorio es singleton en GetIt → el caché en el repositorio es global y
  compartido.
- `UseCase<Type, Params>` requiere un tipo de retorno concreto — cambiar a
  `Unit` es patrón existente en el proyecto.
- `OrderSheet` usa `Equatable` — añadir `clientIds`/`productIds` a `props`
  afecta la deduplicación en `_onRemoteOrderUpdate`, pero los IDs son
  deterministas dados los mismos datos, así que no genera falsos negativos.
- `fpdart` ya provee `Unit` y `unit` — no requiere dependencia nueva.

## 3) Objetivo técnico

- Reducir lecturas Firestore de ~29.500/día a ~2.800/día (~90% reducción).
- Eliminar 0 reads en `updateCell` (actualmente 132/invocación).
- Centralizar resolución de catálogos en un caché compartido con invalidación
  automática.
- Eliminar código muerto del flujo de polling previo.
- Mantener el comportamiento funcional idéntico para el usuario.

## 4) Diseño técnico de la solución

### 4.1 — OPT-1: Caché in-memory de catálogos

**Ubicación:** `OrdersTodayRepositoryImpl` (capa data).

Añadir campos privados al repositorio:

```dart
List<ClientModel>? _cachedClients;
List<ProductModel>? _cachedProducts;
```

Métodos helper:

```dart
Future<List<ClientModel>> _getClients() async {
  return _cachedClients ??= await _clientFirestore.getAll();
}

Future<List<ProductModel>> _getProducts() async {
  return _cachedProducts ??= await _productFirestore.getAll();
}

void _invalidateCache() {
  _cachedClients = null;
  _cachedProducts = null;
}
```

**Puntos de uso:**

- Todas las llamadas actuales a `_clientFirestore.getAll()` /
  `_productFirestore.getAll()` en el repositorio se sustituyen por
  `_getClients()` / `_getProducts()`.
- En `watchTodayOrders.refreshMaps()`, se llama a `_invalidateCache()` antes de
  recargar, asegurando datos frescos cuando cambia la estructura.

**Invalidación:**

- En `watchTodayOrders`, cuando `idsChanged == true` → `_invalidateCache()` +
  recargar.
- En `_readOrderSheetWithoutSync` (usado tras add/remove) → no invalidar, porque
  el caché de nombres sigue siendo válido (la estructura cambió pero los
  catálogos no).
- Si se quisiera invalidación explícita futura → exponer un método
  `invalidateEntityCache()` en el contrato del repositorio (fuera de alcance
  actual).

### 4.2 — OPT-2: Eliminar re-lectura post-write en updateCell

**Cambio de contrato:**

```dart
// Repository contract (antes)
Future<Either<Failure, OrderSheet>> updateCell({...});

// Repository contract (después)
Future<Either<Failure, Unit>> updateCell({...});
```

**Cambio de implementación:** Eliminar del método `updateCell` en
`OrdersTodayRepositoryImpl`:

1. La lectura de `getOrderDocument` (para traducir índices) → ya no necesaria
   con OPT-3.
2. Las lecturas de `getAll()` de clientes/productos → ya no necesarias con
   OPT-3.
3. El bloque completo de re-lectura post-write (`updatedDoc`, `rows`,
   `_buildOrderSheet`).
4. Devolver `Right(unit)` tras el batch write exitoso.

**Cambio de use case:** `UpdateOrderCell` pasa de `UseCase<OrderSheet, ...>` a
`UseCase<Unit, ...>`.

**Cambio de BLoC:** En `_flushPendingWrite`, el `.then((result) {...})` ya
ignora el `OrderSheet` del resultado — no requiere cambio funcional, solo
adaptación de tipos.

### 4.3 — OPT-3: Pasar IDs directos al use case

**Ampliar `OrderSheet`:**

Añadir dos campos:

```dart
final List<String> clientIds;
final List<String> productIds;
```

Incluirlos en: constructor, `copyWith`, `props`.

**Cambiar `_buildOrderSheet`:** Pasar `clientIds` y `productIds` al constructor
de `OrderSheet`.

**Cambiar `UpdateOrderCellParams`:**

De:

```dart
final String spreadsheetId;
final int productRow;
final int clientCol;
final num value;
final DateTime date;
```

A:

```dart
final String productId;
final String? clientId;  // null = stock update
final num value;
final DateTime date;
```

`spreadsheetId` ya no es necesario (se infiere de `date`).

**Cambiar contrato y repositorio `updateCell`:**

De:

```dart
Future<Either<Failure, Unit>> updateCell({
  required String spreadsheetId,
  required int productRow,
  required int clientCol,
  required num value,
  required DateTime date,
});
```

A:

```dart
Future<Either<Failure, Unit>> updateCell({
  required String productId,
  required String? clientId,
  required num value,
  required DateTime date,
});
```

Implementación simplificada:

```dart
Future<Either<Failure, Unit>> updateCell({...}) async {
  try {
    final dateStr = _formatDate(date);
    if (clientId != null) {
      await _firestoreDataSource.updateQuantity(
        date: dateStr, productId: productId,
        clientId: clientId, value: value,
      );
    } else {
      await _firestoreDataSource.updateStock(
        date: dateStr, productId: productId, value: value,
      );
    }
    return const Right(unit);
  } on ServerException {
    return Left(ServerFailure());
  } catch (e, st) {
    _logger.error('Error updating cell', e, st);
    return Left(ServerFailure());
  }
}
```

**0 reads.** Solo 2 writes (batch en el datasource: row + root
`lastModifiedAt`).

**Cambiar BLoC `_onCellUpdate`:**

La traducción de índice a ID se hace en el BLoC, que ya tiene el `OrderSheet` en
estado:

```dart
// Translate UI indices to Firestore IDs
final numClients = sheet.clients.length;
final isStock = event.clientCol >= numClients;
final productId = sheet.productIds[event.productRow];
final clientId = isStock ? null : sheet.clientIds[event.clientCol];

_pendingWrite = UpdateOrderCellParams(
  productId: productId,
  clientId: clientId,
  value: event.value,
  date: DateTime.now(),
);
```

**Cambiar tipo de `_pendingWrite`:** `UpdateOrderCellParams?` sigue siendo el
tipo, pero con la nueva firma.

### 4.4 — OPT-4: Eliminar código muerto de polling

**Artefactos a eliminar:**

1. `OrdersTodayCheckModifiedRequested` en `orders_today_event.dart`.
2. `on<OrdersTodayCheckModifiedRequested>(_onCheckModified)` en el constructor
   del BLoC.
3. Método `_onCheckModified` completo en el BLoC.
4. `getSheetModifiedTime` del contrato `OrdersTodayRepository`.
5. `getSheetModifiedTime` de la implementación `OrdersTodayRepositoryImpl`.

### Contratos e interfaces

| Contrato                                     | Cambio                                                         |
| -------------------------------------------- | -------------------------------------------------------------- |
| `OrderSheet`                                 | + `clientIds`, + `productIds` (campos obligatorios)            |
| `OrdersTodayRepository.updateCell`           | firma: de índices a IDs, retorno: `Unit`                       |
| `OrdersTodayRepository.getSheetModifiedTime` | eliminado                                                      |
| `UpdateOrderCell`                            | `UseCase<Unit, UpdateOrderCellParams>`                         |
| `UpdateOrderCellParams`                      | de `spreadsheetId/productRow/clientCol` a `productId/clientId` |

### Flujo de datos — edición de celda (después)

```
UI tap → OrdersTable.onCellUpdated(row, col, val)
       → Page → CellUpdateRequested(row, col, val)
       → BLoC._onCellUpdate:
           1. Optimistic update local → emit
           2. Traduce row→productId, col→clientId usando sheet.productIds/clientIds
           3. Crea UpdateOrderCellParams(productId, clientId, val, date)
           4. Timer debounce 500ms → _flushPendingWrite
       → UseCase.call(params)
       → Repository.updateCell(productId, clientId, val, date)
           1. if clientId != null → datasource.updateQuantity (batch 2 writes)
           2. else → datasource.updateStock (batch 2 writes)
           3. return Right(unit)
       → Firestore listener picks up change → watchTodayOrders emits OrderSheet
       → BLoC._onRemoteOrderUpdate deduplicates
```

**Reads: 0. Writes: 2.**

### Gestión de errores y validaciones

- **Bounds check en BLoC:** Antes de traducir `productRow` / `clientCol`,
  verificar que los índices están dentro de los rangos de `sheet.productIds` y
  `sheet.clientIds`. Si están fuera, loguear warning y return (no emitir error
  al usuario — edición inválida silenciosa).
- **Caché miss en primer uso:** `_getClients()` / `_getProducts()` cargan
  automáticamente si el caché es `null`. No requiere manejo especial.
- **Error de caché refresh:** Si `getAll()` falla durante `refreshMaps()` en el
  watcher, el `handleError` del stream lo captura. El caché queda en su estado
  previo (stale pero funcional).

### Consideraciones de compatibilidad

- `OrderSheet` gana 2 campos obligatorios (`clientIds`, `productIds`). Todos los
  puntos donde se construye un `OrderSheet` deben actualizarse:
  - `_buildOrderSheet` en el repositorio (único constructor centralizado).
  - `_applyOptimisticUpdate` en el BLoC (usa `copyWith`, no afectado).
  - Tests existentes que construyan `OrderSheet` directamente.
- El `copyWith` de `OrderSheet` debe incluir los nuevos campos.

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno.

### Artefactos a modificar

| Artefacto                                                                       | Cambio esperado                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/domain/entities/order_sheet.dart`                    | + `clientIds`, + `productIds`, actualizar `copyWith`, `props`, constructor                                                                                                                                                                           |
| `lib/features/orders_today/domain/repositories/orders_today_repository.dart`    | `updateCell` nueva firma (IDs, retorno `Unit`), eliminar `getSheetModifiedTime`                                                                                                                                                                      |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart` | + caché `_cachedClients`/`_cachedProducts` + helpers, reescribir `updateCell` (0 reads), sustituir 7× `getAll()` por `_getClients()`/`_getProducts()`, `refreshMaps` invalida caché, eliminar `getSheetModifiedTime`, pasar IDs a `_buildOrderSheet` |
| `lib/features/orders_today/domain/usecases/update_order_cell.dart`              | `UseCase<Unit, ...>`, cambiar `UpdateOrderCellParams` de índices a IDs                                                                                                                                                                               |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`            | Traducción idx→ID en `_onCellUpdate`, adaptar `_pendingWrite`/`_flushPendingWrite` a nueva firma, eliminar `_onCheckModified` + registration                                                                                                         |
| `lib/features/orders_today/presentation/bloc/orders_today_event.dart`           | Eliminar `OrdersTodayCheckModifiedRequested`                                                                                                                                                                                                         |

### Artefactos a retirar o reemplazar

| Artefacto                                    | Motivo                                   |
| -------------------------------------------- | ---------------------------------------- |
| `OrdersTodayCheckModifiedRequested` (evento) | Código muerto post-migración a listeners |
| `_onCheckModified` (handler BLoC)            | Código muerto                            |
| `getSheetModifiedTime` (contrato + impl)     | Solo lo usaba `_onCheckModified`         |

## 6) Estrategia de implementación

1. **Paso 1 — Ampliar `OrderSheet`**: Añadir `clientIds`, `productIds` a la
   entidad. Actualizar constructor, `copyWith`, `props`.
2. **Paso 2 — Actualizar `_buildOrderSheet`**: Pasar `clientIds`, `productIds`
   al constructor de `OrderSheet`.
3. **Paso 3 — Caché en repositorio (OPT-1)**: Añadir `_cachedClients`,
   `_cachedProducts`, `_getClients()`, `_getProducts()`, `_invalidateCache()`.
   Sustituir todas las llamadas directas a `getAll()`.
4. **Paso 4 — Integrar caché en `watchTodayOrders`**: `refreshMaps()` llama a
   `_invalidateCache()` antes de recargar. Usar `_getClients()` /
   `_getProducts()`.
5. **Paso 5 — Cambiar contrato `updateCell` (OPT-2 + OPT-3)**: Cambiar firma en
   `OrdersTodayRepository` (de índices a IDs, retorno `Unit`).
6. **Paso 6 — Reescribir `updateCell` en repositorio**: Eliminar todas las
   lecturas, solo write + return `Right(unit)`.
7. **Paso 7 — Cambiar `UpdateOrderCell` y `UpdateOrderCellParams`**: Adaptar use
   case a `UseCase<Unit, ...>`, cambiar params de índices a IDs.
8. **Paso 8 — Adaptar BLoC**: Traducción idx→ID en `_onCellUpdate`, adaptar
   `_pendingWrite` y `_flushPendingWrite` a nueva firma/tipo.
9. **Paso 9 — Eliminar código muerto (OPT-4)**: Eliminar
   `CheckModifiedRequested` del evento, `_onCheckModified` + registration del
   BLoC, `getSheetModifiedTime` del contrato y repositorio.
10. **Paso 10 — Validar**: `dart analyze lib/` + `flutter test`.

### Orden recomendado

Seguir la numeración propuesta. Los pasos 1-2 son prerequisitos de OPT-3. El
paso 3-4 (OPT-1) es independiente y puede hacerse antes o después. Los pasos 5-8
(OPT-2+OPT-3) deben hacerse juntos. El paso 9 (OPT-4) es independiente.

### Dependencias entre pasos

- Paso 2 depende de paso 1 (nuevos campos en `OrderSheet`).
- Pasos 5-8 dependen de paso 1 (BLoC necesita `clientIds`/`productIds` en
  `OrderSheet` para traducir).
- Paso 4 depende de paso 3 (caché debe existir para que `refreshMaps` lo use).
- Paso 9 es independiente de todos los demás.

### Puntos delicados

- **`_pendingWrite` en BLoC**: Tiene tipo `UpdateOrderCellParams?`. Al cambiar
  los campos del params (paso 7), el paso 8 debe actualizarlo coordinadamente.
  Si se compila entre medias, habrá error.
- **`close()` del BLoC**: Llama a `_updateOrderCell(params)` con el pending
  write. Debe funcionar con la nueva firma.
- **`_applyOptimisticUpdate`**: Usa `event.clientCol` para detectar stock
  (`== numClients + 1`). Este comportamiento no cambia (el evento
  `CellUpdateRequested` mantiene los índices de UI, la traducción a IDs es
  posterior).

## 7) Estrategia de validación

### Automática

- `dart analyze lib/` — 0 issues.
- `flutter test` — todos los tests existentes pasan.
- Verificar que no quedan referencias a `getSheetModifiedTime`,
  `CheckModifiedRequested`, `_onCheckModified`.
- Verificar que no quedan llamadas directas a `_clientFirestore.getAll()` /
  `_productFirestore.getAll()` en el repositorio (fuera de
  `_getClients`/`_getProducts`).

### Manual

- Abrir la pantalla de pedidos de hoy, editar varias celdas rápidamente → la UI
  responde igual que antes.
- Con 2 dispositivos/sesiones: editar en uno, ver que el otro recibe el cambio
  vía listener.
- Añadir/eliminar un cliente o producto → la tabla se actualiza correctamente.
- Verificar en la consola de Firebase que las lecturas diarias se han reducido
  significativamente.

### Escenarios de prueba clave

| Escenario                                       | Esperado                           |
| ----------------------------------------------- | ---------------------------------- |
| Edición de celda quantity                       | 0 reads, 2 writes                  |
| Edición de celda stock                          | 0 reads, 2 writes                  |
| Carga inicial de pantalla                       | 1 + P + C + P reads (una sola vez) |
| Segunda edición (caché caliente)                | 0 reads                            |
| Otro usuario añade cliente (cambio estructural) | Caché se invalida, se recarga      |
| Edición rápida (debounce)                       | Solo se escribe la última          |

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                 | Probabilidad | Impacto                                       | Mitigación                                 |
| ------------------------------------------------------ | ------------ | --------------------------------------------- | ------------------------------------------ |
| Caché stale tras renombramiento sin cambio estructural | Media        | Bajo (nombre viejo hasta recarga)             | Documentado como tradeoff aceptable (S-02) |
| Race condition entre caché e invalidación en stream    | Baja         | Bajo (estado se corrige en siguiente emisión) | debounce 200ms ya mitiga ráfagas           |
| `_pendingWrite` con params viejos durante migración    | N/A          | Compilación                                   | Pasos 5-8 deben hacerse en bloque          |

### Impacto potencial

- **Positivo**: ~90% reducción de reads Firestore, código más limpio, latencia
  de escritura reducida.
- **Negativo**: Nombres stale en caso extremo de renombramiento sin cambio
  estructural.

### Plan de rollback

- Revertir los commits de la rama. No hay cambio en modelo de datos Firestore ni
  en RTDB. No hay migración de datos.

## 9) Suposiciones

- Los catálogos de clientes/productos (nombre, orden) no cambian con alta
  frecuencia durante la sesión de pedidos.
- `OrderSheet` con IDs no rompe ningún consumidor externo a `orders_today` (la
  entidad solo se usa dentro de la feature).
- El patrón `UseCase<Unit, Params>` es idiomático en este proyecto (verificado:
  9 instancias existentes).

## 10) Preguntas abiertas

Ninguna — todas las ambigüedades del análisis funcional han sido resueltas con
supuestos razonables.

## 11) Notas para implementación

- Respetar la detección de stock en el BLoC: `event.clientCol >= numClients`
  para quantity, `== numClients + 1` para stock. La lógica actual usa
  `numClients + 1` en `_applyOptimisticUpdate` pero `>= numClients` en el
  repositorio. Unificar al migrar la traducción al BLoC.
- `_buildOrderSheet` es el único punto donde se construye `OrderSheet` en el
  repositorio → cambio centralizado para añadir `clientIds`/`productIds`.
- El `copyWith` de `OrderSheet` ya cubre los nuevos campos porque los copia por
  defecto (`?? this.field`). Los tests que construyen `OrderSheet` directamente
  necesitarán pasar los nuevos campos requeridos.
- No crear nuevas dependencias ni paquetes.
- Secuencia sugerida: pasos 1-2 (entidad) → 3-4 (caché) → 5-8 (contrato+use
  case+BLoC) → 9 (limpieza) → 10 (validación).
- **Estado: Listo para implementación**
