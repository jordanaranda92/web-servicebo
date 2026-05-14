# Technical Analysis: Historial de pedidos desde Firestore

- **Fecha:** 2026-05-13
- **Identificador:** orders-history-firestore
- **Fuente:** docs/functional-analysis/2026-05-13-orders-history-firestore.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Reescribir `OrdersHistoryRepositoryImpl` (actualmente un stub vacío) para que
  lea los pedidos históricos desde Firestore, reutilizando el
  `OrderFirestoreDataSource` ya registrado en el contenedor DI.
- Introducir una entidad `OrderDateInfo` para transportar fecha + conteos de
  clientes/productos desde el repositorio hasta la UI (RF-06b).
- Adaptar contrato del repositorio, use case, BLoC (estados y mapeo de errores),
  widget `HistoryDateList` y módulo DI.
- Extraer la lógica de `_buildOrderSheet` a una función compartida para evitar
  duplicación con `OrdersTodayRepositoryImpl`.
- Riesgo general estimado: **bajo** — la infraestructura ya existe; se trata de
  conectar piezas existentes.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con BLoC, GetIt y fpdart.
- La feature `orders_history` tiene las 3 capas (domain, data, presentation)
  creadas, pero la capa de datos es un stub.

### Módulos relevantes

| Módulo                                                                       | Estado                                                                                           |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `orders_history/data/repositories/orders_history_repository_impl.dart`       | Stub: retorna `Right([])` y `Left(ConfigNotFoundFailure())`                                      |
| `orders_history/domain/repositories/orders_history_repository.dart`          | Contrato: `getAvailableDates()` → `List<DateTime>`, `getHistoryOrders(DateTime)` → `OrderSheet`  |
| `orders_history/domain/usecases/get_available_dates.dart`                    | Funcional, usa `NoParams`                                                                        |
| `orders_history/domain/usecases/get_history_orders.dart`                     | Funcional, usa `GetHistoryOrdersParams(date)`                                                    |
| `orders_history/presentation/bloc/`                                          | Completo: 5 eventos, 8 estados, funcional                                                        |
| `orders_history/presentation/pages/orders_history_page.dart`                 | Completa con navegación, filtros, búsqueda                                                       |
| `orders_history/presentation/widgets/`                                       | 4 widgets: date list, table, empty, error                                                        |
| `orders_today/data/datasources/remote/order_firestore_data_source.dart`      | Contrato completo con `getOrderDocument`, `getOrderRows`, etc.                                   |
| `orders_today/data/datasources/remote/order_firestore_data_source_impl.dart` | Implementación completa contra `orders/{YYYY-MM-DD}` + `rows/`                                   |
| `orders_today/data/models/order_document_model.dart`                         | Modelo con `clientIds`, `productIds`, `invoicedBy`, timestamps                                   |
| `orders_today/data/models/order_row_model.dart`                              | Modelo con `quantities`, `stock`, `flags`, `notes`, `refunds`, `strictStock`                     |
| `orders_today/data/repositories/orders_today_repository_impl.dart`           | Tiene `_buildOrderSheet()` (~40 líneas) que construye `OrderSheet` a partir de modelos Firestore |
| `clients/data/datasources/client_firestore_data_source.dart`                 | `getAll()` → `List<ClientModel>`                                                                 |
| `products/data/datasources/product_firestore_data_source.dart`               | `getAll()` → `List<ProductModel>`                                                                |
| `app/di/modules/orders_history_module.dart`                                  | Registra repo (stub), use cases y BLoC                                                           |
| `app/di/modules/orders_today_module.dart`                                    | Registra `OrderFirestoreDataSource` como singleton                                               |

### Restricciones

- `OrderFirestoreDataSource` no tiene un método para listar todos los documentos
  de la colección `orders`. Necesita añadirse.
- `_buildOrderSheet` es privado de `OrdersTodayRepositoryImpl`. Para
  reutilizarlo hay que extraerlo.
- Los `OrdersHistoryErrorType` del BLoC (`fileSystemError`, `invalidFormat`) son
  herencia del backend de archivos y deben actualizarse.
- El widget `HistoryDateList` solo recibe `List<DateTime>` — necesita recibir
  también conteos de clientes/productos (RF-06b).

### Dependencias

- `cloud_firestore` — ya presente.
- `ClientFirestoreDataSource`, `ProductFirestoreDataSource` — ya registrados en
  sus módulos respectivos (`clients_module`, `products_module`).
- No se requieren nuevas dependencias externas.

## 3) Objetivo técnico

1. **Reemplazar** el stub de `OrdersHistoryRepositoryImpl` por una
   implementación que consulte Firestore.
2. **Añadir** un método al datasource para listar documentos de `orders`.
3. **Extraer** la lógica de `_buildOrderSheet` a un helper compartido.
4. **Introducir** la entidad `OrderDateInfo` para transportar metadatos de
   fechas.
5. **Adaptar** el contrato del repositorio, use case, BLoC y widgets para
   soportar `OrderDateInfo`.
6. **Actualizar** los tipos de error del BLoC a errores de servidor.
7. **Actualizar** el módulo DI para inyectar las dependencias reales.

### Limitaciones a respetar

- No modificar el `OrderSheet` entity (ya es completo y funcional).
- No cambiar el datasource de `orders_today` más allá de añadir el método de
  listado.
- No añadir listeners en tiempo real al historial (lectura bajo demanda).
- Mantener la pantalla en modo solo lectura.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Reutilizar el `OrderFirestoreDataSource` ya registrado (singleton) para leer
documentos de `orders`. El repositorio de historial se convierte en un
consumidor de solo lectura del mismo datasource que usa `orders_today`,
añadiendo solo un método nuevo para listar documentos. La resolución de nombres
(IDs → nombres) se hace con los datasources de clientes y productos existentes.

### Componentes / módulos / servicios afectados

| Componente                                                | Tipo de cambio                                      |
| --------------------------------------------------------- | --------------------------------------------------- |
| **Nuevo:** `OrderDateInfo` (entidad)                      | Crear                                               |
| **Nuevo:** `order_sheet_builder.dart` (helper compartido) | Crear                                               |
| `OrderFirestoreDataSource` (contrato)                     | Añadir 1 método                                     |
| `OrderFirestoreDataSourceImpl`                            | Implementar 1 método                                |
| `OrdersHistoryRepository` (contrato)                      | Cambiar firma de `getAvailableDates`                |
| `OrdersHistoryRepositoryImpl`                             | Reescribir completo                                 |
| `GetAvailableDates` (use case)                            | Cambiar tipo de retorno                             |
| `OrdersHistoryBloc`                                       | Adaptar a `OrderDateInfo`, cambiar mapeo de errores |
| `OrdersHistoryEvent`                                      | Sin cambios                                         |
| `OrdersHistoryState`                                      | Cambiar `List<DateTime>` → `List<OrderDateInfo>`    |
| `HistoryDateList` (widget)                                | Recibir `OrderDateInfo`, mostrar conteos            |
| `OrdersHistoryPage`                                       | Ajuste menor en paso de datos                       |
| `HistoryErrorState` (widget)                              | Adaptar textos de error                             |
| `orders_history_module.dart` (DI)                         | Inyectar dependencias reales                        |
| `OrdersTodayRepositoryImpl`                               | Reemplazar `_buildOrderSheet` por helper compartido |

### Contratos e interfaces

#### Método nuevo en `OrderFirestoreDataSource`

```dart
/// Returns all root order documents (without subcollections).
/// Used by the history feature to list available dates.
Future<List<OrderDocumentModel>> getAllOrderDocuments();
```

#### Nueva entidad `OrderDateInfo`

```dart
class OrderDateInfo extends Equatable {
  final DateTime date;
  final int clientCount;
  final int productCount;

  const OrderDateInfo({
    required this.date,
    required this.clientCount,
    required this.productCount,
  });

  @override
  List<Object?> get props => [date, clientCount, productCount];
}
```

#### Contrato actualizado de `OrdersHistoryRepository`

```dart
abstract class OrdersHistoryRepository {
  Future<Either<Failure, List<OrderDateInfo>>> getAvailableDates();
  Future<Either<Failure, OrderSheet>> getHistoryOrders(DateTime date);
}
```

#### Helper compartido `buildOrderSheet`

Función top-level que recibe `OrderDocumentModel`, `List<OrderRowModel>`, mapas
de nombres y ordenes, y retorna un `OrderSheet`. Extraída de
`OrdersTodayRepositoryImpl._buildOrderSheet()` sin modificaciones lógicas.

### Flujo de datos

#### `getAvailableDates()`

```
BLoC → GetAvailableDates(NoParams)
     → OrdersHistoryRepository.getAvailableDates()
     → OrderFirestoreDataSource.getAllOrderDocuments()
        → Firestore: collection('orders').get()
     ← List<OrderDocumentModel>
     → Filtrar (excluir fecha actual)
     → Mapear a List<OrderDateInfo> (fecha, clientIds.length, productIds.length)
     → Ordenar de más reciente a más antigua
     ← Either<Failure, List<OrderDateInfo>>
```

#### `getHistoryOrders(date)`

```
BLoC → GetHistoryOrders(date)
     → OrdersHistoryRepository.getHistoryOrders(date)
     → OrderFirestoreDataSource.getOrderDocument(dateStr)
     → OrderFirestoreDataSource.getOrderRows(dateStr)
     → ClientFirestoreDataSource.getAll()
     → ProductFirestoreDataSource.getAll()
     → buildOrderSheet(doc, rows, clientNameMap, productNameMap, productOrderMap)
     ← Either<Failure, OrderSheet>
```

### Gestión de errores y validaciones

| Escenario                          | Error capturado                         | Failure emitido   | ErrorType en BLoC |
| ---------------------------------- | --------------------------------------- | ----------------- | ----------------- |
| Error de red/Firestore             | `FirebaseException` → `ServerException` | `ServerFailure`   | `serverError`     |
| Documento no encontrado para fecha | `null` document                         | `ServerFailure`   | `serverError`     |
| Error interno inesperado           | `catch (e)`                             | `InternalFailure` | `unknown`         |

**Cambios en `OrdersHistoryErrorType`:**

```dart
enum OrdersHistoryErrorType { serverError, unknown }
```

Se eliminan `fileSystemError` e `invalidFormat` (legacy del backend de
archivos). Se añade `serverError`. El mapeo `_mapFailure` se simplifica.

### Consideraciones de compatibilidad o migración

- Los pedidos anteriores a la migración a Firestore (archivos Excel en Drive)
  **no estarán disponibles** en el historial. Solo se mostrarán pedidos creados
  tras la migración. Esto es un comportamiento esperado y documentado en el
  análisis funcional.
- El cambio en el enum `OrdersHistoryErrorType` es un breaking change interno
  pero no afecta a código fuera de la feature `orders_history`.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                          | Propósito                                                                      |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `lib/features/orders_history/domain/entities/order_date_info.dart` | Entidad con fecha + conteos para el listado de fechas                          |
| `lib/features/orders_today/data/helpers/order_sheet_builder.dart`  | Función compartida `buildOrderSheet()` extraída de `OrdersTodayRepositoryImpl` |

### Artefactos a modificar

| Artefacto                                                                                 | Cambio esperado                                                                                                                |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `lib/features/orders_today/data/datasources/remote/order_firestore_data_source.dart`      | Añadir método `getAllOrderDocuments()`                                                                                         |
| `lib/features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart` | Implementar `getAllOrderDocuments()`                                                                                           |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`           | Reemplazar `_buildOrderSheet` por llamada a `buildOrderSheet` del helper compartido                                            |
| `lib/features/orders_history/domain/repositories/orders_history_repository.dart`          | Cambiar retorno de `getAvailableDates` a `List<OrderDateInfo>`                                                                 |
| `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart`       | Reescribir: inyectar datasources, implementar lectura real desde Firestore                                                     |
| `lib/features/orders_history/domain/usecases/get_available_dates.dart`                    | Cambiar tipo de retorno a `List<OrderDateInfo>`                                                                                |
| `lib/features/orders_history/presentation/bloc/orders_history_bloc.dart`                  | Adaptar a `OrderDateInfo`, actualizar `_mapFailure`                                                                            |
| `lib/features/orders_history/presentation/bloc/orders_history_state.dart`                 | Cambiar `List<DateTime>` → `List<OrderDateInfo>` en estados; actualizar enum de errores                                        |
| `lib/features/orders_history/presentation/pages/orders_history_page.dart`                 | Ajustar paso de datos al widget de fechas                                                                                      |
| `lib/features/orders_history/presentation/widgets/history_date_list.dart`                 | Recibir `List<OrderDateInfo>`, mostrar conteo de clientes y productos en cada tile                                             |
| `lib/features/orders_history/presentation/widgets/history_error_state.dart`               | Adaptar mensajes de error al nuevo enum                                                                                        |
| `lib/app/di/modules/orders_history_module.dart`                                           | Inyectar `OrderFirestoreDataSource`, `ClientFirestoreDataSource`, `ProductFirestoreDataSource` y `AppLogger` en el repositorio |
| `test/features/orders_history/data/repositories/orders_history_repository_impl_test.dart` | Reescribir tests para verificar lectura desde Firestore (mocks)                                                                |
| `test/features/orders_history/presentation/bloc/orders_history_bloc_test.dart`            | Adaptar a `OrderDateInfo` y nuevos error types                                                                                 |

### Artefactos a retirar o reemplazar

| Artefacto                                                                     | Motivo                                      |
| ----------------------------------------------------------------------------- | ------------------------------------------- |
| Claves i18n `ordersHistoryErrorFileSystem`, `ordersHistoryErrorInvalidFormat` | Reemplazadas por `ordersHistoryErrorServer` |

## 6) Estrategia de implementación

### Paso 1: Crear entidad `OrderDateInfo`

Crear `lib/features/orders_history/domain/entities/order_date_info.dart` con
`date`, `clientCount`, `productCount`. Clase `Equatable`.

**Dependencias:** Ninguna.

### Paso 2: Extraer `buildOrderSheet` a helper compartido

Crear `lib/features/orders_today/data/helpers/order_sheet_builder.dart` con una
función top-level `buildOrderSheet()` extraída verbatim de
`OrdersTodayRepositoryImpl._buildOrderSheet()`. Actualizar
`OrdersTodayRepositoryImpl` para usar el helper.

**Dependencias:** Ninguna. Verificar que los tests de `orders_today` siguen
pasando.

### Paso 3: Añadir `getAllOrderDocuments` al datasource

Añadir el método al contrato `OrderFirestoreDataSource` y su implementación en
`OrderFirestoreDataSourceImpl`:

```dart
Future<List<OrderDocumentModel>> getAllOrderDocuments() async {
  try {
    final snap = await _firestore.collection('orders').get();
    return snap.docs
        .map((doc) => OrderDocumentModel.fromFirestore(doc.id, doc.data()))
        .toList();
  } on FirebaseException catch (e) {
    throw ServerException(message: 'Error listing order documents: $e');
  }
}
```

**Dependencias:** Ninguna.

### Paso 4: Actualizar contrato y use case del dominio

- Cambiar `OrdersHistoryRepository.getAvailableDates()` para retornar
  `Either<Failure, List<OrderDateInfo>>`.
- Actualizar `GetAvailableDates` para usar el nuevo tipo de retorno.

**Dependencias:** Paso 1.

### Paso 5: Reescribir `OrdersHistoryRepositoryImpl`

Nuevo constructor con dependencias:

```dart
OrdersHistoryRepositoryImpl(
  this._firestoreDataSource,
  this._clientFirestore,
  this._productFirestore,
  this._logger,
);
```

Implementar:

- `getAvailableDates()`: llama `getAllOrderDocuments()`, excluye fecha actual,
  mapea a `OrderDateInfo`, ordena por fecha descendente.
- `getHistoryOrders(date)`: lee documento + rows, resuelve nombres con
  datasources de clientes/productos, llama `buildOrderSheet()`.

**Dependencias:** Pasos 2, 3, 4.

### Paso 6: Adaptar BLoC y estados

- Actualizar `OrdersHistoryState`: reemplazar `List<DateTime>` por
  `List<OrderDateInfo>` en `OrdersHistoryDatesLoaded` y
  `OrdersHistoryDetailLoaded`.
- Actualizar `OrdersHistoryErrorType`: reemplazar `fileSystemError` e
  `invalidFormat` por `serverError`.
- Actualizar `_mapFailure` en el BLoC.
- Adaptar filtros de fecha en el BLoC (`_applyDateFilter`,
  `_onDateRangeChanged`) para operar sobre `OrderDateInfo`.

**Dependencias:** Pasos 1, 4.

### Paso 7: Adaptar widgets

- `HistoryDateList`: cambiar `List<DateTime>` → `List<OrderDateInfo>`. En
  `_DateTile`, mostrar subtítulo con conteo de clientes y productos.
- `HistoryErrorState`: adaptar mensajes al nuevo enum.
- `OrdersHistoryPage`: ajustar paso de datos.
- Actualizar claves i18n: eliminar claves obsoletas de filesystem, añadir clave
  para error de servidor.

**Dependencias:** Paso 6.

### Paso 8: Actualizar DI

Modificar `orders_history_module.dart` para inyectar las dependencias reales:

```dart
sl.registerLazySingleton<OrdersHistoryRepository>(
  () => OrdersHistoryRepositoryImpl(
    sl<OrderFirestoreDataSource>(),
    sl<ClientFirestoreDataSource>(),
    sl<ProductFirestoreDataSource>(),
    sl(),
  ),
);
```

**Dependencias:** Paso 5. El `OrderFirestoreDataSource` ya está registrado como
singleton en `orders_today_module`, que se ejecuta antes.

### Paso 9: Actualizar tests

- Reescribir `orders_history_repository_impl_test.dart` con mocks de
  `OrderFirestoreDataSource`, `ClientFirestoreDataSource`,
  `ProductFirestoreDataSource`.
- Adaptar `orders_history_bloc_test.dart` para usar `OrderDateInfo` y nuevos
  tipos de error.

**Dependencias:** Pasos 5, 6.

### Orden recomendado

1 → 2 → 3 (estos 3 son independientes entre sí) → 4 → 5 → 6 → 7 → 8 → 9

### Dependencias entre pasos

- Paso 4 depende de 1 (entidad `OrderDateInfo`)
- Paso 5 depende de 2, 3 y 4
- Paso 6 depende de 1 y 4
- Paso 7 depende de 6
- Paso 8 depende de 5
- Paso 9 depende de 5 y 6

### Puntos delicados

- **Dependencia cross-feature en DI**: `OrdersHistoryRepositoryImpl` depende de
  `OrderFirestoreDataSource`, registrado en `orders_today_module`. El orden de
  registro en `injection.dart` ya es correcto (`registerOrdersTodayModule` se
  ejecuta antes que `registerOrdersHistoryModule`).
- **Extracción de `_buildOrderSheet`**: al moverlo a helper compartido, asegurar
  que los imports de `OrderDocumentModel`, `OrderRowModel`, `OrderSheet` e
  `InvoicedByInfo` se resuelven correctamente.
- **Cambio de tipo en estados del BLoC**: `OrdersHistoryDatesLoaded` y
  `OrdersHistoryDetailLoaded` pasan de `List<DateTime>` a `List<OrderDateInfo>`.
  Esto afecta a los filtros de fecha del BLoC y a la UI. El `_applyDateFilter`
  debe operar sobre `OrderDateInfo.date`.

## 7) Estrategia de validación

### Verificación automática

- `dart analyze` sobre todos los archivos nuevos y modificados — 0 issues.
- Tests unitarios del repositorio: verificar que `getAvailableDates` lee y
  filtra correctamente los documentos de Firestore, y que `getHistoryOrders`
  construye el `OrderSheet` con nombres resueltos.
- Tests del BLoC: verificar estados con datos reales de `OrderDateInfo`, filtros
  de rango de fechas, mapeo de errores.

### Verificación manual

- Navegar a "Historial de pedidos" y verificar que se muestran fechas reales con
  conteos de clientes/productos.
- Seleccionar una fecha y verificar que la tabla muestra datos correctos.
- Aplicar filtro de rango de fechas y verificar el filtrado.
- Buscar un cliente en el detalle y verificar el filtrado.
- Verificar estado vacío (si no hay pedidos históricos).
- Verificar estado de error (desconectar red).

### Escenarios de test recomendados

| Escenario                                                         | Tipo     |
| ----------------------------------------------------------------- | -------- |
| `getAvailableDates` devuelve fechas excluyendo hoy                | Unitario |
| `getAvailableDates` devuelve vacío si solo existe hoy             | Unitario |
| `getAvailableDates` ordena de más reciente a más antigua          | Unitario |
| `getAvailableDates` incluye conteos correctos                     | Unitario |
| `getAvailableDates` maneja error de Firestore                     | Unitario |
| `getHistoryOrders` construye OrderSheet correcto                  | Unitario |
| `getHistoryOrders` resuelve nombres, fallback para IDs eliminados | Unitario |
| `getHistoryOrders` maneja documento no encontrado                 | Unitario |
| BLoC emite DatesLoaded con OrderDateInfo                          | Unitario |
| BLoC filtra por rango de fechas con OrderDateInfo                 | Unitario |
| BLoC mapea ServerFailure a serverError                            | Unitario |

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                   | Probabilidad           | Impacto |
| ------------------------------------------------------------------------ | ---------------------- | ------- |
| Performance de `getAllOrderDocuments` con muchos documentos (>500)       | Baja                   | Medio   |
| Inconsistencia si un documento de `orders` no tiene formato `YYYY-MM-DD` | Muy baja               | Bajo    |
| Dependencia cross-feature (history → orders_today datasource)            | N/A (ya existe patrón) | Bajo    |

### Impacto potencial

- **Positivo**: La pantalla de historial pasa de no funcional a operativa.
- **Negativo**: Cambio de API interna del BLoC (error types). Solo afecta a
  código dentro de la feature.

### Mitigación

- Para performance: la consulta `collection('orders').get()` sin subcollections
  es ligera. Si el volumen crece, se puede paginar en iteración futura.
- Para IDs no-fecha: parsear con `DateTime.tryParse` y descartar los que no sean
  válidos.
- Para dependencia cross-feature: el datasource ya es singleton compartido; el
  patrón es consistente con el resto del proyecto.

### Plan de rollback

- Revertir los commits de esta feature. El stub anterior es funcional (muestra
  estado vacío). No hay migración de datos ni side effects destructivos.

## 9) Suposiciones

- Los documentos en la colección `orders` usan IDs en formato `YYYY-MM-DD`.
- El `OrderFirestoreDataSource` seguirá siendo un singleton registrado en
  `orders_today_module` y disponible para `orders_history_module`.
- Las colecciones `clients` y `products` contienen los documentos necesarios
  para resolución de nombres. Si un ID no se encuentra, se usa el propio ID como
  fallback.
- El volumen de documentos en `orders` es manejable sin paginación (<1000).

## 10) Preguntas abiertas

- Ninguna. Todas las preguntas funcionales fueron resueltas.

## 11) Notas para implementación

- **No crear un datasource separado** para historial. Reutilizar
  `OrderFirestoreDataSource` (añadiendo solo `getAllOrderDocuments`).
- **No duplicar `_buildOrderSheet`**: extraerlo como función top-level en un
  archivo helper en `orders_today/data/helpers/`. Ambos repositorios la
  importan.
- El helper `buildOrderSheet` no debe ser una clase; una función pura top-level
  es suficiente y más simple.
- Al adaptar `_applyDateFilter` en el BLoC, acceder a `.date` del
  `OrderDateInfo` para la comparación.
- Al formatear fecha para Firestore, usar el mismo `_formatDate` que
  `OrdersTodayRepositoryImpl` (o extraer a utilidad compartida si se prefiere).
  Patrón:
  `'${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'`.
- Asegurar que el registro DI en `orders_history_module` referencia
  `sl<OrderFirestoreDataSource>()` explícitamente para mayor claridad.
- **Estado: Listo para implementación**
