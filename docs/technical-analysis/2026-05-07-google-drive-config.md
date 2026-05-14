# Technical Analysis: Configuración de acceso a Google Drive para Google Sheets

- **Fecha:** 2026-05-07
- **Identificador:** google-drive-config
- **Fuente:** docs/functional-analysis/2026-05-07-google-drive-config.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Integrar Google OAuth 2.0 y Google Drive API en la feature `settings` para
  permitir autenticación, navegación de carpetas y detección de Google Sheets.
- Los tokens OAuth (access + refresh) se almacenarán en `FlutterSecureStorage`
  (ya disponible como dependencia). Los metadatos de configuración (folder ID,
  email, IDs de subcarpetas) se almacenarán en `SharedPreferences` (ya
  disponible).
- Se introduce un nuevo datasource remoto `GoogleDriveRemoteDataSource` para
  encapsular todas las llamadas a las APIs de Google (Drive + Sheets).
- Se amplían la entidad `GoogleDriveConfig`, el repositorio, el Cubit y los
  widgets de la sección Google Drive existente.
- **Nuevas dependencias:** `googleapis` (cliente Dart para Google APIs),
  `googleapis_auth` (autenticación OAuth 2.0 para APIs de Google),
  `url_launcher` (para abrir el navegador en el flujo OAuth de escritorio).
- Riesgo general estimado: **medio** — la complejidad principal reside en el
  flujo OAuth 2.0 para escritorio y la gestión del ciclo de vida de los tokens.

## 2) Contexto técnico observado

### Arquitectura y patrones

- Clean Architecture feature-first con BLoC/Cubit, GetIt y fpdart.
- Patrón DataSource (local/remote) → Repository → Cubit → Widget.
- `Either<Failure, T>` para la gestión de errores en el dominio.
- Excepciones tipadas (`AppException` subclasses) en la capa data, capturadas y
  convertidas a `Failure` en el repository.

### Módulos relevantes

- **Feature `settings`:** ya tiene las 3 capas (data/domain/presentation)
  implementadas. La sección Google Drive tiene un Cubit con `loadSaved()` y
  `disconnect()` funcionales, y un TODO para `connect()` y `selectFolder()`.
- **`SettingsLocalDataSource`:** persiste config de Google Drive (folderId,
  folderName, accountEmail) en SharedPreferences. No almacena tokens OAuth.
- **`SettingsRepository`:** orquesta local data source + remote data source
  (FacturaDirecta). No tiene remote data source para Google Drive.
- **`GoogleDriveConfig` (entidad):** solo tiene `accountEmail`, `folderId`,
  `folderName`. No modela tokens, subcarpetas ni resumen de contenido.
- **`GoogleDriveState`:** tiene 3 estados (Disconnected, Connected, Error).
  Connected solo expone email, folderName, folderId. No modela estados
  intermedios (autenticando, seleccionando carpeta, verificando).
- **`GoogleDriveSection` (widget):** muestra estado conectado (email + folder) o
  un placeholder "coming soon". No tiene UI de conexión OAuth ni navegador de
  carpetas.

### Dependencias existentes

- `flutter_secure_storage: ^10.0.0` — para tokens sensibles
- `shared_preferences: ^2.5.5` — para config no sensible
- `dio: ^5.9.2` — cliente HTTP (no se usará para Google APIs; `googleapis`
  incluye su propio cliente HTTP)
- `connectivity_plus: ^7.1.1` — detección de conectividad
- `equatable: ^2.0.7` — value equality en entidades y estados

### Restricciones

- Aplicación de escritorio (macOS/Windows). El flujo OAuth debe funcionar sin
  `google_sign_in` (que no soporta bien escritorio). Se usará `googleapis_auth`
  con `clientViaUserConsent()` que abre el navegador.
- Se requiere un proyecto en Google Cloud Platform con OAuth 2.0 Client ID de
  tipo "Desktop application" y las APIs de Drive y Sheets habilitadas. Esto es
  un prerequisito de infraestructura.

## 3) Objetivo técnico

### Qué debe cambiar

- Añadir autenticación OAuth 2.0 con Google (obtención y renovación de tokens)
- Añadir navegación de carpetas de Google Drive (listado de carpetas, selección)
- Ampliar la entidad de dominio para modelar tokens, subcarpetas y resumen
- Ampliar el Cubit con estados intermedios y acciones (connect, selectFolder,
  refreshStatus)
- Ampliar el widget para reemplazar el placeholder "coming soon" por la UI
  funcional
- Persistir tokens OAuth en almacenamiento seguro

### Resultado técnico perseguido

- El `GoogleDriveCubit` puede ejecutar el flujo completo: autenticación →
  selección de carpeta → verificación de subcarpetas → resumen de contenido.
- La configuración persiste entre sesiones con renovación automática de tokens.
- Otros módulos (future: `orders_today`, `orders_history`) podrán inyectar el
  servicio de Google Drive y operar con los Sheets sin re-autenticarse.

### Limitaciones a respetar

- No se implementa lectura/escritura de Google Sheets (fuera de alcance)
- No se modifica la sección de carpeta de trabajo local ni FacturaDirecta
- No se añade UI de Google Drive fuera de la pantalla de Ajustes

## 4) Diseño técnico de la solución

### Enfoque propuesto

Introducir un servicio de autenticación Google (`GoogleAuthService`) en
`lib/core/` que encapsule el flujo OAuth y la gestión de tokens, y un datasource
remoto (`GoogleDriveRemoteDataSource`) en la feature `settings` para las
operaciones contra la API de Google Drive. El Cubit orquesta ambos a través del
repository.

**Flujo OAuth para escritorio:**

1. Se construye un `ClientId` con las credenciales del proyecto GCP.
2. Se llama a `clientViaUserConsent()` de `googleapis_auth` que abre el
   navegador del sistema para que el usuario autorice la app.
3. Se recibe un `AuthClient` con `AccessCredentials` (access token + refresh
   token + expiry + scopes).
4. Se persisten las credenciales en `FlutterSecureStorage` (serializadas como
   JSON).
5. En sesiones posteriores, se reconstruye el `AuthClient` desde las
   credenciales almacenadas usando `autoRefreshingClient()` de
   `googleapis_auth`.
6. Si el refresh falla (token revocado), se captura la excepción y se solicita
   re-autenticación.

### Componentes / módulos / servicios afectados

| Capa                  | Componente                            | Cambio                               |
| --------------------- | ------------------------------------- | ------------------------------------ |
| Core                  | `GoogleAuthService` (nuevo)           | Servicio de autenticación OAuth 2.0  |
| Data / DataSource     | `GoogleDriveRemoteDataSource` (nuevo) | Operaciones contra Drive API         |
| Data / DataSource     | `SettingsLocalDataSource` (modificar) | Persistencia de tokens OAuth         |
| Data / Repository     | `SettingsRepositoryImpl` (modificar)  | Integrar nuevo datasource            |
| Domain / Entity       | `GoogleDriveConfig` (modificar)       | Ampliar con tokens y subcarpetas     |
| Domain / Entity       | `DriveFolder` (nuevo)                 | Modelo de carpeta de Drive           |
| Domain / Entity       | `DriveFolderContent` (nuevo)          | Resumen de contenido detectado       |
| Domain / Repository   | `SettingsRepository` (modificar)      | Nuevos métodos para Google Drive     |
| Presentation / State  | `GoogleDriveState` (modificar)        | Estados intermedios                  |
| Presentation / Cubit  | `GoogleDriveCubit` (modificar)        | Acciones connect, selectFolder, etc. |
| Presentation / Widget | `GoogleDriveSection` (modificar)      | UI funcional completa                |
| Presentation / Widget | `DriveFolderPicker` (nuevo)           | Diálogo de navegación de carpetas    |
| DI                    | `settings_module.dart` (modificar)    | Registrar nuevas dependencias        |
| Config                | `app_config.dart` (modificar)         | Añadir Google OAuth Client ID/Secret |
| Config                | Environments (modificar)              | Proveer Client ID por entorno        |

### Contratos e interfaces

**`GoogleAuthService` (core)**

```dart
abstract class GoogleAuthService {
  /// Inicia el flujo OAuth. Devuelve las credenciales o un error.
  Future<Either<Failure, GoogleAuthCredentials>> signIn(List<String> scopes);

  /// Restaura un AuthClient desde credenciales almacenadas.
  Future<Either<Failure, AuthClient>> getAuthenticatedClient();

  /// Elimina las credenciales almacenadas.
  Future<Either<Failure, Unit>> signOut();

  /// Indica si hay credenciales almacenadas.
  Future<bool> isSignedIn();
}
```

**`GoogleDriveRemoteDataSource`**

```dart
abstract class GoogleDriveRemoteDataSource {
  /// Lista las subcarpetas de un folder dado.
  Future<List<DriveFolder>> listFolders(String parentFolderId);

  /// Lista los Google Sheets dentro de un folder.
  Future<List<DriveFileInfo>> listSpreadsheets(String folderId);

  /// Obtiene metadatos de un archivo por su ID.
  Future<DriveFileInfo> getFileInfo(String fileId);

  /// Verifica que un folder existe y es accesible.
  Future<bool> folderExists(String folderId);
}
```

**`SettingsLocalDataSource` (ampliación)**

```dart
// Nuevos métodos:
Future<void> saveGoogleAuthCredentials(String credentialsJson);
Future<String?> getGoogleAuthCredentials();
Future<void> clearGoogleAuthCredentials();

// Nuevos campos de config:
Future<void> saveGoogleDriveSubfolderIds({
  required String historicoId,
  required String plantillasId,
  required String internoId,
});
Map<String, String?>? getGoogleDriveSubfolderIds();
```

**`SettingsRepository` (ampliación)**

```dart
// Nuevos métodos:
Future<Either<Failure, GoogleDriveConfig>> connectGoogleDrive();
Future<Either<Failure, List<DriveFolder>>> listDriveFolders(String parentId);
Future<Either<Failure, DriveFolderContent>> verifyDriveFolder(String folderId);
Future<Either<Failure, Unit>> selectDriveFolder(DriveFolder folder);
```

### Flujo de datos o de control

```
[UI] → GoogleDriveCubit.connect()
  → SettingsRepository.connectGoogleDrive()
    → GoogleAuthService.signIn(scopes)
      → googleapis_auth.clientViaUserConsent() → browser OAuth
      → AccessCredentials (access_token, refresh_token, expiry)
    → SettingsLocalDataSource.saveGoogleAuthCredentials(json)
    → Return GoogleDriveConfig with email, no folder yet
  ← Cubit emits GoogleDriveAuthenticated(email)

[UI] → GoogleDriveCubit.selectFolder(folderId)
  → SettingsRepository.listDriveFolders(folderId)
    → GoogleDriveRemoteDataSource.listFolders(folderId)
      → DriveApi.files.list(q: mimeType=folder AND parents=folderId)
  ← Cubit emits FolderPickerLoaded(folders)

[UI] → GoogleDriveCubit.confirmFolder(folder)
  → SettingsRepository.verifyDriveFolder(folder.id)
    → GoogleDriveRemoteDataSource.listFolders(folder.id) → check historico/, plantillas/, interno/
    → GoogleDriveRemoteDataSource.listSpreadsheets(plantillasId) → check "plantilla"
    → GoogleDriveRemoteDataSource.listSpreadsheets(historicoId) → count date-named sheets
  → SettingsRepository.selectDriveFolder(folder) → persist
  ← Cubit emits GoogleDriveConnected(email, folder, content summary, warnings)

[App restart] → GoogleDriveCubit.loadSaved()
  → SettingsRepository.getGoogleDriveConfig()
    → SettingsLocalDataSource → read all persisted values
    → GoogleAuthService.getAuthenticatedClient() → autoRefreshingClient()
      → if refresh fails → emit ReconnectionNeeded
  ← Cubit emits appropriate state
```

### Gestión de errores y validaciones

| Escenario                          | Excepción / Error               | Failure resultante             |
| ---------------------------------- | ------------------------------- | ------------------------------ |
| OAuth cancelado por usuario        | `UserConsentException` (custom) | `AuthCancelledFailure` (nuevo) |
| OAuth falla (red, servidor)        | `Exception` de googleapis_auth  | `AuthFailure` (nuevo)          |
| Refresh token revocado             | `AccessDeniedException`         | `AuthExpiredFailure` (nuevo)   |
| Carpeta no existe en Drive         | `NotFoundException`             | `ConfigNotFoundFailure`        |
| Sin conexión a internet            | Timeout / `SocketException`     | `NetworkFailure`               |
| Error leyendo credenciales locales | `CacheException`                | `CacheFailure`                 |
| Carpeta sin subcarpetas esperadas  | No es error — aviso informativo | Warning en state, no Failure   |

Nuevos `Failure` a añadir en `core/error/failure.dart`:

```dart
class AuthCancelledFailure extends Failure {}
class AuthFailure extends Failure {}
class AuthExpiredFailure extends Failure {}
```

### Consideraciones de compatibilidad o migración

- La `GoogleDriveConfig` actual tiene 3 campos opcionales. Se amplía con campos
  adicionales de forma retrocompatible (todos opcionales/nullable). Las configs
  guardadas antes de este cambio se cargarán sin tokens → estado `Disconnected`
  (correcto, ya que no se podía conectar antes).
- La sección "Carpeta de trabajo local" en Ajustes permanece en la UI en esta
  fase pero conceptualmente queda deprecada. Su eliminación se hará en una fase
  posterior cuando `orders_today` y `orders_history` se migren a Google Sheets.
- Los tokens OAuth se almacenan en `FlutterSecureStorage` con key dedicado (no
  en SharedPreferences donde estaban los metadatos). Migración de datos no
  necesaria (no había tokens antes).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                                 | Propósito                                                                            |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `lib/core/services/google_auth_service.dart`                                              | Interfaz del servicio de autenticación OAuth                                         |
| `lib/core/services/google_auth_service_impl.dart`                                         | Implementación con `googleapis_auth`                                                 |
| `lib/features/settings/data/datasources/remote/google_drive_remote_data_source.dart`      | Interfaz del datasource remoto de Drive                                              |
| `lib/features/settings/data/datasources/remote/google_drive_remote_data_source_impl.dart` | Implementación con `googleapis` DriveApi                                             |
| `lib/features/settings/domain/entities/drive_folder.dart`                                 | Entidad de carpeta de Drive                                                          |
| `lib/features/settings/domain/entities/drive_folder_content.dart`                         | Resumen del contenido detectado en las subcarpetas                                   |
| `lib/features/settings/presentation/widgets/drive_folder_picker.dart`                     | Widget diálogo para navegar y seleccionar carpetas                                   |
| `lib/core/error/failure.dart` (ampliar)                                                   | Nuevos tipos de Failure: `AuthCancelledFailure`, `AuthFailure`, `AuthExpiredFailure` |

### Artefactos a modificar

| Artefacto                                                                           | Cambio esperado                                                                                                                                                |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pubspec.yaml`                                                                      | Añadir `googleapis`, `googleapis_auth`, `url_launcher`                                                                                                         |
| `lib/features/settings/domain/entities/google_drive_config.dart`                    | Añadir campos para IDs de subcarpetas y resumen de contenido                                                                                                   |
| `lib/features/settings/domain/repositories/settings_repository.dart`                | Nuevos métodos para flujo Google Drive                                                                                                                         |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`      | Nuevos métodos para tokens y subfolder IDs                                                                                                                     |
| `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart` | Implementar nuevos métodos                                                                                                                                     |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`             | Integrar `GoogleAuthService` y `GoogleDriveRemoteDataSource`                                                                                                   |
| `lib/features/settings/presentation/bloc/google_drive_cubit.dart`                   | Implementar `connect()`, `selectFolder()`, `confirmFolder()`, `refreshStatus()`                                                                                |
| `lib/features/settings/presentation/bloc/google_drive_state.dart`                   | Añadir estados: `Authenticating`, `Authenticated`, `FolderPickerLoaded`, `Verifying`, `ReconnectionNeeded`; ampliar `Connected` con content summary y warnings |
| `lib/features/settings/presentation/widgets/google_drive_section.dart`              | Reemplazar placeholder por UI funcional (botón conectar, estado conectado con resumen, cambiar carpeta, desconectar)                                           |
| `lib/app/di/modules/settings_module.dart`                                           | Registrar `GoogleAuthService`, `GoogleDriveRemoteDataSource`                                                                                                   |
| `lib/app/config/app_config.dart`                                                    | Añadir `googleOAuthClientId` y `googleOAuthClientSecret`                                                                                                       |
| `lib/app/config/environments/`                                                      | Proveer valores por entorno                                                                                                                                    |
| ARB files (i18n)                                                                    | Nuevos strings para la UI de Google Drive                                                                                                                      |

### Artefactos a retirar o reemplazar

| Artefacto              | Motivo                                                                     |
| ---------------------- | -------------------------------------------------------------------------- |
| (ninguno en esta fase) | La sección de carpeta local permanece pero queda deprecada conceptualmente |

## 6) Estrategia de implementación

1. **Paso 1 — Dependencias y configuración GCP**
   - Añadir `googleapis`, `googleapis_auth` y `url_launcher` a `pubspec.yaml`
   - Añadir `googleOAuthClientId` y `googleOAuthClientSecret` a `AppConfig` y
     las implementaciones de entorno
   - Prerequisito: tener creado el proyecto GCP con Client ID de escritorio

2. **Paso 2 — Core: servicio de autenticación**
   - Crear `GoogleAuthService` (interfaz) y `GoogleAuthServiceImpl`
   - Implementar `signIn()` con `clientViaUserConsent()` + apertura de navegador
     vía `url_launcher`
   - Implementar `getAuthenticatedClient()` con `autoRefreshingClient()`
   - Implementar persistencia de credenciales en `FlutterSecureStorage`
   - Registrar en DI (core module o settings module)

3. **Paso 3 — Core: tipos de Failure**
   - Añadir `AuthCancelledFailure`, `AuthFailure`, `AuthExpiredFailure` a
     `core/error/failure.dart`

4. **Paso 4 — Domain: entidades**
   - Crear `DriveFolder` y `DriveFolderContent`
   - Ampliar `GoogleDriveConfig` con IDs de subcarpetas y campo de contenido

5. **Paso 5 — Domain: repository contract**
   - Añadir nuevos métodos a `SettingsRepository`

6. **Paso 6 — Data: datasources**
   - Ampliar `SettingsLocalDataSource` con métodos de tokens y subfolder IDs
   - Implementar en `SettingsLocalDataSourceImpl`
   - Crear `GoogleDriveRemoteDataSource` (interfaz + impl)

7. **Paso 7 — Data: repository implementation**
   - Ampliar `SettingsRepositoryImpl` con la orquestación del flujo completo
     (auth service + drive datasource + local datasource)

8. **Paso 8 — Presentation: estados y Cubit**
   - Ampliar `GoogleDriveState` con estados intermedios
   - Implementar las acciones del `GoogleDriveCubit`

9. **Paso 9 — Presentation: widgets**
   - Crear `DriveFolderPicker` (diálogo de navegación)
   - Reescribir `GoogleDriveSection` con la UI completa

10. **Paso 10 — i18n**
    - Añadir todos los strings nuevos a los ficheros ARB

11. **Paso 11 — DI**
    - Registrar todas las nuevas dependencias en `settings_module.dart`

### Orden recomendado

Lineal del 1 al 11. Cada paso depende del anterior (excepto 3 y 10 que son
independientes y pueden hacerse en cualquier momento).

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (necesita las dependencias y el Client ID)
- Pasos 4-5 son independientes de 2-3 pero necesarios antes de 6
- Paso 6 depende de 2, 4 y 5
- Paso 7 depende de 6
- Paso 8 depende de 5 y 7
- Paso 9 depende de 8 y 10

### Puntos delicados

- **OAuth en escritorio:** `clientViaUserConsent()` de `googleapis_auth` abre un
  servidor HTTP local temporal para recibir el callback de Google. Verificar que
  esto funciona correctamente en macOS y Windows (firewall, permisos de red
  local).
- **Serialización de credenciales:** `AccessCredentials` de `googleapis_auth`
  debe serializarse/deserializarse a JSON para persistir en SecureStorage. No
  tiene `toJson()`/`fromJson()` nativos; hay que implementar la conversión
  manualmente.
- **Renovación de tokens:** `autoRefreshingClient()` renueva automáticamente
  pero requiere que el refresh token sea válido. Si Google lo revoca, se lanza
  excepción. Hay que capturarla y emitir estado `ReconnectionNeeded`.
- **Scopes mínimos:** Usar `DriveApi.driveReadonlyScope` para la navegación de
  carpetas y `SheetsApi.spreadsheetsScope` para futura lectura/escritura.
  Solicitar ambos en el `signIn()` inicial.
- **Client Secret en escritorio:** Para apps de escritorio, Google permite
  distribuir el Client Secret embebido (no es realmente "secreto" en este
  contexto). Aun así, no hardcodear: usar `AppConfig` por entorno.

## 7) Estrategia de validación

### Verificación automática (tests)

- **Unit test `GoogleAuthServiceImpl`:** mock de `googleapis_auth` → verificar
  que `signIn()` devuelve credenciales y las persiste; que
  `getAuthenticatedClient()` reconstruye el client; que `signOut()` limpia
  storage.
- **Unit test `GoogleDriveRemoteDataSourceImpl`:** mock de `DriveApi` →
  verificar listado de carpetas, listado de sheets, verificación de existencia.
- **Unit test `SettingsRepositoryImpl`:** mock de auth service + drive
  datasource + local datasource → verificar flujo completo de
  `connectGoogleDrive()`, `verifyDriveFolder()`, `selectDriveFolder()`.
- **Unit test `GoogleDriveCubit`:** `bloc_test` → verificar transiciones de
  estado para cada acción (connect, selectFolder, confirmFolder, disconnect,
  loadSaved con token válido, loadSaved con token revocado).

### Validación manual

- Flujo completo en macOS: conectar → navegar carpetas → seleccionar → verificar
  subcarpetas → ver resumen → cerrar app → reabrir → verificar que la sesión
  persiste.
- Flujo de desconexión y reconexión.
- Revocar permisos desde myaccount.google.com → verificar que la app detecta el
  token revocado y solicita re-autenticación.
- Carpeta sin subcarpetas esperadas → verificar avisos informativos.
- Sin conexión a internet → verificar mensajes de error.

### Escenarios a cubrir

- Primera autenticación exitosa
- Autenticación cancelada por el usuario
- Selección de carpeta con estructura válida (3 subcarpetas + plantilla)
- Selección de carpeta con estructura parcial (faltan subcarpetas)
- Selección de carpeta sin plantilla en `plantillas/`
- Persistencia y restauración entre sesiones
- Renovación automática de access token
- Refresh token revocado externamente
- Error de red durante cualquier operación
- Cambio de carpeta sin desconectar
- Desconexión completa

## 8) Riesgos, impacto y rollback

### Riesgos identificados

1. **OAuth en Windows:** `clientViaUserConsent()` usa un servidor HTTP local. El
   firewall de Windows podría bloquearlo en algunos equipos.
2. **Credenciales GCP:** Se necesita un proyecto GCP con APIs habilitadas. Si no
   está configurado, no se puede probar ni desplegar.
3. **Límites de API:** Google Drive API tiene límites de queries por minuto. Con
   el uso previsto (bajo volumen, bajo demanda) no debería ser problema, pero el
   listado de carpetas en cuentas con muchos archivos podría ser lento.
4. **Cambios en APIs de Google:** Las APIs pueden deprecar endpoints, aunque son
   estables. Usar versiones pinneadas de `googleapis`.

### Impacto potencial

- **Feature `settings`:** cambio significativo en la sección Google Drive (de
  placeholder a funcionalidad completa).
- **Otras features:** sin impacto directo. `orders_today` y `orders_history` no
  se modifican en esta fase.
- **UX:** mejora sustancial — el usuario pasa de un placeholder a una
  configuración funcional de Google Drive.

### Mitigación

1. Probar OAuth en macOS y Windows antes de considerar el paso completado.
2. Documentar los pasos de configuración del proyecto GCP como prerequisito.
3. Implementar paginación en el listado de carpetas si la respuesta es grande.
4. Pinnear versiones de `googleapis` y `googleapis_auth` en `pubspec.yaml`.

### Plan de rollback

- Todos los cambios son aditivos (nuevos archivos, nuevos métodos, nuevas
  dependencias). No se elimina ni modifica comportamiento existente (la config
  que había antes sigue funcionando).
- Para revertir: eliminar las nuevas dependencias de `pubspec.yaml`, borrar los
  archivos nuevos y revertir las ampliaciones de interfaces/implementaciones.
- Los datos de usuario ya persistidos (tokens en SecureStorage, IDs en
  SharedPreferences) no causan problemas si la funcionalidad se revierte —
  simplemente no se usarían.

## 9) Suposiciones

- Se dispone de un proyecto GCP con Client ID de tipo "Desktop app" y las APIs
  de Google Drive y Google Sheets habilitadas antes de comenzar la
  implementación.
- El Client Secret de una aplicación de escritorio se puede distribuir embebido
  en la app (estándar de Google para native/desktop apps).
- `googleapis_auth` `clientViaUserConsent()` funciona correctamente en macOS y
  Windows con Flutter.
- La serialización manual de `AccessCredentials` a JSON es viable y estable (los
  campos están documentados en la librería).
- `FlutterSecureStorage` funciona en macOS y Windows para almacenar los tokens
  OAuth.

## 10) Preguntas abiertas

- Ninguna. Todas las decisiones técnicas están tomadas con la información
  disponible.

## 11) Notas para implementación

- **Restricciones técnicas:**
  - No usar `google_sign_in` — no soporta bien escritorio. Usar
    `googleapis_auth` directamente.
  - Los tokens van en `FlutterSecureStorage`, no en `SharedPreferences`.
  - Los scopes son: `DriveApi.driveReadonlyScope` +
    `SheetsApi.spreadsheetsScope`.
  - La navegación de carpetas debe ser paginada (la API de Drive devuelve máximo
    100 resultados por página por defecto).
- **Secuencia sugerida:** seguir los 11 pasos de la sección 6 en orden.
- **No romper comportamiento existente:**
  - `loadSaved()` del Cubit debe seguir funcionando con configs antiguas (sin
    tokens) → emitir `Disconnected`.
  - `disconnect()` debe limpiar tanto tokens como metadatos.
  - La sección de carpeta de trabajo local sigue visible (se retirará en una
    fase posterior).
- **Estado: Listo para implementación**
