# Technical Analysis: Web-only + URL routing

- **Fecha:** 2026-05-11
- **Identificador:** web-only-url-routing
- **Fuente:** docs/functional-analysis/2026-05-11-web-only-url-routing.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- **Enfoque:** Migrar de `MaterialApp.routes` (rutas imperativas) a `go_router`
  con `ShellRoute` para obtener navegación declarativa basada en URL. Eliminar
  las tres plataformas no-web (Android, macOS, Windows) y dependencias
  asociadas.
- **Áreas impactadas:** Router (`app/router/`), shell de navegación
  (`SideMenuShell`), cubit de menú (`SideMenuCubit`), módulo de clientes
  (detail/edit como rutas propias), login/logout, `firebase_options.dart`,
  `pubspec.yaml`, `main.dart`.
- **Riesgo general estimado:** Medio — el cambio toca el sistema de navegación
  completo y la autenticación, pero la lógica de negocio no se modifica.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first:
  `lib/features/<feature>/{data,domain,presentation}/`
- State management: `flutter_bloc` (Cubits)
- DI: `get_it` (lazy singletons y factories)
- Functional error handling: `fpdart` (`Either<Failure, T>`)

### Módulos relevantes

| Módulo           | Archivo clave                                                     | Rol actual                                                                                     |
| ---------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Router           | `lib/app/router/router.dart`                                      | Define `Map<String, WidgetBuilder>` con 2 rutas: `/` (SideMenuShell) y `/login`                |
| Shell            | `lib/features/home/presentation/pages/side_menu_shell.dart`       | Renderiza `SideMenu` + `_buildPage(index)` vía switch sobre `SideMenuState.selectedIndex`      |
| SideMenuCubit    | `lib/features/home/presentation/bloc/side_menu_cubit.dart`        | Gestiona `selectedIndex` (int) e `isExpanded` (bool, persiste en SharedPreferences)            |
| SideMenuState    | `lib/features/home/presentation/bloc/side_menu_state.dart`        | Equatable con `selectedIndex` + `isExpanded`                                                   |
| NavigationGuard  | `lib/core/services/navigation_guard.dart`                         | Singleton con `shouldBlock` / `onDiscard` para cambios sin guardar                             |
| ClientsPage      | `lib/features/clients/presentation/pages/clients_page.dart`       | Gestiona `_ClientsViewMode` (list/detail/edit) con `setState` local                            |
| ClientDetailView | `lib/features/clients/presentation/pages/client_detail_page.dart` | Recibe `Client` como parámetro, callbacks `onBack`/`onEdit`                                    |
| ClientEditView   | `lib/features/clients/presentation/pages/client_edit_page.dart`   | Recibe `Client`, callbacks `onBack`/`onSaved`                                                  |
| LoginPage        | `lib/features/auth/presentation/pages/login_page.dart`            | Usa `Navigator.pushNamedAndRemoveUntil(AppRoutes.home)`                                        |
| SettingsPage     | `lib/features/settings/presentation/pages/settings_page.dart`     | Logout usa `Navigator.pushNamedAndRemoveUntil(AppRoutes.login)`                                |
| MainApp          | `lib/main.dart`                                                   | `MaterialApp` con `initialRoute`, `routes: appRoutes`, `SystemChrome.setPreferredOrientations` |

### Restricciones

- No existe método `getClientById` en el repositorio de clientes. Solo
  `getClients()` / `watchClients()` (devuelven lista completa).
- `NavigationGuard` es un singleton imperativo (callback-based), no está
  integrado con ningún sistema de routing.
- `desktop_multi_window` está en `pubspec.yaml` pero no se importa en ningún
  archivo Dart.
- `flutter_native_splash` se usa en `main.dart` — es compatible con web pero
  carece de sentido sin plataformas nativas.
- `SystemChrome.setPreferredOrientations` en `main.dart` es un no-op en web.
- `firebase_options.dart` contiene configuraciones para `web` y `macos`.
- La app usa dos entry points: `main_local.dart` y `main_pro.dart`, ambos llaman
  a `runApplication()`.

## 3) Objetivo técnico

### Qué debe cambiar

1. Reemplazar `MaterialApp.routes` + `initialRoute` por `MaterialApp.router` +
   `GoRouter`.
2. Convertir `SideMenuShell` en un `ShellRoute` de `go_router`.
3. Definir 9 sub-rutas para las secciones del menú + 2 rutas paramétrizadas para
   clientes.
4. Derivar `selectedIndex` del menú a partir de la ubicación actual del router
   (no almacenarlo como estado independiente).
5. Extraer `ClientDetailView` y `ClientEditView` como rutas independientes bajo
   `/clients/:id/detail` y `/clients/:id/edit`.
6. Eliminar carpetas de plataforma `android/`, `macos/`, `windows/` y
   dependencias exclusivas desktop.
7. Crear página 404 dedicada.
8. Integrar `NavigationGuard` con `go_router`.

### Resultado técnico

- `GoRouter` como fuente de verdad para la navegación.
- URLs limpias (sin `#`) vía `usePathUrlStrategy()`.
- Deep linking, back/forward del navegador y refresh funcionales.

### Limitaciones a respetar

- No modificar lógica de negocio (cubits, repositories, use cases, data
  sources).
- No cambiar el diseño visual del `SideMenu`.
- Mantener la compatibilidad con el flujo de autenticación existente (Firebase
  Auth + `remember me`).

## 4) Diseño técnico de la solución

### Enfoque propuesto

Adoptar `go_router` (paquete oficial del equipo Flutter) como router
declarativo. Usar `ShellRoute` (sin `indexedStack`) para que las páginas se
reconstruyan al cambiar de sección, manteniendo el comportamiento actual. El
`SideMenu` se integra como parte del shell builder.

### Componentes / módulos / servicios afectados

#### A. Router (`lib/app/router/router.dart`) — **Reescritura completa**

Reemplazar el `Map<String, WidgetBuilder>` por un `GoRouter` con esta
estructura:

```
GoRouter
├── /login                          → LoginPage
├── ShellRoute (SideMenuShell)
│   ├── /home                       → HomePage
│   ├── /orders-today               → OrdersTodayPage
│   ├── /orders-history             → OrdersHistoryPage
│   ├── /clients                    → ClientsPage (solo lista)
│   │   ├── /clients/:id/detail     → ClientDetailPage
│   │   └── /clients/:id/edit       → ClientEditPage
│   ├── /client-categories          → ClientCategoriesPage
│   ├── /shipping-methods           → ShippingMethodsPage
│   ├── /products                   → ProductsPage
│   ├── /invoices                   → InvoicesPage
│   └── /settings                   → SettingsPage
├── redirect: / → /home
└── errorBuilder: → NotFoundPage (404)
```

Constantes de rutas en `AppRoutes`:

```dart
abstract class AppRoutes {
  static const home = '/home';
  static const ordersToday = '/orders-today';
  static const ordersHistory = '/orders-history';
  static const clients = '/clients';
  static const clientDetail = '/clients/:id/detail';
  static const clientEdit = '/clients/:id/edit';
  static const clientCategories = '/client-categories';
  static const shippingMethods = '/shipping-methods';
  static const products = '/products';
  static const invoices = '/invoices';
  static const settings = '/settings';
  static const login = '/login';
}
```

**Redirect global:** Si la ubicación es `/`, redirigir a `/home`.

**Auth redirect:** En `GoRouter.redirect`, comprobar estado de autenticación. Si
el usuario no está autenticado y la ruta no es `/login`, redirigir a `/login`.
Si está autenticado y la ruta es `/login`, redirigir a `/home`.

**`StatefulShellRoute.indexedStack`:** Usar `indexedStack` para que cada sección
del menú mantenga su estado al cambiar entre secciones (el widget no se
reconstruye al volver). Esto es equivalente al comportamiento actual con
`IndexedStack` implícito del switch.

#### B. SideMenuShell — **Refactor**

Pasa de ser un `StatelessWidget` con `BlocBuilder` a ser el `builder` del
`ShellRoute`. Recibe `Widget child` (la página de la ruta activa) y calcula
`selectedIndex` a partir de la ubicación actual del `GoRouter` (mapping ruta →
índice).

- Ya no depende de `SideMenuCubit.selectedIndex`.
- Sigue dependiendo de `SideMenuCubit.isExpanded` (para expand/collapse del
  menú).
- El `onItemSelected` cambia a `context.go(rutaDelÍndice)`.
- La lógica de `NavigationGuard` se integra antes de `context.go`.

#### C. SideMenuCubit/State — **Simplificar**

- Eliminar `selectedIndex` del state y del cubit (se deriva del router).
- Mantener solo `isExpanded` con persistencia en SharedPreferences.
- Renombrar o mantener el nombre actual; el state pasa a contener solo
  `isExpanded`.

#### D. SideMenu widget — **Adaptar firma**

- `selectedIndex` se sigue recibiendo como parámetro (calculado en el shell
  builder desde la rama activa).
- `onItemSelected` se sigue recibiendo como callback (ahora dispara `goBranch`).
- No hay cambios visuales internos.

#### E. ClientsPage — **Simplificar**

- Eliminar `_ClientsViewMode`, `_selectedClient`, `_navigateToDetail`,
  `_navigateToEdit`, `_backToList`, `_handleSaveResult`.
- La página solo muestra la lista de clientes.
- Al pulsar "Ver": `context.go('/clients/${client.id}/detail')`.
- Al pulsar "Editar": `context.go('/clients/${client.id}/edit')`.

#### F. ClientDetailPage — **Convertir en ruta independiente**

- Recibe `clientId` como parámetro de ruta (`:id`).
- Debe obtener el `Client` a partir del ID. Dos opciones:
  - **Opción A (recomendada):** Pasar el objeto `Client` vía
    `GoRouteData.extra`. Si `extra` es null (deep link), buscar en la lista
    cacheada del cubit o hacer fetch.
  - **Opción B:** Crear un `GetClientById` use case (requiere añadir `getById`
    al data source y repository).
- Se recomienda **Opción A** para minimizar cambios en la capa de datos.
- Fallback para deep linking: acceder a `ClientsCubit.state` (si es
  `ClientsLoaded`) y buscar por ID en la lista. Si no se encuentra, mostrar
  loading → fetch lista → buscar. Si sigue sin encontrarse, mostrar error con
  enlace a `/clients`.
- `onEdit`: `context.go('/clients/$id/edit')`.
- `onBack`: `context.pop()` (vuelve a `/clients`).

#### G. ClientEditPage — **Convertir en ruta independiente**

- Misma estrategia que ClientDetailPage para obtener el `Client`.
- `onBack` / `onSaved`: `context.pop()`. Esto devuelve automáticamente al origen
  (si se llegó desde `/clients` vuelve ahí; si se llegó desde
  `/clients/:id/detail` vuelve ahí). Esto resuelve RF-11 de forma natural con
  `go_router` ya que `pop()` sube en la pila de navegación.
- El feedback de guardado exitoso se gestiona vía query parameter o state
  compartido.

#### H. NavigationGuard — **Integrar con go_router**

- `go_router` >=14.0 soporta `onExit` en `GoRoute`, que permite interceptar la
  salida de una ruta.
- Para la edición de cliente: usar `onExit` en la ruta `/clients/:id/edit` para
  verificar `NavigationGuard.shouldBlock` y mostrar el diálogo.
- Alternativa: usar `PopScope` widget dentro de `ClientEditPage` para
  interceptar `pop()`.
- Para navegación por menú (cambiar de sección): el shell builder verifica
  `guard.shouldBlock` antes de llamar `goBranch`, mostrando el diálogo si hay
  cambios sin guardar (comportamiento idéntico al actual).

#### I. LoginPage y SettingsPage — **Adaptar navegación**

- `LoginPage`: Reemplazar `Navigator.pushNamedAndRemoveUntil(AppRoutes.home)`
  por `context.go(AppRoutes.home)`. `go` reemplaza la pila completa.
- `SettingsPage` (logout): Reemplazar
  `Navigator.pushNamedAndRemoveUntil(AppRoutes.login)` por
  `context.go(AppRoutes.login)`.

#### J. MainApp (`main.dart`) — **Adaptar**

- Cambiar `MaterialApp` a `MaterialApp.router` con `routerConfig: goRouter`.
- Eliminar `initialRoute` y `routes`.
- La determinación de ruta inicial se mueve al `initialLocation` del `GoRouter`
  (o al redirect global que evalúa autenticación).
- Eliminar `SystemChrome.setPreferredOrientations` (no-op en web).
- Configurar `usePathUrlStrategy()` en el entry point antes de `runApp`.
- Evaluar si mantener o eliminar `FlutterNativeSplash` (no tiene sentido
  funcional en web-only).

#### K. firebase_options.dart — **Simplificar**

- Eliminar el switch por plataforma. `currentPlatform` puede retornar
  directamente `web` o simplificarse.
- Eliminar la constante `macos`.

### Contratos e interfaces

**Nuevos contratos:**

- `GoRouter` expuesto como singleton registrado en GetIt (accesible para
  `context.go()` y para redirect de auth).
- `AppRoutes` ampliado con todas las rutas como constantes.

**Contratos existentes sin cambios:**

- `ClientsRepository`, `ClientFirestoreDataSource`, todos los use cases de
  clientes.
- `NavigationGuard` — interfaz sin cambios, solo cambia quién lo consume.

### Flujo de datos o de control

**Navegación por menú:**

```
SideMenu.onTap(index)
  → shell builder verifica NavigationGuard.shouldBlock
    → si bloqueado: muestra diálogo → si descarta: guard.clear() → context.go(ruta)
    → si no bloqueado: context.go(rutaDelÍndice)
      → go_router actualiza URL del navegador
      → ShellRoute reconstruye la página correspondiente
      → el shell builder recalcula selectedIndex desde GoRouterState.uri
```

**Deep link:**

```
URL del navegador: /orders-today
  → go_router matchea la ruta dentro del ShellRoute
  → ShellRoute construye OrdersTodayPage como child
  → shell builder calcula selectedIndex=1 desde la URI → SideMenu muestra ítem 1 seleccionado
```

**Detalle de cliente:**

```
ClientsPage → onTap "Ver" → context.go('/clients/${client.id}/detail')
  → go_router navega a ruta hija bajo rama /clients
  → ClientDetailPage recibe :id, obtiene Client desde extra o cubit cache
  → URL = /clients/abc123/detail
  → SideMenu muestra "Clientes" seleccionado (rama index=3)
```

**Back después de editar:**

```
/clients → "Editar" → /clients/abc/edit → context.pop() → /clients
/clients/abc/detail → "Editar" → /clients/abc/edit → context.pop() → /clients/abc/detail
```

### Gestión de errores y validaciones

- **Ruta inexistente:** `GoRouter.errorBuilder` renderiza `NotFoundPage` (404).
- **Deep link a cliente inexistente:** `ClientDetailPage` / `ClientEditPage`
  muestra estado error con opción de volver a `/clients`.
- **Auth expirada:** `GoRouter.redirect` detecta usuario no autenticado →
  redirige a `/login`.
- **ID vacío en URL:** `/clients//detail` no matchea la ruta (`:id` requiere al
  menos un carácter) → va a 404.

### Consideraciones de compatibilidad o migración

- La migración es un cambio de una vez (no incremental). Todas las rutas deben
  migrar simultáneamente.
- Los diálogos que usan `Navigator.of(context).pop()` para cerrar (dentro de
  dialogs) siguen funcionando porque `showDialog` usa su propio `Navigator`
  interno, no `GoRouter`.
- Los `Navigator.pushNamedAndRemoveUntil` en `LoginPage` y `SettingsPage` deben
  migrarse obligatoriamente.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                         | Propósito                            |
| ------------------------------------------------- | ------------------------------------ |
| `lib/core/presentation/pages/not_found_page.dart` | Página 404 para rutas no reconocidas |

### Artefactos a modificar

| Artefacto                                                         | Cambio esperado                                                                                                                                                            |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pubspec.yaml`                                                    | Añadir `go_router`. Eliminar `desktop_multi_window`. Evaluar eliminar `flutter_native_splash`, `flutter_launcher_icons`, `flutter_secure_storage` si solo aplican a native |
| `lib/app/router/router.dart`                                      | Reescribir: definir `GoRouter` con `ShellRoute`, todas las rutas, redirects, errorBuilder                                                                                  |
| `lib/main.dart`                                                   | `MaterialApp.router`, eliminar `SystemChrome`, añadir `usePathUrlStrategy()`, ajustar initialización                                                                       |
| `lib/main_local.dart`                                             | Añadir `usePathUrlStrategy()`                                                                                                                                              |
| `lib/main_pro.dart`                                               | Añadir `usePathUrlStrategy()`                                                                                                                                              |
| `lib/features/home/presentation/pages/side_menu_shell.dart`       | Refactor a shell builder de `StatefulShellRoute`, derivar selectedIndex del router                                                                                         |
| `lib/features/home/presentation/bloc/side_menu_cubit.dart`        | Eliminar `selectItem`/`selectedIndex`, mantener solo `isExpanded`                                                                                                          |
| `lib/features/home/presentation/bloc/side_menu_state.dart`        | Eliminar `selectedIndex` del state                                                                                                                                         |
| `lib/features/home/presentation/widgets/side_menu.dart`           | Sin cambios en la interfaz (sigue recibiendo `selectedIndex` y `onItemSelected` como params)                                                                               |
| `lib/features/clients/presentation/pages/clients_page.dart`       | Eliminar `_ClientsViewMode`, `_selectedClient`, navegación interna. Solo lista. Usar `context.go()` para navegar                                                           |
| `lib/features/clients/presentation/pages/client_detail_page.dart` | Convertir en página autónoma que recibe `:id` de la ruta. Obtener `Client` del cache/extra                                                                                 |
| `lib/features/clients/presentation/pages/client_edit_page.dart`   | Convertir en página autónoma que recibe `:id` de la ruta. Usar `context.pop()` para volver                                                                                 |
| `lib/features/auth/presentation/pages/login_page.dart`            | Reemplazar `Navigator.pushNamedAndRemoveUntil` por `context.go(AppRoutes.home)`                                                                                            |
| `lib/features/settings/presentation/pages/settings_page.dart`     | Reemplazar `Navigator.pushNamedAndRemoveUntil` por `context.go(AppRoutes.login)`                                                                                           |
| `lib/firebase_options.dart`                                       | Simplificar: eliminar switch por plataforma, eliminar constante `macos`, retornar `web` directamente                                                                       |
| `lib/app/di/modules/home_module.dart`                             | Ajustar registro de `SideMenuCubit` (firma simplificada)                                                                                                                   |
| `lib/app/di/injection.dart`                                       | Registrar `GoRouter` como singleton si se necesita acceso fuera de widgets                                                                                                 |
| `firebase.json`                                                   | Añadir sección `hosting` con `"public": "build/web"` y rewrites SPA (`"source": "**"` → `/index.html`)                                                                     |

### Artefactos a retirar o reemplazar

| Artefacto                                            | Motivo                                                   |
| ---------------------------------------------------- | -------------------------------------------------------- |
| `android/` (directorio completo)                     | Plataforma eliminada                                     |
| `macos/` (directorio completo)                       | Plataforma eliminada                                     |
| `windows/` (directorio completo)                     | Plataforma eliminada                                     |
| `servicebo.iml`                                      | Archivo de proyecto IntelliJ, no relevante para web-only |
| Dependencia `desktop_multi_window` en `pubspec.yaml` | Solo para desktop, no se importa en ningún archivo Dart  |

## 6) Estrategia de implementación

### Paso 1: Eliminar plataformas no-web

1. Eliminar carpetas `android/`, `macos/`, `windows/`.
2. Eliminar `servicebo.iml`.
3. Eliminar `desktop_multi_window` de `pubspec.yaml`.
4. Simplificar `firebase_options.dart`.
5. Eliminar `SystemChrome.setPreferredOrientations` de `main.dart`.
6. Evaluar y limpiar `flutter_native_splash` / `flutter_launcher_icons` si solo
   aplican a native.
7. Verificar que `flutter build web` compila correctamente.

### Paso 2: Añadir go_router y configurar URL strategy

1. Añadir `go_router` a `pubspec.yaml`.
2. Llamar `usePathUrlStrategy()` en los entry points (`main.dart`,
   `main_local.dart`, `main_pro.dart`).
3. Definir `AppRoutes` con todas las constantes de ruta.

### Paso 3: Implementar GoRouter con ShellRoute

1. Crear la configuración de `GoRouter` en `lib/app/router/router.dart`.
2. Definir `StatefulShellRoute.indexedStack` con las 9 ramas del menú.
3. Definir sub-rutas `/clients/:id/detail` y `/clients/:id/edit` bajo la rama de
   clientes.
4. Implementar redirect global (`/` → `/home`).
5. Implementar redirect de autenticación.
6. Crear `NotFoundPage` y asignar a `errorBuilder`.

### Paso 4: Refactorizar SideMenuShell

1. Convertir en el `builder` del `StatefulShellRoute`.
2. Derivar `selectedIndex` desde `navigationShell.currentIndex`.
3. Integrar `NavigationGuard` en el `onItemSelected` (antes de `goBranch`).
4. Simplificar `SideMenuCubit` (eliminar `selectedIndex`).

### Paso 5: Refactorizar ClientsPage

1. Eliminar `_ClientsViewMode` y lógica de navegación interna.
2. Cambiar `_navigateToDetail` / `_navigateToEdit` a `context.go(...)`.
3. Eliminar `_backToList`, `_handleSaveResult` (gestionado por routing y `pop`).

### Paso 6: Convertir ClientDetailPage y ClientEditPage en rutas

1. Adaptar `ClientDetailView` para obtener `Client` desde `extra` o cubit cache.
2. Adaptar `ClientEditView` para obtener `Client` desde `extra` o cubit cache.
3. Integrar `NavigationGuard` en `ClientEditPage` (vía `onExit` o `PopScope`).
4. Implementar fallback para deep linking (loading → fetch → error si no
   existe).

### Paso 7: Migrar MainApp y adaptar login/logout

1. Cambiar `MaterialApp` a `MaterialApp.router`.
2. Migrar `LoginPage` y `SettingsPage` a `context.go()`.

### Paso 8: Actualizar DI

1. Ajustar registro de `SideMenuCubit` con la firma simplificada.
2. Registrar `GoRouter` en GetIt si es necesario (para redirect de auth).

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (secuencial, cada paso depende del anterior
excepto 1 que es independiente)

### Dependencias entre pasos

- Paso 3 depende de 2 (go_router disponible).
- Pasos 4, 5, 6, 7 dependen de 3 (router definido).
- Paso 8 depende de 4 (SideMenuCubit simplificado).
- Paso 1 es totalmente independiente y puede hacerse primero o en paralelo.

### Puntos delicados

- **NavigationGuard + go_router:** La integración con `onExit` es relativamente
  nueva en go_router. Verificar que la versión utilizada lo soporta. Alternativa
  segura: `PopScope` widget.
- **Deep linking a cliente:** Sin `getClientById`, el deep link a
  `/clients/:id/detail` depende de que la lista de clientes esté cargada. Si el
  usuario accede directamente por URL, hay que gestionar el estado de carga.
- **Dialogs con Navigator.pop:** Los diálogos (`showDialog`) usan su propio
  Navigator. No interfieren con `GoRouter`. Pero hay que verificar que ningún
  diálogo use `Navigator.of(context)` con `rootNavigator: true` de forma que
  interfiera.
- **State preservation en IndexedStack:** `StatefulShellRoute.indexedStack`
  preserva el estado de cada rama. Esto cambia el ciclo de vida respecto al
  actual (donde las páginas se reconstruyen cada vez). Puede tener implicaciones
  en streams y listeners que se inician en `initState`.

## 7) Estrategia de validación

### Verificación automática

- `flutter build web` compila sin errores ni warnings.
- `flutter analyze` limpio.
- Tests unitarios existentes pasan (especialmente los de cubits y repositories).

### Verificación manual

- Recorrer las 9 secciones del menú verificando que la URL cambia correctamente.
- Pulsar back/forward en el navegador y verificar sincronización URL ↔ menú ↔
  contenido.
- Deep link: abrir directamente cada una de las 11 rutas en una pestaña nueva.
- Refresh (F5) en cada sección y verificar que mantiene la ruta.
- Flujo completo de cliente: lista → detalle → editar → guardar → verificar
  retorno.
- Flujo editar desde lista: lista → editar → guardar → verificar retorno a
  lista.
- NavigationGuard: editar cliente → cambiar de sección → verificar diálogo →
  verificar que cancelar mantiene la ruta.
- Login/logout: verificar que los flujos de autenticación funcionan con el nuevo
  router.
- URL inválida: verificar que muestra página 404.
- `/clients/<id_inexistente>/detail`: verificar que muestra error.
- Dos pestañas abiertas con rutas distintas funcionan independientemente.

### Escenarios a cubrir

- Navegación normal (menú → URL)
- Deep linking (URL directa → menú + contenido)
- Back/forward del navegador
- Refresh de página
- Rutas paramétrizadas (`:id`)
- Ruta raíz `/` → redirect a `/home`
- Ruta inexistente → 404
- Recurso inexistente → error en página
- Cambios sin guardar → diálogo de confirmación
- Login → redirect a home
- Logout → redirect a login
- Estado de menú expandido/colapsado persistente al cambiar rutas

### Tipo de pruebas recomendables

- **Unit tests:** `SideMenuCubit` simplificado (solo `isExpanded`).
- **Widget tests:** Verificar que `SideMenu` renderiza correctamente con
  distintos `selectedIndex`.
- **Integration tests (router):** Verificar que `GoRouter` resuelve las rutas
  correctamente, incluidos redirects y 404.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                             | Probabilidad | Impacto                                      |
| ---------------------------------------------------------------------------------- | ------------ | -------------------------------------------- |
| `onExit` de go_router no cubre todos los escenarios de NavigationGuard             | Media        | Medio — workaround con `PopScope`            |
| Deep link a cliente sin lista cargada genera flash de loading                      | Alta         | Bajo — es aceptable UX                       |
| Cambio de lifecycle al usar `ShellRoute` simple (páginas se reconstruyen cada vez) | Baja         | Bajo — es el comportamiento actual y deseado |
| Algún `Navigator.pop()` en diálogos interfiere con GoRouter                        | Baja         | Medio — fácil de detectar en testing manual  |
| Eliminación de plataformas rompe algún import condicional no detectado             | Baja         | Bajo — fácil de detectar en compilación      |

### Impacto potencial

- El cambio afecta a toda la navegación de la aplicación. Un error en el router
  afecta a todas las secciones.
- Al usar `ShellRoute` sin IndexedStack, las páginas se reconstruyen cada vez
  que se cambia de sección (mismo comportamiento actual). No hay riesgo de
  acumulación de listeners.

### Mitigación

- Probar `onExit` en desarrollo; si no funciona correctamente, usar `PopScope`
  como plan B.
- Las páginas se destruyen y recrean al cambiar de sección (no IndexedStack),
  por lo que no hay riesgo de acumulación de streams/listeners.

### Plan de rollback

- El cambio es un commit (o PR) único. Rollback = revertir el commit.
- Si se detectan problemas graves post-deploy, revertir a la versión anterior
  del router (rutas imperativas).
- Las carpetas de plataforma eliminadas se pueden regenerar con
  `flutter create .` si fuera necesario reactivarlas.

## 9) Suposiciones

- `go_router` versión >=14.0 (soporte para `onExit` y
  `StatefulShellRoute.indexedStack`).
- El paquete `flutter_web_plugins` (para `usePathUrlStrategy`) ya está
  disponible como dependencia transitiva de Flutter SDK.
- Firebase Hosting se configurará con rewrites SPA en `firebase.json` como parte
  de esta implementación.
- Los diálogos existentes (category selector, shipping methods, etc.) usan
  `Navigator.of(context).pop()` del Navigator local del diálogo y no interfieren
  con GoRouter.
- `SharedPreferences` funciona correctamente en web para persistir `isExpanded`.

## 10) Preguntas abiertas

- Sin preguntas abiertas. Todas resueltas:
  - **Firebase Hosting:** `firebase.json` no tiene sección `hosting`. Se debe
    añadir con rewrites SPA como parte de la implementación.
  - **IndexedStack vs rebuild:** Se opta por **reconstruir** las páginas al
    cambiar de sección (comportamiento actual). Usar `ShellRoute` simple en
    lugar de `StatefulShellRoute.indexedStack`.

## 11) Notas para implementación

- **Restricciones técnicas a respetar:**
  - No modificar lógica de cubits de negocio (ClientsCubit, OrdersTodayCubit,
    etc.) más allá de lo estrictamente necesario para la navegación.
  - Respetar la convención de archivos en `snake_case` y clases en `PascalCase`.
  - Usar `context.go()` para navegación que reemplaza la pila y `context.push()`
    para navegación que apila (detalle/edición de cliente).
  - Usar `context.pop()` para volver al origen, resolviendo naturalmente el
    RF-11 (volver a lista o detalle según el origen).

- **Secuencia sugerida:**
  1. Eliminar plataformas (commit independiente, bajo riesgo).
  2. Implementar router + shell + rutas principales (commit nuclear del cambio).
  3. Migrar clientes a rutas paramétrizadas (puede ir en el mismo commit o
     separado).
  4. Verificación manual completa.

- **Consideraciones para no romper comportamiento existente:**
  - Los `Navigator.of(context).pop()` dentro de `showDialog` NO deben cambiarse
    a `context.pop()` de go_router. Solo afectan al overlay del diálogo.
  - `context.go('/home')` tras login reemplaza la pila (el usuario no puede
    volver a login con back). Mismo comportamiento que el actual
    `pushNamedAndRemoveUntil`.
  - Verificar `firebase.json` para rewrites SPA antes del primer deploy con las
    nuevas rutas.

- **Dependencia nueva:**
  - `go_router: ^14.0.0` — paquete oficial de Flutter, mantenido por el equipo
    de Flutter, sin riesgos de adopción.

- **Estado: Listo para implementación**
