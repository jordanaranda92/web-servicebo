# Technical Analysis: Roles de usuario (employee / admin)

- **Fecha:** 2026-05-12
- **Identificador:** user-roles
- **Fuente:** docs/functional-analysis/2026-05-12-user-roles.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Añadir un enum `UserRole` (`employee`, `admin`) a la entidad `AppUser` del
  feature `auth`.
- Obtener el campo `role` del documento Firestore `users/{uid}` durante el
  sign-in y el auto-login, reutilizando la infraestructura existente del
  datasource remoto.
- Crear un `AuthCubit` global (singleton) que mantenga el `AppUser` autenticado
  en memoria y lo exponga a toda la app vía `BlocProvider` en el `MainApp`.
- Construir la lista de ítems del `SideMenu` de forma dinámica en función del
  rol, insertando "Estadísticas" (con divisor) solo para `admin`.
- Registrar la ruta `/statistics` en el router con guard de rol.
- Crear un feature `statistics` mínimo con una página placeholder.
- Áreas impactadas: `auth` (domain + data + presentation), `home` (side menu),
  `app` (router, DI, main), `i18n`, nuevo feature `statistics`.
- Riesgo general estimado: **bajo**. Los cambios son aditivos; el flujo de
  `employee` permanece inalterado.

## 2) Contexto técnico observado

### Arquitectura detectada

Clean Architecture feature-first con capas `domain/`, `data/`, `presentation/`
dentro de cada `lib/features/<feature>/`. BLoC/Cubit para gestión de estado.
GetIt para DI. fpdart (`Either`) para manejo de errores funcional.

### Módulos y capas relevantes

- **`features/auth`**: entidad `AppUser` (uid, email, userName?), repositorio
  con datasource remoto (FirebaseAuth + Firestore) y local (SharedPreferences).
  El datasource ya accede a `_usersCollection` (`users`) para
  `getUserName`/`saveUserName`.
- **`features/home`**: `SideMenu` widget con lista estática de 9 ítems;
  `SideMenuShell` gestiona layout desktop/mobile con `SideMenuCubit`.
- **`app/router`**: `AppRoutes` con `menuPaths` estática (9 paths) e
  `indexFromLocation`. `GoRouter` con `ShellRoute` para el menú.
- **`app/di`**: módulos por feature; `injection.dart` los registra
  secuencialmente.
- **`main.dart`**: `MultiBlocProvider` con `LocaleCubit` y `SideMenuCubit` como
  cubits globales. No existe `AuthCubit` global.
- **Login flow**: `LoginCubit` ejecuta `SignIn` use case →
  `AuthRemoteDataSource.signInWithEmailPassword` → devuelve `AppUser` sin rol.
  `LoginSuccess` no transporta datos del usuario.
- **Auto-login flow**: `_initializeServices` en `main.dart` verifica
  `rememberMe` + `currentUser != null` para decidir ruta inicial.
  `CheckAutoLogin` use case obtiene `AppUser?` desde `getCurrentUser()`
  (síncrono, sin lectura de Firestore).

### Restricciones relevantes

- `getCurrentUser()` del datasource es **síncrono** (lee
  `_firebaseAuth.currentUser`); no lee Firestore. Para obtener el rol en
  auto-login hay que añadir una lectura Firestore asíncrona.
- `LoginSuccess` no contiene el `AppUser`. Exponer el usuario globalmente
  requiere un mecanismo adicional.
- Los índices del `SideMenu` (selectedIndex, separatorBuilder, `menuPaths`) son
  estáticos. Un ítem condicional rompe la correspondencia 1:1 si no se adapta la
  lógica.

### Dependencias

- `cloud_firestore`, `firebase_auth`, `flutter_bloc`, `get_it`, `fpdart`,
  `go_router`, `equatable` — ya presentes.
- No se requieren dependencias nuevas.

## 3) Objetivo técnico

- Que `AppUser` contenga un `UserRole` (`employee` | `admin`) tras cualquier
  flujo de autenticación.
- Que exista un estado global reactivo (`AuthCubit`) con el usuario autenticado
  y su rol, accesible por cualquier widget/cubit de la app.
- Que el `SideMenu` y el router se configuren dinámicamente según el rol.
- Que un `employee` no pueda acceder a `/statistics` ni por menú ni por URL
  directa.

## 4) Diseño técnico de la solución

### Enfoque propuesto

**A) Enum `UserRole` + ampliación de `AppUser`**

Crear un enum `UserRole` en `features/auth/domain/entities/` con dos valores.
Añadir un campo `UserRole role` a `AppUser` (con default `employee`).

**B) Datasource: lectura de `role` desde Firestore**

Ampliar `AuthRemoteDataSource` con un método
`Future<String?> getUserRole(String uid)` — o, más eficientemente, ampliar
`signInWithEmailPassword` y `getCurrentUser` para que lean el documento de
Firestore y extraigan tanto `userName` como `role` en una sola lectura.

La opción más limpia y eficiente: crear un método privado
`_fetchUserProfile(String uid)` en el datasource impl que lee el doc
`users/{uid}` y devuelve `{userName, role}`. Reutilizar en sign-in (tras
Firebase Auth) y en un nuevo `getCurrentUserWithProfile()` (para auto-login).

Esto también optimiza el sign-in: actualmente el sign-in NO lee Firestore, y
`userName` se obtiene después por separado en settings. Con este cambio, sign-in
devuelve `AppUser` completo (con `userName` y `role`) en una sola operación.

**C) Repository + use cases**

- `signIn` ya devuelve `AppUser`; al ampliar el datasource, el `AppUser`
  devuelto incluirá `role` sin cambiar la firma.
- `getCurrentUser()` actualmente es síncrono y no lee Firestore. Hay que añadir
  un método `getCurrentUserWithProfile()` al repositorio (o renombrar) que:
  1. Obtenga `uid` de `FirebaseAuth.currentUser`.
  2. Lea el doc de Firestore para obtener `role` y `userName`.
  3. Devuelva `AppUser` completo.
- `CheckAutoLogin` use case debe usar este nuevo método para devolver `AppUser`
  con rol.

**D) `AuthCubit` global**

Nuevo cubit en `features/auth/presentation/bloc/`:

- Estado: `AuthState` (sealed: `AuthUnauthenticated`,
  `AuthAuthenticated(AppUser user)`).
- Métodos: `setUser(AppUser)`, `clear()`.
- Se registra como `registerLazySingleton` en DI (es global, como `LocaleCubit`
  / `SideMenuCubit`).
- Se añade al `MultiBlocProvider` en `MainApp`.
- `LoginCubit` llama a `AuthCubit.setUser(user)` tras login exitoso.
- El flujo de auto-login en `main.dart` llama a `CheckAutoLogin` y, si devuelve
  usuario, llama a `AuthCubit.setUser(user)`.
- Al hacer sign-out, se llama a `AuthCubit.clear()`.

**E) `SideMenu` dinámico**

- `SideMenu` recibe un parámetro `bool isAdmin` (o `UserRole`).
- La lista `items` se construye condicionalmente: si `isAdmin`, se inserta el
  ítem "Estadísticas" entre "Facturas" y "Ajustes".
- Los índices del `separatorBuilder` se calculan dinámicamente basándose en la
  lista resultante, no con índices hardcodeados.
- `SideMenuShell` obtiene `isAdmin` leyendo el estado de `AuthCubit` (via
  `context.read<AuthCubit>()`).

**F) Router dinámico**

- Añadir `AppRoutes.statistics = '/statistics'`.
- Los `menuPaths` se convierten en un método que acepta `isAdmin` y devuelve la
  lista correspondiente (o se usa un enfoque de mapeo por path sin depender de
  índices fijos).
- El guard del router redirige `/statistics` a `/home` si el usuario no es
  admin. Se accede al rol vía `sl<AuthCubit>().state`.
- Nueva ruta `GoRoute` dentro del `ShellRoute`.

**G) Feature `statistics` (placeholder)**

- Crear `lib/features/statistics/presentation/pages/statistics_page.dart` con
  una página mínima (título + cuerpo vacío).
- No se requiere domain ni data para el placeholder.

**H) i18n**

- Añadir clave `menuStatistics` en `app_es.arb` (y en `app_localizations.dart`
  generado).

### Componentes / módulos / servicios afectados

| Capa         | Artefacto                        | Cambio                                                                              |
| ------------ | -------------------------------- | ----------------------------------------------------------------------------------- |
| Domain       | `AppUser` entity                 | Añadir campo `UserRole role`                                                        |
| Domain       | Nuevo enum `UserRole`            | `employee`, `admin` con factory `fromString`                                        |
| Domain       | `AuthRepository` interface       | Nuevo método `getCurrentUserWithProfile()`                                          |
| Domain       | `CheckAutoLogin` use case        | Usar `getCurrentUserWithProfile`                                                    |
| Data         | `AuthRemoteDataSource` interface | Nuevo método `getCurrentUserWithProfile()`                                          |
| Data         | `AuthRemoteDataSourceImpl`       | `_fetchUserProfile`, integrar lectura de rol en sign-in y getCurrentUserWithProfile |
| Data         | `AuthRepositoryImpl`             | Implementar `getCurrentUserWithProfile`                                             |
| Presentation | Nuevo `AuthCubit` + `AuthState`  | Estado global del usuario autenticado                                               |
| Presentation | `LoginCubit`                     | Tras login, llamar a `AuthCubit.setUser`                                            |
| Presentation | `SideMenu` widget                | Recibir `isAdmin`, construir ítems y separadores dinámicamente                      |
| Presentation | `SideMenuShell`                  | Leer rol de `AuthCubit`, pasar a `SideMenu`, adaptar `_mobileTitleForIndex`         |
| App          | `AppRoutes`                      | Añadir `statistics`, hacer `menuPaths` dinámico                                     |
| App          | `createRouter`                   | Añadir ruta `/statistics`, guard de rol                                             |
| App          | `MainApp` (main.dart)            | Añadir `AuthCubit` al `MultiBlocProvider`, poblar en auto-login                     |
| App          | `auth_module.dart` (DI)          | Registrar `AuthCubit`                                                               |
| App          | `injection.dart` (DI)            | Registrar módulo statistics si aplica                                               |
| i18n         | `app_es.arb`                     | Clave `menuStatistics`                                                              |
| Feature      | `statistics_page.dart`           | Página placeholder                                                                  |

### Contratos e interfaces

**Enum `UserRole`:**

```dart
enum UserRole {
  employee,
  admin;

  static UserRole fromString(String? value) {
    if (value == 'admin') return UserRole.admin;
    return UserRole.employee;
  }
}
```

**`AppUser` ampliado:**

```dart
class AppUser extends Equatable {
  final String uid;
  final String email;
  final String? userName;
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.email,
    this.userName,
    this.role = UserRole.employee,
  });

  bool get isAdmin => role == UserRole.admin;
}
```

**`AuthState`:**

```dart
sealed class AuthState extends Equatable { ... }
class AuthUnauthenticated extends AuthState { ... }
class AuthAuthenticated extends AuthState {
  final AppUser user;
  ...
}
```

**`AuthRepository` (método nuevo):**

```dart
Future<Either<Failure, AppUser?>> getCurrentUserWithProfile();
```

### Flujo de datos o de control

**Sign-in:**

```
LoginPage → LoginCubit.login()
  → SignIn use case → AuthRepository.signIn()
    → AuthRemoteDataSource.signInWithEmailPassword()
      → FirebaseAuth.signIn → uid
      → Firestore users/{uid}.get() → {userName, role}
      → AppUser(uid, email, userName, role)
  → LoginCubit recibe AppUser
  → LoginCubit llama AuthCubit.setUser(user)
  → LoginCubit emite LoginSuccess
  → LoginPage navega a /home
```

**Auto-login:**

```
main._initializeServices()
  → rememberMe + currentUser != null
  → CheckAutoLogin use case
    → AuthRepository.getCurrentUserWithProfile()
      → FirebaseAuth.currentUser → uid
      → Firestore users/{uid}.get() → {userName, role}
      → AppUser(uid, email, userName, role)
  → main guarda AppUser para pasar a AuthCubit
  → MainApp.initState → AuthCubit.setUser(user)
  → ruta inicial = /home
```

**Renderizado del menú:**

```
SideMenuShell.build()
  → context.read<AuthCubit>().state → AuthAuthenticated(user)
  → user.isAdmin → true/false
  → SideMenu(isAdmin: isAdmin, ...)
    → construye items con/sin "Estadísticas"
    → separatorBuilder usa lógica dinámica
```

**Guard de ruta:**

```
GoRouter.redirect
  → si location == /statistics
    → AuthCubit.state → user.role
    → si role != admin → redirect a /home
```

### Gestión de errores y validaciones

- **Documento `users/{uid}` no existe o sin campo `role`**:
  `UserRole.fromString(null)` → `employee`. Log informativo.
- **Error de red al leer Firestore en sign-in**: se captura la excepción; se
  devuelve `AppUser` con `role = employee` y se loguea el error. No se bloquea
  el login.
- **Error de red al leer Firestore en auto-login**: igual; se devuelve `AppUser`
  con `role = employee`.
- **Valor inesperado en `role`**: `UserRole.fromString('supervisor')` →
  `employee`.

### Consideraciones de compatibilidad o migración

- `AppUser` gana un campo nuevo con valor por defecto → no rompe constructores
  existentes.
- `signInWithEmailPassword` cambia su comportamiento interno (ahora lee
  Firestore) pero su firma no cambia.
- `getCurrentUser()` se mantiene tal cual (síncrono) para no romper dependencias
  existentes; el nuevo método es `getCurrentUserWithProfile()`.
- Los tests existentes de `LoginCubit` y `SignIn` necesitarán ajustes menores
  (mocks que devuelven `AppUser` con `role`).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                         | Propósito                                       |
| ----------------------------------------------------------------- | ----------------------------------------------- |
| `lib/features/auth/domain/entities/user_role.dart`                | Enum `UserRole` con factory `fromString`        |
| `lib/features/auth/presentation/bloc/auth_cubit.dart`             | Cubit global que mantiene `AppUser` autenticado |
| `lib/features/auth/presentation/bloc/auth_state.dart`             | Estados del `AuthCubit`                         |
| `lib/features/statistics/presentation/pages/statistics_page.dart` | Página placeholder de Estadísticas              |

### Artefactos a modificar

| Artefacto                                                              | Cambio esperado                                                                                                     |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `lib/features/auth/domain/entities/app_user.dart`                      | Añadir campo `UserRole role` con default `employee`, getter `isAdmin`                                               |
| `lib/features/auth/domain/repositories/auth_repository.dart`           | Añadir método `getCurrentUserWithProfile()`                                                                         |
| `lib/features/auth/data/datasources/auth_remote_data_source.dart`      | Añadir método `getCurrentUserWithProfile()`                                                                         |
| `lib/features/auth/data/datasources/auth_remote_data_source_impl.dart` | Implementar `_fetchUserProfile`, integrar lectura de rol en `signInWithEmailPassword` y `getCurrentUserWithProfile` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart`        | Implementar `getCurrentUserWithProfile`                                                                             |
| `lib/features/auth/domain/usecases/check_auto_login.dart`              | Usar `getCurrentUserWithProfile` en vez de `getCurrentUser`                                                         |
| `lib/features/auth/presentation/bloc/login_cubit.dart`                 | Inyectar `AuthCubit`, llamar `setUser` tras login exitoso                                                           |
| `lib/features/auth/presentation/bloc/login_state.dart`                 | Sin cambios (no necesita transportar AppUser; el AuthCubit lo gestiona)                                             |
| `lib/features/home/presentation/widgets/side_menu.dart`                | Recibir `isAdmin`, construir items dinámicamente, separatorBuilder dinámico                                         |
| `lib/features/home/presentation/pages/side_menu_shell.dart`            | Leer `AuthCubit` para obtener `isAdmin`, pasarlo a `SideMenu`, adaptar `_mobileTitleForIndex` y títulos mobile      |
| `lib/app/router/router.dart`                                           | Añadir `statistics` route path, ruta GoRoute, guard de rol, `menuPaths` dinámico                                    |
| `lib/app/di/modules/auth_module.dart`                                  | Registrar `AuthCubit` como singleton                                                                                |
| `lib/app/di/injection.dart`                                            | Importar módulo statistics si se crea                                                                               |
| `lib/main.dart`                                                        | Añadir `AuthCubit` al `MultiBlocProvider`, poblar con usuario en auto-login                                         |
| `lib/app/localization/l10n/app_es.arb`                                 | Añadir clave `menuStatistics`                                                                                       |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

1. **Crear enum `UserRole`** en `features/auth/domain/entities/user_role.dart`.
2. **Ampliar `AppUser`** con campo `role` y getter `isAdmin`.
3. **Modificar datasource remoto**: añadir `_fetchUserProfile`, integrar lectura
   de rol en `signInWithEmailPassword`, implementar `getCurrentUserWithProfile`.
4. **Modificar datasource interface**: añadir `getCurrentUserWithProfile`.
5. **Modificar `AuthRepository` interface**: añadir `getCurrentUserWithProfile`.
6. **Modificar `AuthRepositoryImpl`**: implementar `getCurrentUserWithProfile`.
7. **Modificar `CheckAutoLogin` use case**: usar `getCurrentUserWithProfile`.
8. **Crear `AuthState` y `AuthCubit`**.
9. **Modificar `LoginCubit`**: inyectar `AuthCubit`, llamar `setUser` tras login
   exitoso.
10. **Registrar `AuthCubit` en DI** (`auth_module.dart`).
11. **Integrar `AuthCubit` en `MainApp`** (`main.dart`): añadir al
    `MultiBlocProvider`, poblar en auto-login.
12. **Añadir clave i18n** `menuStatistics` en `app_es.arb` y regenerar.
13. **Crear `StatisticsPage` placeholder**.
14. **Modificar `AppRoutes` y `createRouter`**: añadir ruta `/statistics`, guard
    de rol, `menuPaths` dinámico.
15. **Modificar `SideMenu`**: recibir `isAdmin`, construir ítems y separadores
    dinámicamente.
16. **Modificar `SideMenuShell`**: leer `AuthCubit`, pasar `isAdmin` a
    `SideMenu`, adaptar `_mobileTitleForIndex`.

### Orden recomendado

Pasos 1-2 → 3-7 (capa data/domain) → 8-11 (cubit global + integración main) →
12-13 (i18n + placeholder) → 14 (router) → 15-16 (side menu).

### Dependencias entre pasos

- Pasos 3-7 dependen de 1-2 (enum y entidad).
- Pasos 8-9 dependen de 2 (necesitan `AppUser` con rol).
- Paso 11 depende de 8 y 10.
- Pasos 14-16 dependen de 8 (necesitan `AuthCubit`) y de 12-13 (i18n y ruta).

### Puntos delicados

- **Índices del menú**: el cambio de lista estática a dinámica afecta a
  `selectedIndex`, `onItemSelected`, `menuPaths`, `indexFromLocation`,
  `_mobileTitleForIndex` y los separadores. Todos deben actualizarse de forma
  coherente.
- **Auto-login y Firestore**: la lectura del documento en auto-login introduce
  una llamada async a Firestore antes de determinar la ruta inicial. Si la
  lectura falla, no debe bloquear el arranque.
- **`LoginCubit` depende de `AuthCubit`**: al inyectar `AuthCubit` (singleton)
  en `LoginCubit` (factory), hay que asegurarse de que `AuthCubit` ya esté
  registrado en DI antes.

## 7) Estrategia de validación

### Verificación automática

- **Tests unitarios** del enum `UserRole.fromString`: valores válidos, null,
  vacío, desconocido.
- **Tests unitarios** de `AuthRemoteDataSourceImpl`: mock de Firestore para
  verificar lectura de `role` en sign-in y `getCurrentUserWithProfile`.
- **Tests unitarios** de `AuthRepositoryImpl.getCurrentUserWithProfile`:
  fallback a employee en caso de error.
- **Tests unitarios** de `CheckAutoLogin`: verificar que devuelve usuario con
  rol.
- **Tests de `AuthCubit`**: `setUser` → `AuthAuthenticated`, `clear` →
  `AuthUnauthenticated`.
- **Tests de `LoginCubit`**: verificar que llama a `AuthCubit.setUser` tras
  login exitoso.
- **Tests de `SideMenu`**: verificar que con `isAdmin: true` se renderiza
  "Estadísticas" y con `false` no.

### Validación manual

- Login con usuario admin → verificar ítem "Estadísticas" visible.
- Login con usuario employee → verificar ítem "Estadísticas" ausente.
- Navegar directamente a `/statistics` como employee → verificar redirección a
  `/home`.
- Auto-login con admin → verificar "Estadísticas" visible.
- Login con usuario sin campo `role` en Firestore → verificar comportamiento
  employee.
- Menú mobile (drawer) → verificar visibilidad condicional.

### Escenarios a cubrir

- Admin: sign-in, auto-login, navegación a statistics, menú desktop, menú
  mobile.
- Employee: sign-in, auto-login, acceso directo a /statistics, menú desktop,
  menú mobile.
- Edge: sin campo role, role vacío, role desconocido, error de Firestore,
  documento inexistente.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **R1** — Lectura de Firestore añade latencia al sign-in. Impacto bajo: es una
  lectura de un solo documento, <100ms típico.
- **R2** — Auto-login ahora es async con Firestore: si falla la red, el usuario
  podría quedarse sin rol correcto. Mitigado con fallback a `employee`.
- **R3** — Romper la correspondencia de índices del menú provocaría navegación
  incorrecta. Mitigado con lógica dinámica basada en paths, no en índices
  hardcodeados.

### Impacto potencial

- Bajo impacto en rendimiento (una lectura Firestore adicional por login).
- Sin impacto en usuarios `employee` (no perciben cambio).
- Sin impacto en datos (lectura only, no escritura).

### Mitigación

- R1: la lectura ya ocurre para `userName` en settings; consolidar en una sola
  lectura mejora la eficiencia.
- R2: fallback a `employee` garantiza que el usuario siempre puede acceder.
- R3: tests exhaustivos del mapeo de índices.

### Plan de rollback

- Revertir los commits. No hay migraciones de datos ni cambios destructivos. El
  campo `role` en Firestore puede coexistir sin que la app lo use.

## 9) Suposiciones

- Los documentos de la colección `users` ya tienen (o tendrán) el campo `role`
  antes del despliegue. Si no, el fallback a `employee` cubre el caso.
- No se requiere cache local del rol (SharedPreferences). Se lee de Firestore en
  cada sesión.
- `AuthCubit` se limpia (estado → `AuthUnauthenticated`) al hacer sign-out. El
  sign-out ya existe y navega a login.

## 10) Preguntas abiertas

- **PA-01** (heredada del funcional): Si la lectura del `role` falla, ¿permitir
  acceso como `employee`? **Propuesta técnica: sí**, con log informativo.
  Implementar así salvo indicación contraria.

## 11) Notas para implementación

- Respetar el patrón existente de `LoginCubit` como factory y `AuthCubit` como
  singleton.
- Usar `context.read<AuthCubit>()` (no `watch`) en `SideMenuShell` si el rol no
  cambia tras login.
- Para los `menuPaths` dinámicos, considerar un método estático
  `AppRoutes.menuPathsForRole(UserRole role)` en lugar de una lista constante,
  para mantener la centralización.
- El `separatorBuilder` actual usa índices hardcodeados (`0, 2, 6, 7`). Debe
  refactorizarse para calcular los divisores basándose en alguna propiedad de
  los ítems o en la estructura de la lista, no en posiciones absolutas. Una
  opción: añadir un flag `hasDividerAfter` al `_MenuItemData`.
- Asegurar que el sign-out llama a `AuthCubit.clear()` antes de navegar a login.
- No olvidar adaptar `_mobileTitleForIndex` en `SideMenuShell` para incluir
  "Estadísticas" condicionalmente.
- **Estado: Listo para implementación**
