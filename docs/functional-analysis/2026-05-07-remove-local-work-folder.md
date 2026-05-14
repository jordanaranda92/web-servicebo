# Functional Analysis: Eliminar carpeta de trabajo local y migrar a Google Drive

- **Fecha:** 2026-05-07
- **Identificador:** remove-local-work-folder
- **Estado:** Ready for technical analysis

## 1) Resumen

Eliminar la funcionalidad de "Carpeta de trabajo" (selección de carpeta local en
el sistema de archivos del ordenador) y sustituirla por Google Drive como única
fuente de almacenamiento y lectura de archivos Excel de pedidos. Todas las
operaciones que actualmente usan rutas locales (`workFolderPath`) pasarán a
trabajar con la API de Google Drive ya integrada.

## 2) Contexto y objetivo

### Qué se solicita

Actualmente la app Servicebo gestiona archivos Excel de pedidos en dos posibles
ubicaciones:

1. **Carpeta de trabajo local** — el usuario selecciona un directorio en su
   ordenador mediante un file picker nativo. Las features `orders_today`,
   `orders_history` y `home/dashboard` leen y escriben archivos `.xlsx`
   directamente del sistema de archivos local usando rutas como
   `$workFolderPath/historico/YYYY-MM-DD.xlsx` y
   `$workFolderPath/plantilla.xlsx`.

2. **Google Drive** — ya existe una integración OAuth completa (autenticación,
   navegación de carpetas, verificación de estructura con subcarpetas
   `historico/`, `plantillas/`, `interno/`) implementada en la sección de
   ajustes.

Se solicita **eliminar la opción 1** y que la aplicación trabaje exclusivamente
con Google Drive.

### Qué problema resuelve

- Elimina la duplicidad de configuración de almacenamiento (dos secciones en
  ajustes para el mismo propósito).
- El flujo real de negocio ya utiliza Google Drive como fuente compartida entre
  3+ usuarios (ver documento de contexto en `docs/facturadirecta`).
- La carpeta local introduce complejidad innecesaria: validación de rutas,
  detección de carpetas inexistentes, permisos del sandbox de macOS, etc.
- Simplifica la experiencia del usuario: una sola configuración de
  almacenamiento.

### Qué resultado funcional se espera

- La sección "Carpeta de trabajo" desaparece de la pantalla de Ajustes.
- Google Drive se convierte en la **única fuente de archivos**.
- Todas las funcionalidades que leían/escribían del sistema de archivos local
  (pedidos del día, histórico de pedidos, dashboard) pasan a operar contra
  Google Drive.
- Si Google Drive no está configurado, la app muestra un estado orientativo
  (similar al actual "sin carpeta de trabajo") indicando que debe configurarse
  Google Drive.

## 3) Alcance

### En alcance

- **Ajustes**: eliminar la sección "Carpeta de trabajo" (UI, cubit, estado,
  entity, métodos de repositorio y datasource).
- **Ajustes**: promover Google Drive a sección principal de almacenamiento
  (primera posición visual si aplica).
- **Orders Today**: sustituir las lecturas/escrituras locales por operaciones
  contra Google Drive (lectura de plantilla, lectura/escritura de archivo del
  día en `historico/`).
- **Orders History**: sustituir la lectura de archivos locales del directorio
  `historico/` por listado y lectura desde Google Drive.
- **Home/Dashboard**: sustituir la lectura de archivos locales para estadísticas
  por lectura desde Google Drive.
- **Validación de prerequisito**: donde antes se validaba "¿hay carpeta de
  trabajo configurada?", ahora se valida "¿hay Google Drive conectado con
  carpeta seleccionada?".
- **Eliminar dependencia de `file_picker`** si ya no se usa en ningún otro lugar
  de la app.
- **Eliminar strings i18n** relacionados con la carpeta de trabajo local que ya
  no se usen.
- **Actualizar tests** afectados.

### Fuera de alcance

- Cambios en la integración de FacturaDirecta.
- Modificaciones al flujo OAuth de Google Drive (ya funciona correctamente).
- Soporte offline o caché local de archivos de Drive (si se necesita, será una
  funcionalidad futura).
- Migración automática de archivos de la carpeta local a Google Drive.

## 4) Actores implicados

- **Usuario final (operador de pedidos)**: persona que gestiona los pedidos
  diarios. Actualmente configura una carpeta local; tras el cambio solo
  configurará Google Drive.
- **Sistema externo (Google Drive API)**: proveedor de almacenamiento y lectura
  de archivos Excel.

## 5) Requisitos funcionales

- **RF-01**: La sección "Carpeta de trabajo" debe eliminarse completamente de la
  pantalla de Ajustes.
- **RF-02**: La sección "Google Drive" debe ser la primera (o única) sección de
  almacenamiento visible en Ajustes.
- **RF-03**: La pantalla de Pedidos de hoy (`OrdersTodayPage`) debe leer el
  archivo Excel del día desde la carpeta `historico/` de Google Drive en lugar
  del sistema de archivos local.
- **RF-04**: La creación del archivo del día (copiar plantilla) debe realizarse
  en Google Drive: copiar el archivo plantilla de la subcarpeta correspondiente
  al `historico/` con el nombre `YYYY-MM-DD.xlsx`.
- **RF-05**: La pantalla de Historial de pedidos (`OrdersHistoryPage`) debe
  listar las fechas disponibles a partir de los archivos `.xlsx` presentes en la
  carpeta `historico/` de Google Drive.
- **RF-06**: La carga de pedidos históricos por fecha debe descargar/leer el
  archivo correspondiente desde Google Drive.
- **RF-07**: El Dashboard debe obtener los datos estadísticos leyendo los
  archivos Excel desde Google Drive (hoy, ayer, misma semana, semana anterior,
  mes actual, mes anterior).
- **RF-08**: Si Google Drive no está conectado o no tiene carpeta seleccionada,
  todas las pantallas dependientes (pedidos hoy, historial, dashboard) deben
  mostrar un estado orientativo indicando que es necesario configurar Google
  Drive en Ajustes.
- **RF-09**: Se debe eliminar la entity `WorkFolderConfig`, el
  `WorkFolderCubit`, los estados asociados, el widget `WorkFolderSection`, y los
  métodos `getWorkFolder()`, `saveWorkFolder()`, `clearWorkFolder()` del
  repositorio y datasource de settings.
- **RF-10**: Se deben eliminar las claves i18n exclusivas de la carpeta de
  trabajo que ya no se utilicen.
- **RF-11**: La dependencia `file_picker` debe eliminarse del proyecto si no se
  utiliza en ningún otro lugar tras esta eliminación.
- **RF-12**: La función "Guardar como nuevo Excel" (si existe en orders_today)
  debe guardar el archivo en Google Drive en lugar de en local.

## 6) Criterios de aceptación

- **CA-01**: La pantalla de Ajustes no muestra la sección "Carpeta de trabajo".
- **CA-02**: La pantalla de Ajustes muestra Google Drive como la sección de
  configuración de almacenamiento.
- **CA-03**: Con Google Drive conectado y carpeta seleccionada, la pantalla de
  Pedidos de hoy carga el archivo del día desde Drive.
- **CA-04**: Si el archivo del día no existe en Drive, el usuario puede crearlo
  (se copia la plantilla desde Drive).
- **CA-05**: La pantalla de Historial muestra las fechas correspondientes a los
  archivos `.xlsx` encontrados en la carpeta `historico/` de Google Drive.
- **CA-06**: Al seleccionar una fecha en el historial, se cargan los pedidos del
  archivo correspondiente desde Drive.
- **CA-07**: El Dashboard muestra estadísticas basadas en archivos leídos desde
  Google Drive.
- **CA-08**: Sin Google Drive configurado, todas las pantallas dependientes
  muestran un mensaje claro indicando que se debe configurar Google Drive en
  Ajustes.
- **CA-09**: No existen referencias a `WorkFolderConfig`, `WorkFolderCubit`,
  `WorkFolderState`, `WorkFolderSection` ni `workFolderPath` en el código
  fuente.
- **CA-10**: El proyecto compila sin errores ni warnings relacionados
  (`dart analyze` limpio).
- **CA-11**: Los tests unitarios existentes se actualizan y pasan correctamente.

## 7) Flujos y comportamiento esperado

### Flujo principal — Pedidos de hoy

1. El usuario navega a "Pedidos de hoy".
2. El sistema verifica si Google Drive está conectado y tiene carpeta
   configurada (vía `SettingsRepository.getGoogleDriveConfig()`).
3. Si está configurado, el sistema busca el archivo `YYYY-MM-DD.xlsx` en la
   subcarpeta `historico/` de Google Drive.
4. Si el archivo existe, se descarga/lee y se muestran los pedidos.
5. Si el archivo no existe, se muestra el estado vacío con opción de crear el
   archivo del día (copiando la plantilla desde Drive).

### Flujo principal — Historial de pedidos

1. El usuario navega a "Historial de pedidos".
2. El sistema verifica la configuración de Google Drive.
3. Si está configurado, lista los archivos `.xlsx` de la subcarpeta `historico/`
   en Drive.
4. El usuario selecciona una fecha.
5. El sistema descarga/lee el archivo correspondiente y muestra los pedidos.

### Flujo principal — Dashboard

1. El usuario abre el Dashboard (Home).
2. El sistema verifica la configuración de Google Drive.
3. Si está configurado, lee los archivos necesarios (hoy, ayer, semanas, meses)
   desde `historico/` en Drive.
4. Se calculan y muestran las estadísticas.

### Flujos alternativos

- **Google Drive no configurado**: se muestra un estado vacío con mensaje
  orientativo y botón/enlace para ir a Ajustes > Google Drive.
- **Google Drive conectado pero sin carpeta seleccionada**: mismo tratamiento
  que "no configurado", pero el mensaje puede ser más específico ("Selecciona
  una carpeta en Google Drive").
- **Token OAuth expirado**: el sistema intenta refrescar automáticamente. Si
  falla, se muestra estado de reconexión necesaria.
- **Archivo no encontrado en Drive**: se informa al usuario (para historial) o
  se ofrece crear (para hoy).

### Estados especiales / excepciones

- **Estado vacío**: Google Drive no configurado → mensaje orientativo con acción
  a Ajustes.
- **Estado loading/procesando**: mientras se leen archivos de Drive (puede ser
  más lento que local) → indicador de carga.
- **Estado error**: fallo de red, error de API de Drive, permisos insuficientes
  → mensaje de error con opción de reintentar.
- **Sin conexión a internet**: las operaciones contra Drive fallan → mensaje
  indicando que se requiere conexión.

## 8) Edge cases

- **EC-01**: El usuario tenía configurada una carpeta local pero no Google Drive
  → tras la actualización, al abrir la app verá el estado "Google Drive no
  configurado" en todas las pantallas que antes usaban la carpeta local. No se
  realiza migración automática.
- **EC-02**: La subcarpeta `historico/` no existe en la carpeta de Drive
  seleccionada → debe mostrarse un error claro o crearse automáticamente (según
  verificación existente de estructura).
- **EC-03**: Archivo del día ya existente al intentar crear → no sobrescribir,
  cargar el existente.
- **EC-04**: Múltiples usuarios editando simultáneamente el mismo archivo en
  Drive → fuera de alcance de esta funcionalidad; Drive gestiona la concurrencia
  a nivel de archivo.
- **EC-05**: Archivos con formato inesperado (no `.xlsx` o corrupto) en la
  carpeta `historico/` de Drive → manejar como error de lectura, igual que se
  hacía con archivos locales.
- **EC-06**: Carpeta de Drive eliminada externamente después de configurarla →
  al intentar operar, se muestra error y se invita a reconfigurar.
- **EC-07**: Latencia de red al leer desde Drive vs. lectura local instantánea →
  el usuario puede percibir mayor tiempo de carga. Considerar indicadores de
  progreso adecuados.

## 9) Impacto funcional

### Módulos o procesos afectados

| Módulo             | Impacto                                                                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `settings`         | Eliminación de WorkFolder (entity, cubit, state, section, métodos de repositorio/datasource). Promoción de Google Drive como almacenamiento principal. |
| `orders_today`     | Cambio de fuente de datos: de file system local a Google Drive API. Afecta bloc, events, repository, datasource.                                       |
| `orders_history`   | Cambio de fuente de datos: de file system local a Google Drive API. Afecta bloc, events, use cases, repository.                                        |
| `home` (dashboard) | Cambio de fuente de datos: de file system local a Google Drive API. Afecta cubit, use case, repository.                                                |
| `i18n`             | Eliminación de ~10 claves de carpeta de trabajo.                                                                                                       |
| `pubspec.yaml`     | Posible eliminación de `file_picker`.                                                                                                                  |
| Tests              | Actualización de todos los tests que mockean `getWorkFolder()` o usan `workFolderPath`.                                                                |

### Impacto en usuario o negocio

- **Positivo**: Experiencia simplificada, una sola configuración de
  almacenamiento alineada con el flujo real de trabajo (Drive compartido).
- **Negativo potencial**: Dependencia de conexión a internet para todas las
  operaciones con archivos. Sin modo offline.
- **Migración**: Los usuarios que tenían carpeta local configurada deberán
  configurar Google Drive. No hay migración automática de datos.

### Impacto en experiencia de usuario

- Eliminación de una sección en Ajustes → interfaz más limpia.
- Las operaciones de lectura/escritura pueden ser ligeramente más lentas (red
  vs. disco local) → importante mostrar indicadores de carga.
- Primer uso tras actualización: los usuarios existentes que usaban carpeta
  local verán que deben configurar Google Drive.

## 10) Suposiciones

- **S-01**: La integración OAuth de Google Drive ya implementada funciona
  correctamente y permite leer/escribir archivos en las subcarpetas
  configuradas.
- **S-02**: Las operaciones necesarias sobre Google Drive (listar archivos, leer
  contenido, copiar archivo, crear archivo) están disponibles a través de la API
  de Drive ya integrada o se pueden añadir al datasource remoto existente.
- **S-03**: La estructura de carpetas en Drive (`historico/`, `plantillas/`,
  `interno/`) ya se valida durante la configuración y se puede asumir presente
  durante las operaciones.
- **S-04**: No se requiere soporte offline en esta iteración. Todas las
  operaciones requieren conexión a internet.
- **S-05**: El paquete `file_picker` no se usa en ninguna otra parte de la app
  además de `WorkFolderCubit.pickFolder()`.
- **S-06**: La función `save_as_new_excel` (usada en `orders_today`) también
  trabaja actualmente con el sistema de archivos local y deberá adaptarse.

## 11) Preguntas abiertas

- **PA-01**: ¿Se desea implementar algún tipo de caché local de los archivos
  leídos desde Drive para mejorar rendimiento o permitir un modo offline básico?
  (Supuesto actual: no, todas las lecturas van contra Drive directamente).
- **PA-02**: ¿Debe la app mostrar algún mensaje de migración o ayuda contextual
  para usuarios que venían usando la carpeta local y actualizan a esta versión?
- **PA-03**: ¿La operación de guardar/actualizar el Excel del día en Drive
  (escritura) debe hacerse de forma idéntica a la local (sobrescribir el archivo
  completo) o existe algún comportamiento diferencial deseado?

## 12) Notas para análisis técnico

- **Dependencia crítica**: Los repositorios de `orders_today`, `orders_history`
  y `home/dashboard` actualmente reciben un `String workFolderPath` y construyen
  rutas locales. El cambio implica sustituir ese parámetro por identificadores
  de carpeta de Google Drive (`folderId`, `historicoFolderId`, etc.) y usar la
  API de Drive en lugar de `dart:io` (`File`, `Directory`).
- **Datasource remoto existente**: Ya existe `GoogleDriveRemoteDataSource` con
  operaciones de listado y verificación de carpetas. Se necesitará ampliar con
  operaciones de lectura de contenido de archivo, copia de archivo y
  escritura/subida de archivo.
- **Servicio de auth existente**: `GoogleAuthService` ya maneja tokens OAuth y
  refresh. Los datasources de las features deberán obtener el client autenticado
  a través de este servicio.
- **`SaveAsNewExcel` use case**: revisar su implementación actual (import
  visible en `orders_today_page.dart`) ya que probablemente usa `dart:io` para
  escribir archivos y deberá adaptarse a Drive.
- **`file_picker` en `pubspec.yaml`**: verificar si se usa en algún otro lugar
  antes de eliminarlo. Si solo se usaba en `WorkFolderCubit`, puede retirarse.
- **Entitlements macOS**: evaluar si `files.user-selected.read-write` puede
  eliminarse si ya no se accede al sistema de archivos local para selección de
  carpetas. El entitlement `network.client` debe mantenerse.
- **Rendimiento**: las lecturas a Drive son asíncronas y con latencia de red. El
  Dashboard actualmente lee múltiples archivos en paralelo (`_readSheetSafe`
  para hoy, ayer, semanas, meses) — considerar estrategia de paralelización de
  llamadas a Drive y posible throttling de la API.
- **Estado: Listo para análisis técnico**
