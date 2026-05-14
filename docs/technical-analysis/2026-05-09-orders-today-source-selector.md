# Technical Analysis: Selector de origen de Pedidos de hoy

- **Fecha:** 2026-05-09
- **Identificador:** orders-today-source-selector
- **Fuente:**
  docs/functional-analysis/2026-05-09-orders-today-source-selector.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Interceptar la navegación al índice 1 (Pedidos de hoy) en `SideMenuShell` para
  mostrar un diálogo modal de selección de origen antes de navegar.
- El diálogo ofrece dos opciones: flujo actual (Firestore) o selección de hoja
  de cálculo de Google Drive.
- Para la opción de Google Drive, se reutiliza
  `GoogleDriveRemoteDataSource.listSpreadsheets()` dentro de un nuevo widget de
  selección de spreadsheets.
- No se introduce nueva dependencia externa ni se modifica la feature
  `orders_today`.
- Principales áreas impactadas: feature `home` (presentación) y archivo i18n.
- Riesgo general estimado: **bajo**.

## 2) Contexto técnico observado

### Arquitectura y patrones

- **Clean Architecture feature-first** con BLoC/Cubit, GetIt para DI, fpdart.
- La navegación se gestiona mediante `SideMenuCubit` (estado = índice
  seleccionado). `SideMenuShell` construye la página correspondiente con
  `_buildPage(index)`.
- Ya existe un punto de interceptación en `SideMenuShell.onItemSelected`: se
  comprueba `NavigationGuard.shouldBlock` antes de navegar.

### Módulos relevantes

- **`home/presentation/pages/side_menu_shell.dart`**: Orquesta la navegación
  lateral. Contiene `_showUnsavedDialog` como patrón de interceptación
  existente.
- **`home/presentation/bloc/side_menu_cubit.dart`**: Cubit que gestiona el
  índice activo del menú.
- **`settings/data/datasources/remote/google_drive_remote_data_source.dart`**:
  Contrato con `listSpreadsheets(String folderId)` que devuelve
  `List<DriveFileInfo>`.
- **`settings/data/datasources/remote/google_drive_remote_data_source_impl.dart`**:
  Implementación que lista Google Spreadsheets + Excel en una carpeta de Drive.
- **`settings/data/datasources/local/settings_local_data_source.dart`**: Provee
  `getGoogleDriveFolderId()`, `getGoogleDriveAccountEmail()`, etc.

### Restricciones

- El `SideMenuShell` es un `StatelessWidget`. Los diálogos se lanzan desde
  métodos estáticos usando `showDialog`.
- `GoogleDriveRemoteDataSource` y `SettingsLocalDataSource` están registrados
  como singletons en GetIt (`sl`).
- La clase `DriveFileInfo` (id, name, mimeType) ya existe y es suficiente para
  representar los spreadsheets listados.

## 3) Objetivo técnico

- **Qué debe cambiar**: La lógica de `onItemSelected` en `SideMenuShell` para el
  índice 1 debe abrir un diálogo de selección de origen en lugar de navegar
  directamente.
- **Resultado técnico**: El usuario ve un diálogo modal al pulsar "Pedidos de
  hoy" que le permite elegir entre el flujo actual o seleccionar una hoja de
  cálculo de Drive. El flujo actual permanece inalterado al elegir la primera
  opción.
- **Limitaciones a respetar**: No modificar `OrdersTodayPage`, no alterar el
  `SideMenuCubit`, no introducir nuevas dependencias externas, respetar el
  `NavigationGuard` existente.

## 4) Diseño técnico de la solución

### Enfoque propuesto

1. **Interceptación en `SideMenuShell`**: En el callback `onItemSelected`,
   cuando `index == 1`, en lugar de llamar directamente a
   `SideMenuCubit.selectItem(1)`, se invoca un nuevo método
   `_showOrdersSourceDialog(context)`.
2. **Diálogo de selección de origen**: Un `AlertDialog` o `SimpleDialog` con dos
   opciones tipo `ListTile` con icono y texto.
   - **Opción 1**: Icono de app + texto i18n → cierra el diálogo y llama a
     `SideMenuCubit.selectItem(1)`.
   - **Opción 2**: Icono de Google Drive + texto i18n → inicia el flujo de
     selección de spreadsheet.
3. **Flujo de selección de spreadsheet**: Se muestra un segundo diálogo (o se
   reemplaza el contenido del primero) con un widget `SpreadsheetPickerDialog`
   que:
   - Lee la configuración de Google Drive desde `SettingsLocalDataSource` (vía
     `sl`).
   - Si no hay configuración, muestra un mensaje indicando que debe configurarse
     en Ajustes.
   - Si hay configuración, llama a
     `GoogleDriveRemoteDataSource.listSpreadsheets(folderId)`.
   - Muestra la lista en un `ListView` dentro de un diálogo con estados:
     loading, loaded, empty, error.
   - Al seleccionar un spreadsheet, muestra un `SnackBar` o diálogo de
     confirmación con nombre e ID.
4. **Interacción con `NavigationGuard`**: El guard se evalúa **antes** de
   mostrar el diálogo de selección de origen. Si `guard.shouldBlock`, se muestra
   primero el diálogo de cambios no guardados (flujo existente). Solo si el
   usuario acepta descartar se procede a mostrar el diálogo de origen.

### Componentes / módulos / servicios afectados

| Componente                        | Feature            | Tipo de cambio                                |
| --------------------------------- | ------------------ | --------------------------------------------- |
| `SideMenuShell`                   | `home`             | Modificación: interceptar índice 1            |
| `SpreadsheetPickerDialog` (nuevo) | `home`             | Creación: widget de selección de spreadsheets |
| `app_es.arb`                      | `app/localization` | Modificación: ~10 nuevas claves i18n          |

### Contratos e interfaces

No se crean nuevos contratos. Se reutilizan:

- `GoogleDriveRemoteDataSource.listSpreadsheets(String folderId)` →
  `Future<List<DriveFileInfo>>`
- `SettingsLocalDataSource.getGoogleDriveFolderId()` → `String?`
- `SettingsLocalDataSource.getGoogleDriveAccountEmail()` → `String?`

### Flujo de datos o de control

```
Usuario pulsa "Pedidos de hoy" (index=1)
  │
  ├─ guard.shouldBlock? → _showUnsavedDialog (flujo existente)
  │     └─ usuario descarta → continúa ↓
  │
  ├─ _showOrdersSourceDialog(context)
  │     │
  │     ├─ Opción "Aplicación" seleccionada
  │     │     └─ Navigator.pop → SideMenuCubit.selectItem(1)
  │     │
  │     └─ Opción "Hoja de cálculo" seleccionada
  │           │
  │           ├─ SettingsLocalDataSource.getGoogleDriveFolderId() == null?
  │           │     └─ Mostrar mensaje "Configura Google Drive en Ajustes"
  │           │
  │           └─ folderId != null
  │                 └─ showDialog(SpreadsheetPickerDialog)
  │                       │
  │                       ├─ loading → CircularProgressIndicator
  │                       ├─ GoogleDriveRemoteDataSource.listSpreadsheets(folderId)
  │                       ├─ lista cargada → ListView de DriveFileInfo
  │                       ├─ lista vacía → mensaje "No hay hojas de cálculo"
  │                       ├─ error → mensaje + botón reintentar
  │                       │
  │                       └─ Usuario selecciona spreadsheet
  │                             └─ SnackBar confirmación (nombre + ID)
  │                                 (sin procesamiento posterior en esta iteración)
```

### Gestión de errores y validaciones

- **Google Drive no configurado**: Se detecta comprobando
  `SettingsLocalDataSource.getGoogleDriveFolderId() == null` o
  `getGoogleDriveAccountEmail() == null`. Se muestra mensaje i18n con enlace a
  Ajustes.
- **Error de red / autenticación expirada**:
  `GoogleDriveRemoteDataSource.listSpreadsheets()` lanza `ServerException`. Se
  captura en el diálogo y se muestra un estado de error con opción de
  reintentar.
- **Carpeta eliminada en Drive**: La API de Drive devuelve error 404 que se
  traduce en `ServerException`. Se muestra como error genérico.
- **Diálogo apilado (EC-01)**: El propio mecanismo de `showDialog` con
  `barrierDismissible: true` evita problemas; además, el guard de
  `if (index == state.selectedIndex) return` previene la apertura duplicada ya
  que el índice no cambia hasta que se selecciona la opción 1.

### Consideraciones de compatibilidad o migración

- No hay migración de datos.
- No se rompe ningún flujo existente: si el usuario elige la opción 1 del
  diálogo, el comportamiento es idéntico al actual.
- No se modifican contratos, repositorios ni use cases.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                               | Propósito                                                                                                                                            |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/home/presentation/widgets/spreadsheet_picker_dialog.dart` | Widget `StatefulWidget` que lista spreadsheets de una carpeta de Google Drive, gestiona estados loading/loaded/empty/error y permite seleccionar uno |

### Artefactos a modificar

| Artefacto                                                   | Cambio esperado                                                                                                                                                                                   |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/home/presentation/pages/side_menu_shell.dart` | Añadir método `_showOrdersSourceDialog()`. Modificar `onItemSelected` para interceptar índice 1 y mostrar el diálogo en lugar de navegar directamente. Ajustar la secuencia con `NavigationGuard` |
| `lib/app/localization/l10n/app_es.arb`                      | Añadir ~10 claves i18n para el diálogo de selección y el selector de spreadsheets                                                                                                                 |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Pasos

1. **Añadir claves i18n** en `app_es.arb` y regenerar con `flutter gen-l10n`.
2. **Crear `SpreadsheetPickerDialog`**: widget que recibe `folderId`, resuelve
   `GoogleDriveRemoteDataSource` desde `sl`, lista spreadsheets y permite
   seleccionar uno. Gestiona estados internos con `StatefulWidget` +
   `FutureBuilder` o estado local.
3. **Modificar `SideMenuShell`**: interceptar `index == 1` en `onItemSelected`,
   añadir `_showOrdersSourceDialog`. Manejar correctamente la secuencia
   `NavigationGuard` → diálogo de origen → navegación o selección de
   spreadsheet.
4. **Validar**: `flutter gen-l10n`, `dart analyze`, `flutter test`.

### Orden recomendado

1 → 2 → 3 → 4 (secuencial; cada paso depende del anterior).

### Dependencias entre pasos

- Paso 2 depende de paso 1 (necesita las claves i18n).
- Paso 3 depende de paso 2 (importa `SpreadsheetPickerDialog`).
- Paso 4 valida todo.

### Puntos delicados

- **Interacción `NavigationGuard` + diálogo de origen**: La secuencia correcta
  es: (1) evaluar guard, (2) si guard permite, mostrar diálogo de origen, (3)
  según opción elegida, navegar o abrir picker. No se debe mostrar el diálogo de
  origen antes de resolver el guard.
- **EC-02 — Ya en índice 1**: El `if (index == state.selectedIndex) return`
  actual en `SideMenuShell` evita la re-apertura. Esto es correcto y se
  mantiene. El diálogo solo aparece cuando se navega **hacia** el índice 1 desde
  otro índice.
- **Resolución de `sl` en widgets**: El `SpreadsheetPickerDialog` resolverá
  `GoogleDriveRemoteDataSource` y `SettingsLocalDataSource` desde `sl` (GetIt
  global), patrón ya establecido en el proyecto (ej: `OrdersTodayPage` usa
  `sl<SettingsRepository>()`).

## 7) Estrategia de validación

### Verificación automática

- `dart analyze` sobre los archivos modificados/creados: 0 issues.
- `flutter gen-l10n`: regeneración exitosa.
- `flutter test`: todos los tests existentes pasan (el diálogo no afecta tests
  de otros features).

### Verificación manual

- Pulsar "Pedidos de hoy" desde otro ítem del menú → aparece el diálogo con dos
  opciones.
- Seleccionar "Pedidos de hoy (aplicación)" → se muestra `OrdersTodayPage`
  (flujo idéntico al actual).
- Seleccionar "Abrir desde hoja de cálculo" con Google Drive configurado → se
  muestra la lista de spreadsheets.
- Seleccionar un spreadsheet → se muestra confirmación (nombre + ID).
- Seleccionar "Abrir desde hoja de cálculo" sin Google Drive configurado → se
  muestra mensaje informativo.
- Cerrar el diálogo sin elegir → permanece en la pantalla previa.
- Probar con `NavigationGuard` activo (cambios sin guardar) → primero aparece el
  diálogo de cambios no guardados, luego el de selección de origen.

### Escenarios a cubrir

- Flujo normal: app seleccionada, spreadsheet seleccionado.
- Google Drive no configurado.
- Carpeta vacía (sin spreadsheets).
- Error de red al listar spreadsheets.
- Cancelación del diálogo de origen.
- Cancelación del selector de spreadsheets.
- Interacción con NavigationGuard.

### Tipo de pruebas recomendables

- **Tests unitarios**: No son estrictamente necesarios para esta iteración (la
  lógica es mayoritariamente de UI/presentación). Si se desean, un widget test
  del `SpreadsheetPickerDialog` con mock de `GoogleDriveRemoteDataSource`.
- **Tests manuales**: Validación completa del flujo en runtime con cuenta de
  Google Drive real.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                                  | Probabilidad | Impacto | Mitigación                                                                 |
| --------------------------------------------------------------------------------------- | ------------ | ------- | -------------------------------------------------------------------------- |
| El diálogo extra molesta al usuario que siempre elige la misma opción                   | Media        | Bajo    | En iteraciones futuras se puede añadir "recordar elección"                 |
| `listSpreadsheets` tarda mucho si la carpeta tiene muchos archivos                      | Baja         | Bajo    | Ya implementado con paginación en `GoogleDriveRemoteDataSourceImpl`        |
| La autenticación de Google expira entre apertura del diálogo y selección de spreadsheet | Baja         | Bajo    | `ServerException` capturada y mostrada como error con opción de reintentar |

### Impacto potencial

- **Bajo**: Solo se modifica el flujo de navegación hacia "Pedidos de hoy". No
  se toca la lógica de negocio, repositorios, use cases ni datasources
  existentes.
- No hay cambio de modelo de datos.
- No hay migración.

### Mitigación

- El diálogo es 100% cancelable (barrierDismissible + botón cerrar).
- La opción 1 reproduce exactamente el comportamiento actual.

### Plan de rollback

- Revertir los cambios en `SideMenuShell` (eliminar interceptación del índice 1)
  para volver al flujo directo.
- Eliminar `SpreadsheetPickerDialog`.
- Eliminar las claves i18n añadidas.
- Impacto del rollback: nulo sobre el resto del sistema.

## 9) Suposiciones

- **S-01**: `GoogleDriveRemoteDataSource` está disponible en `sl` sin
  restricciones (registrado como LazySingleton en `settings_module.dart`).
  Verificado en el código.
- **S-02**: `SettingsLocalDataSource` está disponible en `sl`. Verificado.
- **S-03**: `DriveFileInfo` (id, name, mimeType) es suficiente para mostrar la
  lista y confirmar la selección. No se necesita información adicional del
  archivo.
- **S-04**: El `SpreadsheetPickerDialog` se implementa como `StatefulWidget` con
  estado local (loading/loaded/error), sin necesidad de un Cubit dedicado, dado
  que la lógica es simple y autocontenida.

## 10) Preguntas abiertas

- **PA-01**: Tras seleccionar el spreadsheet, ¿se almacena la selección en algún
  sitio (SharedPreferences, estado del cubit) para uso en iteraciones futuras, o
  solo se muestra la confirmación? → **Propuesta**: en esta iteración, solo
  confirmación visual. En la siguiente, se definirá la persistencia.
- **PA-02**: ¿Debe el selector de spreadsheets permitir navegar subcarpetas de
  Drive o solo listar los de la carpeta raíz configurada? → **Propuesta**: solo
  la carpeta raíz configurada en esta iteración (simplicidad).

## 11) Notas para implementación

- Respetar la secuencia `NavigationGuard` → diálogo de origen. El guard se
  evalúa primero en `onItemSelected` (línea existente). El diálogo de origen se
  muestra **después** de que el guard lo permita, pero **antes** de llamar a
  `selectItem(1)`.
- En `SideMenuShell.onItemSelected`, la interceptación del índice 1 se coloca
  después de la comprobación del guard:
  ```
  if (index == state.selectedIndex) return;
  if (guard.shouldBlock) { _showUnsavedDialog(...); return; }
  if (index == 1) { _showOrdersSourceDialog(context); return; }
  context.read<SideMenuCubit>().selectItem(index);
  ```
- El `SpreadsheetPickerDialog` debe usar `try/catch` al llamar a
  `listSpreadsheets()` y gestionar `ServerException` mostrando el estado de
  error.
- Todos los textos visibles deben usar claves del ARB. No hardcodear strings.
- No crear un Cubit separado para el diálogo — la lógica es suficientemente
  simple para estado local del widget.
- **Estado: Listo para implementación**
