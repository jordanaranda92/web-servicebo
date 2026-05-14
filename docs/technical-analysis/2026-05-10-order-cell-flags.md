# Technical Analysis: Flags de celda en pedidos (compensación, reserva, stock estricto)

- **Fecha:** 2026-05-10
- **Identificador:** order-cell-flags
- **Fuente:** docs/functional-analysis/2026-05-10-order-cell-flags.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Ampliar `OrderRowModel` con dos campos nuevos (`flags`, `strictStock`) que se
  persisten en Firestore dentro del subdocumento
  `orders/{date}/rows/{productId}`.
- Propagar esos campos hasta `OrderSheet` (entidad de dominio) para que la capa
  de presentación los consuma.
- Añadir métodos en `OrderFirestoreDataSource` para actualizar flags
  individuales con escrituras atómicas (batch).
- Crear un nuevo use case `UpdateCellFlag` que orqueste la escritura del flag y
  un nuevo evento en el BLoC.
- Incorporar menú contextual (`showMenu`) en `_buildDataCell` de `OrdersTable`
  mediante `GestureDetector.onSecondaryTapUp` para celdas de cantidad y stock.
- Aplicar color de fondo (verde pastel / azul pastel) y color de fuente (rojo)
  según los flags activos en `_dataCellColor` y en el estilo de texto de la
  celda de stock.
- Principales áreas impactadas: `data/models/`, `data/datasources/remote/`,
  `data/repositories/`, `domain/entities/`, `domain/usecases/`,
  `domain/repositories/`, `presentation/bloc/`, `presentation/widgets/`,
  `app/di/`, `l10n/`.
- Riesgo general estimado: **bajo**. Es una extensión aditiva sobre estructuras
  existentes. Los campos nuevos son opcionales en Firestore (retrocompatible).
  La propagación en tiempo real ya existe via `watchOrderRows`.

## 2) Contexto técnico observado

- **Arquitectura**: Clean Architecture feature-first con BLoC, GetIt, fpdart.
- **Estructura Firestore actual**:
  - `orders/{YYYY-MM-DD}` → `OrderDocumentModel` (clientIds, productIds,
    timestamps)
  - `orders/{YYYY-MM-DD}/rows/{productId}` → `OrderRowModel` (quantities:
    Map<String,num>, stock: num)
- **RTDB**: Solo usada para presencia (cursores y locks en `today/locks/` y
  `today/cursors/`). No almacena datos de negocio.
- **Listeners en tiempo real**: `watchOrderRows()` escucha
  `_rowsCol(date).snapshots()` y emite `List<OrderRowModel>`. El repositorio
  combina con `watchOrderDocument()` vía `Rx.combineLatest2` y construye
  `OrderSheet`. Cualquier campo nuevo en los subdocumentos de fila se propagará
  automáticamente.
- **Renderizado de celdas**: `_buildDataCell()` en `OrdersTable` determina tipo
  de celda (client, pedidos, stocks, quedan), calcula estilos, y delega color a
  `_dataCellColor()`. Edición con `GestureDetector.onTap` → `_startEditing()`.
- **Patrón de escritura**: Las actualizaciones de celda usan batch write
  (campo + `lastModifiedAt`), con debounce de 500ms en el BLoC y actualización
  optimista local.
- **i18n**: Solo español, `app_es.arb` como template. Claves con prefijo
  `ordersToday*`.
- **DI**: `orders_today_module.dart` registra todos los datasources,
  repositorio, use cases y BLoC/Cubit.
- **Theme**: `CustomColors` en `theme_extensions.dart` tiene `success`,
  `warning`, `info`. Colores del sistema via `ColorScheme`.

## 3) Objetivo técnico

- Extender el modelo de datos de fila (`OrderRowModel`) con campos `flags`
  (Map<String, String>) y `strictStock` (bool) sin romper compatibilidad con
  documentos existentes.
- Transportar esos datos hasta la entidad `OrderSheet` para consumo en
  presentación.
- Proveer un mecanismo de escritura puntual de flags independiente de la
  escritura de cantidad/stock.
- Exponer menú contextual (click derecho) en las celdas editables con opciones
  dinámicas según estado del flag.
- Garantizar que los cambios se propaguen en tiempo real a otros usuarios sin
  infraestructura adicional.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Extensión aditiva vertical: se añaden campos opcionales en cada capa (model →
entity → datasource → repository → use case → bloc → widget) siguiendo el camino
ya establecido para `quantities` y `stock`.

Los flags de cantidad (`compensation` / `reservation`) se almacenan como mapa
sparse `clientId → flagType` dentro del subdocumento de fila. El flag
`strictStock` es un booleano a nivel de fila. Ambos son opcionales y defaultean
a vacío/false, lo que garantiza retrocompatibilidad con documentos existentes
sin migración.

La interacción de menú contextual se implementa con
`GestureDetector.onSecondaryTapUp` + `showMenu()` de Flutter, que funciona en
desktop (macOS/Windows) y web. Es independiente de `onTap` (edición), por lo que
ambas interacciones coexisten sin conflicto.

### Componentes / módulos / servicios afectados

| Capa                  | Componente                          | Cambio                                                                                 |
| --------------------- | ----------------------------------- | -------------------------------------------------------------------------------------- |
| Data - Model          | `OrderRowModel`                     | Nuevos campos `flags`, `strictStock`                                                   |
| Data - Datasource     | `OrderFirestoreDataSource` / `Impl` | Nuevos métodos `updateFlag()`, `updateStrictStock()`                                   |
| Data - Repository     | `OrdersTodayRepositoryImpl`         | Nuevo método `updateCellFlag()`, propagar flags en `_buildOrderSheet()`                |
| Domain - Entity       | `OrderSheet`                        | Nuevos campos `cellFlags`, `strictStocks`                                              |
| Domain - Repository   | `OrdersTodayRepository`             | Nuevo método abstracto `updateCellFlag()`                                              |
| Domain - UseCase      | `UpdateCellFlag` (nuevo)            | Orquesta la escritura del flag                                                         |
| Presentation - BLoC   | `OrdersTodayBloc`                   | Nuevo evento `OrdersTodayCellFlagUpdateRequested`, handler con optimistic update       |
| Presentation - Events | `orders_today_event.dart`           | Nuevo evento sealed class                                                              |
| Presentation - Widget | `OrdersTable`                       | `onSecondaryTapUp` + `showMenu`, lógica de color en `_dataCellColor` y estilo de texto |
| DI                    | `orders_today_module.dart`          | Registrar `UpdateCellFlag` y pasarlo al BLoC                                           |
| i18n                  | `app_es.arb`                        | ~6 nuevas claves                                                                       |

### Contratos e interfaces

**Firestore — subdocumento de fila expandido:**

```json
{
    "quantities": { "clientA": 5, "clientB": 3 },
    "stock": 20,
    "flags": { "clientA": "compensation" },
    "strictStock": true
}
```

- `flags`: Map<String, String> sparse. Clave = clientId, valor =
  `"compensation"` | `"reservation"`. Ausencia = sin flag.
- `strictStock`: bool. Ausencia = `false`.

**`OrderRowModel` expandido:**

```dart
class OrderRowModel {
  final String productId;
  final Map<String, num> quantities;
  final num stock;
  final Map<String, String> flags;     // nuevo
  final bool strictStock;              // nuevo
}
```

**`OrderSheet` expandido:**

```dart
class OrderSheet {
  // ... campos existentes ...
  final List<Map<String, String>> cellFlags;  // cellFlags[productIdx] = {clientId: flagType}
  final List<bool> strictStocks;              // strictStocks[productIdx]
}
```

**Nuevo método en `OrderFirestoreDataSource`:**

```dart
Future<void> updateFlag({
  required String date,
  required String productId,
  required String clientId,
  required String? flagType, // null = eliminar flag
});

Future<void> updateStrictStock({
  required String date,
  required String productId,
  required bool strictStock,
});
```

**Nuevo método en `OrdersTodayRepository`:**

```dart
Future<Either<Failure, Unit>> updateCellFlag({
  required String productId,
  required String? clientId, // null = strictStock
  required String? flagType, // null = eliminar, "compensation", "reservation", "strictStock"
  required DateTime date,
});
```

**Nuevo use case `UpdateCellFlag`:**

```dart
class UpdateCellFlag implements UseCase<Unit, UpdateCellFlagParams> { ... }
class UpdateCellFlagParams extends Equatable {
  final String productId;
  final String? clientId;
  final String? flagType;
  final DateTime date;
}
```

**Nuevo evento BLoC:**

```dart
final class OrdersTodayCellFlagUpdateRequested extends OrdersTodayEvent {
  final int productRow;
  final int? clientCol; // null = stock flag
  final String? flagType; // null = remove, "compensation", "reservation", "strictStock"
}
```

**Callback nuevo en `OrdersTable`:**

```dart
final void Function(int productRow, int? clientCol, String? flagType)? onCellFlagUpdated;
```

### Flujo de datos o de control

```
[Click derecho en celda]
  → GestureDetector.onSecondaryTapUp
  → showMenu() con opciones dinámicas según flag actual
  → usuario selecciona opción
  → widget.onCellFlagUpdated(productRow, clientCol, flagType)
  → OrdersTodayPage dispatch OrdersTodayCellFlagUpdateRequested
  → BLoC: optimistic update local (modifica OrderSheet.cellFlags/strictStocks)
  → BLoC: llama UpdateCellFlag use case (debounce NO necesario: es acción puntual)
  → Repository: llama datasource.updateFlag() o updateStrictStock()
  → Firestore: batch write (flag + lastModifiedAt)
  → Firestore listener (watchOrderRows) emite nuevo OrderRowModel con flag actualizado
  → Repository combina y emite OrderSheet actualizado
  → BLoC: OrdersTodayRemoteOrderUpdated → deduplicación (mismo dato = ignorar)
  → Otros usuarios: reciben el cambio vía su propio listener
```

### Gestión de errores y validaciones

- **Retrocompatibilidad**: `OrderRowModel.fromFirestore` debe tratar `flags` y
  `strictStock` como opcionales con defaults (`{}` y `false`).
- **Flag mutuamente excluyente**: La lógica de exclusividad se implementa en el
  datasource: si `flagType` es `compensation`, se escribe directamente
  (sobrescribe cualquier valor anterior para ese clientId); si es `null`, se
  elimina la entrada del mapa.
- **Error de escritura**: Si el use case devuelve `Left(Failure)`, el BLoC debe
  revertir el optimistic update re-emitiendo el estado anterior. En la UI, se
  muestra un SnackBar de error (reutilizar patrón existente de
  `ordersTodayCellLocked`).
- **Celda sin producto/cliente válido**: Validar índices antes de dispatch,
  igual que en `_onCellUpdate`.

### Consideraciones de compatibilidad o migración

- **No se requiere migración**: Los campos `flags` y `strictStock` son
  opcionales en Firestore. Los documentos existentes seguirán funcionando sin
  cambios — `fromFirestore` los defaulteará.
- **No se requiere cambio en RTDB**: El sistema de presencia (locks/cursors) no
  se ve afectado. Los flags no necesitan locks ya que la escritura es atómica y
  no hay conflicto con la edición de cantidad (son campos distintos del mismo
  documento).
- **`toMap()` de `OrderRowModel`**: Debe incluir los nuevos campos para que
  `createOrder()` funcione correctamente con la estructura expandida (aunque los
  valores iniciales son `{}` y `false`, lo que es equivalente a ausencia).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                         | Propósito                                 |
| ----------------------------------------------------------------- | ----------------------------------------- |
| `lib/features/orders_today/domain/usecases/update_cell_flag.dart` | Use case para actualizar un flag de celda |

### Artefactos a modificar

| Artefacto                                                                                 | Cambio esperado                                                                                                                               |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/data/models/order_row_model.dart`                              | Añadir campos `flags` (Map<String,String>) y `strictStock` (bool) con parsing/serialización                                                   |
| `lib/features/orders_today/domain/entities/order_sheet.dart`                              | Añadir campos `cellFlags` (List<Map<String,String>>) y `strictStocks` (List<bool>) con copyWith y props                                       |
| `lib/features/orders_today/data/datasources/remote/order_firestore_data_source.dart`      | Añadir métodos abstractos `updateFlag()` y `updateStrictStock()`                                                                              |
| `lib/features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart` | Implementar `updateFlag()` y `updateStrictStock()` con batch writes                                                                           |
| `lib/features/orders_today/domain/repositories/orders_today_repository.dart`              | Añadir método abstracto `updateCellFlag()`                                                                                                    |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`           | Implementar `updateCellFlag()`, propagar flags en `_buildOrderSheet()`                                                                        |
| `lib/features/orders_today/presentation/bloc/orders_today_event.dart`                     | Añadir evento `OrdersTodayCellFlagUpdateRequested`                                                                                            |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`                      | Handler para nuevo evento con optimistic update, registrar use case, handler                                                                  |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`                        | `onSecondaryTapUp` + `showMenu`, callback `onCellFlagUpdated`, lógica de color en `_dataCellColor`, estilo de fuente rojo para stock estricto |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`                     | Pasar callback `onCellFlagUpdated` y dispatch del nuevo evento                                                                                |
| `lib/app/di/modules/orders_today_module.dart`                                             | Registrar `UpdateCellFlag` y pasarlo como dependencia al BLoC                                                                                 |
| `lib/app/localization/l10n/app_es.arb`                                                    | ~6 nuevas claves i18n para textos del menú contextual                                                                                         |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

1. **Paso 1 — Modelo de datos**: Extender `OrderRowModel` con `flags` y
   `strictStock`. Actualizar `fromFirestore()` y `toMap()`.
2. **Paso 2 — Entidad de dominio**: Extender `OrderSheet` con `cellFlags` y
   `strictStocks`. Actualizar `copyWith()` y `props`.
3. **Paso 3 — Datasource Firestore**: Añadir `updateFlag()` y
   `updateStrictStock()` en la interfaz abstracta y la implementación.
4. **Paso 4 — Repositorio**: Implementar `updateCellFlag()`. Actualizar
   `_buildOrderSheet()` para construir `cellFlags` y `strictStocks` a partir de
   los `OrderRowModel`.
5. **Paso 5 — Use case**: Crear `UpdateCellFlag` con `UpdateCellFlagParams`.
6. **Paso 6 — BLoC**: Añadir evento `OrdersTodayCellFlagUpdateRequested`,
   handler con optimistic update, inyectar el nuevo use case.
7. **Paso 7 — i18n**: Añadir claves en `app_es.arb`:
   - `ordersTodayMarkCompensation` / `ordersTodayUnmarkCompensation`
   - `ordersTodayMarkReservation` / `ordersTodayUnmarkReservation`
   - `ordersTodayMarkStrictStock` / `ordersTodayUnmarkStrictStock`
8. **Paso 8 — DI**: Registrar `UpdateCellFlag` y pasarlo al factory del BLoC.
9. **Paso 9 — Widget**: Implementar menú contextual en `_buildDataCell` con
   `onSecondaryTapUp`, actualizar `_dataCellColor` para flags de cantidad,
   actualizar estilo de texto para stock estricto.
10. **Paso 10 — Page**: Conectar callback `onCellFlagUpdated` con dispatch del
    evento al BLoC.

### Orden recomendado

Estrictamente secuencial de capa interna a capa externa: Model → Entity →
Datasource → Repository → UseCase → BLoC → i18n → DI → Widget → Page.

### Dependencias entre pasos

- Pasos 1-2 son independientes entre sí pero prerequisito de todo lo demás.
- Paso 3 depende de paso 1 (necesita los nuevos campos del modelo).
- Paso 4 depende de pasos 1, 2 y 3.
- Paso 5 depende de paso 4 (interfaz del repositorio).
- Paso 6 depende de pasos 2 y 5 (entidad y use case).
- Paso 7 (i18n) es independiente, puede hacerse en cualquier momento.
- Paso 8 depende de pasos 5 y 6.
- Pasos 9-10 dependen de todos los anteriores.

### Puntos delicados

- **`_buildOrderSheet()` en el repositorio**: Es el punto central de
  construcción. Debe iterar `rowMap` para extraer `flags` y `strictStock` y
  construir las listas paralelas `cellFlags` y `strictStocks` en el mismo orden
  que `productIds`.
- **Optimistic update en BLoC**: El handler de
  `OrdersTodayCellFlagUpdateRequested` debe clonar `cellFlags`/`strictStocks`,
  aplicar el cambio, y emitir. La mutua exclusividad (al marcar compensation se
  desmarca reservation en la misma celda) se aplica aquí y también en el
  datasource.
- **`_dataCellColor` en el widget**: Debe evaluar los flags ANTES de los colores
  de highlight/alternancia, pero DESPUÉS de los colores de celdas calculadas
  (QUEDAN, PEDIDOS). Un flag en una celda de cantidad prevalece sobre la
  alternancia de filas y el highlight de selección.
- **`showMenu` posicionamiento**: Usar `RelativeRect.fromLTRB` con las
  coordenadas del `TapUpDetails.globalPosition` del `onSecondaryTapUp`.

## 7) Estrategia de validación

### Verificación automática

- Compilación limpia (`flutter analyze`).
- Tests unitarios para:
  - `OrderRowModel.fromFirestore` con y sin campos `flags`/`strictStock`
    (retrocompatibilidad).
  - `OrderRowModel.toMap` incluye los nuevos campos.
  - `_buildOrderSheet` construye `cellFlags` y `strictStocks` correctamente.
  - `UpdateCellFlag` use case invoca repositorio con parámetros correctos.
  - Handler del BLoC aplica optimistic update correctamente (marcar, desmarcar,
    mutua exclusividad).

### Verificación manual

- Click derecho en celda de cantidad → menú con opciones correctas según estado.
- Marcar compensación → fondo verde pastel visible y diferenciable.
- Marcar reserva → fondo azul pastel visible y diferenciable.
- Marcar compensación en celda con reserva → la reserva se desmarca, fondo
  cambia a verde.
- Click derecho en celda de stock → menú con opción stock estricto.
- Marcar stock estricto → fuente roja visible y diferenciable del rojo de
  QUEDAN.
- Recargar la app → flags persisten.
- Segundo usuario conectado → ve cambios de flags en tiempo real.
- Editar valor de celda con flag → el flag permanece.
- Eliminar producto/cliente con flags → sin errores.

### Escenarios a cubrir

- Documento existente sin campos `flags`/`strictStock` (migración implícita).
- Celda con valor 0 y flag activo.
- Operaciones offline (Firestore offline persistence).
- Navegación rápida entre celdas con flags activos.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                                 | Probabilidad | Impacto                                                   |
| -------------------------------------------------------------------------------------- | ------------ | --------------------------------------------------------- |
| Los colores verde/azul pastel no se distinguen bien del fondo de alternancia de filas  | Baja         | Bajo — ajuste de valores de color                         |
| El menú contextual interfiere con el scroll o con gestos existentes en la tabla        | Baja         | Medio — requiere ajuste de hit testing                    |
| `showMenu` no funciona correctamente en web (click derecho capturado por el navegador) | Media        | Medio — puede requerir `Listener` para eventos de puntero |

### Impacto potencial

- **Positivo**: Los operadores pueden comunicar visualmente información
  contextual sin herramientas externas.
- **Negativo mínimo**: Aumento marginal del tamaño de los documentos Firestore
  (campos opcionales sparse).

### Mitigación

- Para colores: definir valores exactos de color con alpha suficiente para
  diferenciarse. Considerar añadir `compensation` e `reservation` a
  `CustomColors` en `theme_extensions.dart`.
- Para web: si `onSecondaryTapUp` no funciona en web, usar `Listener` con
  `onPointerDown` filtrando por `kSecondaryButton`. Probar en web durante
  desarrollo.
- Para rendimiento: los flags son campos primitivos (string, bool) con lectura
  O(1) — sin impacto en rendimiento.

### Plan de rollback

- Los campos `flags` y `strictStock` son aditivos y opcionales. Revertir el
  código no rompe datos existentes; los campos simplemente se ignorarán.
- Si se necesita limpiar datos: un script simple puede recorrer
  `orders/*/rows/*` y eliminar los campos `flags` y `strictStock`.

## 9) Suposiciones

- `GestureDetector.onSecondaryTapUp` funciona en macOS y Windows (plataformas
  objetivo principales de esta app desktop).
- Los colores verde pastel (`Color(0xFFC8E6C9)` ~Material green 100) y azul
  pastel (`Color(0xFFBBDEFB)` ~Material blue 100) son suficientemente
  diferenciables.
- El rojo para stock estricto usa `colorScheme.error` (el mismo rojo del tema),
  diferenciable del rojo de fondo de QUEDAN negativo porque aplica a la fuente,
  no al fondo.
- No se necesitan flags para celdas de PEDIDOS ni QUEDAN (solo celdas
  editables).

## 10) Preguntas abiertas

Ninguna. Todas las preguntas funcionales fueron resueltas en el análisis
funcional.

## 11) Notas para implementación

- **Retrocompatibilidad Firestore**: `fromFirestore` debe usar `?? {}` y
  `?? false` para los nuevos campos. No se necesita migración.
- **Mutua exclusividad**: Implementar tanto en el optimistic update del BLoC
  como en el datasource Firestore. En el datasource basta con escribir el valor
  directamente (sobrescribe la entrada anterior para ese clientId).
- **Colores de flag vs. colores existentes**: En `_dataCellColor`, evaluar flags
  solo para celdas de tipo `isClient`. El flag prevalece sobre alternancia de
  filas y highlight, pero NO sobre el estado `isSelected` (celda en edición).
- **Stock estricto → no afecta color de fondo**: Solo cambia el `color` del
  `TextStyle` de la celda de stock a `colorScheme.error`. Se aplica en la
  sección `isStocks` de `_buildDataCell`, no en `_dataCellColor`.
- **Secuencia sugerida**: Seguir la estrategia de implementación de capa interna
  a externa.
- **No crear nuevo canal de comunicación**: Los listeners Firestore existentes
  (`watchOrderRows → combineLatest2 → asyncMap → _buildOrderSheet`) propagarán
  automáticamente los nuevos campos una vez que `OrderRowModel.fromFirestore` y
  `_buildOrderSheet` los procesen.
- **Estado: Listo para implementación**
