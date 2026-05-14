# Implementation Report: Pantalla de Ajustes

- **Fecha:** 2026-05-06
- **Identificador:** settings-page
- **Plan técnico:** docs/technical-analysis/2026-05-06-settings-page.md
- **Estado:** Completed with warnings

## 1) Resumen

Se ha implementado la pantalla de Ajustes completa con tres secciones (Carpeta
de trabajo, Google Drive, FacturaDirecta), reemplazando el placeholder
existente. Se han completado las fases 1 y 2 del plan técnico. La fase 3
(integración OAuth de Google Drive) queda pendiente con un placeholder visual
"próximamente" según lo previsto en el plan.

## 2) Alcance ejecutado

- **Fase 1 — Carpeta de trabajo:** Implementada al 100%. Selector de directorio
  nativo vía `file_picker`, persistencia con SharedPreferences, detección de
  carpeta inexistente, UI completa con estados vacío/configurado/inválido/error.
- **Fase 2 — FacturaDirecta:** Implementada al 100%. Formulario con subdominio y
  API token, persistencia (subdominio en SharedPreferences, API token en
  FlutterSecureStorage), verificación de conexión HTTP con Basic Auth vía Dio,
  estados guardado/verificando/verificado/error/desconectado.
- **Fase 3 — Google Drive:** Placeholder funcional implementado. Cubit con
  estados y acciones de carga/desconexión, sección UI con mensaje
  "próximamente". La integración OAuth real queda pendiente.
- **Infraestructura transversal:** Entities, repositorio unificado, datasources,
  módulo DI, i18n, entitlements macOS, tests unitarios.

## 3) Artefactos tocados

### Creados

- `lib/features/settings/domain/entities/work_folder_config.dart`
- `lib/features/settings/domain/entities/google_drive_config.dart`
- `lib/features/settings/domain/entities/factura_directa_config.dart`
- `lib/features/settings/domain/repositories/settings_repository.dart`
- `lib/features/settings/data/datasources/local/settings_local_data_source.dart`
- `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`
- `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source.dart`
- `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source_impl.dart`
- `lib/features/settings/data/repositories/settings_repository_impl.dart`
- `lib/features/settings/presentation/bloc/work_folder_cubit.dart`
- `lib/features/settings/presentation/bloc/work_folder_state.dart`
- `lib/features/settings/presentation/bloc/factura_directa_cubit.dart`
- `lib/features/settings/presentation/bloc/factura_directa_state.dart`
- `lib/features/settings/presentation/bloc/google_drive_cubit.dart`
- `lib/features/settings/presentation/bloc/google_drive_state.dart`
- `lib/features/settings/presentation/widgets/settings_section.dart`
- `lib/features/settings/presentation/widgets/work_folder_section.dart`
- `lib/features/settings/presentation/widgets/factura_directa_section.dart`
- `lib/features/settings/presentation/widgets/google_drive_section.dart`
- `lib/app/di/modules/settings_module.dart`
- `test/features/settings/presentation/bloc/work_folder_cubit_test.dart`
- `test/features/settings/presentation/bloc/factura_directa_cubit_test.dart`
- `test/features/settings/data/repositories/settings_repository_impl_test.dart`

### Modificados

- `lib/features/settings/presentation/pages/settings_page.dart` — Reescrito
  completamente de placeholder a layout funcional con MultiBlocProvider y tres
  secciones
- `lib/app/di/injection.dart` — Añadida importación y llamada a
  `registerSettingsModule(sl)`
- `lib/app/localization/l10n/app_es.arb` — Añadidas 28 claves i18n para la
  pantalla de Ajustes
- `pubspec.yaml` — Añadidas dependencias `file_picker: ^8.3.7` y
  `flutter_secure_storage: ^9.2.4`
- `macos/Runner/DebugProfile.entitlements` — Añadidos entitlements:
  `network.client`, `files.user-selected.read-write`, `keychain-access-groups`
- `macos/Runner/Release.entitlements` — Añadidos entitlements: `network.client`,
  `files.user-selected.read-write`, `keychain-access-groups`

### Retirados o reemplazados

- Ninguno (el placeholder se reescribió in-place)

## 4) Validación ejecutada

### Automática

- **dart analyze:** 0 issues en `lib/features/settings/` y `lib/app/di/`
- **Tests unitarios:** 32 tests ejecutados, 32 pasados, 0 fallos
  - `work_folder_cubit_test.dart` — 5 tests (loadSaved con carpeta
    válida/inválida/vacía/error, clearFolder éxito/error)
  - `factura_directa_cubit_test.dart` — 10 tests (loadSaved, save con
    validaciones, verifyConnection éxito/error/campos vacíos, disconnect)
  - `settings_repository_impl_test.dart` — 9 tests (getWorkFolder,
    saveWorkFolder, clearWorkFolder, getFacturaDirectaConfig,
    saveFacturaDirectaConfig, verifyFacturaDirectaConnection con
    éxito/ServerException/NetworkException)

### Manual pendiente

- Ejecución de la app en macOS para verificar:
  - Selector de directorio nativo
  - Persistencia entre sesiones
  - Entitlements de sandbox funcionando correctamente
  - Verificación de conexión con credenciales reales de FacturaDirecta (no
    disponibles aún)

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** Se añadió `com.apple.security.network.client` a los
  entitlements de macOS. Este entitlement no estaba explícitamente mencionado en
  el análisis técnico pero es necesario para que Dio pueda hacer llamadas HTTP
  salientes desde el sandbox de macOS.
  - **Justificación:** Sin este entitlement, la verificación de conexión con
    FacturaDirecta fallaría en macOS sandbox.
  - **Impacto:** Ninguno negativo; es un requisito técnico del sandbox.

- **Desviación 2:** El datasource local se dividió en dos archivos (contrato
  `settings_local_data_source.dart` + implementación
  `settings_local_data_source_impl.dart`) en lugar de un solo archivo como hacía
  la feature `locale`.
  - **Justificación:** El datasource es más complejo (SharedPreferences +
    SecureStorage) y tener contrato separado facilita el testing con mocks.
  - **Impacto:** Positivo para testabilidad, sin impacto funcional.

## 6) Riesgos, incidencias y pendientes

### Riesgos

- **Entitlements de macOS:** Los `keychain-access-groups` usan
  `$(AppIdentifierPrefix)com.servicebo.app`. Si el bundle identifier real de la
  app es diferente, habrá que ajustarlo.
- **FacturaDirecta Basic Auth:** El formato exacto de autenticación (`apiToken:`
  vs `:apiToken`) no se ha podido verificar sin credenciales reales. Puede
  requerir ajuste.

### Incidencias

- Ninguna durante la implementación.

### Pendientes

- **Fase 3 — Google Drive OAuth:** Integración completa con la API de Google
  Drive (autenticación OAuth, selector de carpetas). Requiere crear proyecto en
  Google Cloud Console y evaluar paquetes desktop.
- **Verificación manual en macOS:** Probar selector de directorio, persistencia
  y entitlements en una ejecución real.
- **Test con credenciales reales de FacturaDirecta:** Validar formato de Basic
  Auth cuando se disponga de credenciales.
- **Tests de WorkFolderCubit.pickFolder():** No se incluyeron tests para
  `pickFolder()` porque depende directamente de `FilePicker.platform` que
  requiere un wrapper mockeable para testear. Pendiente de evaluar si se añade
  dicho wrapper.

## 7) Resultado final

- Estado final: ⚠️ Completado con warnings
  - Fases 1 y 2 completadas al 100%
  - Fase 3 (Google Drive) como placeholder según lo previsto
  - Pendiente verificación manual en macOS y test con credenciales reales
- Siguiente paso recomendado: validación manual ejecutando la app en macOS →
  ajuste de bundle identifier si necesario → implementar Fase 3 cuando se
  disponga del proyecto de Google Cloud Console
