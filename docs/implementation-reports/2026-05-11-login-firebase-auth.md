# Implementation Report: Login con Firebase Authentication

- **Fecha:** 2026-05-11
- **Identificador:** login-firebase-auth
- **Plan técnico:** docs/technical-analysis/2026-05-11-login-firebase-auth.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la funcionalidad completa de login con Firebase
Authentication siguiendo el plan técnico. Se creó la feature `auth` con Clean
Architecture feature-first, se modificó el flujo de arranque para evaluar el
estado de sesión, se añadió la ruta `/login` al router, se migró el nombre de
usuario de SharedPreferences a Firestore, se añadió el botón "Cerrar sesión" en
Ajustes y se internacionalizaron todos los textos.

La compilación es limpia (0 errores, 0 warnings nuevos).

## 2) Alcance ejecutado

Todas las partes del plan se han implementado:

- Dependencia `firebase_auth: ^6.4.0` añadida (ajustada de `^5.5.1` a `^6.4.0`
  por compatibilidad con las versiones existentes de Firebase en el proyecto).
- Failures de autenticación en `core/error/failure.dart`.
- Feature `auth` completa: domain (entity, contrato, 6 use cases), data (2
  datasources + repo impl), presentation (cubit, state, login page).
- Módulo DI `auth_module.dart` registrado en `injection.dart`.
- `FirebaseAuth` registrado en `core_module.dart`.
- Ruta `/login` añadida al router.
- `main.dart` modificado para evaluar autologin y estado de sesión.
- Botón "Cerrar sesión" en `SettingsPage`.
- `UserIdentitySection` migrada a usar `AuthRepository` (Firestore) en lugar de
  `SettingsRepository` (SharedPreferences).
- `getUserName`/`saveUserName` retirados de `SettingsRepository`,
  `SettingsLocalDataSource` y sus implementaciones.
- 14 claves i18n añadidas al archivo ARB.

## 3) Artefactos tocados

### Creados

- `lib/features/auth/domain/entities/app_user.dart`
- `lib/features/auth/domain/repositories/auth_repository.dart`
- `lib/features/auth/domain/usecases/sign_in.dart`
- `lib/features/auth/domain/usecases/sign_out.dart`
- `lib/features/auth/domain/usecases/get_current_user.dart`
- `lib/features/auth/domain/usecases/get_user_name.dart`
- `lib/features/auth/domain/usecases/save_user_name.dart`
- `lib/features/auth/domain/usecases/check_auto_login.dart`
- `lib/features/auth/data/datasources/auth_remote_data_source.dart`
- `lib/features/auth/data/datasources/auth_remote_data_source_impl.dart`
- `lib/features/auth/data/datasources/auth_local_data_source.dart`
- `lib/features/auth/data/datasources/auth_local_data_source_impl.dart`
- `lib/features/auth/data/repositories/auth_repository_impl.dart`
- `lib/features/auth/presentation/bloc/login_cubit.dart`
- `lib/features/auth/presentation/bloc/login_state.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/app/di/modules/auth_module.dart`

### Modificados

- `pubspec.yaml` — añadida dependencia `firebase_auth: ^6.4.0`
- `lib/core/error/failure.dart` — añadidos 4 tipos de failure de auth
- `lib/app/di/injection.dart` — import y registro de `registerAuthModule`
- `lib/app/di/modules/core_module.dart` — registro de `FirebaseAuth` en GetIt
- `lib/app/di/modules/orders_today_module.dart` — migrado uso de
  `SettingsRepository.getUserName()` a `FirebaseAuth.currentUser`
- `lib/app/router/router.dart` — añadida ruta `/login` y constante
  `AppRoutes.login`
- `lib/main.dart` — lógica de ruta inicial basada en estado de autenticación +
  rememberMe
- `lib/features/settings/presentation/pages/settings_page.dart` — añadido botón
  "Cerrar sesión"
- `lib/features/settings/presentation/widgets/user_identity_section.dart` —
  migrado a `AuthRepository` (Firestore)
- `lib/features/settings/domain/repositories/settings_repository.dart` —
  retirados métodos de user identity
- `lib/features/settings/data/datasources/local/settings_local_data_source.dart`
  — retirados métodos de user identity
- `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`
  — retirados métodos + constante
- `lib/features/settings/data/repositories/settings_repository_impl.dart` —
  retirados métodos + `_generateUserCode` + import `dart:async`
- `lib/app/localization/l10n/app_es.arb` — añadidas 14 claves i18n de login y
  cerrar sesión

### Retirados o reemplazados

- `SettingsRepository.getUserName()` / `saveUserName()` — retirados
  (responsabilidad transferida a `AuthRepository`)
- `SettingsLocalDataSource.getUserName()` / `saveUserName()` — retirados
- `SettingsRepositoryImpl._generateUserCode()` — retirado

## 4) Validación ejecutada

- **`dart analyze lib/`:** 0 errores, 0 warnings. Solo 1 `info` pre-existente no
  relacionado.
- **`flutter pub get`:** dependencias resueltas correctamente.
- **`flutter gen-l10n`:** archivos de localización generados sin errores.

## 5) Desviaciones respecto al análisis técnico

- **Versión de `firebase_auth`:** el plan técnico indicaba `^5.5.1`, pero se
  requirió `^6.4.0` por incompatibilidad de `firebase_core_platform_interface`
  entre `firebase_auth ^5.x` y los paquetes Firebase existentes en el proyecto
  (`firebase_database ^12.3.0`, `firebase_core ^4.7.0`). Impacto: ninguno
  funcional, la API de `firebase_auth 6.x` es compatible.
- **`OrdersPresenceCubit` en `orders_today_module.dart`:** el plan técnico no
  contemplaba que este cubit usaba `SettingsRepository.getUserName()`. Se migró
  a usar `FirebaseAuth.currentUser.uid`/`email` como identificadores de
  presencia. Impacto: el userId de presencia ahora es el UID de Firebase Auth en
  vez de un código local aleatorio, lo cual es más correcto para identificar
  usuarios de forma única.

## 6) Riesgos, incidencias y pendientes

- **Prerequisito:** el proveedor de email/password debe estar habilitado en
  Firebase Console antes de probar.
- **Reglas de Firestore:** la colección `users` debe tener reglas que permitan
  lectura/escritura autenticada (ej:
  `allow read, write: if request.auth.uid == resource.id`).
- **Tests unitarios:** no se han creado tests para la nueva feature `auth`. Se
  recomienda añadir tests para `AuthRepositoryImpl` y `LoginCubit` como
  siguiente paso.
- **Datos legacy:** el campo `settings_user_name` en SharedPreferences dejará de
  usarse. Los usuarios deberán reconfigurar su nombre tras el primer login.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual de flujos de login/logout +
  creación de tests unitarios para la feature `auth`
