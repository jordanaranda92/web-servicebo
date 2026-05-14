# Technical Analysis: Migración de pedidos de hoy de Google Sheets a Firestore

- **Fecha:** 2026-05-09
- **Identificador:** orders-firestore-migration
- **Fuente:** docs/functional-analysis/2026-05-09-orders-firestore-migration.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Reemplazar el datasource de Google Sheets (`OrdersSheetDataSource`) y sus
dependencias de Google Drive/Sheets API en la feature `orders_today` por un
nuevo datasource de Firestore (`OrderFirestoreDataSource`) que opera
directamente contra la colección `orders/{YYYY-MM-DD}` con subcolección
`rows/{productId}`.

- **Áreas impactadas:** capa `data` de `orders_today` (nuevo datasource, nuevo
  DTO/modelo, repositorio), módulo DI, y adaptación menor del BLoC para
  sincronización de clientes/productos activos.
- **Capas que NO cambian:** entidad de dominio `OrderSheet`, contrato del
  repositorio `OrdersTodayRepository` (se mantiene), capa de presentación
  completa (UI intacta).
- **RTDB se mantiene** sin cambios para sincronización en tiempo real.
- **Riesgo general estimado:** Medio — el cambio es significativo en la capa
  data pero está bien aislado por Clean Architecture. El dominio y la
  presentación no se ven afectados.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC, GetIt (DI), fpdart (`Either`).

### Estructura actual de `orders_today`

```
orders_today/
├── data/
│   ├── datasources/
│   │   ├── local/           → (vacío)
│   │   └── remote/
│   │       ├── excel_drive_data_source.dart      → ExcelDriveDataSource (legacy, no usado por esta feature)
│   │       ├── excel_drive_data_source_impl.dart
│   │       ├── orders_rtdb_data_source.dart       → OrdersRtdbDataSource (locks, cursores, deltas)
│   │       ├── orders_rtdb_data_source_impl.dart
│   │       ├── orders_sheet_data_source.dart       → OrdersSheetDataSource (Google Sheets API)
│   │       └── orders_sheet_data_source_impl.dart
│   ├── dto/
│   │   ├── cell_delta.dart
│   │   ├── cell_key_utils.dart
│   │   ├── cursor_info.dart
│   │   ├── lock_info.dart
│   │   └── order_sheet_data.dart    → OrderSheetData (DTO actual)
│   └── repositories/
│       └── orders_today_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── order_sheet.dart         → OrderSheet
│   ├── repositories/
│   │   └── orders_today_repository.dart
│   └── usecases/
│       ├── create_today_file.dart
│       ├── get_today_orders.dart
│       └── update_order_cell.dart
└── presentation/
    ├── bloc/                        → OrdersTodayBloc, events, states, presence
    ├── pages/                       → OrdersTodayPage, OrdersViewPage
    └── widgets/                     → OrdersTable, toolbar, empty/error states
```

### Flujo actual de datos (a reemplazar)

1. `OrdersTodayRepositoryImpl` recibe `OrdersSheetDataSource` +
   `GoogleSheetsDataSource` (core) + `GoogleDriveRemoteDataSource` +
   `SettingsLocalDataSource` + `ProductFirestoreDataSource`.
2. Para leer: llama a
   `_sheetDataSource.readTodaySheet(historicoFolderId, dateStr)` que busca el
   archivo en Drive y lee celdas vía Sheets API → retorna `OrderSheetData`
   (DTO).
3. Para crear: lee clientes activos de Google Sheets (hoja "clientes" del
   spreadsheet "configuración" en Drive) y productos activos de Firestore
   (`ProductFirestoreDataSource`); llama a
   `_sheetDataSource.createTodaySheet(...)` que copia plantilla + escribe
   datos + fórmulas + formato.
4. Para editar: llama a `_sheetDataSource.updateCell(...)` vía Sheets API, luego
   re-lee el sheet completo.
5. RTDB opera en paralelo para locks/cursores/deltas en tiempo real.

### Modelo de dominio actual (se mantiene)

```dart
class OrderSheet extends Equatable {
  final String date;
  final List<String> clients;     // nombres de clientes (columnas)
  final List<String> products;    // nombres de productos (filas)
  final List<List<num>> quantities; // quantities[productIdx][clientIdx]
  final List<num> pedidos;        // sum por producto
  final List<num> stocks;         // stock por producto
  final List<num> quedan;         // stocks - pedidos
  final List<int> clientOrders;   // números de orden
  final String? spreadsheetId;    // ID del sheet en Drive
  final DateTime? modifiedTime;   // última modificación
}
```

### Dependencias relevantes

- `cloud_firestore: ^6.3.0` — ya en `pubspec.yaml`.
- `firebase_database` — ya en uso para RTDB.
- `ClientFirestoreDataSource` — colección `clients` en Firestore (tiene
  `getAll()`, `watchAll()`).
- `ProductFirestoreDataSource` — colección `products` en Firestore (tiene
  `getAll()`, `watchAll()`).
- `SettingsLocalDataSource` — actualmente provee IDs de carpetas de Drive
  (`historicoFolderId`, `plantillasFolderId`, etc.).

### Restricciones

- No introducir nuevas dependencias externas (`cloud_firestore` ya existe).
- No modificar la capa de presentación (UI intacta).
- No eliminar `OrdersSheetDataSource` ni `ExcelDriveDataSource` (otras features
  o código futuro podría referenciarlos).
- RTDB se mantiene: `OrdersRtdbDataSource`, DTOs de `cell_delta`,
  `cell_key_utils`, `cursor_info`, `lock_info` no se tocan.

## 3) Objetivo técnico

1. **Crear** un nuevo datasource `OrderFirestoreDataSource` que opere contra
   Firestore (`orders/{YYYY-MM-DD}` + subcolección `rows/{productId}`).
2. **Reescribir** `OrdersTodayRepositoryImpl` para usar el nuevo datasource en
   lugar de `OrdersSheetDataSource`, `GoogleSheetsDataSource` y
   `GoogleDriveRemoteDataSource`.
3. **Implementar** la lógica de sincronización dinámica de clientes/productos
   activos al cargar un pedido existente (RF-11, RF-12).
4. **Adaptar** el módulo DI para inyectar el nuevo datasource.
5. **Eliminar** la dependencia del repositorio con `SettingsLocalDataSource` (ya
   no necesita IDs de carpetas de Drive), `GoogleSheetsDataSource` y
   `GoogleDriveRemoteDataSource`.
6. **Mantener** el contrato del repositorio `OrdersTodayRepository` y la entidad
   `OrderSheet` sin cambios de firma.

### Limitaciones a respetar

- `OrderSheet.spreadsheetId` pasa a contener el document ID de Firestore
  (`YYYY-MM-DD`) en vez de un Google Sheets ID. Internamente compatible (es un
  `String?`), pero semánticamente cambia. La UI no lo usa directamente.
- `OrderSheet.modifiedTime` sigue funcionando (se lee del campo `lastModifiedAt`
  del documento).
- `OrderSheet.clientOrders` se genera como secuencia 1..N basándose en el orden
  de `clientIds`.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear un datasource de Firestore que encapsula toda la lectura/escritura contra
la colección `orders`. El repositorio orquesta la resolución de nombres (join
con `clients`/`products`) y la sincronización dinámica. El BLoC y la UI no
cambian.

### Componentes / módulos / servicios afectados

| Componente                                       | Tipo de cambio                                                                              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| **Nuevo:** `OrderFirestoreDataSource` (contrato) | Crear                                                                                       |
| **Nuevo:** `OrderFirestoreDataSourceImpl`        | Crear                                                                                       |
| **Nuevo:** `OrderDocumentModel` (modelo/DTO)     | Crear                                                                                       |
| **Nuevo:** `OrderRowModel` (modelo/DTO)          | Crear                                                                                       |
| `OrdersTodayRepositoryImpl`                      | Reescribir: usar nuevo datasource                                                           |
| `OrdersTodayRepository` (contrato)               | Sin cambios de firma                                                                        |
| `OrderSheet` (entity)                            | Sin cambios                                                                                 |
| `OrderSheetData` (DTO actual)                    | Deja de usarse en esta feature (no eliminar)                                                |
| `OrdersSheetDataSource`                          | Deja de usarse en esta feature (no eliminar)                                                |
| `orders_today_module.dart` (DI)                  | Actualizar registros                                                                        |
| `OrdersTodayBloc`                                | Cambio menor: `_flushPendingSheetsWrite` → adaptación (la escritura ya no es "Sheets sync") |
| Use cases                                        | Sin cambios (operan sobre el contrato del repositorio)                                      |
| Presentación                                     | Sin cambios                                                                                 |

### Contratos e interfaces

#### Nuevo datasource: `OrderFirestoreDataSource`

```dart
abstract class OrderFirestoreDataSource {
  /// Verifica si existe el documento de pedido para [date].
  Future<bool> exists(String date);

  /// Lee el documento raíz de pedido para [date].
  /// Retorna null si no existe.
  Future<OrderDocumentModel?> getOrderDocument(String date);

  /// Lee todos los subdocumentos de la subcolección rows para [date].
  Future<List<OrderRowModel>> getOrderRows(String date);

  /// Crea el documento raíz y todos los subdocumentos de rows.
  /// Usa batched write para atomicidad.
  Future<void> createOrder({
    required String date,
    required List<String> clientIds,
    required List<String> productIds,
  });

  /// Actualiza la cantidad de un cliente para un producto.
  /// Si [value] es 0, elimina la entrada del mapa (sparse).
  /// Actualiza lastModifiedAt del documento raíz.
  Future<void> updateQuantity({
    required String date,
    required String productId,
    required String clientId,
    required num value,
  });

  /// Actualiza el stock de un producto.
  /// Actualiza lastModifiedAt del documento raíz.
  Future<void> updateStock({
    required String date,
    required String productId,
    required num value,
  });

  /// Sincroniza clientIds/productIds y subdocumentos de rows
  /// con las listas de clientes/productos activos actuales.
  /// Retorna true si hubo cambios.
  Future<bool> syncActiveEntities({
    required String date,
    required List<String> activeClientIds,
    required List<String> activeProductIds,
  });
}
```

#### Modelos / DTOs Firestore

```dart
/// Modelo del documento raíz orders/{YYYY-MM-DD}
class OrderDocumentModel {
  final String date;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final List<String> clientIds;
  final List<String> productIds;

  // fromFirestore, toMap
}

/// Modelo de subdocumento orders/{YYYY-MM-DD}/rows/{productId}
class OrderRowModel {
  final String productId;
  final Map<String, num> quantities; // clientId → cantidad (sparse)
  final num stock;

  // fromFirestore, toMap
}
```

### Flujo de datos — Lectura (nuevo)

```
OrdersTodayBloc
  → GetTodayOrders (use case)
    → OrdersTodayRepository.getTodayOrders(date)
      → OrderFirestoreDataSource.getOrderDocument(dateStr)
        → Firestore: orders/{YYYY-MM-DD}.get()
      → Si null → retorna Right(null) → estado NoFile
      → OrderFirestoreDataSource.getOrderRows(dateStr)
        → Firestore: orders/{YYYY-MM-DD}/rows.get()
      → ClientFirestoreDataSource.getAll()
      → ProductFirestoreDataSource.getAll()
      → Sincronizar activos vs documento (RF-11, RF-12)
      → Resolver nombres: clientIds → client.name, productIds → product.name
      → Calcular pedidos[], stocks[], quedan[]
      → Construir OrderSheet → Right(orderSheet)
```

### Flujo de datos — Creación (nuevo)

```
OrdersTodayBloc
  → CreateTodayFile (use case)
    → OrdersTodayRepository.createTodaySheet(date)
      → ClientFirestoreDataSource.getAll() → filtrar isActive, ordenar por order
      → ProductFirestoreDataSource.getAll() → filtrar isActive, ordenar por order
      → OrderFirestoreDataSource.createOrder(date, clientIds, productIds)
        → Firestore batched write:
          - set orders/{YYYY-MM-DD} { createdAt, lastModifiedAt, clientIds, productIds }
          - set orders/{YYYY-MM-DD}/rows/{productId} { quantities: {}, stock: 0 } × N
      → Leer y construir OrderSheet (reutilizando flujo de lectura)
```

### Flujo de datos — Edición de celda (nuevo)

```
OrdersTodayBloc
  → Optimistic update local (ya existe, sin cambios)
  → RTDB write (ya existe, sin cambios)
  → UpdateOrderCell (use case) — debounced
    → OrdersTodayRepository.updateCell(...)
      → Resolver productId desde productIdx: usar productIds[productRow]
      → Resolver clientId desde clientIdx: usar clientIds[clientCol]
      → Si es celda de cantidad:
        → OrderFirestoreDataSource.updateQuantity(date, productId, clientId, value)
      → Si es celda de stock:
        → OrderFirestoreDataSource.updateStock(date, productId, value)
      → Re-leer y retornar OrderSheet actualizado
```

### Flujo de datos — Sincronización de activos (RF-11, RF-12)

```
Al cargar el pedido (getTodayOrders):
  1. Leer documento raíz → clientIds, productIds almacenados.
  2. Leer clientes/productos activos de Firestore.
  3. Comparar:
     - Nuevos clientes activos no en clientIds → añadir a clientIds.
     - clientIds con clientes no activos → eliminar de clientIds + limpiar quantities.
     - Nuevos productos activos no en productIds → añadir a productIds + crear subdocumento rows.
     - productIds con productos no activos → eliminar de productIds + eliminar subdocumento rows.
  4. Si hubo cambios → syncActiveEntities() ejecuta batched write.
  5. Continuar con la lectura normal.
```

### Gestión de errores y validaciones

- **Documento no existe al crear:** usar `set()` con merge para idempotencia
  (FA-01 — creación duplicada). Si ya existe, se lee el existente.
- **Cantidad = 0:** se elimina la clave del mapa `quantities` vía
  `FieldValue.delete()` (RF sparse, EC-03).
- **Cliente/producto eliminado de Firestore:** al sincronizar, si un ID en
  `clientIds`/`productIds` no se encuentra en las colecciones, se trata como
  desactivado y se elimina (EC-02).
- **Errores de Firestore:** se capturan `FirebaseException` y se mapean a
  `ServerFailure`.
- **Sin conexión:** Firestore lanzará error → se propaga como `ServerFailure` →
  el BLoC emite `OrdersTodayError` (sin cambios en el flujo de error actual).

### Consideraciones de compatibilidad o migración

- **No hay migración de datos**: los pedidos históricos en Google Sheets se
  mantienen accesibles vía `orders_history`.
- **Cambio semántico de `spreadsheetId`**: pasa de ser un Google Sheets ID a ser
  el date string (`YYYY-MM-DD`). Internamente el BLoC lo usa para saber si hay
  un sheet cargado y para pasar al use case de `updateCell`. El repositorio lo
  reinterpretará como date.
- **`OrderSheet.clientOrders`**: se genera como
  `List.generate(clientIds.length, (i) => i + 1)`.
- **`OrderSheet.modifiedTime`**: se lee del campo `lastModifiedAt` del
  documento.
- **Necesario adaptar `updateCell` en el repositorio**: actualmente recibe
  `spreadsheetId` + `productRow` (índice) + `clientCol` (índice). El repositorio
  traducirá los índices a IDs usando las listas `productIds`/`clientIds` del
  documento cargado. El date se extrae del parámetro `date` que ya recibe.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                                 | Propósito                                                                    |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `lib/features/orders_today/data/datasources/remote/order_firestore_data_source.dart`      | Contrato del nuevo datasource Firestore                                      |
| `lib/features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart` | Implementación: operaciones CRUD contra `orders/{date}` y `rows/{productId}` |
| `lib/features/orders_today/data/models/order_document_model.dart`                         | Modelo del documento raíz con `fromFirestore` / `toMap`                      |
| `lib/features/orders_today/data/models/order_row_model.dart`                              | Modelo de subdocumento `rows` con `fromFirestore` / `toMap`                  |

### Artefactos a modificar

| Artefacto                                                                       | Cambio esperado                                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart` | Reescribir: reemplazar `OrdersSheetDataSource`, `GoogleSheetsDataSource`, `GoogleDriveRemoteDataSource`, `SettingsLocalDataSource` por `OrderFirestoreDataSource`, `ClientFirestoreDataSource`, `ProductFirestoreDataSource`. Implementar lógica de sincronización de activos y resolución de nombres. |
| `lib/app/di/modules/orders_today_module.dart`                                   | Registrar `OrderFirestoreDataSource` → `OrderFirestoreDataSourceImpl`; actualizar constructor de `OrdersTodayRepositoryImpl` con las nuevas dependencias; eliminar dependencias de Sheets/Drive ya innecesarias para este repositorio.                                                                 |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`            | Cambio menor: el log message de `_flushPendingSheetsWrite` dice "Sheets sync"; renombrar referencia. Sin cambio funcional.                                                                                                                                                                             |

### Artefactos a retirar o reemplazar

| Artefacto                                                           | Motivo                                                                                                                       |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Uso de `OrdersSheetDataSource` en `OrdersTodayRepositoryImpl`       | Reemplazado por `OrderFirestoreDataSource`. El contrato y la implementación se mantienen en el código base (no se eliminan). |
| Uso de `GoogleSheetsDataSource` en `OrdersTodayRepositoryImpl`      | Ya no es necesario para leer clientes del spreadsheet "configuración"; los clientes se leen de Firestore.                    |
| Uso de `GoogleDriveRemoteDataSource` en `OrdersTodayRepositoryImpl` | Ya no se necesita buscar spreadsheets en Drive.                                                                              |
| Uso de `SettingsLocalDataSource` en `OrdersTodayRepositoryImpl`     | Ya no se necesitan IDs de carpetas de Drive.                                                                                 |
| `OrderSheetData` (DTO)                                              | Deja de usarse en esta feature, pero se mantiene en el código base.                                                          |

## 6) Estrategia de implementación

### Paso 1: Crear modelos Firestore

Crear `OrderDocumentModel` y `OrderRowModel` con métodos
`fromFirestore(String id, Map<String, dynamic> data)` y `toMap()`.

**Dependencias:** Ninguna.

### Paso 2: Crear contrato `OrderFirestoreDataSource`

Definir la interfaz abstracta con los métodos: `exists`, `getOrderDocument`,
`getOrderRows`, `createOrder`, `updateQuantity`, `updateStock`,
`syncActiveEntities`.

**Dependencias:** Paso 1 (usa los modelos).

### Paso 3: Implementar `OrderFirestoreDataSourceImpl`

Implementación con `FirebaseFirestore` como dependencia inyectada. Usar:

- `_firestore.collection('orders').doc(date)` para el documento raíz.
- `.collection('rows')` para la subcolección.
- `WriteBatch` para creación atómica y sincronización de activos.
- `FieldValue.delete()` para eliminar entradas sparse en quantities.
- `FieldValue.serverTimestamp()` para `lastModifiedAt`.

**Dependencias:** Pasos 1 y 2.

### Paso 4: Reescribir `OrdersTodayRepositoryImpl`

- Cambiar dependencias del constructor: eliminar `OrdersSheetDataSource`,
  `GoogleSheetsDataSource`, `GoogleDriveRemoteDataSource`,
  `SettingsLocalDataSource`. Añadir `OrderFirestoreDataSource`,
  `ClientFirestoreDataSource`.
- `getTodayOrders()`: leer documento + rows, sincronizar activos, resolver
  nombres, calcular pedidos/quedan, construir `OrderSheet`.
- `createTodaySheet()`: leer clientes/productos activos, llamar `createOrder()`,
  luego reutilizar lectura.
- `updateCell()`: traducir índices a IDs, llamar `updateQuantity()` o
  `updateStock()`, re-leer y retornar.
- `getSheetModifiedTime()`: leer `lastModifiedAt` del documento.

**Dependencias:** Paso 3.

### Paso 5: Actualizar módulo DI

- Registrar `OrderFirestoreDataSource` →
  `OrderFirestoreDataSourceImpl(sl<FirebaseFirestore>())`.
- Actualizar `OrdersTodayRepositoryImpl` con las nuevas dependencias.
- Mantener registros de `OrdersSheetDataSource` y `ExcelDriveDataSource` (otras
  features los usan).

**Dependencias:** Paso 4.

### Paso 6: Adaptar BLoC (menor)

- Renombrar `_flushPendingSheetsWrite` → `_flushPendingWrite` y sus referencias
  internas (cosmético).
- Sin cambios funcionales.

**Dependencias:** Ninguna (puede hacerse en paralelo).

### Orden recomendado

```
Paso 1 → Paso 2 → Paso 3 → Paso 4 → Paso 5 → Paso 6
```

Secuencia lineal. Cada paso depende del anterior excepto el paso 6 que es
independiente.

### Dependencias entre pasos

- Pasos 1-3 son puramente capa data, sin efecto en el resto hasta que el
  repositorio los consume.
- Paso 4 es el punto de integración principal.
- Paso 5 es el que "conecta" todo en runtime.
- Paso 6 es cosmético.

### Puntos delicados

- **Traducción de índices a IDs en `updateCell`**: el BLoC envía `productRow` y
  `clientCol` como índices numéricos (0-based). El repositorio debe mantener en
  memoria (o re-leer) las listas `productIds`/`clientIds` para traducirlos.
  Solución: al cargar el pedido, el repositorio puede cachear estas listas, o
  bien recibirlas como parámetro.
- **Creación duplicada (FA-01)**: usar `set()` con `SetOptions(merge: true)`
  para el documento raíz. Para los subdocumentos, verificar existencia antes de
  crear o usar `set` que es idempotente para documentos con datos vacíos.
- **Sincronización de activos**: debe ejecutarse antes de construir el
  `OrderSheet` en cada carga. Si la sincronización falla (permisos, red), no
  debe bloquear la lectura — se puede cargar con los datos existentes y
  reintentar la sincronización.
- **Batched write limit**: Firestore permite máximo 500 operaciones por batch.
  Para un pedido típico (< 50 productos), no es problema. Si excepcionalmente
  hubiera más, dividir en múltiples batches.

## 7) Estrategia de validación

### Verificaciones automáticas (tests unitarios)

- **`OrderDocumentModel`**: test de `fromFirestore` y `toMap` con datos de
  ejemplo.
- **`OrderRowModel`**: test de `fromFirestore` y `toMap`, incluyendo mapa sparse
  y vacío.
- **`OrderFirestoreDataSourceImpl`**: tests con `FakeFirebaseFirestore` (paquete
  `fake_cloud_firestore`):
  - Crear pedido y verificar documentos creados.
  - Leer pedido existente.
  - Actualizar cantidad (caso normal y caso sparse = 0 → delete).
  - Actualizar stock.
  - `syncActiveEntities`: añadir cliente, eliminar cliente, añadir producto,
    eliminar producto.
  - `exists` con documento existente y no existente.
- **`OrdersTodayRepositoryImpl`**: tests con mocks (mocktail):
  - `getTodayOrders` → documento existe → retorna `OrderSheet` correcto.
  - `getTodayOrders` → documento no existe → retorna `null`.
  - `getTodayOrders` → sincronización de activos se ejecuta.
  - `createTodaySheet` → crea correctamente.
  - `createTodaySheet` → documento ya existe (FA-01) → carga existente.
  - `updateCell` → cantidad actualizada.
  - `updateCell` → stock actualizado.
  - Errores de Firestore → retorna `Failure` correcto.

### Verificaciones manuales

- Abrir la app → "Pedidos de hoy" → debe mostrar estado vacío si no hay
  documento.
- Crear pedido → verificar documento en Firestore console.
- Editar cantidad → verificar actualización en Firestore console.
- Editar stock → verificar QUEDAN se recalcula correctamente.
- Desactivar un cliente en la gestión de clientes → recargar pedidos → el
  cliente desaparece.
- Activar un nuevo producto → recargar pedidos → el producto aparece con
  cantidades en 0.
- Dos operadores simultáneos → RTDB sincronización sigue funcionando.
- Sin conexión → error mostrado correctamente.

### Escenarios de edge case a cubrir

- Pedido con 0 clientes activos.
- Pedido con 0 productos activos.
- Cantidad = 0 → entrada eliminada del mapa sparse.
- Creación simultánea por dos operadores.
- Cliente eliminado de Firestore (no solo desactivado).

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                                     | Probabilidad | Impacto | Mitigación                                                                                          |
| ------------------------------------------------------------------------------------------ | ------------ | ------- | --------------------------------------------------------------------------------------------------- |
| Inconsistencia al sincronizar activos si falla a mitad de batch                            | Baja         | Medio   | Usar `WriteBatch` para atomicidad. Si falla, los datos previos se mantienen intactos.               |
| Traducción incorrecta de índices a IDs (desfase por sincronización)                        | Media        | Alto    | Cachear `productIds`/`clientIds` al cargar el pedido; re-leer tras sincronización.                  |
| Costes de lectura Firestore elevados si hay muchos productos                               | Baja         | Bajo    | Un pedido típico tiene < 20 productos → < 25 lecturas por carga. Aceptable.                         |
| RTDB cell keys basados en índices numéricos se desfasan si se sincroniza un producto nuevo | Media        | Alto    | Al sincronizar activos, resetear los nodos RTDB (`cells`, `locks`, `cursors`) para evitar desfases. |

### Impacto potencial

- **Funcionalidad rota si la implementación es incorrecta**: el pedido del día
  es la feature principal de la app. Requiere testing exhaustivo.
- **RTDB desfase**: si un producto se inserta en medio de `productIds` al
  sincronizar, los índices RTDB (que usan `row_col`) se desfasan. **Mitigación
  crítica**: al ejecutar `syncActiveEntities`, llamar a
  `OrdersRtdbDataSource.resetToday(date)` para limpiar las celdas RTDB. Los
  operadores verán un refresh completo, pero se evita corrupción de datos.

### Plan de rollback

1. **Código**: revertir el commit que introduce los cambios (el código anterior
   de `OrdersSheetDataSource` no se elimina, solo deja de usarse).
2. **Datos**: los documentos de Firestore creados durante el periodo de pruebas
   se pueden eliminar manualmente. No afectan al flujo anterior.
3. **DI**: restaurar el módulo DI para inyectar las dependencias de Sheets/Drive
   al repositorio.
4. **Tiempo estimado de rollback**: inmediato — un revert de commit.

## 9) Suposiciones

- `cloud_firestore` ya está correctamente configurado y las instancias de
  `FirebaseFirestore` están registradas en GetIt.
- Las colecciones `clients` y `products` en Firestore contienen datos fiables
  con campos `isActive`, `order`, `name` e `id` (document ID).
- El volumen de productos y clientes activos es < 100 (dentro de los límites de
  un batch de Firestore).
- `fake_cloud_firestore` está o puede añadirse como dev dependency para tests
  del datasource.
- La latencia de escritura a Firestore es comparable o mejor que la de Google
  Sheets API para la UX actual.

## 10) Preguntas abiertas

- **PA-01**: ¿Se debe verificar que `fake_cloud_firestore` está disponible como
  dev dependency, o se añade como parte de esta implementación?
- **PA-02**: ¿El reset de RTDB al sincronizar activos (mitigación del desfase de
  índices) es aceptable para el usuario? Implica que todos los operadores verán
  un refresh de datos tras una sincronización.

## 11) Notas para implementación

### Restricciones técnicas a respetar

- **No modificar** `OrderSheet`, `OrdersTodayRepository` (contrato), ni ningún
  archivo de presentación.
- **No eliminar** `OrdersSheetDataSource`, `OrderSheetData`,
  `ExcelDriveDataSource` ni `ExcelParserService`.
- **Mantener** `OrdersRtdbDataSource` y toda su infraestructura sin cambios.
- Usar `WriteBatch` de Firestore para operaciones que involucren múltiples
  documentos (creación, sincronización).
- Usar `FieldValue.delete()` para eliminar entradas sparse, no `update` con
  valor null.
- Usar `FieldValue.serverTimestamp()` para `lastModifiedAt` para evitar desfases
  de reloj.

### Secuencia sugerida

1. Modelos → 2. Contrato datasource → 3. Implementación datasource → 4.
   Repositorio → 5. DI → 6. BLoC cosmético.

### Consideraciones importantes para no romper comportamiento existente

- El campo `OrderSheet.spreadsheetId` pasará a contener el date string en vez de
  un Google Sheets ID. El BLoC lo usa en `_onCellUpdate` para verificar
  `spreadsheetId != null` y pasarlo a `UpdateOrderCellParams`. El repositorio
  ahora lo usará como date string para localizar el documento Firestore.
  **Alternativa más limpia**: en el repositorio, ignorar `spreadsheetId` de los
  params y usar `date` directamente (que ya se recibe). Esto evita dependencia
  semántica del campo.
- `_isDriveConfigured` en `OrdersTodayPage` controla si se muestra la UI o el
  mensaje "configura Google Drive". **Para que la funcionalidad funcione sin
  Drive configurado**, se debe revisar esta lógica o asegurar que Firebase está
  siempre disponible cuando se llega a esta pantalla. Opción: cambiar el check a
  verificar si Firebase está disponible en vez de Drive.

- **Estado: Listo para implementación**
