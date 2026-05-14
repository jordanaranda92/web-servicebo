# Technical Analysis: Pantalla de Ajustes

- **Fecha:** 2026-05-06
- **Identificador:** settings-page
- **Fuente:** docs/functional-analysis/2026-05-06-settings-page.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Expandir la feature `settings` (actualmente solo
  `presentation/pages/settings_page.dart` placeholder) con capas completas de
  Clean Architecture: `domain/`, `data/` y `presentation/` (BLoC, widgets).
- Se añadirán **3 Cubits** independientes (uno por sección de ajustes) que
  gestionan estado local, persistencia y verificación de conexión.
- Persistencia local con `SharedPreferences` (ya disponible) para valores no
  sensibles (carpeta de trabajo, subdominio, carpeta Google Drive) y
  `flutter_secure_storage` para credenciales sensibles (API token de
  FacturaDirecta, tokens OAuth de Google).
- Nuevas dependencias: `file_picker` (selector de directorio nativo),
  `flutter_secure_storage` (almacenamiento seguro),
  `googleapis`/`googleapis_auth` + `extension_google_sign_in_as_googleapis_auth`
  o `desktop_webview_auth` (OAuth Google + Drive API). La integración completa
  de Google Drive (OAuth + folder picker) tiene complejidad significativa; se
  propone una implementación por fases.
- Verificación de conexión con FacturaDirecta: petición HTTP GET con Basic Auth
  vía `Dio` (ya en proyecto).
- Riesgo general estimado: **medio** — la sección de carpeta de trabajo y
  FacturaDirecta son directas; la integración OAuth de Google Drive en desktop
  eleva la complejidad.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con BLoC/Cubit, GetIt y fpdart.
- Patrón de referencia: feature `locale` — `domain/repositories/` (contrato) →
  `data/repositories/` (implementación con SharedPreferences) →
  `presentation/bloc/` (Cubit) → módulo DI en `app/di/modules/`.

### Estructura actual de `settings`

```
lib/features/settings/
└── presentation/
    └── pages/
        └── settings_page.dart   ← placeholder con ícono + texto
```

No existen capas `data/` ni `domain/`.

### Módulos y capas relevantes

- `lib/app/di/injection.dart` — orquestador de DI; invoca módulos por feature.
- `lib/app/di/modules/core_module.dart` — registra `SharedPreferences` y
  `AppLogger`.
- `lib/core/error/failure.dart` — `Failure` base + subclases (`NetworkFailure`,
  `ServerFailure`, `CacheFailure`).
- `lib/core/error/exceptions.dart` — excepciones técnicas (`ServerException`,
  `CacheException`, etc.).
- `lib/core/usecase/usecase.dart` — contrato `UseCase<Type, Params>` con
  `Either<Failure, T>`.
- `lib/app/localization/l10n/app_es.arb` — único fichero ARB (solo español).
- `lib/features/home/presentation/pages/side_menu_shell.dart` — `IndexedStack`
  con `SettingsPage` en índice 3; no requiere cambios de navegación.

### Dependencias existentes relevantes

- `shared_preferences: ^2.5.0` — ya registrado como singleton en GetIt.
- `dio: ^5.9.2` — cliente HTTP disponible.
- `flutter_bloc: ^9.0.0`, `equatable: ^2.0.7`, `fpdart: ^1.2.0`.

### Restricciones

- App de escritorio (macOS/Windows): los paquetes elegidos deben soportar
  desktop.
- i18n obligatoria: todos los textos visibles deben ir a `app_es.arb`.
- Design tokens del tema: no hardcodear colores/tamaños; usar
  `Theme.of(context)` y constantes de `theme_constants.dart`.

## 3) Objetivo técnico

- **Qué debe cambiar:** La feature `settings` pasa de placeholder a
  funcionalidad completa con tres secciones de configuración persistidas
  localmente.
- **Resultado técnico:** Tres Cubits funcionales, repositorios con persistencia,
  datasources locales, y una UI scrollable con secciones diferenciadas, todo
  inyectado vía GetIt.
- **Limitaciones a respetar:** No implementar lógica de negocio de otras
  features (generación de Excel, subida a Drive, volcado a FacturaDirecta). Solo
  persistir y validar la configuración; exponer contratos que futuras features
  consumirán.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Tres subsistemas independientes dentro de la feature `settings`, cada uno con su
propio flujo Cubit → Repository → DataSource. Esto permite:

- Guardar cada sección de forma independiente (RF-17).
- Testear aisladamente.
- Reutilizar los repositorios desde otras features vía GetIt.

### Componentes / módulos / servicios afectados

#### Domain layer

**Entities:**

- `WorkFolderConfig` — entidad con `path: String` y `isValid: bool`.
- `GoogleDriveConfig` — entidad con `accountEmail: String?`,
  `folderId: String?`, `folderName: String?`, `isConnected: bool`.
- `FacturaDirectaConfig` — entidad con `subdomain: String`, `apiToken: String`,
  `isConnected: bool`.

**Repository contracts:**

- `SettingsRepository` — contrato unificado con métodos agrupados:
  ```
  // Carpeta de trabajo
  Future<Either<Failure, WorkFolderConfig?>> getWorkFolder();
  Future<Either<Failure, Unit>> saveWorkFolder(String path);
  Future<Either<Failure, Unit>> clearWorkFolder();

  // Google Drive
  Future<Either<Failure, GoogleDriveConfig?>> getGoogleDriveConfig();
  Future<Either<Failure, Unit>> saveGoogleDriveConfig(GoogleDriveConfig config);
  Future<Either<Failure, Unit>> clearGoogleDriveConfig();

  // FacturaDirecta
  Future<Either<Failure, FacturaDirectaConfig?>> getFacturaDirectaConfig();
  Future<Either<Failure, Unit>> saveFacturaDirectaConfig(FacturaDirectaConfig config);
  Future<Either<Failure, Unit>> clearFacturaDirectaConfig();
  Future<Either<Failure, bool>> verifyFacturaDirectaConnection(FacturaDirectaConfig config);
  ```

> **Alternativa considerada:** tres repositorios separados. Se descarta por
> ahora: los tres subsistemas comparten el mismo contexto de feature y el
> repositorio único evita proliferación. Si crece mucho, se puede refactorizar.

#### Data layer

**Local DataSource (`SettingsLocalDataSource`):**

- Lectura/escritura en `SharedPreferences` para datos no sensibles:
  `workFolderPath`, `googleDriveFolderId`, `googleDriveFolderName`,
  `googleDriveAccountEmail`, `facturaDirectaSubdomain`.
- Lectura/escritura en `FlutterSecureStorage` para datos sensibles:
  `facturaDirectaApiToken`, `googleDriveOAuthCredentials`.

**Remote DataSource (`FacturaDirectaRemoteDataSource`):**

- Método `verifyConnection(subdomain, apiToken)` → HTTP GET a
  `https://{subdomain}.facturadirecta.com/api` con Basic Auth
  (`Authorization: Basic base64(apiToken:)`).
- Usa `Dio` ya disponible en el proyecto.

**RepositoryImpl (`SettingsRepositoryImpl`):**

- Inyecta `SettingsLocalDataSource` y `FacturaDirectaRemoteDataSource`.
- Mapea excepciones (`CacheException`, `ServerException`, `NetworkException`) a
  `Failure`s.

#### Presentation layer

**Cubits (uno por sección, registrados como `registerFactory` por ser estado de
pantalla):**

1. `WorkFolderCubit` + `WorkFolderState`:
   - Estados: `initial`, `configured(path, isValid)`, `error(message)`.
   - Acciones: `loadSaved()`, `pickFolder()`, `clearFolder()`.
   - `pickFolder()` invoca `file_picker` para abrir el selector de directorio
     nativo.

2. `GoogleDriveCubit` + `GoogleDriveState`:
   - Estados: `disconnected`, `connecting`, `connected(email, folderName)`,
     `error(message)`.
   - Acciones: `loadSaved()`, `connect()`, `selectFolder()`, `disconnect()`.
   - La integración OAuth + folder picker se implementará en una fase posterior
     (ver sección 6). En la primera fase, se deja la sección con estado
     "próximamente" o un placeholder funcional con campos manuales simples
     (folder ID).

3. `FacturaDirectaCubit` + `FacturaDirectaState`:
   - Estados: `disconnected`, `editing(subdomain, apiToken)`,
     `saved(subdomain)`, `verifying`, `verified(success)`, `error(message)`.
   - Acciones: `loadSaved()`, `save(subdomain, apiToken)`, `verifyConnection()`,
     `disconnect()`.

**Widgets:**

- `SettingsPage` — reescritura completa: `SingleChildScrollView` con tres
  secciones (`SettingsSection` wrapper reutilizable con título + contenido).
- `WorkFolderSection` — muestra ruta o estado vacío, botón para seleccionar
  carpeta, botón para limpiar.
- `GoogleDriveSection` — muestra estado de conexión, botón conectar/desconectar,
  carpeta seleccionada.
- `FacturaDirectaSection` — formulario con `TextField` para subdominio y API
  token (obscureText), botones Guardar / Verificar / Desconectar.
- `SettingsSection` — widget wrapper reutilizable (`Card` con `Column`, título y
  child).

### Contratos e interfaces

- `SettingsRepository` (abstracto en `domain/repositories/`): contrato que la
  capa `data/` implementa y `presentation/` consume.
- `SettingsLocalDataSource` (abstracto en `data/datasources/local/`): contrato
  para persistencia local.
- `FacturaDirectaRemoteDataSource` (abstracto en `data/datasources/remote/`):
  contrato para verificación HTTP.

### Flujo de datos o de control

```
UI (SettingsPage)
  → Cubit (WorkFolderCubit / GoogleDriveCubit / FacturaDirectaCubit)
    → SettingsRepository (contrato en domain/)
      → SettingsRepositoryImpl (en data/)
        → SettingsLocalDataSource (SharedPreferences + SecureStorage)
        → FacturaDirectaRemoteDataSource (Dio HTTP)
```

Para la selección de carpeta:

```
UI → WorkFolderCubit.pickFolder()
  → FilePicker.platform.getDirectoryPath()  (invocado desde el Cubit)
  → SettingsRepository.saveWorkFolder(path)
  → SettingsLocalDataSource.saveWorkFolderPath(path)
```

> **Nota:** `file_picker` se invoca desde el Cubit (no desde la UI directamente)
> para mantener testabilidad. Se inyectará un wrapper abstracto si se desea
> mockear en tests, pero dado que es una interacción de sistema simple, se puede
> aceptar la dependencia directa en el Cubit con un `@visibleForTesting` setter.

### Gestión de errores y validaciones

- **Validaciones en Cubit** (antes de llamar al repositorio):
  - Carpeta de trabajo: verificar que la ruta no esté vacía (el file picker ya
    garantiza esto).
  - FacturaDirecta: `subdomain` no vacío, `apiToken` no vacío.
  - Google Drive: carpeta seleccionada antes de guardar.
- **Errores de persistencia:** `CacheException` → `CacheFailure` → estado error
  en UI con mensaje i18n.
- **Errores de red (verificación FacturaDirecta):**
  - Respuesta 401 → credenciales inválidas.
  - Timeout / sin conexión → error de red.
  - Respuesta 2xx → conexión exitosa.
- **Carpeta inexistente:** Al cargar configuración guardada, verificar con
  `Directory(path).existsSync()`. Si no existe, emitir estado `configured` con
  `isValid: false` para que la UI muestre advertencia.

### Consideraciones de compatibilidad o migración

- **Sin migración de datos:** No hay configuración previa que migrar (feature
  nueva).
- **`file_picker` en desktop:** El paquete `file_picker` soporta macOS y
  Windows. En macOS requiere el entitlement
  `com.apple.security.files.user-selected.read-write` en el sandbox (si se usa
  sandbox; verificar `macos/Runner/*.entitlements`).
- **`flutter_secure_storage` en desktop:** Soporta macOS (Keychain) y Windows
  (Windows Credential Manager) a partir de versiones recientes.
- **Google Drive OAuth en desktop:** Requiere crear un proyecto en Google Cloud
  Console con OAuth client ID de tipo "Desktop app" (aún no existe; hay que
  crearlo). Cada usuario se autenticará con su propia cuenta de Google. El flujo
  OAuth en desktop usa un servidor local temporal (`loopback redirect`). Esto es
  la parte de mayor complejidad y se recomienda abordar en una segunda fase.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                               | Propósito                                            |
| --------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `lib/features/settings/domain/entities/work_folder_config.dart`                         | Entity para configuración de carpeta de trabajo      |
| `lib/features/settings/domain/entities/google_drive_config.dart`                        | Entity para configuración de Google Drive            |
| `lib/features/settings/domain/entities/factura_directa_config.dart`                     | Entity para configuración de FacturaDirecta          |
| `lib/features/settings/domain/repositories/settings_repository.dart`                    | Contrato del repositorio de settings                 |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`          | DataSource local (SharedPreferences + SecureStorage) |
| `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source.dart` | DataSource remoto para verificación FacturaDirecta   |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`                 | Implementación del repositorio                       |
| `lib/features/settings/presentation/bloc/work_folder_cubit.dart`                        | Cubit para sección carpeta de trabajo                |
| `lib/features/settings/presentation/bloc/work_folder_state.dart`                        | Estados del Cubit de carpeta de trabajo              |
| `lib/features/settings/presentation/bloc/google_drive_cubit.dart`                       | Cubit para sección Google Drive                      |
| `lib/features/settings/presentation/bloc/google_drive_state.dart`                       | Estados del Cubit de Google Drive                    |
| `lib/features/settings/presentation/bloc/factura_directa_cubit.dart`                    | Cubit para sección FacturaDirecta                    |
| `lib/features/settings/presentation/bloc/factura_directa_state.dart`                    | Estados del Cubit de FacturaDirecta                  |
| `lib/features/settings/presentation/widgets/settings_section.dart`                      | Widget wrapper reutilizable para cada sección        |
| `lib/features/settings/presentation/widgets/work_folder_section.dart`                   | Widget para la sección de carpeta de trabajo         |
| `lib/features/settings/presentation/widgets/google_drive_section.dart`                  | Widget para la sección de Google Drive               |
| `lib/features/settings/presentation/widgets/factura_directa_section.dart`               | Widget para la sección de FacturaDirecta             |
| `lib/app/di/modules/settings_module.dart`                                               | Módulo DI para la feature settings                   |
| `test/features/settings/...`                                                            | Tests unitarios para Cubits, Repository, DataSources |

### Artefactos a modificar

| Artefacto                                                     | Cambio esperado                                                                                                                    |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/settings/presentation/pages/settings_page.dart` | Reescribir: de placeholder a layout scrollable con tres BlocProvider + secciones                                                   |
| `lib/app/di/injection.dart`                                   | Añadir llamada a `registerSettingsModule(sl)`                                                                                      |
| `lib/app/localization/l10n/app_es.arb`                        | Añadir ~25-30 claves i18n para textos de la pantalla de Ajustes                                                                    |
| `pubspec.yaml`                                                | Añadir dependencias: `file_picker`, `flutter_secure_storage`                                                                       |
| `macos/Runner/DebugProfile.entitlements`                      | Añadir entitlements: `com.apple.security.files.user-selected.read-write` (file_picker) y `keychain-access-groups` (secure_storage) |
| `macos/Runner/Release.entitlements`                           | Ídem                                                                                                                               |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                                                              |
| --------- | ------------------------------------------------------------------- |
| Ninguno   | No se retira ningún artefacto; el placeholder se reescribe in-place |

## 6) Estrategia de implementación

### Fase 1 — Infraestructura base y carpeta de trabajo (complejidad: baja)

1. **Paso 1:** Añadir dependencias al `pubspec.yaml` (`file_picker`,
   `flutter_secure_storage`).
2. **Paso 2:** Crear entities en `domain/entities/` (`WorkFolderConfig`,
   `GoogleDriveConfig`, `FacturaDirectaConfig`).
3. **Paso 3:** Crear contrato `SettingsRepository` en `domain/repositories/`.
4. **Paso 4:** Crear `SettingsLocalDataSource` (contrato + implementación) en
   `data/datasources/local/`.
5. **Paso 5:** Crear `SettingsRepositoryImpl` en `data/repositories/`.
6. **Paso 6:** Crear `WorkFolderCubit` + `WorkFolderState` en
   `presentation/bloc/`.
7. **Paso 7:** Crear widget `SettingsSection` (wrapper) y `WorkFolderSection`.
8. **Paso 8:** Reescribir `SettingsPage` con layout scrollable y
   `WorkFolderSection`.
9. **Paso 9:** Crear `settings_module.dart` en DI y registrarlo en
   `injection.dart`.
10. **Paso 10:** Añadir claves i18n para la sección de carpeta de trabajo en
    `app_es.arb`.
11. **Paso 11:** Verificar entitlements de macOS para `file_picker`.
12. **Paso 12:** Tests unitarios para `WorkFolderCubit` y
    `SettingsRepositoryImpl` (parte carpeta).

### Fase 2 — FacturaDirecta (complejidad: baja-media)

13. **Paso 13:** Crear `FacturaDirectaRemoteDataSource` (contrato +
    implementación con Dio).
14. **Paso 14:** Extender `SettingsRepositoryImpl` con lógica de FacturaDirecta
    (save, load, verify, clear).
15. **Paso 15:** Crear `FacturaDirectaCubit` + `FacturaDirectaState`.
16. **Paso 16:** Crear widget `FacturaDirectaSection` (formulario con
    subdominio + API token).
17. **Paso 17:** Integrar `FacturaDirectaSection` en `SettingsPage`.
18. **Paso 18:** Añadir claves i18n para FacturaDirecta.
19. **Paso 19:** Tests unitarios para `FacturaDirectaCubit`,
    `FacturaDirectaRemoteDataSource`, y repositorio.

### Fase 3 — Google Drive (complejidad: alta)

20. **Paso 20:** Evaluar e integrar paquetes para OAuth desktop de Google
    (`googleapis_auth` con flujo loopback, o `desktop_webview_auth`).
21. **Paso 21:** Implementar wrapper para Google Drive API (listar carpetas,
    seleccionar carpeta).
22. **Paso 22:** Crear `GoogleDriveCubit` + `GoogleDriveState`.
23. **Paso 23:** Crear widget `GoogleDriveSection` (botón conectar, selector de
    carpeta, desconectar).
24. **Paso 24:** Integrar `GoogleDriveSection` en `SettingsPage`.
25. **Paso 25:** Añadir claves i18n para Google Drive.
26. **Paso 26:** Tests unitarios para `GoogleDriveCubit`.

### Orden recomendado

Fase 1 → Fase 2 → Fase 3 (secuencial). Las fases 1 y 2 pueden completarse de
forma rápida. La fase 3 requiere configuración en Google Cloud Console y
evaluación de paquetes desktop OAuth.

### Dependencias entre pasos

- Pasos 2-3 (entities + contrato) son prerequisito de todo lo demás.
- Pasos 4-5 (datasource + repo impl) son prerequisito de los Cubits.
- Paso 9 (DI) debe actualizarse al añadir cada Cubit nuevo.
- Paso 13 (remote datasource) es prerequisito del paso 15 (FacturaDirectaCubit).

### Puntos delicados

- **macOS entitlements (CONFIRMADO: sandbox activo):** La app usa sandbox de
  macOS. `file_picker` necesita
  `com.apple.security.files.user-selected.read-write` en ambos entitlements
  (`DebugProfile.entitlements` y `Release.entitlements`). Sin este entitlement,
  el selector de directorios fallará silenciosamente o lanzará error.
- **Google Drive OAuth en desktop:** No hay un paquete "estándar" consolidado
  para OAuth de Google en Flutter desktop. Opciones: `googleapis_auth` con
  servidor loopback local, webview, o `url_launcher` con redirect a `localhost`.
  Requiere prueba y evaluación.
- **SecureStorage en macOS (CONFIRMADO: sandbox activo):**
  `flutter_secure_storage` usa Keychain. Con sandbox activo necesita el
  entitlement `keychain-access-groups` en ambos entitlements.
- **Verificación de FacturaDirecta:** La API de FacturaDirecta usa Basic Auth
  donde el API token va como contraseña. El formato del header es
  `Authorization: Basic base64("apiToken:")` (con dos puntos después del token,
  sin usuario). Verificar el formato exacto con la documentación.

## 7) Estrategia de validación

### Verificación automática (tests unitarios)

- **Cubits:** Usar `bloc_test` para verificar transiciones de estado:
  - `WorkFolderCubit`: load → configured, pick → configured, clear → initial.
  - `FacturaDirectaCubit`: load → saved, save → saved, verify → verified/error,
    disconnect → disconnected.
  - `GoogleDriveCubit`: connect → connected, selectFolder → connected(folder),
    disconnect → disconnected.
- **SettingsRepositoryImpl:** Mockear datasources con `mocktail`; verificar
  mapeo exception → failure.
- **FacturaDirectaRemoteDataSource:** Mockear `Dio`; verificar manejo de
  respuestas 2xx, 401, timeout.

### Verificación manual

- Abrir pantalla de Ajustes → verificar que las tres secciones se renderizan.
- Seleccionar carpeta de trabajo → verificar que aparece la ruta.
- Cerrar y reabrir app → verificar que la ruta persiste.
- Eliminar carpeta del disco → reabrir → verificar que aparece advertencia.
- Configurar FacturaDirecta → guardar → verificar persistencia.
- Verificar conexión con credenciales válidas e inválidas.
- Desconectar FacturaDirecta → verificar que se limpia.
- (Fase 3) Conectar Google Drive → seleccionar carpeta → verificar.

### Escenarios a cubrir

- Estado inicial (sin configuración previa).
- Guardar y recuperar cada tipo de configuración.
- Cambiar configuración existente.
- Desconectar/limpiar cada sección.
- Errores de red al verificar conexión.
- Carpeta de trabajo eliminada entre sesiones.
- Credenciales vacías (validación de formulario).

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                             | Probabilidad | Impacto                                                |
| ------------------------------------------------------------------ | ------------ | ------------------------------------------------------ |
| `file_picker` no funciona correctamente en macOS sandbox           | Media        | Alto — bloquea sección 1                               |
| OAuth de Google Drive en desktop sin paquete maduro                | Alta         | Alto — bloquea sección 2 (fase 3)                      |
| `flutter_secure_storage` requiere configuración adicional en macOS | Baja         | Medio — workaround con SharedPreferences temporalmente |
| API de FacturaDirecta con formato de auth diferente al esperado    | Baja         | Bajo — ajustar header en datasource                    |

### Impacto potencial

- La feature `settings` pasa de placeholder a funcionalidad real. No afecta a
  ningún flujo existente.
- El `SettingsRepository` expone contratos que futuras features consumirán
  (generación Excel, backup Drive, volcado FacturaDirecta).
- Se añaden dos nuevas dependencias al proyecto (`file_picker`,
  `flutter_secure_storage`).

### Mitigación

- Probar `file_picker` en macOS con y sin sandbox antes de integrar la UI
  completa.
- Para Google Drive (fase 3), hacer spike técnico antes de comprometerse con un
  paquete.
- Si `flutter_secure_storage` da problemas en desktop, usar `SharedPreferences`
  temporalmente con un TODO de migración.

### Plan de rollback

- Los cambios son aditivos (archivos nuevos + modificación de placeholder). Para
  rollback basta con revertir los commits.
- Si la fase 3 (Google Drive) se bloquea, las fases 1 y 2 son independientes y
  funcionales por sí solas. La sección Google Drive puede quedarse con un
  placeholder "próximamente".

## 9) Suposiciones

- **S-01:** La API de FacturaDirecta acepta HTTP Basic Auth con el API token
  como contraseña y campo de usuario vacío (formato: `base64(":apiToken")` o
  `base64("apiToken:")`). A verificar con prueba real.
- **S-02:** `file_picker` ^8.x soporta `getDirectoryPath()` en macOS y Windows
  sin problemas conocidos.
- **S-03:** La app usa sandbox en macOS (confirmado). Se deben añadir los
  entitlements necesarios para `file_picker` y `flutter_secure_storage`.
- **S-04:** Para la fase 3, cada usuario autenticará con su propia cuenta de
  Google (no una cuenta genérica de la app). Se necesitará crear un proyecto en
  Google Cloud Console para obtener el OAuth client ID de tipo "Desktop app",
  pero la autenticación es individual por usuario. Se usará `googleapis_auth`
  con flujo loopback (servidor HTTP local temporal). Requiere que no haya
  firewall bloqueando localhost.
- **S-05:** Los tres Cubits de settings son de scope de pantalla (no globales),
  por lo que se registran con `registerFactory`. Sin embargo, el
  `SettingsRepository` sí es singleton para poder ser consumido desde otras
  features.

## 10) Preguntas abiertas

- **PA-01:** ~~¿La app de macOS usa sandbox?~~ → **Sí, confirmado.** Se añadirán
  los entitlements necesarios.
- **PA-02:** ~~¿Se dispone de credenciales de prueba de FacturaDirecta?~~ → **No
  todavía.** El formato de Basic Auth se implementará según la documentación
  conocida y se ajustará cuando se disponga de credenciales reales.
- **PA-03:** ~~¿Existe proyecto en Google Cloud Console?~~ → **No existe.**
  Habrá que crearlo. Cada usuario usará su propia cuenta de Google Drive (no una
  genérica). El proyecto de Cloud Console solo proporciona el OAuth client ID;
  la autenticación es individual por usuario.

## 11) Notas para implementación

- **Respetar patrón existente:** Seguir la estructura de la feature `locale`
  como referencia (contrato en domain → impl en data → Cubit en presentation →
  módulo DI).
- **Cubits con `registerFactory`:** Los Cubits de settings son de pantalla, no
  globales. Pero el repositorio es `registerLazySingleton` para que otras
  features puedan inyectarlo.
- **i18n:** Todos los textos nuevos van a `app_es.arb`. No hardcodear strings.
- **Theme tokens:** Usar `AppSpacing`, `AppRadii`, `AppIconSizes` y
  `colorScheme`/`textTheme` de `Theme.of(context)`. No hardcodear colores ni
  tamaños.
- **`SettingsPage` dentro de `IndexedStack`:** La página ya está integrada en el
  menú lateral (índice 3). No tocar navegación ni `SideMenuShell`.
- **API token obscurecido:** El campo de API token debe usar `obscureText: true`
  en el `TextField`.
- **Carpeta inexistente:** Al cargar `WorkFolderConfig`, verificar con
  `Directory(path).existsSync()` y marcar `isValid` en consecuencia. Solo
  disponible en desktop (dart:io).
- **Fase 3 desacoplable:** Si Google Drive se retrasa, la `GoogleDriveSection`
  puede mostrar un placeholder "próximamente" sin bloquear el resto.
- **Secuencia sugerida:** Fase 1 completa (infraestructura + carpeta) → Fase 2
  (FacturaDirecta) → Fase 3 (Google Drive). Cada fase es un conjunto de commits
  independiente y desplegable.
- **Estado: Listo para implementación**
