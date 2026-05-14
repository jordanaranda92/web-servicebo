# Functional Analysis: Pantalla de Ajustes

- **Fecha:** 2026-05-06
- **Identificador:** settings-page
- **Estado:** Ready for technical analysis

## 1) Resumen

Implementar el contenido funcional de la pantalla de Ajustes (actualmente un
placeholder) con tres bloques de configuración: carpeta de trabajo local, copia
de seguridad en Google Drive y cuenta de FacturaDirecta.

## 2) Contexto y objetivo

- **Qué se solicita:** Reemplazar el placeholder actual de la pantalla de
  Ajustes por una interfaz con tres secciones de configuración que permitan al
  usuario gestionar la carpeta local de trabajo, la carpeta remota de Google
  Drive para backups y las credenciales de la API de FacturaDirecta.
- **Qué problema resuelve:** Actualmente no hay forma de configurar dónde se
  almacenan los ficheros Excel de pedidos, ni de activar la copia de seguridad
  remota, ni de conectar con FacturaDirecta para el volcado de pedidos vía API.
- **Resultado funcional esperado:** El usuario puede configurar y persistir los
  tres ajustes desde la pantalla de Ajustes. Las demás funcionalidades de la
  aplicación (generación de Excel, backup, volcado a FacturaDirecta) podrán
  consumir estos ajustes para operar.

## 3) Alcance

### En alcance

- UI de la pantalla de Ajustes con tres secciones diferenciadas
- **Sección 1 — Carpeta de trabajo:** seleccionar una carpeta local donde se
  guardarán los ficheros Excel (el de hoy y los históricos con nombre
  `yyyy-mm-dd.xlsx`)
- **Sección 2 — Google Drive:** configurar una carpeta remota de Google Drive
  para almacenar copias de seguridad de los Excel, seleccionando la carpeta
  destino mediante un flujo de selección con la API de Google Drive
- **Sección 3 — FacturaDirecta:** configurar las credenciales/cuenta de
  FacturaDirecta para el volcado de pedidos vía API
- Persistencia local de los ajustes (que sobrevivan al cierre de la app)
- Validación básica de los campos antes de guardar
- Feedback visual al usuario tras guardar exitosamente o ante errores de
  validación

### Fuera de alcance

- Generación o escritura real de los ficheros Excel (es responsabilidad de otra
  feature)
- Sincronización efectiva con Google Drive (subida/descarga de archivos)
- Llamadas reales a la API de FacturaDirecta (volcado de pedidos)
- Gestión de permisos de sistema de archivos a nivel de SO

## 4) Actores implicados

- **Usuario final (operador):** Persona que usa la aplicación de escritorio para
  gestionar pedidos. Es quien configura los ajustes.

## 5) Requisitos funcionales

### Sección: Carpeta de trabajo

- **RF-01:** El usuario puede seleccionar una carpeta local del sistema de
  archivos como carpeta de trabajo.
- **RF-02:** La ruta de la carpeta seleccionada se muestra en la UI una vez
  seleccionada.
- **RF-03:** Si ya hay una carpeta configurada previamente, se muestra su ruta
  al abrir la pantalla.
- **RF-04:** El usuario puede cambiar la carpeta de trabajo en cualquier momento
  seleccionando otra.
- **RF-05:** La ruta seleccionada se persiste localmente para futuras sesiones.

### Sección: Google Drive

- **RF-06:** El usuario puede autenticarse con su cuenta de Google mediante un
  flujo OAuth.
- **RF-07:** Tras autenticarse, el usuario puede navegar y seleccionar una
  carpeta de Google Drive como destino de las copias de seguridad, mediante un
  flujo de selección proporcionado por la API de Google Drive.
- **RF-08:** La configuración de Google Drive (credenciales OAuth y carpeta
  seleccionada) se persiste localmente.
- **RF-09:** El usuario puede ver el estado actual de la configuración: cuenta
  conectada, nombre de la carpeta seleccionada, o estado "no configurada".
- **RF-10:** El usuario puede eliminar la configuración de Google Drive
  (desconectar cuenta y borrar carpeta seleccionada).

### Sección: FacturaDirecta

- **RF-11:** El usuario puede introducir dos campos para configurar
  FacturaDirecta: **subdominio de cuenta** (slug) y **API token**. La URL base
  se construye como `https://{subdominio}.facturadirecta.com/api`.
- **RF-12:** Las credenciales de FacturaDirecta (subdominio y API token) se
  persisten de forma local.
- **RF-13:** El usuario puede ver si la cuenta de FacturaDirecta está
  configurada o no (mostrando el subdominio cuando está configurada).
- **RF-14:** El usuario puede verificar la conexión con FacturaDirecta (test de
  conectividad básico mediante llamada HTTP con autenticación Basic Auth usando
  el API token).
- **RF-15:** El usuario puede eliminar la configuración de FacturaDirecta
  (desconectar).

### General

- **RF-16:** Cada sección se presenta visualmente separada con un encabezado
  descriptivo.
- **RF-17:** Cada sección tiene su propio botón "Guardar" independiente.

## 6) Criterios de aceptación

- **CA-01:** Al abrir la pantalla de Ajustes, se muestran las tres secciones
  (Carpeta de trabajo, Google Drive, FacturaDirecta).
- **CA-02:** Al pulsar el botón/control de seleccionar carpeta de trabajo, se
  abre un selector de directorios del sistema operativo.
- **CA-03:** Tras seleccionar una carpeta, la ruta se muestra en pantalla y
  queda persistida.
- **CA-04:** Al cerrar y reabrir la aplicación, la carpeta de trabajo
  previamente configurada se muestra correctamente.
- **CA-05:** El usuario puede introducir la configuración de Google Drive y al
  guardar se persiste correctamente.
- **CA-06:** El usuario puede introducir las credenciales de FacturaDirecta y al
  guardar se persisten correctamente.
- **CA-07:** Al pulsar "Verificar conexión" en FacturaDirecta, se muestra un
  indicador de resultado (éxito o error con mensaje).
- **CA-08:** Al pulsar "Desconectar" en Google Drive o FacturaDirecta, la
  configuración se borra y la sección vuelve al estado "no configurada".
- **CA-09:** Si el usuario intenta guardar sin datos obligatorios, se muestra un
  mensaje de validación.
- **CA-10:** Todos los textos visibles al usuario están internacionalizados
  (i18n).

## 7) Flujos y comportamiento esperado

### Flujo principal — Configurar carpeta de trabajo

1. El usuario navega a Ajustes desde el menú lateral.
2. La pantalla muestra las tres secciones; la sección "Carpeta de trabajo"
   muestra la ruta actual o un estado "no configurada".
3. El usuario pulsa el botón para seleccionar carpeta.
4. Se abre el selector de directorios nativo del SO.
5. El usuario selecciona una carpeta y confirma.
6. La ruta seleccionada se muestra en la UI.
7. La configuración se persiste automáticamente al seleccionar la carpeta.

### Flujo principal — Configurar Google Drive

1. El usuario localiza la sección "Google Drive" en la pantalla de Ajustes.
2. Pulsa "Conectar con Google Drive".
3. Se inicia el flujo de autenticación OAuth con Google.
4. Tras autenticarse exitosamente, se muestra la cuenta conectada.
5. El usuario pulsa "Seleccionar carpeta".
6. La aplicación muestra un selector/navegador de carpetas de Google Drive
   obtenido mediante la API.
7. El usuario selecciona la carpeta destino y confirma.
8. La aplicación persiste la configuración (tokens OAuth y carpeta
   seleccionada).
9. Se muestra el nombre de la carpeta seleccionada y el estado "Conectado".

### Flujo principal — Configurar FacturaDirecta

1. El usuario localiza la sección "FacturaDirecta" en la pantalla de Ajustes.
2. Introduce el **subdominio de cuenta** (slug) y el **API token**.
3. Pulsa "Guardar".
4. La aplicación valida y persiste la configuración.
5. Opcionalmente, el usuario pulsa "Verificar conexión".
6. La aplicación hace una llamada de prueba a la API y muestra el resultado.

### Flujos alternativos

- **FA-01 — Cancelar selección de carpeta:** El usuario abre el selector de
  directorios pero cancela. No se modifica la configuración actual.
- **FA-02 — Cambiar carpeta de trabajo:** El usuario repite el flujo principal
  de selección y la nueva ruta reemplaza a la anterior.
- **FA-03 — Desconectar Google Drive:** El usuario pulsa "Desconectar", se borra
  la configuración y la sección vuelve a estado inicial.
- **FA-04 — Desconectar FacturaDirecta:** Mismo comportamiento que FA-03 para
  esta sección.
- **FA-05 — Verificación de conexión fallida:** Se muestra un mensaje de error
  indicando la causa (credenciales inválidas, error de red, etc.).

### Estados especiales / excepciones

- **Estado vacío (primera vez):** Las tres secciones aparecen en estado "no
  configurada" con indicaciones claras de qué hacer.
- **Estado loading/procesando:** Al verificar conexión con FacturaDirecta se
  muestra un indicador de carga.
- **Estado error:** Si la verificación de conexión falla, se muestra el error.
  Si la persistencia local falla, se notifica al usuario.
- **Carpeta inexistente:** Si la carpeta de trabajo configurada previamente ya
  no existe en disco, se informa al usuario y se solicita nueva selección.

## 8) Edge cases

- **EC-01:** La carpeta de trabajo configurada fue eliminada del sistema de
  archivos entre sesiones. La app debe detectarlo y avisar al usuario.
- **EC-02:** El usuario introduce caracteres especiales o rutas inválidas
  manualmente (si se permite entrada manual). Se debe validar.
- **EC-03:** Pérdida de conectividad durante la verificación de conexión con
  FacturaDirecta. Se debe manejar con timeout y mensaje de error.
- **EC-04:** Credenciales de FacturaDirecta con formato incorrecto. Validación
  antes de guardar.
- **EC-05:** El usuario cambia la carpeta de trabajo mientras hay procesos de
  generación de Excel en curso (si aplica en el futuro). La configuración solo
  debe aplicarse a operaciones futuras.
- **EC-06:** Datos de Google Drive parcialmente configurados (ej: carpeta sin ID
  válido). Validar completitud antes de guardar.

## 9) Impacto funcional

- **Módulos afectados:**
  - Feature `settings`: pasa de placeholder a funcionalidad real (impacto
    directo).
  - Futuras features de generación de Excel: consumirán la carpeta de trabajo.
  - Futura feature de backup a Google Drive: consumirá la configuración de
    carpeta remota.
  - Futura feature de volcado a FacturaDirecta: consumirá las credenciales
    configuradas.
- **Impacto en usuario:** El usuario obtiene control sobre dónde se almacenan
  sus datos y cómo se integran con servicios externos.
- **Impacto en experiencia de usuario:** La pantalla de Ajustes deja de ser un
  placeholder y se convierte en un punto central de configuración de la app.

## 10) Suposiciones

- **S-01:** La aplicación se ejecuta en entorno de escritorio (macOS/Windows)
  donde es posible acceder al sistema de archivos local y abrir un selector de
  directorios nativo.
- **S-02:** FacturaDirecta expone una API REST autenticada mediante HTTP Basic
  Auth. Los campos requeridos son: subdominio de cuenta (slug) y API token. La
  URL base sigue el patrón `https://{subdominio}.facturadirecta.com/api`.
- **S-03:** La configuración de Google Drive incluye autenticación OAuth y
  selección de carpeta destino mediante la API de Google Drive. La subida real
  de archivos es responsabilidad de otra feature.
- **S-04:** Las credenciales sensibles (API key de FacturaDirecta) se almacenan
  localmente. En esta fase no se requiere cifrado adicional más allá de lo que
  ofrece el mecanismo de almacenamiento local (shared_preferences o similar).
- **S-05:** Los textos de la pantalla se incorporarán al sistema de i18n
  existente (ARB files).
- **S-06:** La carpeta de trabajo se selecciona mediante un diálogo de selección
  de directorio, no mediante entrada manual de texto libre.

## 11) Preguntas abiertas

- Todas las preguntas han sido resueltas.

## 12) Notas para análisis técnico

- La feature `settings` ya existe con la estructura
  `lib/features/settings/presentation/pages/settings_page.dart` (placeholder).
  Se necesitan capas `data/` y `domain/` además de ampliar `presentation/`.
- La app usa Clean Architecture feature-first con BLoC, GetIt y fpdart.
- Para la selección de carpeta de trabajo será necesario un paquete de file
  picker compatible con desktop (ej: `file_picker`).
- La persistencia local puede apoyarse en `shared_preferences` (ya en pubspec)
  para valores simples, pero evaluar si las credenciales sensibles (API token de
  FacturaDirecta, tokens OAuth de Google) requieren `flutter_secure_storage` o
  similar.
- La verificación de conexión con FacturaDirecta implicará una llamada HTTP GET
  con Basic Auth al endpoint `https://{subdominio}.facturadirecta.com/api` (el
  proyecto ya usa `dio`).
- Para Google Drive se necesitará integrar la API de Google Drive (paquete
  `googleapis` / `google_sign_in` o equivalente desktop) para el flujo OAuth y
  la selección de carpetas.
- Cada sección tendrá su propio botón "Guardar" independiente.
- Los textos internacionalizados deben añadirse a los ficheros ARB existentes.
- La pantalla se renderiza dentro del `IndexedStack` del `SideMenuShell`, por lo
  que no necesita navegación adicional (ya está integrada en el índice 3).
- **Estado: Listo para análisis técnico**
