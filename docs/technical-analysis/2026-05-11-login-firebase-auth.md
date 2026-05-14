# Technical Analysis: Login con Firebase Authentication

- **Fecha:** 2026-05-11
- **Identificador:** login-firebase-auth
- **Fuente:** docs/functional-analysis/2026-05-11-login-firebase-auth.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Se propone crear una nueva feature `auth` siguiendo Clean Architecture
feature-first, que encapsule la autenticación con Firebase Auth
(email/password), la gestión de la preferencia "Recordarme" en
SharedPreferences, y la lectura/escritura del perfil de usuario en Firestore
(colección `users`). El flujo de arranque en `main.dart` determinará la ruta
inicial (`/login` o `/`) según el estado de sesión y la flag de "Recordarme". La
feature `settings` se modificará para añadir el botón "Cerrar sesión" y
redirigir la lectura/escritura del nombre de usuario al nuevo repositorio de la
feature `auth`.

- **Áreas impactadas:** nueva feature `auth`, `main.dart`, `router.dart`,
  `injection.dart`, `settings` (page + user identity section), `pubspec.yaml`,
  archivos ARB de i18n.
- **Riesgo general estimado:** medio — la lógica de autenticación es directa,
  pero el cambio en la fuente de datos del nombre de usuario y la modificación
  del flujo de arranque requieren coordinación cuidadosa.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con capas `data/`, `domain/`,
  `presentation/` por feature.
- **BLoC/Cubit** para gestión de estado.
- **GetIt** (`sl`) para inyección de dependencias, con módulos por feature en
  `lib/app/di/modules/`.
- **fpdart** (`Either<Failure, T>`) para manejo funcional de errores.
- **UseCase base** en `lib/core/usecase/usecase.dart` (`UseCase<Type, Params>`,
  `NoParams`).

### Módulos relevantes

- **Router** (`lib/app/router/router.dart`): rutas con nombre
  (`Map<String, WidgetBuilder>`), ruta única actual: `'/'` → `SideMenuShell`.
- **main.dart**: inicializa Firebase (best-effort), DI, y lanza `MainApp` con
  `initialRoute: '/'`.
- **Settings feature**: `SettingsRepository` con
  `getUserName()`/`saveUserName()` delegando a `SettingsLocalDataSource`
  (SharedPreferences). Widget `UserIdentitySection` usa `SettingsRepository`
  directamente vía `sl`.
- **core_module.dart**: registra `FirebaseFirestore` y `FirebaseDatabase`
  condicionalmente (`if (firebaseAvailable)`).

### Dependencias existentes relevantes

- `firebase_core: ^4.7.0`, `cloud_firestore: ^6.3.0`,
  `firebase_database: ^12.3.0` — ya en `pubspec.yaml`.
- `shared_preferences: ^2.5.5` — disponible para la flag "Recordarme".
- `flutter_secure_storage: ^10.0.0` — disponible pero no necesaria para este
  caso.
- **`firebase_auth` NO está en `pubspec.yaml`** — debe añadirse.

### Restricciones

- La app fuerza orientación landscape.
- i18n obligatorio — solo locale `es` actualmente (`app_es.arb`).
- Firebase puede no inicializarse (manejo best-effort actual) — con auth
  obligatorio esto requiere ajuste.

## 3) Objetivo técnico

- **Qué debe cambiar:** añadir autenticación obligatoria como puerta de entrada
  a la app, con una nueva feature `auth` y ajustes en el flujo de arranque,
  router y settings.
- **Resultado técnico:** la app solo permite acceso a usuarios autenticados vía
  Firebase Auth; el perfil de usuario (userName) se almacena en Firestore; la
  sesión se puede persistir/revocar mediante "Recordarme".
- **Limitaciones a respetar:** Clean Architecture feature-first, i18n, design
  tokens del tema, patrones existentes de Firestore datasources.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear la feature `auth` con tres capas. El dominio define una entidad `AppUser`,
un contrato `AuthRepository` y use cases. La capa de datos implementa dos
datasources: uno remoto (`FirebaseAuth` + `Firestore`) y uno local
(SharedPreferences para "Recordarme"). La presentación usa un `AuthCubit` para
la pantalla de Login y un `AuthCubit` a nivel de app para controlar el estado de
sesión global.

### Componentes / módulos / servicios afectados

#### Nueva feature: `lib/features/auth/`

```
lib/features/auth/
├── data/
│   ├── datasources/
│   │   ├── auth_remote_data_source.dart          # Contrato
│   │   ├── auth_remote_data_source_impl.dart      # FirebaseAuth + Firestore
│   │   ├── auth_local_data_source.dart            # Contrato
│   │   └── auth_local_data_source_impl.dart       # SharedPreferences (rememberMe)
│   └── repositories/
│       └── auth_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── app_user.dart
│   ├── repositories/
│   │   └── auth_repository.dart
│   └── usecases/
│       ├── sign_in.dart
│       ├── sign_out.dart
│       ├── get_current_user.dart
│       ├── get_user_name.dart
│       ├── save_user_name.dart
│       └── check_auto_login.dart
└── presentation/
    ├── bloc/
    │   ├── login_cubit.dart
    │   └── login_state.dart
    └── pages/
        └── login_page.dart
```

#### Contratos e interfaces

**`AppUser` (entity):**

```dart
class AppUser extends Equatable {
  final String uid;
  final String email;
  final String? userName;

  const AppUser({required this.uid, required this.email, this.userName});

  @override
  List<Object?> get props => [uid, email, userName];
}
```

**`AuthRepository` (contrato domain):**

```dart
abstract class AuthRepository {
  /// Intenta sign-in con email/password.
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  });

  /// Cierra sesión de Firebase Auth y limpia la flag rememberMe.
  Future<Either<Failure, Unit>> signOut();

  /// Devuelve el usuario actual si hay sesión activa, null si no.
  Future<Either<Failure, AppUser?>> getCurrentUser();

  /// Lee el userName del documento Firestore del usuario.
  Future<Either<Failure, String?>> getUserName(String uid);

  /// Escribe el userName en el documento Firestore del usuario.
  Future<Either<Failure, Unit>> saveUserName(String uid, String name);

  /// Lee la flag rememberMe de SharedPreferences.
  bool isRememberMeEnabled();

  /// Guarda la flag rememberMe.
  Future<void> setRememberMe(bool value);
}
```

**`AuthRemoteDataSource` (contrato data):**

```dart
abstract class AuthRemoteDataSource {
  Future<AppUser> signInWithEmailPassword(String email, String password);
  Future<void> signOut();
  AppUser? getCurrentUser();
  Future<String?> getUserName(String uid);
  Future<void> saveUserName(String uid, String name);
}
```

**`AuthLocalDataSource` (contrato data):**

```dart
abstract class AuthLocalDataSource {
  bool getRememberMe();
  Future<void> setRememberMe(bool value);
}
```

### Flujo de datos o de control

#### Arranque de la app (`main.dart` / `_initializeServices`)

1. Firebase se inicializa (ya existente).
2. DI se inicializa (ya existente) — ahora incluye `registerAuthModule`.
3. **Nuevo:** se evalúa la ruta inicial:
   - Si `firebaseAvailable` es `false` → ruta = `/login` (mostrará error de
     servicio no disponible).
   - Si `AuthLocalDataSource.getRememberMe()` es `true` Y
     `FirebaseAuth.instance.currentUser != null` → ruta = `/` (autologin).
   - En cualquier otro caso → ruta = `/login`.
   - Si `rememberMe` es `false` Y hay sesión de Firebase activa → se hace
     `signOut()` para limpiar la sesión residual.

#### Login flow

1. `LoginPage` renderiza formulario con email, password, checkbox "Recordarme".
2. Usuario envía → `LoginCubit.signIn(email, password, rememberMe)`.
3. `LoginCubit` invoca `SignIn` use case → `AuthRepository.signIn()`.
4. `AuthRepositoryImpl.signIn()` →
   `AuthRemoteDataSource.signInWithEmailPassword()` (que usa
   `FirebaseAuth.instance.signInWithEmailAndPassword()`).
5. Éxito → `AuthRepositoryImpl` persiste `rememberMe` vía
   `AuthLocalDataSource.setRememberMe()` → retorna `Right(AppUser)`.
6. `LoginCubit` emite estado `LoginSuccess`.
7. `LoginPage` detecta `LoginSuccess` → navega a `/` con `pushReplacementNamed`
   (limpiando pila).

#### Cerrar sesión

1. `SettingsPage` → botón "Cerrar sesión" invoca `SignOut` use case.
2. `AuthRepository.signOut()` → `FirebaseAuth.instance.signOut()` +
   `AuthLocalDataSource.setRememberMe(false)`.
3. Navegar a `/login` con `pushNamedAndRemoveUntil`.

#### Nombre de usuario (UserIdentitySection)

1. Al construir `UserIdentitySection`, obtener UID del usuario actual desde
   `AuthRepository.getCurrentUser()`.
2. Leer nombre con `GetUserName` use case → `AuthRepository.getUserName(uid)` →
   Firestore `users/{uid}`.
3. Guardar nombre con `SaveUserName` use case →
   `AuthRepository.saveUserName(uid, name)` → Firestore `users/{uid}`.

### Gestión de errores y validaciones

**Errores de Firebase Auth mapeados:**

| `FirebaseAuthException.code`                             | Failure                         | Mensaje i18n sugerido                             |
| -------------------------------------------------------- | ------------------------------- | ------------------------------------------------- |
| `invalid-credential`, `wrong-password`, `user-not-found` | `AuthInvalidCredentialsFailure` | "Email o contraseña incorrectos"                  |
| `user-disabled`                                          | `AuthUserDisabledFailure`       | "Cuenta deshabilitada. Contacta al administrador" |
| `too-many-requests`                                      | `AuthTooManyRequestsFailure`    | "Demasiados intentos. Inténtalo más tarde"        |
| `network-request-failed`                                 | `NetworkFailure` (existente)    | "Sin conexión a internet"                         |
| Otros                                                    | `AuthUnknownFailure`            | "Error de autenticación inesperado"               |

**Validaciones en la UI (LoginCubit/LoginPage):**

- Email vacío → mensaje local.
- Email con formato inválido → validación regex antes de enviar a Firebase.
- Password vacío → mensaje local.
- Trim de email antes de enviar.

**Errores de Firestore (getUserName/saveUserName):**

- `FirebaseException` → `ServerFailure` (patrón existente en el proyecto).
- Si el documento no existe al leer → retornar `null` (no error).
- Si el documento no existe al escribir → usar `set` con `merge: true` para
  crearlo automáticamente.

### Consideraciones de compatibilidad o migración

- **Nombre de usuario en SharedPreferences:** tras la migración, el campo
  `settings_user_name` de SharedPreferences dejará de usarse para leer/escribir.
  No es necesario migrarlo automáticamente — el usuario deberá establecer su
  nombre en la nueva fuente (Firestore). La lectura/escritura en
  SharedPreferences puede eliminarse del `SettingsRepository` y
  `SettingsLocalDataSource` o dejarse como legacy inactivo.
- **`SettingsRepository.getUserName()` / `saveUserName()`:** estos métodos dejan
  de ser responsabilidad de settings. La `UserIdentitySection` pasará a usar
  `AuthRepository` (o los use cases correspondientes) en lugar de
  `SettingsRepository`. Los métodos en `SettingsRepository` pueden retirarse.
- **Firebase obligatorio:** actualmente la app funciona sin Firebase. Con auth
  obligatorio, si Firebase no está disponible la app no puede operar. El flujo
  de arranque deberá llevar al Login con un mensaje de error en ese caso.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                              | Propósito                                                                                                                   |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/auth/domain/entities/app_user.dart`                      | Entidad de usuario autenticado                                                                                              |
| `lib/features/auth/domain/repositories/auth_repository.dart`           | Contrato del repositorio de autenticación                                                                                   |
| `lib/features/auth/domain/usecases/sign_in.dart`                       | Use case de inicio de sesión                                                                                                |
| `lib/features/auth/domain/usecases/sign_out.dart`                      | Use case de cierre de sesión                                                                                                |
| `lib/features/auth/domain/usecases/get_current_user.dart`              | Use case para obtener usuario actual                                                                                        |
| `lib/features/auth/domain/usecases/get_user_name.dart`                 | Use case para leer userName de Firestore                                                                                    |
| `lib/features/auth/domain/usecases/save_user_name.dart`                | Use case para escribir userName en Firestore                                                                                |
| `lib/features/auth/domain/usecases/check_auto_login.dart`              | Use case para verificar si aplica autologin                                                                                 |
| `lib/features/auth/data/datasources/auth_remote_data_source.dart`      | Contrato datasource remoto (Firebase Auth + Firestore)                                                                      |
| `lib/features/auth/data/datasources/auth_remote_data_source_impl.dart` | Implementación con FirebaseAuth y FirebaseFirestore                                                                         |
| `lib/features/auth/data/datasources/auth_local_data_source.dart`       | Contrato datasource local (SharedPreferences)                                                                               |
| `lib/features/auth/data/datasources/auth_local_data_source_impl.dart`  | Implementación con SharedPreferences                                                                                        |
| `lib/features/auth/data/repositories/auth_repository_impl.dart`        | Implementación del repositorio                                                                                              |
| `lib/features/auth/presentation/bloc/login_cubit.dart`                 | Cubit de la pantalla de Login                                                                                               |
| `lib/features/auth/presentation/bloc/login_state.dart`                 | Estados del Cubit de Login                                                                                                  |
| `lib/features/auth/presentation/pages/login_page.dart`                 | Pantalla de Login con diseño visual atractivo                                                                               |
| `lib/app/di/modules/auth_module.dart`                                  | Módulo DI para la feature auth                                                                                              |
| `lib/core/error/failure.dart` (extensión)                              | Nuevos tipos `AuthInvalidCredentialsFailure`, `AuthUserDisabledFailure`, `AuthTooManyRequestsFailure`, `AuthUnknownFailure` |

### Artefactos a modificar

| Artefacto                                                               | Cambio esperado                                                                                                                                                           |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pubspec.yaml`                                                          | Añadir dependencia `firebase_auth`                                                                                                                                        |
| `lib/app/router/router.dart`                                            | Añadir ruta `/login` → `LoginPage`. Añadir constante `AppRoutes.login`.                                                                                                   |
| `lib/app/di/injection.dart`                                             | Importar y llamar `registerAuthModule(sl)` antes de los demás módulos de features.                                                                                        |
| `lib/main.dart`                                                         | Modificar `_initializeServices` para evaluar ruta inicial según estado de autenticación.                                                                                  |
| `lib/app/di/modules/core_module.dart`                                   | Registrar `FirebaseAuth.instance` en GetIt cuando `firebaseAvailable` es true.                                                                                            |
| `lib/features/settings/presentation/pages/settings_page.dart`           | Añadir botón "Cerrar sesión" debajo de `FacturaDirectaSection`, alineado a la derecha.                                                                                    |
| `lib/features/settings/presentation/widgets/user_identity_section.dart` | Cambiar fuente de datos: usar `AuthRepository` (o sus use cases) en lugar de `SettingsRepository` para `getUserName`/`saveUserName`. Obtener UID del usuario autenticado. |
| `lib/core/error/failure.dart`                                           | Añadir clases de failure de autenticación.                                                                                                                                |
| `lib/app/localization/l10n/app_es.arb`                                  | Añadir claves i18n para Login: labels, placeholders, mensajes de error, "Recordarme", "Cerrar sesión", "Iniciar sesión".                                                  |

### Artefactos a retirar o reemplazar

| Artefacto                                                  | Motivo                                                                                                        |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `SettingsRepository.getUserName()` / `saveUserName()`      | La responsabilidad se traslada a `AuthRepository`. Retirar estos métodos del contrato y de la implementación. |
| `SettingsLocalDataSource.getUserName()` / `saveUserName()` | Idem. Retirar del contrato e implementación.                                                                  |
| `SettingsRepositoryImpl._generateUserCode()`               | Ya no se necesita generación local de código de usuario.                                                      |

## 6) Estrategia de implementación

1. **Paso 1 — Dependencia:** Añadir `firebase_auth` en `pubspec.yaml`.

2. **Paso 2 — Failures:** Añadir los tipos de failure de autenticación en
   `lib/core/error/failure.dart`.

3. **Paso 3 — Feature auth / domain:** Crear entity `AppUser`, contrato
   `AuthRepository` y todos los use cases.

4. **Paso 4 — Feature auth / data:** Crear contratos e implementaciones de
   datasources (`AuthRemoteDataSource` con FirebaseAuth + Firestore,
   `AuthLocalDataSource` con SharedPreferences) y `AuthRepositoryImpl`.

5. **Paso 5 — Feature auth / presentation:** Crear `LoginCubit`, `LoginState` y
   `LoginPage`.

6. **Paso 6 — DI:** Crear `auth_module.dart` y registrarlo en `injection.dart`.
   Registrar `FirebaseAuth` en `core_module.dart`.

7. **Paso 7 — Router:** Añadir ruta `/login` en `router.dart`.

8. **Paso 8 — Main:** Modificar `_initializeServices` para calcular ruta inicial
   según autenticación y rememberMe.

9. **Paso 9 — Settings (Cerrar sesión):** Añadir botón "Cerrar sesión" en
   `settings_page.dart`.

10. **Paso 10 — Settings (UserIdentity migración):** Modificar
    `UserIdentitySection` para usar `AuthRepository` en lugar de
    `SettingsRepository`. Retirar `getUserName`/`saveUserName` de
    `SettingsRepository`, `SettingsLocalDataSource` y sus implementaciones.

11. **Paso 11 — i18n:** Añadir todas las claves de traducción necesarias en
    `app_es.arb`.

12. **Paso 12 — Validación:** Verificar flujos completos, edge cases y
    compilación.

### Orden recomendado

- Pasos 1–3 son fundacionales y no tienen dependencias externas.
- Paso 4 depende de 2–3.
- Paso 5 depende de 3–4.
- Paso 6 depende de 4–5.
- Pasos 7–8 dependen de 5–6.
- Pasos 9–10 dependen de 3–4 y pueden hacerse en paralelo con 7–8.
- Paso 11 puede avanzarse en paralelo desde el paso 5.
- Paso 12 es el último.

### Dependencias entre pasos

- La `LoginPage` (paso 5) necesita los use cases (paso 3) y el DI (paso 6) para
  funcionar end-to-end, pero puede crearse en paralelo si se asume DI pendiente.
- La modificación de `UserIdentitySection` (paso 10) depende de que
  `AuthRepository` esté disponible y registrado en DI.
- Las claves i18n (paso 11) deben existir antes de que la UI compile sin
  errores.

### Puntos delicados

- **Retirada de `getUserName`/`saveUserName` de Settings:** hay que asegurarse
  de que no queda ninguna referencia en otros widgets o cubits.
- **Flujo de arranque:** la evaluación de ruta inicial ocurre antes de que la UI
  esté montada, por lo que la verificación de autenticación debe ser síncrona o
  gestionarse durante la inicialización.
- **Firestore `users/{uid}` inexistente:** el datasource debe usar
  `set(merge: true)` en `saveUserName` para crear el documento si no existe, y
  retornar `null` sin error en `getUserName` si no existe.
- **Sign-out al arrancar sin "Recordarme":** si el usuario no marcó
  "Recordarme", al arrancar la app se debe hacer `signOut()` para invalidar la
  sesión de Firebase que persiste por defecto.

## 7) Estrategia de validación

### Verificación automática (tests)

- **`AuthRepositoryImpl`:** tests unitarios con mocks de `AuthRemoteDataSource`
  y `AuthLocalDataSource`:
  - `signIn` exitoso, credenciales incorrectas, usuario deshabilitado, error de
    red.
  - `signOut` limpia rememberMe.
  - `getCurrentUser` con sesión activa y sin sesión.
  - `getUserName` con documento existente y no existente.
  - `saveUserName` crea/actualiza documento.
- **`LoginCubit`:** tests con `bloc_test`:
  - Emite `LoginLoading` → `LoginSuccess` en login exitoso.
  - Emite `LoginLoading` → `LoginError` con mensaje correcto según tipo de
    failure.
  - Valida email/password vacíos.
- **Use cases:** tests triviales de paso a repositorio.

### Validación manual

- Flujo completo de login con credenciales válidas e inválidas.
- Verificar "Recordarme" activo: cerrar app, reabrir → acceso directo.
- Verificar "Recordarme" inactivo: cerrar app, reabrir → pantalla de Login.
- Cerrar sesión desde Ajustes → redirección a Login.
- Editar nombre de usuario en Ajustes → verificar persistencia en Firestore.
- Firebase no disponible → pantalla de Login muestra error.
- Sin conexión → Login muestra error de red.

### Escenarios a cubrir

- Login exitoso con autologin activo/inactivo.
- Credenciales incorrectas (email inexistente, password incorrecto).
- Cuenta deshabilitada.
- Rate-limiting de Firebase Auth.
- Documento de usuario inexistente en Firestore al acceder a Ajustes.
- Sesión expirada/revocada tras autologin.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                         | Probabilidad | Impacto                                            |
| ------------------------------------------------------------------------------ | ------------ | -------------------------------------------------- |
| Proveedor email/password no habilitado en Firebase Console                     | Baja         | Alto — login no funciona                           |
| Reglas de Firestore bloquean lectura/escritura de `users`                      | Media        | Alto — userName no se carga/guarda                 |
| Sesión de Firebase Auth persistida por defecto causa bypass de "no Recordarme" | Media        | Medio — resuelto con signOut explícito al arrancar |
| Refactoring de `UserIdentitySection` rompe la pantalla de Ajustes              | Baja         | Medio — detectable en QA                           |

### Impacto potencial

- **Usuarios existentes** pierden acceso hasta que se les cree cuenta en
  Firebase Auth.
- **Nombre de usuario** almacenado localmente se pierde; deberán reentrarlo.
- **Funcionamiento offline** queda limitado tras la autenticación inicial (las
  operaciones de Firestore existentes ya tienen este requisito).

### Mitigación

- Documentar en README los pasos de configuración de Firebase Auth (habilitar
  proveedor, crear usuarios).
- Usar `set(merge: true)` en Firestore para evitar errores por documentos
  inexistentes.
- El signOut al arrancar sin "Recordarme" garantiza el comportamiento esperado.
- Mantener los tests unitarios actualizados.

### Plan de rollback

- Revertir los commits de la feature `auth`.
- Retirar `firebase_auth` del `pubspec.yaml`.
- Restaurar `getUserName`/`saveUserName` en `SettingsRepository` si ya fueron
  retirados.
- El cambio es aditivo en su mayoría (nueva feature), por lo que el rollback es
  de bajo riesgo.

## 9) Suposiciones

- **S-01:** El proveedor de email/password ya está habilitado en la consola de
  Firebase del proyecto.
- **S-02:** La colección `users` en Firestore se creará implícitamente al
  escribir el primer documento. Las reglas de seguridad permiten
  lectura/escritura autenticada a `users/{uid}` donde `request.auth.uid == uid`.
- **S-03:** Si el documento del usuario no existe en Firestore al leer, la app
  lo creará automáticamente al guardar el nombre (resolviendo PA-01 del análisis
  funcional).
- **S-04:** "No Recordarme" implica hacer `signOut` de Firebase Auth al arrancar
  la app si la flag es `false`, forzando re-login (resolviendo PA-02 del
  análisis funcional).
- **S-05:** La Firestore database ID es `servicebo` (como ya está configurado en
  `core_module.dart`).
- **S-06:** No se requiere texto adicional de bienvenida en el Login más allá
  del logo (resolviendo PA-03).

## 10) Preguntas abiertas

- **PA-01:** ¿Las reglas de seguridad de Firestore ya permiten lectura/escritura
  autenticada sobre la colección `users`? Si no, deben configurarse antes de
  desplegar.

## 11) Notas para implementación

- Respetar el patrón existente de Firestore datasources (ver
  `ClientCategoryFirestoreDataSourceImpl` como referencia): inyección de
  `FirebaseFirestore`, manejo de `FirebaseException` → `ServerException`,
  timeouts en escrituras.
- La `LoginPage` debe usar design tokens del tema (`AppSpacing`, `AppRadii`,
  `AppElevation`) y `Theme.of(context)` — no hardcodear colores ni tamaños.
- Todos los textos visibles al usuario deben usar claves de `AppLocalizations`
  (i18n obligatorio).
- El `LoginCubit` debe ser un `Cubit` (no BLoC), ya que el flujo es simple
  (submit → resultado). Similar al patrón de `FacturaDirectaCubit`.
- Registrar `FirebaseAuth.instance` en `core_module.dart` dentro del bloque
  `if (firebaseAvailable)`, junto a `FirebaseFirestore` y `FirebaseDatabase`.
- El botón "Cerrar sesión" en Settings debe usar la navegación con
  `Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false)` para
  limpiar completamente la pila.
- La retirada de `getUserName`/`saveUserName` de `SettingsRepository` no afecta
  a otros módulos — la única referencia es `UserIdentitySection`.
- El diseño de la `LoginPage` debe ser centrado y responsive en landscape, con
  el logo a un tamaño prominente, los campos de formulario con ancho acotado
  (~400px), y el checkbox "Recordarme" alineado bajo los campos.
- **Secuencia sugerida para el implementador:** empezar por los pasos
  fundacionales (1–4), luego UI (5, 11), integración (6–8), y modificaciones de
  settings (9–10) al final.
- **Estado: Listo para implementación**
