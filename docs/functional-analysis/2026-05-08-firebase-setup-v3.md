# Functional Analysis: Firebase RTDB — Concurrencia en Pedidos de Hoy

- **Fecha:** 2026-05-08
- **Identificador:** firebase-setup
- **Estado:** Ready for technical analysis

## 1) Resumen

Integrar Firebase (un único proyecto) en Servicebo para habilitar **Realtime
Database (RTDB)**. El uso principal de RTDB es resolver la **concurrencia
multiusuario en la pantalla de Pedidos de Hoy**: locks de celdas, sincronización
de cambios en tiempo real, cursores remotos y un indicador de usuarios
conectados. Se incluye la gestión de identidad de usuario (código aleatorio de 6
letras, persistido localmente y editable en Ajustes). Google Sheets pasa a ser
backup persistente; se elimina el polling actual. Tanto las celdas de cantidades
de clientes como la columna de STOCKS se editan con concurrencia vía RTDB.

## 2) Contexto y objetivo

### Qué se solicita

1. Configurar Firebase (`firebase_core`, `firebase_database`).
2. Sistema de edición concurrente multiusuario en Pedidos de Hoy con locks,
   deltas, cursores e indicador de presencia.
3. Identidad de usuario local: código aleatorio de 6 letras asignado en la
   primera apertura, editable en Ajustes.
4. Degradar Google Sheets de fuente de verdad a backup persistente.

### Qué problema resuelve

- **Actualmente:** la pantalla de Pedidos de Hoy usa polling (`Timer.periodic` →
  `OrdersTodayCheckModifiedRequested`) para detectar cambios en Google Sheets.
  Es lento, no bloquea celdas y permite sobrescrituras entre usuarios.
- **Con RTDB:** cambios propagados en ~100ms, celdas bloqueadas durante edición,
  cursores y presencia visibles.

### Qué resultado funcional se espera

- Múltiples usuarios trabajan simultáneamente sin conflictos ni pérdida de
  datos.
- Las celdas bloqueadas son visualmente identificables e inaccesibles para otros
  usuarios.
- Los cursores remotos y un contador de usuarios conectados son visibles.
- Google Sheets se actualiza en background como backup.

## 3) Alcance

### En alcance

- **AC-01:** Configuración de un único proyecto Firebase (macOS + Windows).
- **AC-02:** Dependencias: `firebase_core`, `firebase_database`.
- **AC-03:** Inicialización de Firebase en el arranque.
- **AC-04:** Identidad de usuario: generación de código aleatorio de 6 letras en
  la primera apertura, persistido en `SharedPreferences`, editable en la
  pantalla de Ajustes.
- **AC-05:** Estructura RTDB: nodo `today` con `date`, `locks`, `cells`,
  `cursors`.
- **AC-06:** Flujo de apertura: leer `today/date`, resetear si no es hoy, cargar
  sheet base, suscribirse a `cells`, `locks`, `cursors`.
- **AC-07:** Flujo de edición concurrente para celdas de **cantidades de
  clientes** (`quantities[r][c]`).
- **AC-08:** Flujo de edición concurrente para celdas de **STOCKS**
  (`stocks[r]`).
- **AC-09:** Recepción de cambios remotos: actualizar `OrderSheet` con deltas.
- **AC-10:** Visualización de celdas bloqueadas por otros.
- **AC-11:** Visualización de cursores remotos (posición + color + nombre de
  usuario).
- **AC-12:** Indicador global de usuarios conectados.
- **AC-13:** Limpieza de locks expirados (TTL 60s) en el cliente.
- **AC-14:** Eliminación de `Timer.periodic` de polling.
- **AC-15:** Google Sheets como backup: `updateCell` en background, flush al
  cerrar, reconciliación al abrir al día siguiente.

### Fuera de alcance

- Reglas de seguridad RTDB para producción.
- Cloud Functions o lógica server-side.
- Migración de datos históricos a RTDB.
- Soporte para plataformas móviles (iOS/Android).
- Firebase Authentication.
- Resolución de conflictos offline complejos.

## 4) Actores implicados

| Actor                       | Rol                                                                                               |
| --------------------------- | ------------------------------------------------------------------------------------------------- |
| **Usuario operador**        | Edita celdas de cantidades y stocks, ve cambios y cursores remotos, gestiona su nombre de usuario |
| **Usuarios concurrentes**   | Otros operadores editando la misma hoja simultáneamente                                           |
| **Sistema (Firebase RTDB)** | Propaga cambios en tiempo real entre clientes                                                     |
| **Sistema (Google Sheets)** | Almacenamiento persistente de backup                                                              |

## 5) Requisitos funcionales

### Identidad de usuario

- **RF-01:** Al abrir la app por primera vez, se genera automáticamente un
  código aleatorio de 6 letras mayúsculas (ej: `XKWMPQ`) como nombre de usuario.
- **RF-02:** El código se persiste localmente en `SharedPreferences`.
- **RF-03:** El usuario puede ver y editar su nombre de usuario en la pantalla
  de **Ajustes**.
- **RF-04:** El nombre de usuario se usa como valor del campo `user` en locks,
  cells y como key en cursors de RTDB.
- **RF-05:** El nombre de usuario debe ser no vacío. Si el usuario lo deja vacío
  al editar, se mantiene el valor anterior o se regenera.

### Configuración Firebase

- **RF-06:** El proyecto debe incluir `firebase_core` y `firebase_database`.
- **RF-07:** Firebase se inicializa al arrancar la app, antes de la inyección de
  dependencias, usando un único proyecto Firebase.
- **RF-08:** Si la inicialización de Firebase falla, la app registra el error y
  continúa sin tiempo real (degradación graceful al comportamiento actual con
  polling).

### Estructura RTDB

- **RF-09:** Nodo raíz para pedidos: `today` con la estructura:
  ```
  today/
    date: "YYYY-MM-DD"
    locks/
      {productRow}_{clientCol}: { user, ts }     ← cantidades
      stock_{productRow}: { user, ts }            ← stocks
    cells/
      {productRow}_{clientCol}: { v, user, ts }   ← cantidades
      stock_{productRow}: { v, user, ts }          ← stocks
    cursors/
      {userId}: { r, c, color }
  ```
- **RF-10:** Las claves de celdas de cantidades se forman como
  `{productRow}_{clientCol}`. Las claves de stocks se forman como
  `stock_{productRow}`.

### Flujo de apertura

- **RF-11:** Al abrir Pedidos de Hoy, leer `today/date` de RTDB.
- **RF-12:** Si `today/date` ≠ hoy → transacción atómica para resetear `today`
  (vaciar locks, cells, cursors; actualizar date).
- **RF-13:** Cargar sheet completo de Google Sheets como estado base.
- **RF-14:** Aplicar deltas de `today/cells` sobre el estado base (cantidades y
  stocks).
- **RF-15:** Suscribirse a `today/cells` → aplicar deltas futuros.
- **RF-16:** Suscribirse a `today/locks` → pintar celdas bloqueadas.
- **RF-17:** Suscribirse a `today/cursors` → pintar cursores remotos.
- **RF-18:** Escribir mi cursor en `today/cursors/{userId}` con
  `onDisconnect().remove()`.
- **RF-19:** Eliminar el `Timer.periodic` de polling.

### Flujo de edición (cantidades y stocks)

- **RF-20:** Al seleccionar una celda para editar, transacción en
  `today/locks/{key}`:
  - Vacío o propio → escribir lock → abrir editor.
  - De otro usuario (no expirado) → rechazar ("Celda bloqueada por {user}").
- **RF-21:** Al confirmar el valor editado:
  1. Escribir en `today/cells/{key}` = `{ v, user, ts }`.
  2. Borrar `today/locks/{key}`.
  3. Background: `updateCell` en Google Sheets (fire-and-forget).
- **RF-22:** Al cancelar la edición, borrar lock sin escribir en cells.

### Recepción de cambios remotos

- **RF-23:** Al recibir un cambio en `today/cells/{key}` donde `user ≠ yo`:
  - Si es celda de cantidad: actualizar `quantities[r][c]`, recalcular
    `pedidos[r]` y `quedan[r]`.
  - Si es celda de stock: actualizar `stocks[r]`, recalcular `quedan[r]`.
  - Emitir nuevo `OrdersTodayLoaded`.
- **RF-24:** Al recibir cambios en `today/locks`, actualizar visualización de
  celdas bloqueadas.
- **RF-25:** Al recibir cambios en `today/cursors`, actualizar posición de
  cursores remotos.

### Presencia y cursores

- **RF-26:** Al entrar en la pantalla, registrar presencia en
  `today/cursors/{userId}` con posición, color y nombre.
- **RF-27:** Mostrar un indicador global con el número de usuarios conectados
  (derivado del conteo de entries en `today/cursors`).
- **RF-28:** Usar `onDisconnect().remove()` para limpiar el cursor al
  desconectarse.

### Locks expirados

- **RF-29:** Al suscribirse a `today/locks`, si un lock tiene `ts > 60s` de
  antigüedad → cualquier cliente lo borra.

### Google Sheets como backup

- **RF-30:** Cada edición escribe en Google Sheets en background (no bloquea
  UI).
- **RF-31:** Si falla la escritura a Sheets, el dato no se pierde (ya está en
  RTDB).
- **RF-32:** Al abrir al día siguiente, el sheet completo de Google Sheets es el
  nuevo estado base.

## 6) Criterios de aceptación

- **CA-01:** La app compila y arranca sin errores en macOS y Windows con
  Firebase inicializado.
- **CA-02:** En la primera apertura, se genera un código de 6 letras como nombre
  de usuario y se muestra en Ajustes.
- **CA-03:** El usuario puede editar su nombre de usuario en Ajustes y el cambio
  se refleja en locks/cursors de RTDB.
- **CA-04:** Dos instancias: usuario A edita celda (3,5), usuario B ve el cambio
  en <2s.
- **CA-05:** Mientras A edita celda (3,5), B ve la celda bloqueada con el nombre
  de A y no puede editarla.
- **CA-06:** Cuando A confirma, el lock desaparece y B puede editar esa celda.
- **CA-07:** Dos instancias: usuario A edita STOCKS de la fila 3, usuario B ve
  el cambio reflejado y `quedan[3]` se recalcula.
- **CA-08:** Los cursores remotos son visibles con color e identificador del
  usuario.
- **CA-09:** Se muestra un indicador del número de usuarios conectados en la
  pantalla de Pedidos de Hoy.
- **CA-10:** Al abrir en un nuevo día, el nodo `today` se resetea atómicamente y
  se carga el sheet base limpio.
- **CA-11:** Lock huérfano (usuario cierra sin confirmar) se limpia en <60s por
  otro cliente.
- **CA-12:** No hay `Timer.periodic` ni polling. Sincronización 100% por
  listeners RTDB.
- **CA-13:** Ediciones se persisten en Google Sheets en background.
- **CA-14:** Si Firebase no está disponible, la app funciona en modo actual
  (Google Sheets + polling) como fallback.
- **CA-15:** Tests existentes no se rompen.

## 7) Flujos y comportamiento esperado

### Flujo principal — Primera apertura (usuario nuevo)

```
1. La app detecta que no existe nombre de usuario en SharedPreferences
2. Genera código aleatorio de 6 letras (ej: "XKWMPQ")
3. Lo persiste en SharedPreferences
4. El código se usa como userId para toda la sesión
```

### Flujo principal — Apertura de Pedidos de Hoy

```
1. Usuario abre pantalla "Pedidos de Hoy"
2. Leer today/date de RTDB
3. ¿Coincide con hoy?
   ├─ SÍ → continuar
   └─ NO → Transacción atómica: resetear today {date: hoy, locks: {}, cells: {}, cursors: {}}
4. Cargar sheet completo de Google Sheets → estado base (OrderSheet)
5. Aplicar deltas de today/cells sobre estado base (cantidades + stocks)
6. Emitir OrdersTodayLoaded con estado combinado
7. Suscribirse a today/cells → deltas futuros
8. Suscribirse a today/locks → bloqueos
9. Suscribirse a today/cursors → cursores remotos + conteo de conectados
10. Registrar mi cursor en today/cursors/{userId} + onDisconnect().remove()
```

### Flujo principal — Edición de celda de cantidad

```
1. Usuario toca celda (r, c) — key = "{r}_{c}"
2. Transacción en today/locks/{r}_{c}:
   ├─ Vacío o mío → lock {user, ts} → abrir editor
   └─ De otro (no expirado) → feedback "Bloqueada por {user}" → cancelar
3. Usuario confirma valor = V
4. Escribir today/cells/{r}_{c} = {v: V, user, ts}
5. Borrar today/locks/{r}_{c}
6. Background: updateCell en Google Sheets
7. Local: quantities[r][c] = V, recalcular pedidos[r] y quedan[r]
8. Emitir OrdersTodayLoaded
```

### Flujo principal — Edición de celda de STOCKS

```
1. Usuario toca celda de stocks fila r — key = "stock_{r}"
2. Transacción en today/locks/stock_{r}:
   ├─ Vacío o mío → lock {user, ts} → abrir editor
   └─ De otro (no expirado) → feedback "Bloqueada por {user}" → cancelar
3. Usuario confirma valor = S
4. Escribir today/cells/stock_{r} = {v: S, user, ts}
5. Borrar today/locks/stock_{r}
6. Background: updateCell en Google Sheets (columna de stocks)
7. Local: stocks[r] = S, recalcular quedan[r] = stocks[r] - pedidos[r]
8. Emitir OrdersTodayLoaded
```

### Flujo de recepción de cambio remoto

```
1. Firebase listener dispara con cambio en today/cells/{key}
2. ¿user == yo? → Ignorar
3. Parsear key:
   ├─ "{r}_{c}" → quantities[r][c] = v, recalcular pedidos[r], quedan[r]
   └─ "stock_{r}" → stocks[r] = v, recalcular quedan[r]
4. Emitir OrdersTodayLoaded actualizado
```

### Flujo de edición de nombre de usuario (Ajustes)

```
1. Usuario abre Ajustes
2. Ve su código actual (ej: "XKWMPQ")
3. Edita el nombre (ej: "JORDAN")
4. Validación: no vacío, se acepta cualquier texto
5. Se persiste en SharedPreferences
6. Si hay suscripciones RTDB activas, actualizar el cursor con el nuevo nombre
```

### Flujos alternativos

- **FA-01 — Cancelación de edición:** Borrar lock, no escribir en cells.
- **FA-02 — Firebase no disponible al arrancar:** Modo degradado con Google
  Sheets + polling + indicador visual de "sincronización offline".
- **FA-03 — Pérdida de conexión durante uso:** RTDB opera offline con cache
  local. Sincronización al reconectar. Locks huérfanos limpiados por TTL.
- **FA-04 — Fallo de escritura a Google Sheets:** Dato seguro en RTDB. Reintento
  o reconciliación en siguiente apertura.
- **FA-05 — Lock simultáneo:** Transacción Firebase garantiza que solo uno gana.
- **FA-06 — Creación de archivo (no existe sheet para hoy):** Flujo actual →
  `OrdersEmptyState` → crear archivo → inicializar nodo RTDB.

### Estados especiales / excepciones

- **Estado vacío:** `OrdersEmptyState` actual con opción de crear archivo.
- **Estado loading:** Indicador de carga mientras se obtiene sheet base y se
  sincronizan deltas.
- **Estado error (solo Sheets):** Si falla la carga del sheet base,
  `OrdersErrorState`. Firebase no ayuda aquí porque la estructura (clients,
  products) viene de Sheets.
- **Estado error (solo Firebase):** Degradación a polling; la app funciona pero
  sin concurrencia.

## 8) Edge cases

- **EC-01:** Usuario cierra la app sin confirmar edición → lock huérfano →
  limpiado en ≤60s por cualquier otro cliente.
- **EC-02:** Dos clientes detectan `today/date ≠ hoy` simultáneamente →
  transacción atómica: solo uno resetea, el otro relee.
- **EC-03:** Usuario edita la misma celda dos veces rápido → segundo lock
  reemplaza al primero (mismo user); segundo valor sobrescribe en cells.
- **EC-04:** Lock a punto de expirar mientras el usuario escribe → podría perder
  el lock. Mejora futura: extender TTL al interactuar.
- **EC-05:** Google Sheets caído al arrancar → no se puede obtener estado base.
  Mostrar error con reintento. RTDB no tiene la estructura completa (clients,
  products).
- **EC-06:** Hot restart → `Firebase.initializeApp` múltiple → verificar si ya
  inicializado.
- **EC-08:** Cursor de usuario desconectado queda en `cursors` →
  `onDisconnect().remove()` lo limpia automáticamente.
- **EC-09:** Usuario cambia su nombre en Ajustes mientras tiene un lock activo →
  el lock antiguo tiene el nombre viejo. Es aceptable: el lock expirará o se
  completará la edición.
- **EC-10:** Dos usuarios eligen el mismo nombre → no es un problema funcional
  (los locks usan el nombre para visualización, no como ID de autenticación). Si
  se desea evitar duplicados es una mejora futura.
- **EC-11:** Edición de stock y cantidad de la misma fila por dos usuarios
  simultáneamente → son keys distintos (`stock_3` vs `3_5`), locks
  independientes, ambas ediciones proceden y se recalcula `quedan[3]`
  correctamente.

## 9) Impacto funcional

### Módulos y archivos afectados

| Área                                              | Impacto                                                                                                  |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `pubspec.yaml`                                    | Nuevas dependencias: `firebase_core`, `firebase_database`                                                |
| `lib/main.dart`                                   | `Firebase.initializeApp` en `_initializeServices`                                                        |
| `lib/app/config/`                                 | `FirebaseOptions` (generado por FlutterFire CLI o manual)                                                |
| `lib/app/di/`                                     | Registro de servicios de Firebase y del servicio de identidad de usuario                                 |
| `lib/features/settings/`                          | Nuevo campo: nombre de usuario editable. Persistencia en SharedPreferences. UI en la pantalla de ajustes |
| `lib/features/orders_today/presentation/bloc/`    | Nuevos eventos para deltas remotos, locks, cursores, presencia; eliminación de `CheckModifiedRequested`  |
| `lib/features/orders_today/presentation/pages/`   | Eliminar `Timer.periodic`; gestionar suscripciones RTDB; indicador de usuarios conectados                |
| `lib/features/orders_today/presentation/widgets/` | Pintar celdas bloqueadas (cantidades + stocks), cursores remotos                                         |
| `lib/features/orders_today/domain/`               | Posibles entidades: `CellLock`, `RemoteCursor`; extensión del repositorio                                |
| `lib/features/orders_today/data/`                 | Nuevo datasource para RTDB; datasource de Sheets se simplifica                                           |
| `lib/core/`                                       | Posible servicio de identidad de usuario                                                                 |
| `macos/`                                          | Entitlements de red, Podfile                                                                             |
| `windows/`                                        | CMakeLists si es necesario                                                                               |

### Impacto en usuario

- **Positivo:** Edición colaborativa sin conflictos. Visibilidad de quién edita
  qué. Indicador de presencia.
- **Nuevo:** Campo de nombre de usuario en Ajustes.

### Impacto en negocio

- Elimina pérdida de datos por edición concurrente.
- Habilita trabajo simultáneo de múltiples operadores.

### Impacto en experiencia de usuario

- Celdas bloqueadas: visualmente distinguibles (color/icono + tooltip con nombre
  de usuario).
- Cursores remotos: indicador de color con nombre del usuario.
- Indicador de usuarios conectados: badge o texto con conteo.
- Feedback "Celda bloqueada por {user}" inmediato y claro.

## 10) Suposiciones

- **S-01:** Un único proyecto Firebase para todos los entornos.
- **S-02:** La identidad de usuario es el código de 6 letras generado localmente
  (no autenticación Firebase). Es suficiente para identificación visual entre
  operadores.
- **S-03:** Plataformas objetivo: macOS y Windows (desktop).
- **S-04:** TTL de 60s para locks es suficiente.
- **S-05:** La estructura del `OrderSheet` (clients, products) sigue viniendo de
  Google Sheets. RTDB sincroniza `quantities` y `stocks`.
- **S-06:** Reglas RTDB abiertas en fase inicial.
- **S-07:** macOS ≥ 10.15.
- **S-08:** No se necesita unicidad garantizada del nombre de usuario.
- **S-09:** El nombre de usuario puede ser editado a cualquier texto no vacío
  (no solo 6 letras).

## 11) Preguntas abiertas

No quedan preguntas abiertas. Todas las ambigüedades han sido resueltas.

## 12) Notas para análisis técnico

- **Compatibilidad plugins:** Verificar `firebase_database` en macOS y Windows.
- **FlutterFire CLI:** Usar `flutterfire configure` para generar
  `firebase_options.dart`.
- **Transacciones RTDB:** `DatabaseReference.runTransaction` para locks y reset
  de `today/date`.
- **Listeners granulares:** Usar `onChildAdded`, `onChildChanged`,
  `onChildRemoved` en `today/cells`, `today/locks`, `today/cursors` (no
  `onValue` del nodo completo).
- **`onDisconnect()`:** `ref('today/cursors/{userId}').onDisconnect().remove()`
  para limpiar presencia.
- **Identidad de usuario:** Implementar en `lib/features/settings/` o
  `lib/core/` como servicio inyectado. Generación con `Random` + charset `A-Z`.
  Persistir con key nueva en `SharedPreferences`.
- **STOCKS en RTDB:** Usar key `stock_{productRow}` para distinguir de
  cantidades `{r}_{c}`.
- **BLoC refactor:** Considerar dividir en dos BLoCs: datos (cells) y presencia
  (locks + cursors). O usar streams separados dentro del mismo BLoC.
- **Degradación graceful:** Flag/servicio que detecte disponibilidad de Firebase
  y active polling como fallback.
- **Tests:** Mock del datasource RTDB. No depender de Firebase real en tests.
- **Entitlements macOS:** Verificar `com.apple.security.network.client`
  (probablemente ya activo por Google APIs).
- **Estado: Listo para análisis técnico.**
