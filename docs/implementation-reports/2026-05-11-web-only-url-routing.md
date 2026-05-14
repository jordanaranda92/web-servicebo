# Implementation Report: Web-only + URL-based Navigation

- **Fecha:** 2026-05-11
- **Identificador:** web-only-url-routing
- **Fuente:** docs/technical-analysis/2026-05-11-web-only-url-routing.md
- **Estado:** Completed with warnings

## 1) Resumen

Se ha implementado la migración completa de la app Servicebo a plataforma web
exclusiva con navegación declarativa basada en URLs usando `go_router`. Se
eliminaron las plataformas Android, macOS y Windows, se reemplazó el sistema de
navegación imperativo (`Navigator` + `SideMenuCubit.selectItem`) por rutas
declarativas con `GoRouter` y `ShellRoute`, y se simplificaron los componentes
afectados.

## 2) Alcance ejecutado

- ✅ Eliminación de plataformas no-web (android/, macos/, windows/,
  servicebo.iml)
- ✅ Simplificación de `firebase_options.dart` a web-only
- ✅ Adición de `go_router ^14.8.1` y `flutter_web_plugins`
- ✅ Creación del router declarativo con `GoRouter`, `ShellRoute`, auth
  redirect, 404
- ✅ Refactorización de `SideMenuShell` para derivar índice desde URL
- ✅ Simplificación de `SideMenuCubit`/`SideMenuState` (solo `isExpanded`)
- ✅ Conversión de `ClientsPage` a vista de solo lista con navegación go_router
- ✅ Conversión de `ClientDetailPage` a página standalone con resolución de
  cliente
- ✅ Conversión de `ClientEditPage` a página standalone con `NavigationGuard`
- ✅ Creación de `NotFoundPage` (404)
- ✅ Migración de `MainApp` a `MaterialApp.router`
- ✅ Migración de `LoginPage` y `SettingsPage` a `context.go()`
- ✅ Eliminación de dependencias obsoletas (`flutter_native_splash`,
  `desktop_multi_window`)
- ✅ Limpieza de `HomePage`, `OrdersHistoryPage`, `OrdersTodayPage`
- ✅ Actualización de `firebase.json` (hosting + rewrites SPA + eliminación
  macOS)
- ✅ Actualización de tests de `SideMenuCubit`
- ✅ Adición de claves i18n: `notFoundMessage`, `notFoundGoHome`,
  `clientNotFoundMessage`, `clientNotFoundGoBack`, `clientSaveSuccess`

## 3) Artefactos tocados

### Creados

- `lib/core/presentation/pages/not_found_page.dart`

### Modificados

- `pubspec.yaml` — eliminado `flutter_native_splash`, añadido `go_router`,
  `flutter_web_plugins`
- `lib/firebase_options.dart` — simplificado a web-only
- `lib/main.dart` — `MaterialApp.router`, `usePathUrlStrategy()`, eliminado
  splash/orientation
- `lib/app/router/router.dart` — reescrito completo con GoRouter
- `lib/app/localization/l10n/app_es.arb` — 5 nuevas claves i18n
- `lib/features/home/presentation/pages/side_menu_shell.dart` — recibe `child`,
  deriva índice de URL
- `lib/features/home/presentation/bloc/side_menu_cubit.dart` — eliminado
  `selectItem`
- `lib/features/home/presentation/bloc/side_menu_state.dart` — eliminado
  `selectedIndex`
- `lib/features/home/presentation/pages/home_page.dart` — eliminado listener de
  menú, go_router para invoices
- `lib/features/orders_history/presentation/pages/orders_history_page.dart` —
  simplificado a StatelessWidget
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  eliminado listener, go_router, eliminado dart:io
- `lib/features/clients/presentation/pages/clients_page.dart` — solo lista,
  go_router navigation
- `lib/features/clients/presentation/pages/client_detail_page.dart` — standalone
  con resolución de cliente
- `lib/features/clients/presentation/pages/client_edit_page.dart` — standalone
  con NavigationGuard
- `lib/features/auth/presentation/pages/login_page.dart` — `context.go()`
- `lib/features/settings/presentation/pages/settings_page.dart` — `context.go()`
- `firebase.json` — hosting config, eliminado macOS, SPA rewrites
- `test/features/home/presentation/bloc/side_menu_cubit_test.dart` — adaptado a
  nuevo estado

### Retirados o reemplazados

- `android/` — directorio completo eliminado
- `macos/` — directorio completo eliminado
- `windows/` — directorio completo eliminado
- `servicebo.iml` — eliminado

## 4) Validación ejecutada

- `flutter pub get` — ✅ exitoso
- `flutter analyze` — ✅ 1 info pre-existente (no relacionado), 0 errores
- Tests de `SideMenuCubit` — adaptados al nuevo estado simplificado

### Incidencias encontradas y resolución

- **Duplicate `initState` en `client_detail_page.dart`**: se eliminó el
  `initState` residual del widget original
- **`widget.shippingMethods` → `_shippingMethods`**: referencia obsoleta
  corregida
- **`flutter_native_splash` sin usar**: eliminada de pubspec tras quitar la
  referencia en main.dart
- **`dart:io` en `orders_today_page.dart`**: eliminada rama no-web con
  `File.writeAsBytes`, mantenida solo `_downloadOnWeb`
- **`flutter_web_plugins` no declarada**: añadida como dependencia SDK en
  pubspec

## 5) Desviaciones respecto al análisis técnico

- **OrdersHistoryPage convertida a StatelessWidget**: el análisis no lo
  especificaba, pero al eliminar el listener de `SideMenuCubit` (ya innecesario
  con rebuild por navegación), el estado mutable quedó vacío. Impacto: ninguno
  funcional.
- **Eliminación de `_cachedCategories` y `_cachedShippingMethods` en
  ClientsPage**: ya no necesarios al delegar detalle/edición a páginas
  independientes que cargan sus propias dependencias.
- **Resolución de cliente en deep link via `cubit.stream`**: el análisis técnico
  sugería `fetchClientsOnce` que no existía en el cubit. Se usó el stream
  existente (`watchClientsStream` + `await for`) en su lugar. Impacto:
  equivalente funcionalmente.
- **`clientSaveSuccess` en lugar de `settingsSavedMessage`**: se creó una clave
  i18n específica para el contexto de clientes.

## 6) Riesgos, incidencias y pendientes

- **⚠️ `flutter build web` no ejecutado**: se validó con `flutter analyze` pero
  no se ejecutó el build completo. Se recomienda ejecutar antes de deploy.
- **⚠️ Tests de integración/widget**: no existen tests de widget para las
  páginas modificadas. El routing y la navegación solo se validan por análisis
  estático.
- **⚠️ `file_picker` en pubspec**: sigue como dependencia aunque su uso en
  `orders_today_page.dart` se redujo. Verificar si se usa en otros archivos.
- **TODO**: Verificar que `GetClientFdData` sigue importado correctamente en
  `client_detail_page.dart` (se usa para cargar datos de FacturaDirecta en deep
  link).

## 7) Resultado final

- Estado final: ⚠️ Completado con warnings
- Siguiente paso recomendado: ejecutar `flutter build web` para validar
  compilación completa, realizar prueba manual de navegación (deep links, back,
  guard de cambios sin guardar)
