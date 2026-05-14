# Technical Analysis: Vista de solo lectura de pedidos de hoy (pantalla empaquetado)

- **Fecha:** 2026-05-13
- **Identificador:** orders-today-readonly-view
- **Fuente:** docs/functional-analysis/2026-05-13-orders-today-readonly-view.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Añadir campo `lastModifiedAt` a la entidad `OrderSheet` y propagarlo desde
  `OrderDocumentModel` a través del mapping del repositorio.
- Añadir propiedad `readOnly` al widget `OrdersTable` para desactivar edición,
  menú contextual y acciones de modificación.
- Crear una nueva página `OrdersTodayReadonlyPage` que instancia su propio BLoC
  de solo lectura, muestra `OrdersTable` en modo `readOnly` con un footer que
  incluye timestamp + indicador de conexión.
- Registrar una nueva ruta `/orders-today/view` **fuera** del `ShellRoute` (sin
  `SideMenuShell`) pero protegida por el guard de autenticación.
- Conectar el botón ampliar existente para abrir esa ruta en nueva pestaña via
  `web/web.dart`.
- Añadir claves i18n necesarias.
- Principales áreas impactadas: entidad de dominio, widget `OrdersTable`,
  router, nueva página, i18n.
- Riesgo general estimado: **bajo** — los cambios son aditivos y la lógica de
  negocio no se modifica.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC, GetIt y fpdart.
- Router: `go_router` con un `ShellRoute` que envuelve con `SideMenuShell`.
- Todas las rutas dentro del `ShellRoute` se protegen con un `redirect` global
  que verifica `FirebaseAuth.currentUser`.

### Módulos relevantes

- **`orders_today/domain/entities/order_sheet.dart`**: entidad Equatable con
  todos los datos de la tabla. **No incluye** `lastModifiedAt`.
- **`orders_today/data/models/order_document_model.dart`**: modelo Firestore que
  **sí incluye** `lastModifiedAt`.
- **`orders_today/data/repositories/orders_today_repository_impl.dart`**:
  `_buildOrderSheet()` mapea `OrderDocumentModel` → `OrderSheet` pero descarta
  `lastModifiedAt`.
- **`orders_today/presentation/widgets/orders_table.dart`**: tabla con callbacks
  nullable (`onCellUpdated`, `onAddClient`, etc.). Algunos elementos ya se
  ocultan si el callback es `null` (ej: `if (widget.onAddClient != null)`), pero
  `isEditable` se calcula como `isClient || isStocks` sin verificar callbacks →
  las celdas son interactivas incluso si `onCellUpdated` es null.
- **`orders_today/presentation/widgets/orders_table_footer.dart`**: footer con
  sección de usuarios conectados y `trailing` opcional.
- **`orders_today/presentation/pages/orders_today_page.dart`**: contiene el
  botón ampliar con `onPressed: () {}` vacío.
- **`app/router/router.dart`**: rutas definidas con `ShellRoute` + redirect
  global.
- **`core/utils/web_download_web.dart`**: ya usa `package:web/web.dart` para
  interacción con el navegador (patrón conditional import con stub).
- **`orders_today/presentation/bloc/orders_today_bloc.dart`**: el BLoC ya
  suscribe `watchTodayOrders` para actualizaciones en tiempo real via
  `_startWatch()`.

### Restricciones

- Web only (la app no se ejecuta en iOS/Android).
- Apertura de nueva ventana debe ser síncrona (directa desde `onPressed`) para
  evitar bloqueo de popups.
- `package:web/web.dart` ya disponible como dependencia (usado en
  `web_download_web.dart`).

## 3) Objetivo técnico

- **Qué debe cambiar:** Propagar `lastModifiedAt` a `OrderSheet`, hacer que
  `OrdersTable` soporte modo solo lectura explícito, crear nueva página y ruta
  sin shell.
- **Resultado:** Una URL `/orders-today/view` accesible en nueva pestaña que
  muestra la tabla de pedidos del día en modo solo lectura, actualizada en
  tiempo real, con timestamp e indicador de conexión.
- **Limitaciones:** No se modifica la lógica de negocio ni el flujo de escritura
  de datos.

## 4) Diseño técnico de la solución

### Enfoque propuesto

1. **Propagación de `lastModifiedAt`**: Añadir campo `DateTime? lastModifiedAt`
   a `OrderSheet` y mapearlo en `_buildOrderSheet` desde
   `OrderDocumentModel.lastModifiedAt`.
2. **Modo solo lectura en `OrdersTable`**: Añadir propiedad
   `bool readOnly = false`. Cuando `readOnly == true`:
   - `isEditable` se fuerza a `false` (no se entra en modo edición).
   - No se desactiva el context menu del navegador (`BrowserContextMenu`).
   - No se muestra el botón "+ Añadir cliente" ni "+ Añadir producto" (ya
     controlado por callbacks null, pero `readOnly` refuerza).
   - No se muestran menús contextuales de celdas, clientes ni productos.
   - No se inicializa la suscripción de presencia.
3. **Nueva página `OrdersTodayReadonlyPage`**: Página ligera que:
   - Crea su propio `OrdersTodayBloc` (solo carga + watch, sin escritura).
   - Muestra estados loading/error/vacío apropiados.
   - En estado `Loaded`: renderiza `OrdersTable` con `readOnly: true` y un
     footer personalizado con timestamp + indicador.
4. **Widget de footer readonly**: Muestra "Última actualización: DD/MM/YYYY
   HH:mm:ss" con un punto verde parpadeante (animado con `AnimationController`).
   El punto cambia a gris si el stream se interrumpe.
5. **Ruta fuera del shell**: Añadir `GoRoute` al nivel raíz (fuera del
   `ShellRoute`), protegida por el redirect existente.
6. **Acción del botón ampliar**: Usar `web.window.open()` de
   `package:web/web.dart` con conditional import para abrir `/orders-today/view`
   en `_blank`.

### Componentes / módulos / servicios afectados

| Componente                                         | Tipo de cambio                                |
| -------------------------------------------------- | --------------------------------------------- |
| `OrderSheet` (entidad de dominio)                  | Añadir campo `lastModifiedAt`                 |
| `OrdersTodayRepositoryImpl._buildOrderSheet`       | Propagar `lastModifiedAt`                     |
| `OrdersTable` (widget)                             | Añadir prop `readOnly`                        |
| `OrdersTodayReadonlyPage` (nueva página)           | Crear                                         |
| `ReadonlyFooter` / `LiveIndicator` (nuevo widget)  | Crear                                         |
| `router.dart`                                      | Nueva ruta                                    |
| `orders_today_page.dart`                           | Conectar botón ampliar                        |
| `app_es.arb`                                       | Nuevas claves i18n                            |
| `web_open_url_web.dart` / `web_open_url_stub.dart` | Crear (conditional import para `window.open`) |

### Contratos e interfaces

**`OrderSheet`** — se añade:

```dart
final DateTime? lastModifiedAt;
```

Con valor por defecto `null` y propagado en `copyWith` y `props`.

**`OrdersTable`** — se añade:

```dart
final bool readOnly;  // default: false
```

No se crean nuevos repositorios, use cases ni data sources. La página readonly
consume el mismo BLoC existente en modo lectura.

### Flujo de datos o de control

```
[Botón ampliar] → window.open('/orders-today/view', '_blank')
                        │
                        ▼
[GoRouter] → redirect verifica auth → OrdersTodayReadonlyPage
                        │
                        ▼
[OrdersTodayBloc] → OrdersTodayLoadRequested
                        │
                        ▼
[GetTodayOrders] → Firestore → OrderSheet (con lastModifiedAt)
                        │
                        ▼
[OrdersTodayBloc._startWatch] → watchTodayOrders stream
                        │
                        ▼
[OrdersTable readOnly:true] + ReadonlyFooter(lastModifiedAt, isConnected)
```

### Gestión de errores y validaciones

- **Sin documento del día:** La página muestra un estado informativo ("No hay
  pedidos para hoy") sin opción de crear. Se reutiliza el estado
  `OrdersTodayNoFile` o se adapta el handling del BLoC en la página readonly
  para no disparar `CreateTodayFileRequested`.
- **Error Firestore:** Mostrar estado error con botón reintentar (solo recarga).
- **Pérdida de conexión:** Firestore SDK mantiene último snapshot en caché. El
  indicador de conexión se basa en si el stream sigue emitiendo: si no emite
  durante un timeout configurable o se cierra, el punto pasa a gris.
- **`lastModifiedAt` null:** Mostrar "—" o no mostrar el timestamp hasta que se
  reciba un valor.

### Consideraciones de compatibilidad o migración

- `lastModifiedAt` se añade como campo nullable con default `null` a
  `OrderSheet` → no rompe ningún constructor existente (con named params
  opcionales).
- `readOnly` tiene default `false` → no afecta ningún uso actual de
  `OrdersTable`.
- La ruta nueva es aditiva, no modifica rutas existentes.
- No hay migración de datos: `lastModifiedAt` ya existe en todos los documentos
  de Firestore.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                      | Propósito                                                           |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| `lib/features/orders_today/presentation/pages/orders_today_readonly_page.dart` | Página de solo lectura que instancia BLoC y muestra la tabla        |
| `lib/features/orders_today/presentation/widgets/readonly_footer.dart`          | Footer con timestamp de última modificación e indicador de conexión |
| `lib/core/utils/web_open_url_stub.dart`                                        | Stub multiplataforma para `openUrlInNewTab`                         |
| `lib/core/utils/web_open_url_web.dart`                                         | Implementación web con `web.window.open()`                          |

### Artefactos a modificar

| Artefacto                                                                       | Cambio esperado                                                                                                              |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/domain/entities/order_sheet.dart`                    | Añadir `DateTime? lastModifiedAt` al constructor, copyWith y props                                                           |
| `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart` | Pasar `doc.lastModifiedAt` a `OrderSheet` en `_buildOrderSheet`                                                              |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`              | Añadir prop `bool readOnly = false`; condicionar `isEditable`, menús contextuales y `BrowserContextMenu`                     |
| `lib/app/router/router.dart`                                                    | Añadir constante `ordersTodayView`, nueva `GoRoute` fuera del `ShellRoute`                                                   |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`           | Conectar `onPressed` del botón ampliar para abrir URL en nueva pestaña                                                       |
| `lib/app/localization/l10n/app_es.arb`                                          | Añadir claves: `ordersTodayReadonlyTitle`, `ordersTodayLastModified`, `ordersTodayNoOrdersToday`, `ordersTodayLiveConnected` |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

1. **Paso 1 — Propagar `lastModifiedAt` a `OrderSheet`**
   - Añadir campo a la entidad, actualizar `copyWith`, `props` y constructor.
   - Modificar `_buildOrderSheet` en el repositorio para pasar
     `doc.lastModifiedAt`.

2. **Paso 2 — Modo `readOnly` en `OrdersTable`**
   - Añadir propiedad `bool readOnly = false` al widget.
   - En `_OrdersTableState`: condicionar `isEditable` →
     `(isClient || isStocks) && !widget.readOnly`.
   - Condicionar menús contextuales de celdas, clientes y productos: no mostrar
     si `readOnly`.
   - Condicionar `BrowserContextMenu.disableContextMenu()` en `initState`: solo
     si `!widget.readOnly`.
   - Condicionar inicialización de presencia: no suscribir si `readOnly`.

3. **Paso 3 — Utilidad `openUrlInNewTab`**
   - Crear `web_open_url_stub.dart` con función no-op.
   - Crear `web_open_url_web.dart` con `web.window.open(url, '_blank')`.

4. **Paso 4 — Claves i18n**
   - Añadir las claves necesarias al archivo ARB.
   - Regenerar traducciones (`flutter gen-l10n`).

5. **Paso 5 — Widget `ReadonlyFooter`**
   - Crear widget con fecha/hora formateada y animación de punto verde
     parpadeante.
   - El punto se anima con `AnimationController` de repeat (parpadeo ~1s).
   - Recibe `DateTime? lastModifiedAt` y `bool isConnected`.

6. **Paso 6 — Página `OrdersTodayReadonlyPage`**
   - Instanciar `OrdersTodayBloc` desde GetIt.
   - Disparar `OrdersTodayLoadRequested`.
   - Manejar estados: loading, error (con retry), vacío (sin crear), loaded.
   - En estado loaded: `OrdersTable(readOnly: true, orderSheet: ...)` +
     `ReadonlyFooter`.
   - Controlar `isConnected` basándose en si el BLoC sigue recibiendo eventos
     del stream (usar estado del stream watch del BLoC).

7. **Paso 7 — Ruta y navegación**
   - Añadir `static const String ordersTodayView = '/orders-today/view'` a
     `AppRoutes`.
   - Añadir `GoRoute` fuera del `ShellRoute` pero dentro del array `routes` del
     `GoRouter`.
   - Conectar botón ampliar en `orders_today_page.dart` con `openUrlInNewTab`.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7

### Dependencias entre pasos

- Paso 5 depende de paso 1 (necesita `lastModifiedAt` en `OrderSheet`).
- Paso 6 depende de pasos 2, 4 y 5.
- Paso 7 depende de pasos 3 y 6.

### Puntos delicados

- **`isEditable` en `OrdersTable`:** Es la línea crítica. Actualmente
  `isEditable = isClient || isStocks` se calcula sin verificar nada más. Se debe
  condicionar con `!widget.readOnly`. Si se omite, las celdas serían editables
  en la vista de solo lectura.
- **`BrowserContextMenu`:** En modo readOnly no se debe desactivar el menú
  contextual del navegador (no hay razón para bloquearlo). Si se omite, la vista
  readonly bloquearía el clic derecho nativo del navegador sin ofrecer menú
  propio.
- **Apertura de ventana síncrona:** `window.open` debe llamarse directamente en
  `onPressed`, sin `await` previo, para que el navegador no lo bloquee como
  popup.
- **Estado `OrdersTodayCreating` en readonly:** El BLoC intenta crear el
  documento si no existe. En la página readonly, se debe interceptar el estado
  `OrdersTodayNoFile`/`null` y mostrar un mensaje en lugar de disparar creación.
  La forma más simple es modificar la lógica en la página (no en el BLoC):
  verificar el estado y no disparar `CreateTodayFileRequested`.

## 7) Estrategia de validación

### Verificación automática

- `dart analyze` — sin errores ni warnings.
- `flutter test` — tests existentes siguen pasando (campo nullable con default
  no rompe).
- Test unitario para `OrderSheet.copyWith` verificando que `lastModifiedAt` se
  propaga.
- Test unitario para verificar que `_buildOrderSheet` incluye `lastModifiedAt`.

### Verificación manual

- Abrir la pantalla de pedidos de hoy → pulsar botón ampliar → se abre nueva
  pestaña con la tabla.
- Verificar que la tabla no es editable (clic, doble clic, clic derecho no
  activan nada).
- Modificar una celda en la pestaña principal → verificar que el cambio aparece
  en la pestaña readonly.
- Verificar que el timestamp de última modificación se muestra y se actualiza.
- Verificar el punto verde parpadeante.
- Acceder a `/orders-today/view` sin sesión → redirige a login.
- Acceder a `/orders-today/view` cuando no hay pedidos del día → muestra mensaje
  informativo.

### Escenarios a cubrir

- Tabla vacía (0 clientes, 0 productos).
- Tabla con muchos clientes/productos (scroll horizontal y vertical).
- Cambios estructurales en tiempo real (añadir/eliminar cliente desde la
  pantalla principal).
- Múltiples pestañas de solo lectura abiertas simultáneamente.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                          | Probabilidad | Impacto                                        |
| ----------------------------------------------- | ------------ | ---------------------------------------------- |
| Olvidar condicionar `isEditable` con `readOnly` | Baja         | Alto — celdas editables en vista readonly      |
| BLoC intenta crear documento en readonly        | Baja         | Medio — efecto secundario no deseado           |
| Popup bloqueado por navegador                   | Baja         | Bajo — el usuario puede permitirlo manualmente |

### Impacto potencial

- **En funcionalidad existente:** Nulo si `readOnly` tiene default `false` y
  `lastModifiedAt` es nullable con default `null`.
- **En rendimiento:** Despreciable — una suscripción Firestore adicional por
  pestaña readonly.
- **En datos:** Nulo — no se modifica la escritura.

### Mitigación

- Review explícito de la línea `isEditable` post-implementación.
- La página readonly no debe disparar eventos de escritura al BLoC.
- Usar `window.open` directamente en `onPressed` (no async) para evitar bloqueo.

### Plan de rollback

- Todos los cambios son aditivos. Revertir = eliminar la ruta, la página
  readonly y la utilidad; el campo `lastModifiedAt` y `readOnly` pueden quedarse
  sin efectos laterales.
- No hay migración de datos ni cambios destructivos.

## 9) Suposiciones

- El paquete `web` ya está declarado como dependencia (confirmado por su uso en
  `web_download_web.dart`).
- El redirect global del router aplica a rutas fuera del `ShellRoute`
  (confirmado: el redirect está en `GoRouter`, no en el `ShellRoute`).
- El BLoC `OrdersTodayBloc` puede instanciarse múltiples veces
  independientemente (está registrado como `factory` en GetIt, confirmado).
- El auto-create del día en el BLoC (`_loadOrders` llama a `_createTodayFile` si
  sheet es null) se puede evitar en la página readonly manejando el estado
  `null`/`OrdersTodayCreating` como "sin pedidos" antes de que el BLoC intente
  crear.

## 10) Preguntas abiertas

Ninguna — todas resueltas en el análisis funcional.

## 11) Notas para implementación

- **No modificar la lógica de negocio del BLoC existente.** La página readonly
  maneja la presentación de estados de forma diferente (no crea documentos),
  interceptando antes de que el BLoC lo intente, o usando el evento
  `OrdersTodayLoadRequested` y manejando el estado `OrdersTodayCreating` como
  "no hay pedidos".
- **Alternativa más limpia para evitar auto-create:** El BLoC auto-crea en
  `_loadOrders` si `getTodayOrders` devuelve `null`. Para la página readonly se
  puede crear un nuevo evento `OrdersTodayLoadReadonlyRequested` que no dispare
  creación, o simplemente crear una variante de `_onLoad` que emita
  `OrdersTodayNoFile` en lugar de `OrdersTodayCreating`. La opción más simple es
  añadir un parámetro `bool createIfMissing = true` al evento
  `OrdersTodayLoadRequested`.
- **Conditional import para `window.open`:** Seguir el mismo patrón de
  `web_download_stub.dart` / `web_download_web.dart`.
- Secuencia sugerida: dominio → widget → utils → i18n → page → router.
- **Estado: Listo para implementación**
