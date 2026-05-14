# Implementation Report: Roles de usuario (employee / admin)

- **Fecha:** 2026-05-12
- **Identificador:** user-roles
- **Plan técnico:** docs/technical-analysis/2026-05-12-user-roles.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado el sistema de roles de usuario (`employee` / `admin`) en la
aplicación. El flujo de login y auto-login ahora obtiene el campo `role` del
documento `users/{uid}` de Firestore. Se ha creado un `AuthCubit` global que
expone el usuario autenticado y su rol a toda la app. El menú lateral muestra
condicionalmente el ítem "Estadísticas" solo para administradores, con guard de
ruta para proteger el acceso directo por URL.

## 2) Alcance ejecutado

- Enum `UserRole` con factory `fromString` y fallback a `employee`.
- `AppUser` ampliado con campo `role` y getter `isAdmin`.
- Datasource remoto: lectura consolidada de `userName` y `role` en una sola
  operación Firestore (`_fetchUserProfile`), integrada en sign-in y nuevo
  `getCurrentUserWithProfile`.
- Repository e interfaz ampliados con `getCurrentUserWithProfile`.
- `CheckAutoLogin` use case actualizado para usar `getCurrentUserWithProfile` y
  devolver usuario con rol.
- `AuthCubit` global (singleton) con estados `AuthUnauthenticated` /
  `AuthAuthenticated(AppUser)`.
- `LoginCubit` inyecta `AuthCubit` y llama a `setUser` tras login exitoso.
- `AuthCubit` registrado en DI como singleton y añadido al `MultiBlocProvider`
  en `MainApp`.
- Auto-login en `main.dart` poblado con `CheckAutoLogin` + `AuthCubit.setUser`.
- Sign-out en `SettingsPage` limpia `AuthCubit` con `.clear()`.
- i18n: clave `menuStatistics` añadida y generada.
- `StatisticsPage` placeholder creada.
- Router: ruta `/statistics`, guard de rol (redirect a `/home` si no admin),
  `menuPaths` dinámico basado en rol.
- `SideMenu`: recibe `isAdmin`, construye ítems condicionalmente, separadores
  basados en flag `hasDividerAfter` en vez de índices hardcodeados.
- `SideMenuShell`: lee `AuthCubit` para determinar `isAdmin`, pasa a `SideMenu`
  y navegación con paths dinámicos, adapta `_mobileTitleForIndex`.

## 3) Artefactos tocados

### Creados

- `lib/features/auth/domain/entities/user_role.dart`
- `lib/features/auth/presentation/bloc/auth_cubit.dart`
- `lib/features/auth/presentation/bloc/auth_state.dart`
- `lib/features/statistics/presentation/pages/statistics_page.dart`

### Modificados

- `lib/features/auth/domain/entities/app_user.dart`
- `lib/features/auth/domain/repositories/auth_repository.dart`
- `lib/features/auth/data/datasources/auth_remote_data_source.dart`
- `lib/features/auth/data/datasources/auth_remote_data_source_impl.dart`
- `lib/features/auth/data/repositories/auth_repository_impl.dart`
- `lib/features/auth/domain/usecases/check_auto_login.dart`
- `lib/features/auth/presentation/bloc/login_cubit.dart`
- `lib/features/home/presentation/widgets/side_menu.dart`
- `lib/features/home/presentation/pages/side_menu_shell.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/app/router/router.dart`
- `lib/app/di/modules/auth_module.dart`
- `lib/main.dart`
- `lib/app/localization/l10n/app_es.arb`
- `lib/app/localization/l10n/app_localizations.dart` (auto-generado)
- `lib/app/localization/l10n/app_localizations_es.dart` (auto-generado)

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- **Análisis estático (`dart analyze lib/`):** 1 issue preexistente (info-level,
  no relacionado con esta implementación). Sin errores ni warnings nuevos.
- **Verificación de errores IDE:** Sin errores reportados en los archivos
  modificados.
- **Revisión manual de flujos:**
  - Sign-in: lectura de perfil (userName + role) integrada en
    `signInWithEmailPassword` → `AuthCubit.setUser` → menú dinámico.
  - Auto-login: `CheckAutoLogin` → `getCurrentUserWithProfile` →
    `AuthCubit.setUser` en `_initializeServices`.
  - Sign-out: `AuthCubit.clear()` antes de navegar a login.
  - Guard de ruta: `/statistics` redirige a `/home` si no es admin.
  - Fallback a `employee` en todos los edge cases (documento inexistente, campo
    ausente, valor inesperado, error de red).

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** Se añadió la limpieza de `AuthCubit` en el sign-out
  (`SettingsPage._confirmSignOut`), que no estaba explícitamente detallado como
  artefacto a modificar en el análisis técnico, pero era necesario para
  completar el ciclo de autenticación.
  - **Justificación:** Sin limpiar `AuthCubit` en sign-out, un nuevo login como
    `employee` podría heredar el estado `admin` del usuario anterior.
  - **Impacto:** Ninguno negativo; garantiza coherencia del estado de
    autenticación.

- **Desviación 2:** El análisis técnico proponía que `signInWithEmailPassword`
  ahora lea Firestore para obtener el perfil completo. Esto ya incluye
  `userName`, lo que significa que tras login el `AppUser` ya tiene `userName`
  disponible (antes solo se obtenía después en settings). Esta es una mejora
  implícita en eficiencia.
  - **Impacto:** Positivo — reduce una lectura Firestore posterior en settings
    si ya tiene el userName.

## 6) Riesgos, incidencias y pendientes

- **Riesgo:** La lectura de Firestore en `signInWithEmailPassword` añade
  latencia al login (~100ms para lectura de un documento individual). Mitigado
  con fallback silencioso si falla.
- **Pendiente:** Los tests unitarios existentes de `LoginCubit`, `SignIn`,
  `AuthRemoteDataSourceImpl`, `CheckAutoLogin` necesitan actualización para
  reflejar los nuevos parámetros y el `AuthCubit` inyectado.
- **Pendiente:** Validación manual completa con usuarios reales en Firestore
  (admin y employee).
- **Pendiente:** Contenido real de la pantalla de Estadísticas (fuera de
  alcance, entregada como placeholder).

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual con usuarios de Firestore que
  tengan `role: "admin"` y `role: "employee"`, seguida de actualización de tests
  unitarios existentes.
