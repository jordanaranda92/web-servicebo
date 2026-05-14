# Functional Analysis: Configuración de acceso a Google Drive para Google Sheets

- **Fecha:** 2026-05-07
- **Identificador:** google-drive-config
- **Estado:** Ready for technical analysis
- **Revisión:** v2 — preguntas abiertas resueltas

## 1) Resumen

Permitir al usuario configurar el acceso a su cuenta de Google Drive desde la
sección de Ajustes, de modo que la aplicación pueda acceder a un directorio
específico dentro de Google Drive donde se encuentran los Google Sheets de:
pedidos del día, histórico de pedidos y plantilla. Esta configuración sustituye
el enfoque actual basado en archivos Excel locales por uno basado en Google
Sheets compartidos en la nube, habilitando el trabajo colaborativo en tiempo
real (varios operadores editando simultáneamente el mismo Google Sheet).

## 2) Contexto y objetivo

- **Qué se solicita:** Que el usuario pueda autenticarse con su cuenta de Google
  y seleccionar un directorio de Google Drive que contenga los Google Sheets de
  trabajo: el archivo de pedidos de hoy, los archivos históricos y la plantilla
  base.
- **Qué problema resuelve:** Actualmente los análisis de "Pedidos de hoy" y
  "Historial de pedidos" están diseñados para leer archivos Excel locales del
  sistema de ficheros. Sin embargo, el flujo real de trabajo de Servicebo se
  basa en un Google Sheet compartido en Google Drive donde hasta 3 personas
  trabajan simultáneamente. Configurar el acceso a Google Drive permite que la
  aplicación lea (y potencialmente escriba) directamente los Google Sheets,
  eliminando la necesidad de descargar/subir archivos Excel manualmente.
- **Qué resultado funcional se espera:** El usuario configura su cuenta de
  Google y selecciona la carpeta de Drive que contiene los Google Sheets de
  pedidos. A partir de ese momento, las features de pedidos de hoy e historial
  consumen los datos directamente desde Google Sheets. **El modo Google Drive
  reemplaza completamente al modo local (archivos Excel locales).**

## 3) Alcance

### En alcance

- Autenticación del usuario con su cuenta de Google mediante flujo OAuth 2.0
  (con los scopes necesarios para Google Drive y Google Sheets API)
- Selección de un directorio dentro de Google Drive como "carpeta de trabajo
  remota"
- Visualización del estado de conexión: cuenta conectada (email), nombre de la
  carpeta seleccionada, o estado "no configurada"
- Persistencia local de la configuración (tokens OAuth, refresh token, ID de la
  carpeta seleccionada, email de la cuenta)
- Detección automática dentro del directorio seleccionado de los tres tipos de
  Google Sheets esperados:
  - **Plantilla:** un Google Sheet con nombre fijo o convención reconocible
    (p.ej. `plantilla`)
  - **Pedidos de hoy:** un Google Sheet con nombre basado en la fecha del día
    (p.ej. `2026-05-07`)
  - **Histórico:** los demás Google Sheets con nombre de fecha en el mismo
    directorio
- Validación de que el directorio seleccionado contiene al menos la plantilla
- Posibilidad de desconectar la cuenta de Google Drive (borrar tokens y
  configuración)
- Posibilidad de cambiar la carpeta seleccionada sin desconectar la cuenta
- Integración en la pantalla de Ajustes existente, dentro de la sección "Google
  Drive" ya definida
- Renovación automática de tokens (refresh token) cuando el access token expire

### Fuera de alcance

- Lectura o escritura de los datos de los Google Sheets (responsabilidad de las
  features `orders_today` y `orders_history` en futuras iteraciones)
- Creación del Google Sheet del día a partir de la plantilla (se analizará como
  parte de la evolución de `orders_today`)
- Gestión de permisos de los Google Sheets (el usuario es responsable de
  compartir los archivos adecuadamente en Google Drive)
- Sincronización bidireccional o caché local de los datos de los Sheets
- Migración automática de archivos Excel locales existentes a Google Sheets
- Indicador visual de estado de conexión con Google Drive en otras pantallas
  (menú lateral, barra superior, etc.)
- Configuración de la carpeta de trabajo local — **el modo local queda deprecado
  y será reemplazado completamente por Google Drive**
- Configuración de FacturaDirecta (ya definida en el análisis `settings-page`)

## 4) Actores implicados

| Actor                    | Rol                                                                                      |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| Usuario final (operador) | Configura su cuenta de Google y selecciona la carpeta de Drive con los Sheets de pedidos |
| Google OAuth 2.0         | Servicio externo de autenticación que gestiona los permisos de acceso a Drive y Sheets   |
| Google Drive API         | Servicio externo que permite listar y navegar carpetas del usuario                       |
| Feature `settings`       | Pantalla donde se aloja la configuración de Google Drive                                 |

## 5) Requisitos funcionales

### Autenticación

- **RF-01:** El usuario puede iniciar un flujo de autenticación OAuth 2.0 con
  Google desde la sección "Google Drive" de la pantalla de Ajustes.
- **RF-02:** El flujo OAuth debe solicitar los scopes mínimos necesarios para:
  - Leer metadatos de archivos y carpetas en Google Drive (listar, navegar)
  - Leer y escribir Google Sheets (para que las features de pedidos puedan
    operar en el futuro)
- **RF-03:** Tras una autenticación exitosa, la aplicación debe almacenar de
  forma local y segura los tokens OAuth (access token + refresh token).
- **RF-04:** La aplicación debe renovar automáticamente el access token
  utilizando el refresh token cuando este expire, sin intervención del usuario.
- **RF-05:** Si el refresh token se revoca o invalida (por ejemplo, el usuario
  revoca permisos desde su cuenta de Google), la aplicación debe detectarlo y
  solicitar al usuario que vuelva a autenticarse.

### Selección de carpeta

- **RF-06:** Tras autenticarse, el usuario puede navegar por la estructura de
  carpetas de su Google Drive para seleccionar la carpeta que contiene los
  Google Sheets de pedidos.
- **RF-07:** El navegador de carpetas debe mostrar únicamente carpetas (no
  archivos) para facilitar la selección.
- **RF-08:** El usuario puede confirmar la selección de una carpeta. Al hacerlo,
  se persiste el ID y nombre de la carpeta seleccionada.
- **RF-09:** Al seleccionar una carpeta, la aplicación debe verificar que
  contiene las subcarpetas esperadas (`historico/`, `plantillas/`, `interno/`).
  Si alguna no existe, se muestra un aviso informativo (no bloqueante) indicando
  qué subcarpetas faltan.
- **RF-09b:** La aplicación debe verificar que la subcarpeta `plantillas/`
  contiene al menos un Google Sheet llamado `plantilla`. Si no lo contiene, se
  muestra un aviso informativo adicional.

### Visualización del estado

- **RF-10:** La sección "Google Drive" debe mostrar el estado actual de la
  configuración:
  - **No configurada:** indicación clara con botón "Conectar con Google Drive"
  - **Conectada:** email de la cuenta de Google, nombre de la carpeta
    seleccionada, y un resumen de los Google Sheets detectados en ella
    (plantilla, archivo de hoy, número de archivos históricos)
- **RF-11:** Si la cuenta está conectada pero no se ha seleccionado carpeta, se
  muestra la cuenta conectada y un botón "Seleccionar carpeta".

### Gestión de la configuración

- **RF-12:** El usuario puede cambiar la carpeta seleccionada en cualquier
  momento repitiendo el flujo de selección, sin necesidad de desconectar la
  cuenta.
- **RF-13:** El usuario puede desconectar la cuenta de Google Drive. Al hacerlo,
  se eliminan los tokens OAuth y la configuración de carpeta, y la sección
  vuelve al estado "no configurada".
- **RF-14:** La configuración completa (tokens, ID de carpeta, email de cuenta)
  se persiste localmente y sobrevive al cierre de la aplicación.

### Detección de Google Sheets en la carpeta

- **RF-15:** Una vez configurada la carpeta, la aplicación debe poder listar los
  Google Sheets contenidos en las subcarpetas e identificar:
  - **Plantilla:** Google Sheet en `plantillas/` cuyo nombre sea `plantilla`
    (case-insensitive)
  - **Pedidos de hoy:** Google Sheet en `historico/` cuyo nombre coincida con la
    fecha actual en formato `YYYY-MM-DD`
  - **Históricos:** todos los Google Sheets en `historico/` cuyo nombre siga el
    patrón `YYYY-MM-DD`
  - **Configuración interna:** Google Sheets en `interno/` (listado informativo)
- **RF-16:** Esta detección se realiza bajo demanda (al abrir Ajustes o al
  refrescar manualmente), no de forma periódica en segundo plano.

## 6) Criterios de aceptación

- **CA-01:** Al pulsar "Conectar con Google Drive" se inicia el flujo OAuth y,
  tras autenticarse correctamente, se muestra el email de la cuenta conectada.
- **CA-02:** Tras conectar la cuenta, el usuario puede navegar las carpetas de
  su Google Drive y seleccionar una como carpeta de trabajo.
- **CA-03:** Al seleccionar una carpeta, se muestra su nombre y se persiste la
  configuración.
- **CA-04:** Si la carpeta seleccionada no contiene las subcarpetas esperadas
  (`historico/`, `plantillas/`, `interno/`) o no se encuentra la plantilla en
  `plantillas/`, se muestran avisos informativos correspondientes.
- **CA-05:** Al cerrar y reabrir la aplicación, la configuración de Google Drive
  (cuenta, carpeta) se mantiene y se muestra correctamente.
- **CA-06:** Si el access token expira, la aplicación lo renueva automáticamente
  usando el refresh token sin que el usuario deba intervenir.
- **CA-07:** Al pulsar "Desconectar", se borran tokens y configuración, y la
  sección vuelve al estado "no configurada".
- **CA-08:** El usuario puede cambiar la carpeta seleccionada sin desconectar la
  cuenta.
- **CA-09:** La sección muestra un resumen de los Google Sheets detectados en
  cada subcarpeta (plantilla en `plantillas/`, archivo de hoy en `historico/`, N
  archivos históricos en `historico/`).
- **CA-10:** Todos los textos de la UI están internacionalizados (i18n).

## 7) Flujos y comportamiento esperado

### Flujo principal — Primera configuración

1. El usuario navega a Ajustes desde el menú lateral.
2. Localiza la sección "Google Drive", que muestra estado "No configurada" con
   un botón "Conectar con Google Drive".
3. Pulsa "Conectar con Google Drive".
4. Se abre el flujo de autenticación OAuth (ventana del navegador o webview).
5. El usuario selecciona su cuenta de Google e inicia sesión si es necesario.
6. Acepta los permisos solicitados (acceso a Drive y Sheets).
7. La aplicación recibe los tokens y muestra el email de la cuenta conectada.
8. Aparece un botón "Seleccionar carpeta".
9. El usuario pulsa "Seleccionar carpeta".
10. Se muestra un navegador de carpetas de Google Drive.
11. El usuario navega hasta la carpeta deseada y la selecciona.
12. La aplicación verifica la estructura de subcarpetas (`historico/`,
    `plantillas/`, `interno/`) y la presencia de la plantilla.
13. Se muestra el nombre de la carpeta, estado de las subcarpetas, estado de la
    plantilla y resumen de archivos detectados.
14. La configuración se persiste automáticamente.

### Flujo alternativo — Cambiar carpeta

1. El usuario está en Ajustes con una cuenta de Google Drive ya conectada y una
   carpeta configurada.
2. Pulsa "Cambiar carpeta".
3. Se abre el navegador de carpetas.
4. Selecciona una nueva carpeta.
5. La configuración se actualiza con la nueva carpeta.

### Flujo alternativo — Desconectar cuenta

1. El usuario pulsa "Desconectar" en la sección Google Drive.
2. Se muestra un diálogo de confirmación.
3. Si confirma, se eliminan los tokens y la configuración de carpeta.
4. La sección vuelve al estado "No configurada".

### Flujo alternativo — Error de autenticación

1. El usuario inicia el flujo OAuth.
2. Cancela el proceso o se produce un error (red, permisos denegados).
3. La aplicación muestra un mensaje de error y la sección permanece en estado
   "No configurada".

### Flujo alternativo — Token revocado

1. La aplicación intenta renovar el access token.
2. Google rechaza el refresh token (permisos revocados).
3. La sección muestra un estado "Reconexión necesaria" con un botón para volver
   a autenticarse.
4. Los datos de carpeta se mantienen para no perder la referencia; solo se
   invalidan los tokens.

### Estados especiales / excepciones

- **Estado vacío (primera vez):** Sección "Google Drive" con indicación "No
  configurada" y botón de conexión.
- **Estado loading/procesando:** Indicador de carga durante la autenticación
  OAuth, durante la navegación de carpetas y durante la verificación de
  contenido de la carpeta.
- **Estado error:** Mensaje descriptivo si falla la autenticación, la conexión
  de red o la consulta a la API de Google Drive.
- **Sin conexión a internet:** Si no hay conexión al intentar autenticarse o
  navegar carpetas, mostrar error de conectividad.
- **Carpeta eliminada en Drive:** Si la carpeta configurada fue eliminada en
  Google Drive entre sesiones, la aplicación debe detectarlo al intentar acceder
  y avisar al usuario para que seleccione otra.

## 8) Edge cases

- **EC-01:** El usuario tiene múltiples cuentas de Google. El flujo OAuth debe
  permitir elegir con qué cuenta autenticarse (comportamiento estándar de Google
  OAuth).
- **EC-02:** La carpeta seleccionada en Google Drive es eliminada o movida
  externamente. La aplicación debe detectar el error al intentar listar su
  contenido y solicitar al usuario que seleccione otra carpeta.
- **EC-03:** El usuario revoca los permisos de la aplicación desde la
  configuración de su cuenta de Google (myaccount.google.com). La aplicación
  debe manejar el rechazo del refresh token y solicitar re-autenticación.
- **EC-04:** La carpeta contiene archivos que no son Google Sheets (PDFs,
  imágenes, etc.). La detección debe ignorar archivos que no sean de tipo Google
  Sheets.
- **EC-05:** La carpeta contiene Google Sheets con nombres que coinciden
  parcialmente con el patrón de fecha (p.ej. `2026-05-07 copia`,
  `borrador-2026-05-07`). La detección debe requerir coincidencia exacta del
  patrón `YYYY-MM-DD`.
- **EC-06:** Pérdida de conectividad durante la navegación de carpetas en Google
  Drive. Mostrar error y permitir reintentar.
- **EC-07:** El directorio raíz de Google Drive es seleccionado como carpeta de
  trabajo. No se debe prohibir, pero se debe permitir (el usuario puede
  organizar sus archivos como prefiera).
- **EC-08:** Los tokens almacenados localmente se corrompen o son eliminados
  manualmente por el usuario. La aplicación debe detectar que la configuración
  es inválida y solicitar re-autenticación.

## 9) Impacto funcional

- **Módulos o procesos afectados:**
  - **Feature `settings`:** Se amplía la sección "Google Drive" para incluir la
    autenticación OAuth completa y la selección de carpeta con detección de
    Sheets. Esto sustituye y amplía los RF-06 a RF-10 del análisis
    `settings-page` del 2026-05-06.
  - **Feature `orders_today`:** Deberá adaptarse para leer el Google Sheet del
    día desde `historico/` en Google Drive, reemplazando la lectura de Excel
    local.
  - **Feature `orders_history`:** Deberá adaptarse para listar y leer los Google
    Sheets históricos desde `historico/` en Google Drive.
  - **Sección «Carpeta de trabajo» en Ajustes:** Queda deprecada. El modo local
    será reemplazado completamente por Google Drive.
  - **Core / Infraestructura:** Requerirá un servicio de Google Drive/Sheets que
    gestione autenticación, listado de archivos y lectura/escritura de Sheets.
- **Impacto en usuario:** El usuario pasa de trabajar con archivos Excel locales
  a trabajar con Google Sheets compartidos, habilitando la colaboración
  simultánea de múltiples operadores (hasta 3 personas trabajando en el mismo
  Sheet a la vez).
- **Impacto en experiencia de usuario:** Elimina la necesidad de descargar/subir
  archivos manualmente. Los datos están siempre actualizados en la nube. Se
  requiere conexión a internet para operar con los pedidos.

## 10) Suposiciones

- **S-01:** La aplicación se ejecuta en entorno de escritorio (macOS/Windows)
  donde se puede abrir un navegador o webview para el flujo OAuth 2.0 de Google.
- **S-02:** Se asume que el usuario dispone de una cuenta de Google con acceso a
  Google Drive y que los Google Sheets de pedidos ya están creados y compartidos
  en la carpeta correspondiente.
- **S-03:** La convención de nombres de los Google Sheets sigue el patrón:
  `plantilla` para la plantilla base y `YYYY-MM-DD` para los archivos de pedidos
  de cada día.
- **S-04:** Los scopes OAuth necesarios son al mínimo:
  `https://www.googleapis.com/auth/drive.readonly` (para navegar carpetas y
  listar archivos) y `https://www.googleapis.com/auth/spreadsheets` (para
  leer/escribir Sheets). El scope exacto se refinará en el análisis técnico.
- **S-05:** Los tokens OAuth se almacenan localmente de forma segura. El
  mecanismo concreto de almacenamiento seguro se decidirá en el análisis
  técnico.
- **S-06:** La estructura de la carpeta de trabajo en Google Drive tiene tres
  subcarpetas obligatorias:
  - `historico/` — Google Sheets de pedidos diarios (`YYYY-MM-DD`)
  - `plantillas/` — plantillas base (al menos `plantilla`)
  - `interno/` — otros Google Sheets de configuración interna
- **S-07:** La app necesitará un proyecto de Google Cloud con las APIs de Google
  Drive y Google Sheets habilitadas, y credenciales OAuth 2.0 configuradas
  (Client ID para aplicación de escritorio). La configuración de este proyecto
  se asume como prerequisito de infraestructura.

## 11) Preguntas abiertas

- Todas las preguntas han sido resueltas.

### Preguntas resueltas

- **PA-01 (resuelta):** El modo Google Drive reemplaza completamente al modo
  local. No se mantiene compatibilidad con archivos Excel locales.
- **PA-02 (resuelta):** No se requiere indicador visual de estado de conexión en
  otras pantallas.
- **PA-03 (resuelta):** La carpeta de Google Drive tiene estructura con tres
  subcarpetas: `historico/` (sheets de pedidos), `plantillas/` (plantillas base)
  e `interno/` (sheets de configuración interna).

## 12) Notas para análisis técnico

- La feature `settings` ya existe con la estructura Clean Architecture (`data/`,
  `domain/`, `presentation/`) en `lib/features/settings/`. El análisis previo
  (`settings-page` 2026-05-06) define la sección de Google Drive con RF-06 a
  RF-10; esta nueva especificación los amplía y detalla significativamente.
- Se necesitará un proyecto de Google Cloud Platform con OAuth 2.0 client ID
  para aplicación de escritorio, con las APIs de Drive y Sheets habilitadas.
- El almacenamiento seguro de tokens OAuth es crítico. Evaluar opciones como
  `flutter_secure_storage` o el keychain nativo del SO.
- La navegación de carpetas de Google Drive se realiza mediante la
  [Google Drive API v3](https://developers.google.com/drive/api/v3/reference)
  (`files.list` con `mimeType = 'application/vnd.google-apps.folder'` y
  `parents` para navegar la jerarquía).
- La detección de Google Sheets usa el mimeType
  `application/vnd.google-apps.spreadsheet`.
- Considerar el paquete `googleapis` de Dart para la integración con Google
  APIs, y `google_sign_in` o `extension_google_sign_in_as_googleapis_auth` para
  el flujo OAuth en escritorio.
- La renovación automática de tokens (refresh token flow) debe integrarse en la
  capa de datos/infraestructura para que sea transparente al resto de la app.
- **Fuente:** docs/functional-analysis/2026-05-06-settings-page.md
- **Estado: Listo para análisis técnico**
