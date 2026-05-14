# Technical Analysis: Auto-creación de pedidos de hoy con animación

- **Fecha:** 2026-05-10
- **Identificador:** auto-create-today-orders
- **Fuente:** docs/functional-analysis/2026-05-10-auto-create-today-orders.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Modificar el flujo del BLoC `OrdersTodayBloc` para que, al detectar que no
  existe el documento del día (estado `NoFile`), dispare automáticamente la
  creación combinada con un temporizador de 3 segundos mínimos.
- Añadir un nuevo estado BLoC `OrdersTodayCreating` para distinguir la animación
  de preparación del loading genérico.
- Crear un widget `OrdersPreparingState` que muestre la animación con mensaje
  i18n.
- Modificar la UI para reaccionar al nuevo estado y distinguir entre "no-file
  por carga inicial" (auto-crear) y "no-file por eliminación remota" (mostrar
  estado vacío con botón manual).
- Principales áreas impactadas: BLoC (estados, eventos, handler), capa de
  presentación (página + widget nuevo), i18n (1 clave nueva).
- Riesgo general estimado: **bajo** — cambio localizado en presentación, sin
  modificar dominio ni datos.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con BLoC, GetIt y fpdart.
- Feature `orders_today` con capas: `domain/`, `data/`, `presentation/`.
- BLoC usa `sealed class` para estados y eventos (`Equatable`).

### Estados BLoC actuales

| Estado               | Significado                             |
| -------------------- | --------------------------------------- |
| `OrdersTodayInitial` | Estado inicial antes de cualquier carga |
| `OrdersTodayLoading` | Carga en curso (spinner genérico)       |
| `OrdersTodayLoaded`  | Datos cargados, muestra tabla           |
| `OrdersTodayNoFile`  | No existe documento del día             |
| `OrdersTodayError`   | Error con tipo clasificado              |

### Flujo actual al cargar

1. `OrdersTodayLoadRequested` → emit `OrdersTodayLoading` → `_loadOrders()`
2. `_loadOrders()` llama `_getTodayOrders` → si `null` → emit
   `OrdersTodayNoFile`
3. UI muestra `OrdersEmptyState` con botón manual "Crear pedido de hoy"
4. Al pulsar → `OrdersTodayCreateFileRequested` → emit `OrdersTodayLoading` →
   `_createTodayFile` → emit `Loaded` o `Error`

### Flujo de eliminación remota

- `watchTodayOrders` emite `null` → `_onRemoteOrderUpdate` → emit
  `OrdersTodayNoFile`
- El BLoC no distingue entre "no-file inicial" y "no-file por eliminación
  remota"

### Restricciones

- No se deben modificar capas de dominio ni datos.
- La creación ya es idempotente (`createTodaySheet` verifica existencia previa).
- Solo idioma `es` en el proyecto (único ARB).

## 3) Objetivo técnico

- **Qué debe cambiar:** El flujo de `_onLoad` del BLoC debe, cuando no existe
  documento, disparar automáticamente la creación con animación mínima de 3
  segundos en vez de detenerse en `NoFile`.
- **Resultado:** La UI transiciona sin intervención de `Loading` → `Creating`
  (animación 3s) → `Loaded` (tabla).
- **Limitaciones:** El estado `OrdersTodayNoFile` sigue existiendo y se usa
  exclusivamente cuando el documento se elimina externamente (eliminación
  remota), donde se mantiene el `OrdersEmptyState` con botón manual.

## 4) Diseño técnico de la solución

### Enfoque propuesto

**Estrategia: nuevo estado + lógica de auto-creación en `_onLoad`.**

1. Añadir un estado `OrdersTodayCreating` al sealed class de estados.
2. Modificar `_loadOrders()` para que, cuando `getTodayOrders` devuelve `null`,
   en vez de emitir `NoFile`, emita `OrdersTodayCreating` e inicie la
   auto-creación con `Future.wait` (creación + delay de 3s).
3. Si la auto-creación tiene éxito → emit `OrdersTodayLoaded`.
4. Si falla → emit `OrdersTodayError`.
5. El estado `OrdersTodayNoFile` solo se emite desde `_onRemoteOrderUpdate`
   (eliminación remota).
6. Crear widget `OrdersPreparingState` para la animación.
7. En la UI, mapear `OrdersTodayCreating` al nuevo widget.

### Componentes / módulos / servicios afectados

| Componente                    | Capa                 | Tipo de cambio                            |
| ----------------------------- | -------------------- | ----------------------------------------- |
| `orders_today_state.dart`     | Presentación/BLoC    | Añadir estado `OrdersTodayCreating`       |
| `orders_today_bloc.dart`      | Presentación/BLoC    | Modificar `_loadOrders()` para auto-crear |
| `orders_today_page.dart`      | Presentación/UI      | Mapear nuevo estado en `switch`           |
| `orders_preparing_state.dart` | Presentación/Widgets | Widget nuevo para animación               |
| `app_es.arb`                  | i18n                 | 1 clave nueva                             |
| `app_localizations.dart`      | i18n (generado)      | Se regenera con `flutter gen-l10n`        |
| `app_localizations_es.dart`   | i18n (generado)      | Se regenera con `flutter gen-l10n`        |

### Contratos e interfaces

**Nuevo estado:**

```dart
final class OrdersTodayCreating extends OrdersTodayState {
  const OrdersTodayCreating();
}
```

No se requieren nuevos eventos. El flujo de auto-creación se dispara
internamente en `_loadOrders()`, no por un evento externo.

**Nuevo widget:**

```dart
class OrdersPreparingState extends StatelessWidget {
  const OrdersPreparingState({super.key});
  // Muestra CircularProgressIndicator + texto i18n
}
```

### Flujo de datos o de control

```
Usuario navega a "Pedidos de hoy"
  │
  ▼
OrdersTodayLoadRequested
  │
  ▼
emit OrdersTodayLoading  (spinner genérico breve)
  │
  ▼
_loadOrders() → _getTodayOrders()
  │
  ├─ sheet != null → emit OrdersTodayLoaded (flujo normal)
  │
  └─ sheet == null (no existe documento)
      │
      ▼
    emit OrdersTodayCreating  (animación "Preparando plantilla...")
      │
      ▼
    Future.wait([
      _createTodayFile(CreateTodayFileParams(date: DateTime.now())),
      Future.delayed(Duration(seconds: 3)),
    ])
      │
      ├─ success → emit OrdersTodayLoaded(orderSheet: sheet)
      │                + _startWatch()
      │
      └─ failure → emit OrdersTodayError(errorType: ...)
```

**Eliminación remota (sin cambios funcionales, solo clarificación):**

```
watchTodayOrders emite null
  │
  ▼
_onRemoteOrderUpdate → emit OrdersTodayNoFile
  │
  ▼
UI muestra OrdersEmptyState (botón manual)
```

### Gestión de errores y validaciones

- **Error en creación:** `_createTodayFile` devuelve `Left(Failure)` → se emite
  `OrdersTodayError` con el tipo mapeado. El timer de 3s se ignora (no se espera
  si ya hay error). Se puede lograr con `Future.wait` donde si la creación
  falla, se propaga el error inmediatamente sin esperar al delay.
- **Documento creado concurrentemente:** `createTodaySheet` ya maneja esto
  internamente — detecta documento existente y lo carga. No requiere cambio.
- **BLoC cerrado durante creación:** Verificar `isClosed` antes de emitir tras
  el `Future.wait`. Esto ya es un patrón usado en otros handlers del BLoC.

### Consideraciones de compatibilidad o migración

- **No hay breaking changes:** El estado `OrdersTodayNoFile` sigue existiendo.
  Se usa para eliminación remota.
- **`OrdersEmptyState`** no se elimina — sigue siendo necesario para el caso de
  eliminación remota.
- **Tests existentes:** Los tests que verifican que `_loadOrders` con `null`
  emite `NoFile` deberán actualizarse para esperar `Creating` → `Loaded` (o
  `Error`).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                    | Propósito                                                      |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `lib/features/orders_today/presentation/widgets/orders_preparing_state.dart` | Widget con animación y mensaje i18n para el estado de creación |

### Artefactos a modificar

| Artefacto                                                             | Cambio esperado                                                                                                              |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/presentation/bloc/orders_today_state.dart` | Añadir `OrdersTodayCreating` al sealed class                                                                                 |
| `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart`  | Modificar `_loadOrders()`: cuando `sheet == null`, emitir `Creating` y ejecutar auto-creación con `Future.wait` de 3s mínimo |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart` | Añadir case `OrdersTodayCreating` en el `switch` del `BlocBuilder` mapeado al nuevo widget                                   |
| `lib/app/localization/l10n/app_es.arb`                                | Añadir clave `ordersTodayPreparingTemplate`                                                                                  |
| Tests del BLoC (si existen)                                           | Actualizar expectativas para el nuevo flujo                                                                                  |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                                                 |
| --------- | ------------------------------------------------------ |
| Ninguno   | `OrdersEmptyState` se mantiene para eliminación remota |

## 6) Estrategia de implementación

### Pasos ordenados

1. **Añadir clave i18n** en `app_es.arb`:
   ```
   "ordersTodayPreparingTemplate": "Preparando plantilla para pedidos de hoy…"
   ```
   Ejecutar `flutter gen-l10n` para regenerar.

2. **Añadir estado `OrdersTodayCreating`** en `orders_today_state.dart`:
   ```dart
   final class OrdersTodayCreating extends OrdersTodayState {
     const OrdersTodayCreating();
   }
   ```

3. **Modificar `_loadOrders()` en el BLoC** para implementar la auto-creación:
   - Cuando `sheet == null`: emitir `OrdersTodayCreating`, ejecutar
     `Future.wait` con creación + delay 3s, luego emitir resultado.
   - Si error: emitir `OrdersTodayError` sin esperar delay.

4. **Crear widget `OrdersPreparingState`** en `presentation/widgets/`:
   - `CircularProgressIndicator` + texto i18n `ordersTodayPreparingTemplate`.
   - Usar design tokens del tema (colores, tipografía).

5. **Actualizar `_OrdersTodayContentState.build()`** en la página:
   - Añadir case `OrdersTodayCreating()` en el `switch` mapeándolo al nuevo
     widget.

6. **Actualizar tests** del BLoC para reflejar el nuevo flujo.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6

### Dependencias entre pasos

- Paso 3 depende de paso 2 (nuevo estado).
- Paso 4 depende de paso 1 (clave i18n).
- Paso 5 depende de pasos 2 y 4 (estado + widget).

### Puntos delicados

- **`Future.wait` con error temprano:** Si `_createTodayFile` falla antes de los
  3s, no se debe esperar al delay para mostrar el error. Implementar con una
  variable que capture el resultado de la creación y, si es error, emitir
  inmediatamente. Alternativa: usar `Future.wait` pero envolver la creación para
  propagar errores sin esperar el delay.

  Patrón sugerido:
  ```dart
  emit(const OrdersTodayCreating());
  final results = await Future.wait([
    _createTodayFile(CreateTodayFileParams(date: DateTime.now())),
    Future.delayed(const Duration(seconds: 3)),
  ], eagerError: false);
  final createResult = results[0] as Either<Failure, OrderSheet>;
  createResult.fold(
    (failure) => emit(OrdersTodayError(errorType: _mapFailure(failure))),
    (sheet) {
      _startWatch();
      emit(OrdersTodayLoaded(orderSheet: sheet));
    },
  );
  ```

  Nota: `eagerError: false` (default) asegura que ambos futures completen. Esto
  es correcto porque incluso si falla la creación, queremos que el delay
  complete (no cancelable), pero emitiremos error igualmente. Sin embargo, para
  UX podría ser preferible emitir el error sin esperar. En ese caso se puede
  usar una implementación más manual:

  ```dart
  emit(const OrdersTodayCreating());
  final createFuture = _createTodayFile(CreateTodayFileParams(date: DateTime.now()));
  final delayFuture = Future.delayed(const Duration(seconds: 3));
  final createResult = await createFuture;
  // Si error, emitir inmediatamente sin esperar delay
  if (createResult.isLeft()) {
    createResult.fold(
      (failure) => emit(OrdersTodayError(errorType: _mapFailure(failure))),
      (_) {},
    );
    return;
  }
  // Si éxito, esperar a que el delay complete
  await delayFuture;
  createResult.fold(
    (_) {},
    (sheet) {
      _startWatch();
      emit(OrdersTodayLoaded(orderSheet: sheet));
    },
  );
  ```

  **Recomendación:** Usar el segundo patrón (error inmediato, éxito espera
  delay). Esto ofrece mejor UX: el usuario ve el error rápidamente sin esperar
  3s innecesarios.

- **Guard `isClosed`:** Verificar que el BLoC no esté cerrado antes de emitir
  tras `await`. Dado que `emit` dentro de un handler de BLoC no debería llamarse
  si el BLoC está cerrado, y `flutter_bloc` ya gestiona esto internamente (el
  handler recibe un `Emitter` scoped), no se requiere guard adicional.

## 7) Estrategia de validación

### Verificación automática

- **Test unitario del BLoC:** Verificar que `OrdersTodayLoadRequested` cuando
  `getTodayOrders` retorna `null`:
  - Emite secuencia:
    `[OrdersTodayLoading, OrdersTodayCreating, OrdersTodayLoaded]`
  - La transición de `Creating` a `Loaded` tarda al menos 3 segundos (usar
    `fakeAsync`).
- **Test unitario del BLoC — error:** Verificar que si `createTodayFile` falla:
  - Emite secuencia:
    `[OrdersTodayLoading, OrdersTodayCreating, OrdersTodayError]`
  - El error se emite sin esperar los 3s.
- **Test unitario del BLoC — eliminación remota:** Verificar que
  `_onRemoteOrderUpdate` con `null` sigue emitiendo `OrdersTodayNoFile` (no
  `Creating`).

### Verificación manual

- Navegar a "Pedidos de hoy" sin documento existente → verificar animación con
  mensaje durante ~3s → tabla aparece.
- Navegar con documento existente → tabla carga directamente sin animación.
- Simular error (desconexión) → verificar que el error aparece rápidamente, no
  tras 3s.
- Con la tabla visible, eliminar el documento desde Firestore console →
  verificar que aparece el estado vacío con botón manual (no auto-creación).

### Escenarios a cubrir

- Creación rápida (<1s) → animación dura 3s completos.
- Creación lenta (>3s) → tabla aparece inmediatamente al completar.
- Creación con error → error inmediato.
- Documento ya existente al cargar → tabla directa.
- Eliminación remota → estado vacío con botón manual.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **R-01 (bajo):** Tests existentes del BLoC fallan al esperar `NoFile` donde
  ahora se emite `Creating`. Mitigación: actualizar tests en el mismo PR.
- **R-02 (bajo):** Si el delay de 3s no se cancela al cerrar el BLoC, podría
  intentar emitir en un BLoC cerrado. Mitigación: `flutter_bloc` ya protege
  contra esto internamente con el `Emitter` scoped al handler.

### Impacto potencial

- Solo afecta a la feature `orders_today`, capa de presentación.
- No impacta otras features ni capas de dominio/datos.
- No modifica contratos de repositorio ni use cases.

### Mitigación

- Desarrollo incremental siguiendo los pasos ordenados.
- Cada paso es testeable de forma independiente.

### Plan de rollback

- Revertir los cambios en BLoC, estados, página y widget.
- Los cambios son puramente aditivos (nuevo estado, nuevo widget) y la
  modificación del BLoC es localizada en `_loadOrders()`.

## 9) Suposiciones

- S-01: No se requiere animación Lottie ni dependencia externa —
  `CircularProgressIndicator` + texto es suficiente (PA-01 del análisis
  funcional queda abierta a criterio de implementación).
- S-02: `flutter gen-l10n` se ejecuta como parte del flujo normal de desarrollo
  tras modificar ARBs.
- S-03: No hay tests existentes del BLoC que estén afectados (verificar en
  implementación; si los hay, se actualizan).

## 10) Preguntas abiertas

- Ninguna bloqueante. PA-01 (tipo de animación) se deja a criterio de
  implementación: `CircularProgressIndicator` con texto como baseline.

## 11) Notas para implementación

- **Restricción clave:** `OrdersTodayNoFile` se reserva exclusivamente para
  eliminación remota (cuando `_onRemoteOrderUpdate` recibe `null`). No debe
  emitirse desde `_loadOrders()`.
- **Secuencia sugerida:** i18n → estado → BLoC → widget → página → tests.
- **Patrón de error temprano:** Usar el patrón donde el error se emite
  inmediatamente sin esperar el delay de 3s. Solo en caso de éxito se espera a
  que el delay complete.
- **No romper `_onCreateFile`:** El handler existente de
  `OrdersTodayCreateFileRequested` sigue funcionando para el caso de botón
  manual (eliminación remota). No modificarlo.
- **Widget `OrdersEmptyState`:** No eliminarlo ni modificarlo. Sigue en uso para
  el estado `OrdersTodayNoFile` (eliminación remota).
- **Estado: Listo para implementación**
