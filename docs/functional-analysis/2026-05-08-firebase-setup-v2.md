# Functional Analysis: Configuración de Firebase y Concurrencia en Pedidos de Hoy

- **Fecha:** 2026-05-08
- **Identificador:** firebase-setup
- **Estado:** Ready for technical analysis

## 1) Resumen

Integrar Firebase (un único proyecto) en la aplicación Servicebo para habilitar
**Realtime Database (RTDB)** y **Analytics**. El uso principal de RTDB es
resolver la **concurrencia multiusuario en la pantalla de Pedidos de Hoy**,
permitiendo que varias personas editen la hoja de pedidos simultáneamente con
bloqueo de celdas, sincronización de cambios en tiempo real y visualización de
cursores remotos. Google Sheets deja de ser fuente de verdad en tiempo real y
pasa a ser **backup persistente**. Se elimina el polling actual
(`Timer.periodic`) en favor de listeners de Firebase.

## 2) Contexto y objetivo

### Qué se solicita

1. Configurar Firebase (`firebase_core`, `firebase_database`,
   `firebase_analytics`) en el proyecto.
2. Implementar un sistema de edición concurrente en la pantalla de Pedidos de
   Hoy basado en RTDB, con locks de celda, sincronización de deltas y cursores
   remotos.
3. Degradar Google Sheets de "fuente de verdad en tiempo real" a "backup
   persistente", eliminando el polling por `modifiedTime`.

### Qué problema resuelve

- **Actualmente:** la pantalla de Pedidos de Hoy usa polling (`Timer.periodic` →
  `OrdersTodayCheckModifiedRequested`) para detectar cambios en Google Sheets.
  Esto es lento (~segundos de latencia), no permite saber si otro usuario está
  editando una celda, y dos usuarios pueden sobrescribirse mutuamente.
- **Con Firebase RTDB:** los cambios se propagan en ~100ms, las celdas se
  bloquean durante la edición, y cada usuario ve los cursores de los demás.

### Qué resultado funcional se espera

- Múltiples usuarios pueden trabajar en la misma hoja de pedidos simultáneamente
  sin conflictos ni pérdida de datos.
- Las celdas bloqueadas por otro usuario son visualmente identificables y no
  editables.
- Los cursores de los demás usuarios son visibles.
- Google Sheets se actualiza en background como backup; si falla la escritura a
  Sheets, el dato no se pierde (está en RTDB).
- Firebase Analytics registra eventos de uso de la aplicación.

## 3) Alcance

### En alcance

- **AC-01:** Configuración de un único proyecto Firebase con apps para macOS y
  Windows.
- **AC-02:** Integración de dependencias: `firebase_core`, `firebase_database`,
  `firebase_analytics`.
- **AC-03:** Inicialización de Firebase en el arranque de la app (integrada con
  `_initializeServices`).
- **AC-04:** Estructura de datos en RTDB para el nodo `today` (date, locks,
  cells, cursors).
- **AC-05:** Flujo de apertura: leer `today/date`, resetear si no es hoy, cargar
  sheet base de Google Sheets, suscribirse a `cells`, `locks` y `cursors`.
- **AC-06:** Flujo de edición: transacción de lock → edición → escritura en
  `cells` + borrado de lock → escritura a Google Sheets en background.
- **AC-07:** Recepción de cambios remotos: actualizar `OrderSheet` en el BLoC
  con deltas recibidos de RTDB.
- **AC-08:** Visualización de celdas bloqueadas por otros usuarios.
- **AC-09:** Visualización de cursores remotos (posición + color por usuario).
- **AC-10:** Limpieza de locks expirados en el cliente (lock con `ts > 60s` →
  borrar).
- **AC-11:** Eliminación del `Timer.periodic` de polling existente en
  `OrdersTodayPage`.
- **AC-12:** Google Sheets como backup: `updateCell` en background
  (fire-and-forget), flush al cerrar la app, reconciliación al abrir al día
  siguiente.
- **AC-13:** Firebase Analytics con eventos automáticos de pantalla.

### Fuera de alcance

- Reglas de seguridad de RTDB para producción (se usarán reglas de desarrollo
  inicialmente).
- Cloud Functions o lógica server-side en Firebase.
- Migración de datos históricos a RTDB (solo se usa para el día en curso).
- Plan detallado de eventos de analytics de negocio (más allá de los
  automáticos).
- Soporte para plataformas móviles (iOS/Android); solo macOS y Windows.
- Firebase Authentication (se usa el sistema existente de Google OAuth /
  FacturaDirecta).
- Resolución de conflictos offline complejos (se confía en el mecanismo
  transaccional de RTDB y los locks).

## 4) Actores implicados

| Actor                       | Rol                                                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Usuario operador**        | Abre la pantalla de Pedidos de Hoy, edita celdas de cantidades, ve los cambios y cursores de otros usuarios |
| **Usuarios concurrentes**   | Otros operadores editando la misma hoja simultáneamente                                                     |
| **Sistema (Firebase RTDB)** | Propaga cambios en tiempo real entre todos los clientes conectados                                          |
| **Sistema (Google Sheets)** | Almacenamiento persistente de backup, fuente de estado base al inicio del día                               |

## 5) Requisitos funcionales

### Configuración Firebase

- **RF-01:** El proyecto debe incluir `firebase_core`, `firebase_database` y
  `firebase_analytics` como dependencias.
- **RF-02:** Firebase debe inicializarse al arrancar la app, antes de la
  inyección de dependencias, usando un único proyecto Firebase.
- **RF-03:** Si la inicialización de Firebase falla, la app debe registrar el
  error y continuar funcionando sin las features de tiempo real (degradación
  graceful a comportamiento actual).

### Estructura RTDB

- **RF-04:** El nodo raíz para la funcionalidad de pedidos será `today` con la
  estructura:
  ```
  today/
    date: "YYYY-MM-DD"
    locks/
      {productRow}_{clientCol}: { user, ts }
    cells/
      {productRow}_{clientCol}: { v, user, ts }
    cursors/
      {userId}: { r, c, color }
  ```
- **RF-05:** La clave de cada celda en `locks` y `cells` se forma como
  `{productRow}_{clientCol}` (ej: `3_5`).

### Flujo de apertura

- **RF-06:** Al abrir la pantalla de Pedidos de Hoy, leer `today/date` de RTDB.
- **RF-07:** Si `today/date` no coincide con la fecha de hoy, ejecutar una
  **transacción atómica** que resetee todo el nodo `today` (vaciar locks, cells,
  cursors y actualizar date).
- **RF-08:** Cargar el sheet completo de Google Sheets como estado base
  (comportamiento actual de `GetTodayOrders`).
- **RF-09:** Suscribirse a `today/cells` y aplicar deltas sobre el estado base.
- **RF-10:** Suscribirse a `today/locks` para pintar celdas bloqueadas.
- **RF-11:** Suscribirse a `today/cursors` para pintar cursores remotos.
- **RF-12:** Eliminar el `Timer.periodic` de polling (`_startPolling` /
  `OrdersTodayCheckModifiedRequested`).

### Flujo de edición

- **RF-13:** Cuando un usuario selecciona una celda para editar, ejecutar una
  **transacción en `today/locks/{r}_{c}`**:
  - Si está vacío o es del propio usuario → escribir lock (user + timestamp) →
    permitir edición.
  - Si es de otro usuario y no ha expirado → rechazar la edición (celda
    bloqueada).
- **RF-14:** Cuando el usuario confirma el valor editado:
  1. Escribir en `today/cells/{r}_{c}` =
     `{ v: valor, user: userId, ts: timestamp }`.
  2. Borrar `today/locks/{r}_{c}`.
  3. Escribir en Google Sheets via `updateCell` en background (fire-and-forget).
- **RF-15:** Cuando el usuario cancela la edición, borrar el lock sin escribir
  en `cells`.

### Recepción de cambios remotos

- **RF-16:** Al recibir un cambio en `today/cells/{r}_{c}`, si el `user` no soy
  yo:
  - Actualizar `quantities[r][c]` en el `OrderSheet`.
  - Recalcular `pedidos[r]` y `quedan[r]`.
  - Emitir nuevo estado `OrdersTodayLoaded`.
- **RF-17:** Al recibir un cambio en `today/locks`, actualizar la visualización
  de celdas bloqueadas (indicar qué usuario tiene el lock).
- **RF-18:** Al recibir un cambio en `today/cursors`, actualizar la posición del
  cursor del usuario remoto en la tabla.

### Locks expirados

- **RF-19:** Al suscribirse a `today/locks`, si un lock tiene `ts` mayor a 60
  segundos de antigüedad, cualquier cliente puede borrarlo.

### Google Sheets como backup

- **RF-20:** Cada edición confirma en Google Sheets en background (no bloquea
  UI).
- **RF-21:** Si falla la escritura a Google Sheets, el dato no se pierde (ya
  está en RTDB). La app puede reintentar o dejarlo para la siguiente apertura.
- **RF-22:** Al abrir la app al día siguiente, se lee el sheet completo de
  Google Sheets como nuevo estado base (reconciliación natural).

### Analytics

- **RF-23:** Firebase Analytics debe registrar al menos los eventos automáticos
  de pantalla (`screen_view`).

## 6) Criterios de aceptación

- **CA-01:** La app compila y arranca sin errores en macOS y Windows con
  Firebase inicializado.
- **CA-02:** Dos instancias de la app abiertas simultáneamente: cuando el
  usuario A edita la celda (3,5), el usuario B ve el cambio reflejado en menos
  de 2 segundos.
- **CA-03:** Cuando el usuario A está editando la celda (3,5), el usuario B ve
  la celda visualmente marcada como bloqueada y no puede abrirla para edición.
- **CA-04:** Cuando el usuario A confirma el valor, el lock desaparece y el
  usuario B puede ver el nuevo valor y editar esa celda.
- **CA-05:** Los cursores remotos son visibles: el usuario B ve un indicador de
  color en la posición donde se encuentra el usuario A en la tabla.
- **CA-06:** Al abrir la pantalla de pedidos en un nuevo día, el nodo `today` se
  resetea atómicamente y se carga el sheet de Google Sheets como estado base
  limpio.
- **CA-07:** Si un usuario cierra la app sin confirmar una edición, su lock se
  limpia automáticamente (por otro cliente) en menos de 60 segundos.
- **CA-08:** No existe `Timer.periodic` ni polling de `modifiedTime` en la
  pantalla de Pedidos de Hoy. Toda la sincronización es por listeners de RTDB.
- **CA-09:** Las ediciones se persisten en Google Sheets en background. Si se
  cierra y reabre la app, los datos del día están en Google Sheets.
- **CA-10:** Si Firebase no está disponible (sin red, error de configuración),
  la app funciona en su modo actual (lectura de Google Sheets + polling) como
  fallback.
- **CA-11:** Los tests existentes no se rompen por la integración de Firebase.
- **CA-12:** Un evento de analytics es visible en la consola de Firebase.

## 7) Flujos y comportamiento esperado

### Flujo principal — Apertura y carga con RTDB

```
1. Usuario abre pantalla "Pedidos de Hoy"
2. Leer today/date de RTDB
3. ¿Coincide con hoy?
   ├─ SÍ → continuar
   └─ NO → Transacción atómica: resetear today {date: hoy, locks: {}, cells: {}, cursors: {}}
4. Cargar sheet completo de Google Sheets → estado base (OrderSheet)
5. Aplicar deltas de today/cells sobre el estado base (si hay celdas editadas hoy)
6. Emitir OrdersTodayLoaded con el estado combinado
7. Suscribirse a today/cells → aplicar deltas futuros
8. Suscribirse a today/locks → pintar bloqueos
9. Suscribirse a today/cursors → pintar cursores remotos
10. Escribir mi cursor en today/cursors/{userId}
```

### Flujo principal — Edición de celda

```
1. Usuario toca celda (r, c)
2. Transacción en today/locks/{r}_{c}:
   ├─ Vacío o mío → escribir lock {user, ts} → abrir editor
   └─ De otro usuario (no expirado) → mostrar feedback "Celda bloqueada por {user}" → cancelar
3. Usuario introduce valor y confirma
4. Escribir today/cells/{r}_{c} = {v: valor, user: userId, ts: now}
   → Firebase propaga a todos los clientes
5. Borrar today/locks/{r}_{c}
   → Firebase propaga desbloqueo
6. Background: updateCell en Google Sheets (fire-and-forget)
7. Actualizar OrderSheet local: quantities[r][c] = valor, recalcular pedidos[r] y quedan[r]
8. Emitir OrdersTodayLoaded actualizado
```

### Flujo de recepción de cambio remoto

```
1. Firebase listener en today/cells/{r}_{c} dispara con nuevo valor
2. ¿Es mi propio cambio (user == yo)? → Ignorar (ya tengo el valor local)
3. Actualizar OrderSheet:
   - quantities[r][c] = valor recibido
   - Recalcular pedidos[r] = sum(quantities[r])
   - Recalcular quedan[r] = stocks[r] - pedidos[r]
4. Emitir OrdersTodayLoaded con OrderSheet actualizado
```

### Flujos alternativos

- **FA-01 — Usuario cancela edición:** Borrar `today/locks/{r}_{c}` sin escribir
  en `cells`. La celda queda desbloqueada.
- **FA-02 — Firebase no disponible al arrancar:** La app opera en modo
  degradado: carga Google Sheets como ahora, reactiva polling con
  `Timer.periodic`, y muestra un indicador de que la sincronización en tiempo
  real no está activa.
- **FA-03 — Pérdida de conexión durante uso:** RTDB opera en modo offline con
  cache local. Los cambios se sincronizan al reconectar. Los locks podrían
  quedar huérfanos → se limpian por TTL (60s).
- **FA-04 — Fallo de escritura a Google Sheets:** El dato ya está en RTDB y
  propagado a todos los clientes. Se encola para reintento o se reconcilia en la
  siguiente apertura.
- **FA-05 — Dos usuarios intentan lockear la misma celda simultáneamente:** La
  transacción de Firebase garantiza que solo uno gana. El segundo recibe "celda
  bloqueada".

### Estados especiales / excepciones

- **Estado vacío (no hay sheet para hoy):** Flujo actual → mostrar
  `OrdersEmptyState` con opción de crear archivo. Al crearlo, se inicializa el
  nodo RTDB también.
- **Estado loading:** Se muestra el indicador de carga actual mientras se
  obtiene el sheet base y se sincronizan los deltas de RTDB.
- **Estado error:** Si falla la carga del sheet base, se muestra
  `OrdersErrorState` como ahora. Si solo falla Firebase, se degrada a polling.
- **Sin permisos/sin datos:** Comportamiento actual; Firebase no afecta a la
  lógica de autenticación.

## 8) Edge cases

- **EC-01:** El usuario edita una celda y cierra la app antes de confirmar →
  lock queda huérfano → cualquier cliente lo limpia tras 60s.
- **EC-02:** Dos clientes detectan que `today/date` no es hoy al mismo tiempo →
  ambos intentan la transacción de reset → la transacción atómica de Firebase
  garantiza que solo uno tiene éxito; el otro relee el resultado.
- **EC-03:** El usuario edita la misma celda dos veces rápidamente → el segundo
  lock reemplaza al primero (mismo usuario); el segundo valor sobrescribe al
  primero en `cells`.
- **EC-04:** Un lock está a punto de expirar (59s) y el usuario está terminando
  de escribir → el usuario podría perder el lock. Se podría extender el TTL al
  interactuar con el editor, pero esto se deja como mejora futura.
- **EC-05:** Google Sheets está caído al arrancar → la app no puede obtener el
  estado base. Si RTDB tiene datos del día actual (cells), se podría reconstruir
  parcialmente, pero la estructura completa (clients, products, stocks) viene de
  Sheets. La app debe mostrar error y reintentar.
- **EC-06:** `firebase_analytics` podría tener soporte limitado en Windows
  desktop. Verificar compatibilidad real; si no está soportado, desactivar
  analytics en Windows sin afectar RTDB.
- **EC-07:** Hot restart en desarrollo → múltiples llamadas a
  `Firebase.initializeApp` deben manejarse sin error (verificar si ya está
  inicializado).
- **EC-08:** El cursor de un usuario que cierra la app queda en `today/cursors`
  → se puede limpiar con `onDisconnect()` de Firebase o por TTL similar a locks.

## 9) Impacto funcional

### Módulos y archivos afectados

| Área                                              | Impacto                                                                                               |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `pubspec.yaml`                                    | Nuevas dependencias: `firebase_core`, `firebase_database`, `firebase_analytics`                       |
| `lib/main.dart`                                   | `Firebase.initializeApp` en `_initializeServices`                                                     |
| `lib/app/config/`                                 | `FirebaseOptions` (posiblemente en `firebase_options.dart` generado por FlutterFire CLI)              |
| `lib/app/di/`                                     | Registro de servicios de Firebase en GetIt                                                            |
| `lib/features/orders_today/presentation/bloc/`    | Nuevos eventos y estados para locks, cells remotos, cursores; eliminación de `CheckModifiedRequested` |
| `lib/features/orders_today/presentation/pages/`   | Eliminar `Timer.periodic` y `_startPolling`; gestionar suscripciones RTDB                             |
| `lib/features/orders_today/presentation/widgets/` | Pintar celdas bloqueadas y cursores remotos en la tabla                                               |
| `lib/features/orders_today/domain/`               | Posible nueva entidad para CellLock / RemoteCursor; nuevo repositorio o extensión del existente       |
| `lib/features/orders_today/data/`                 | Nuevo datasource para RTDB; el datasource de Google Sheets se simplifica (solo backup)                |
| `lib/core/`                                       | Posible servicio wrapper de Firebase RTDB                                                             |
| Plataforma `macos/`                               | Entitlements de red, Podfile                                                                          |
| Plataforma `windows/`                             | CMakeLists si es necesario                                                                            |

### Impacto en usuario

- **Positivo:** Edición colaborativa en tiempo real, sin conflictos ni
  sobrescrituras. Visibilidad de qué celdas están siendo editadas y por quién.
- **Neutral:** El usuario no necesita cambiar su forma de trabajar; la
  experiencia mejora de forma transparente.

### Impacto en negocio

- Elimina el riesgo de pérdida de datos por edición concurrente.
- Habilita el trabajo simultáneo de múltiples operadores en la hoja de pedidos
  diaria.
- Proporciona métricas de uso via Analytics.

### Impacto en experiencia de usuario

- Las celdas bloqueadas por otro usuario deben ser visualmente distinguibles
  (color, icono, tooltip con el nombre del usuario).
- Los cursores remotos deben ser visibles sin ser intrusivos (color +
  identificador del usuario).
- El feedback de "celda bloqueada" debe ser inmediato y claro.

## 10) Suposiciones

- **S-01:** Se usará un único proyecto Firebase para todos los entornos. La
  separación local/pro puede hacerse con prefijos en RTDB o configuración de la
  misma instancia (dado que solo hay un nodo `today` efímero, la separación no
  es crítica).
- **S-02:** La identidad del usuario (para locks y cursors) se deriva del
  sistema de autenticación existente (Google OAuth). No se requiere Firebase
  Auth.
- **S-03:** Las plataformas objetivo son exclusivamente macOS y Windows
  (desktop).
- **S-04:** El TTL de 60 segundos para locks expirados es suficiente; no se
  necesitan Cloud Functions.
- **S-05:** La estructura de `OrderSheet` (clients, products, stocks) sigue
  viniendo de Google Sheets; RTDB solo sincroniza las cantidades editadas
  (`quantities`).
- **S-06:** Se aceptan reglas de seguridad abiertas en RTDB para la fase
  inicial.
- **S-07:** La versión mínima de macOS del proyecto es ≥ 10.15 (requerido por
  Firebase).
- **S-08:** El identificador de usuario para locks/cursors es consistente entre
  sesiones (ej.: email de Google OAuth o un ID derivado).

## 11) Preguntas abiertas

- **PA-01:** ¿Cómo se identifica al usuario en RTDB? ¿Se usa el email del Google
  OAuth como `userId`, un nombre corto, o un ID interno? Esto afecta al campo
  `user` en locks/cells y al key en `cursors`.
- **PA-02:** ¿Debe mostrarse un indicador global de "X usuarios conectados"
  además de los cursores individuales?
- **PA-03:** ¿Las columnas de STOCKS se editan también con concurrencia vía
  RTDB, o solo las celdas de cantidades de clientes (`quantities`)?

## 12) Notas para análisis técnico

- **Compatibilidad de plugins:** Verificar que `firebase_database` funciona en
  macOS y Windows. `firebase_analytics` podría no estar soportado en Windows →
  plan de contingencia (desactivarlo condicionalmente).
- **FlutterFire CLI:** Evaluar `flutterfire configure` para generar
  `firebase_options.dart`.
- **Transacciones RTDB:** Usar `DatabaseReference.runTransaction` para los locks
  y para el reset de `today/date`.
- **Listeners RTDB:** Usar `onChildAdded`, `onChildChanged`, `onChildRemoved` en
  `today/cells`, `today/locks`, `today/cursors` para actualizaciones granulares
  (no `onValue` del nodo completo).
- **`onDisconnect()`:** Usar
  `FirebaseDatabase.instance.ref('today/cursors/{userId}').onDisconnect().remove()`
  para limpiar el cursor al desconectarse.
- **BLoC refactor:** El `OrdersTodayBloc` necesitará nuevos eventos para deltas
  remotos y locks. Posiblemente dividir en dos BLoCs: uno para el estado de
  datos y otro para la capa de presencia/cursores.
- **Testing:** Proveer mock del datasource de RTDB para tests unitarios. No
  depender de Firebase real en tests.
- **Degradación graceful:** Si Firebase no está disponible, la app debe poder
  funcionar con el flujo actual (Google Sheets + polling). Implementar un flag o
  servicio que detecte disponibilidad.
- **Entitlements macOS:** Verificar que `com.apple.security.network.client` está
  habilitado (probablemente ya lo está por Google APIs).
- **Estado: Listo para análisis técnico.**
