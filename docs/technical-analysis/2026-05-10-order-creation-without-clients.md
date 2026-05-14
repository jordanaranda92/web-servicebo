# Technical Analysis: Creación de pedido de hoy sin clientes precargados

- **Fecha:** 2026-05-10
- **Identificador:** order-creation-without-clients
- **Fuente:**
  docs/functional-analysis/2026-05-10-order-creation-without-clients.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Eliminar la carga de clientes activos en `createTodaySheet()` del repositorio,
  pasando `clientIds: []` al datasource.
- Revisar y proteger el widget `OrdersTable` contra el caso
  `clients.length == 0`, que actualmente genera expresiones `.clamp(0, -1)` en
  dos métodos de conversión de posición.
- Sin cambios en la estructura de Firestore, entidades de dominio, datasource ni
  BLoC.
- Riesgo general estimado: **bajo**.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC, GetIt y fpdart. La feature
`orders_today` sigue la estructura canónica:

- `data/datasources/remote/` — `OrderFirestoreDataSource` (abstracción) +
  `OrderFirestoreDataSourceImpl`
- `data/models/` — `OrderDocumentModel`, `OrderRowModel`
- `data/repositories/` — `OrdersTodayRepositoryImpl`
- `domain/entities/` — `OrderSheet`
- `domain/repositories/` — `OrdersTodayRepository`
- `domain/usecases/` — `CreateTodayFile`, `GetTodayOrders`, `AddOrderClients`,
  etc.
- `presentation/bloc/` — `OrdersTodayBloc`
- `presentation/widgets/` — `OrdersTable`

### Módulos relevantes

| Capa         | Artefacto                                      | Rol                                                                              |
| ------------ | ---------------------------------------------- | -------------------------------------------------------------------------------- |
| Data         | `OrdersTodayRepositoryImpl.createTodaySheet()` | Orquesta la creación leyendo clientes/productos activos y llamando al datasource |
| Data         | `OrderFirestoreDataSourceImpl.createOrder()`   | Escribe el documento raíz y subdocumentos en Firestore                           |
| Domain       | `OrderSheet`                                   | Entidad que modela la tabla de pedidos                                           |
| Presentation | `OrdersTable`                                  | Widget que renderiza la tabla (grid)                                             |
| Presentation | `OrdersTodayBloc._applyOptimisticUpdate()`     | Actualización optimista local                                                    |

### Restricciones

- No modificar la estructura de datos de Firestore.
- No alterar el contrato del datasource `createOrder()`.
- Respetar el flujo existente de `addClients`/`removeClients`.

### Dependencias

- `addClients()` ya funciona sobre pedidos existentes — no requiere que el
  pedido se haya creado con clientes.
- La Google Sheets datasource (`OrdersSheetDataSource`) no se ve afectada.

## 3) Objetivo técnico

- **Qué debe cambiar**: `createTodaySheet()` debe dejar de incluir clientes
  activos en la creación del pedido.
- **Resultado técnico**: El documento `orders/{YYYY-MM-DD}` se crea con
  `clientIds: []`, generando un `OrderSheet` con `clients: []` que se renderiza
  como tabla sin columnas de clientes.
- **Limitaciones**: El widget `OrdersTable` debe funcionar sin errores con 0
  columnas de clientes.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Cambio mínimo y localizado:

1. Modificar `createTodaySheet()` para no leer clientes activos y pasar una
   lista vacía.
2. Proteger los métodos del widget `OrdersTable` que fallan con
   `clients.length == 0`.

### Componentes / módulos / servicios afectados

**Cambio principal — repositorio:**

En `OrdersTodayRepositoryImpl.createTodaySheet()` (líneas ~140-157), el bloque
actual:

```dart
final activeClients = allClients.where((c) => c.isActive).toList()
  ..sort((a, b) => (a.order ?? 9999).compareTo(b.order ?? 9999));
// ...
final clientIds = activeClients.map((c) => c.id).toList();
```

Se reemplaza por `clientIds = <String>[]`. Se elimina la lectura y filtrado de
clientes activos. La lectura de `allClients` se sigue necesitando para
`_buildOrderSheet()` (resolución de nombres), pero puede mantenerse porque el
catálogo se consume al leer de vuelta el pedido creado. Alternativamente, dado
que `clientIds` será vacío al crear, los mapas de nombre/orden de clientes no se
usarán en la primera carga post-creación, pero se mantienen por consistencia con
el patrón existente y porque no hay coste adicional (están cacheados).

**Protección en presentación — `OrdersTable`:**

Dos métodos calculan índices de columna con `.clamp(0, clients.length - 1)`.
Cuando `clients.length == 0`, esto produce `.clamp(0, -1)`, que en Dart lanza un
`AssertionError` o produce un valor inválido:

1. `_cellFromLocalPosition()` (línea ~865):
   ```dart
   final col = (...).clamp(0, widget.orderSheet.clients.length - 1);
   ```

2. `_colIdxFromHorizontalOffset()` (línea ~878):
   ```dart
   return col.clamp(0, widget.orderSheet.clients.length - 1);
   ```

**Solución**: Añadir un guard que retorne un valor seguro o que los callers no
invoquen estos métodos cuando no hay clientes. El enfoque más robusto es
proteger en ambos métodos:

- Si `clients.isEmpty`, devolver `(0, 0)` / `0` respectivamente, ya que estos
  métodos solo se invocan desde los `GestureDetector` del área scrollable de
  clientes, que con `scrollColCount == 0` genera una lista vacía y tiene
  `width: 0` — por lo que en la práctica no se alcanzarían. Sin embargo,
  conviene protegerlos defensivamente.

### Contratos e interfaces

Sin cambios. El contrato de `OrderFirestoreDataSource.createOrder()` ya acepta
`clientIds: []`. El contrato del repositorio (`createTodaySheet`) devuelve
`OrderSheet` que ya soporta listas vacías.

### Flujo de datos o de control

Flujo actual:

```
[UI] → CreateFileRequested → [BLoC] → createTodaySheet(date)
→ [Repo] lee clientes activos + productos activos
→ [Repo] llama createOrder(clientIds: [...], productIds: [...])
→ [Firestore] crea doc con clientIds poblado
→ [Repo] lee de vuelta y construye OrderSheet con columnas de clientes
→ [BLoC] emite OrdersTodayLoaded(sheet)
→ [UI] OrdersTable renderiza tabla con columnas de clientes
```

Flujo nuevo:

```
[UI] → CreateFileRequested → [BLoC] → createTodaySheet(date)
→ [Repo] lee productos activos (NO lee clientes activos para la creación)
→ [Repo] llama createOrder(clientIds: [], productIds: [...])
→ [Firestore] crea doc con clientIds: []
→ [Repo] lee de vuelta y construye OrderSheet con clients: []
→ [BLoC] emite OrdersTodayLoaded(sheet)
→ [UI] OrdersTable renderiza tabla SIN columnas de clientes
```

### Gestión de errores y validaciones

- `_buildOrderSheet()` con `clientIds: []` produce `quantities: [[]]` por
  producto (lista vacía de cantidades por fila), `pedidos: [0, ...]`,
  `quedan: [stock, ...]`. Verificado: el bucle
  `for (final clientId in clientIds)` no itera → `rowQuantities = []` →
  `fold(0, ...)` = 0. **Correcto**.
- `_applyOptimisticUpdate()` en el BLoC:
  `event.clientCol >= sheet.clientIds.length` (que es 0) → devuelve `true` para
  cualquier col ≥ 0, evitando acceder a `quantities[row]` por índice de cliente.
  Para stocks, usa `event.clientCol == numClients + 1` (=1), que es el flujo
  correcto. **Correcto**.
- `_onCellUpdate()` en el BLoC: `event.clientCol >= sheet.clientIds.length`
  retorna temprano para cualquier intento de editar una columna de cliente
  inexistente. **Correcto**.
- `_commitAndMove()`: `clients.length` es 0, `stocksCol = 0 + 1 = 1`. La
  navegación horizontal no puede entrar en columnas de clientes (condición
  `newCol < clients.length` nunca es true con col ≥ 0). Solo stocks sería
  alcanzable via columnas fijas. **Correcto**.

### Consideraciones de compatibilidad o migración

- No hay migración de datos. Los pedidos existentes no se ven afectados.
- Si un pedido ya fue creado con clientes (antes del cambio), se carga y
  funciona normalmente.
- El cambio solo afecta a pedidos creados **a partir de la implementación**.

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno.

### Artefactos a modificar

| Artefacto                                                                       | Cambio esperado                                                                                                                                                                           |
| ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart` | En `createTodaySheet()`: eliminar la obtención y filtrado de clientes activos; pasar `clientIds: <String>[]` a `createOrder()`. Actualizar el log para reflejar que no se crean clientes. |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`              | En `_cellFromLocalPosition()` y `_colIdxFromHorizontalOffset()`: añadir guard para `clients.isEmpty` evitando `.clamp(0, -1)`.                                                            |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Paso 1: Modificar `createTodaySheet()` en el repositorio

- Eliminar las líneas que filtran y ordenan clientes activos.
- Pasar `clientIds: <String>[]` a `_firestoreDataSource.createOrder()`.
- Actualizar el mensaje de log para reflejar `0 clients`.

### Paso 2: Proteger `OrdersTable` contra `clients.length == 0`

- En `_cellFromLocalPosition()`: si `clients.isEmpty`, retornar `(rowIdx, 0)`
  sin calcular columna.
- En `_colIdxFromHorizontalOffset()`: si `clients.isEmpty`, retornar `0`.

### Paso 3: Verificación manual

- Crear un pedido de hoy y confirmar que la tabla se muestra sin columnas de
  clientes.
- Añadir un cliente y confirmar que la columna aparece.
- Eliminar el cliente y confirmar que se vuelve al estado sin clientes.
- Verificar PEDIDOS=0, STOCKS editable, QUEDAN=STOCKS.

### Orden recomendado

1. Paso 1 (repositorio) → Paso 2 (widget) → Paso 3 (verificación)

### Dependencias entre pasos

- El paso 2 es independiente del paso 1 pero ambos son necesarios para que el
  flujo completo funcione sin errores.
- El paso 3 requiere que los pasos 1 y 2 estén completados.

### Puntos delicados

- **`_cellFromLocalPosition` y `_colIdxFromHorizontalOffset`**: Son los únicos
  puntos donde `clients.length - 1` se usa como límite superior de un
  `.clamp()`. Con 0 clientes, el `GestureDetector` del área scrollable tiene
  `width: 0` por lo que en teoría no se activaría, pero una protección defensiva
  es prudente para evitar regresiones si el layout cambia.
- **Área scrollable vacía**: Con `scrollColCount == 0`, `List.generate(0, ...)`
  produce una lista vacía y el `SizedBox(width: 0, ...)` del área scrollable
  colapsa a 0. El `Expanded` padre absorbe el espacio. Esto es correcto
  visualmente: la zona de columnas de clientes desaparece y solo quedan las
  columnas fijas (PEDIDOS, STOCKS, QUEDAN).

## 7) Estrategia de validación

### Verificación automática

- Compilación sin errores.
- Ejecutar tests existentes (`flutter test`) para confirmar que no hay
  regresiones.

### Verificación manual

- **Caso 1**: Crear pedido → tabla sin columnas de clientes, PEDIDOS=0,
  STOCKS/QUEDAN editables.
- **Caso 2**: Añadir 1 cliente → columna aparece, cantidades editables.
- **Caso 3**: Añadir múltiples clientes → todas las columnas visibles, sumas
  correctas.
- **Caso 4**: Eliminar todos los clientes → vuelve al estado sin columnas.
- **Caso 5**: Editar STOCKS con 0 clientes → QUEDAN se recalcula correctamente.
- **Caso 6**: Listener en tiempo real con 0 clientes → no hay errores en
  consola.

### Tests recomendables (futuro, no bloqueantes)

- Test unitario de `createTodaySheet()` que verifique que el `OrderSheet`
  resultante tiene `clients: []`.
- Test unitario de `_buildOrderSheet()` con `clientIds: []` verificando
  `quantities`, `pedidos`, `quedan`.
- Widget test de `OrdersTable` con un `OrderSheet` con `clients: []`.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Bajo**: Algún otro widget o componente asuma que `clients` nunca es vacío
  tras la creación. No se ha detectado tal caso en el código inspeccionado.
- **Bajo**: GestureDetector del área scrollable se active con `width: 0` en
  algún edge case de plataforma (p.ej., accesibilidad). Mitigado con los guards
  defensivos.

### Impacto potencial

- El cambio es retrocompatible: pedidos existentes no se ven afectados.
- Operadores que estaban acostumbrados a ver todos los clientes al crear deberán
  añadirlos manualmente.

### Mitigación

- Los guards defensivos en `OrdersTable` previenen crashes con listas vacías.
- La funcionalidad de `addClients` ya existe y ha sido verificada.

### Plan de rollback

- Revertir el commit. El cambio es autocontenido en 2 archivos.

## 9) Suposiciones

- La funcionalidad `addClients` funciona correctamente sobre un pedido con
  `clientIds: []` (el datasource `addClients()` hace `FieldValue.arrayUnion`
  sobre el array vacío existente).
- El widget `OrdersTable` no tiene dependencias externas que asuman
  `clients.length > 0` más allá de los dos métodos identificados.
- No existen tests dedicados de `orders_today` que necesiten actualizarse
  (confirmado: no hay archivos de test en `test/features/orders_today/`).

## 10) Preguntas abiertas

Ninguna. Todas las preguntas del análisis funcional fueron resueltas.

## 11) Notas para implementación

- **Restricción técnica clave**: Proteger `_cellFromLocalPosition()` y
  `_colIdxFromHorizontalOffset()` ANTES de probar la creación sin clientes, para
  evitar crashes si se interactúa con el área vacía.
- **Secuencia sugerida**: Repositorio primero (cambio funcional), widget segundo
  (protección defensiva).
- **No rompe comportamiento existente**: Los pedidos creados antes del cambio
  conservan sus clientes. Solo los nuevos pedidos se crean vacíos.
- **Estado: Listo para implementación**
