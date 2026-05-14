# Functional Analysis: Selector de origen de Pedidos de hoy

- **Fecha:** 2026-05-09
- **Identificador:** orders-today-source-selector
- **Estado:** Ready for technical analysis

## 1) Resumen

Al pulsar el ítem "Pedidos de hoy" en el menú lateral, se mostrará un diálogo
que permite al usuario elegir entre abrir los pedidos gestionados por la
aplicación (flujo actual con Firestore) o abrir una hoja de cálculo de Google
Drive. Si elige la segunda opción, se le presentará un selector para elegir la
hoja de cálculo deseada. La validación de estructura de la hoja seleccionada
queda fuera de alcance de esta iteración.

## 2) Contexto y objetivo

### Qué se solicita

Intercalar un diálogo de selección de origen antes de navegar a la pantalla de
"Pedidos de hoy". Actualmente, pulsar el ítem del menú lateral navega
directamente a `OrdersTodayPage`, que muestra los datos desde Firestore. Se
quiere añadir una segunda vía: permitir al usuario abrir una hoja de cálculo de
Google Drive para consultar los pedidos desde allí.

### Qué problema resuelve

- El usuario puede necesitar consultar pedidos que están en hojas de cálculo de
  Google Drive (por ejemplo, datos históricos aún no migrados, hojas compartidas
  por terceros o flujos paralelos).
- Actualmente no hay forma desde "Pedidos de hoy" de acceder a hojas de cálculo
  externas; el menú solo conduce al flujo gestionado por la aplicación.

### Qué resultado funcional se espera

- El usuario tiene la opción explícita de elegir su fuente de datos cada vez que
  accede a "Pedidos de hoy".
- Si elige la opción de la aplicación, el flujo permanece idéntico al actual.
- Si elige la opción de Google Drive, se le presenta un selector de hojas de
  cálculo y, tras elegir una, se abre (el comportamiento posterior a la
  selección se definirá en una iteración futura).

## 3) Alcance

### En alcance

- **Diálogo de selección de origen**: se muestra al pulsar "Pedidos de hoy" en
  el menú lateral.
- **Opción 1 — Pedidos de hoy (aplicación)**: navega a la pantalla actual
  (`OrdersTodayPage`) sin cambios.
- **Opción 2 — Hoja de cálculo de Google Drive**: abre un selector que permite
  al usuario navegar y elegir una hoja de cálculo (spreadsheet) de Google Drive.
- **Selector de hojas de cálculo**: muestra las hojas de cálculo disponibles en
  la carpeta configurada de Google Drive del usuario (o en la raíz si no hay
  carpeta configurada).
- **Cancelación del diálogo**: si el usuario cierra el diálogo sin elegir,
  permanece en la pantalla actual (no navega).

### Fuera de alcance

- Validación de la estructura/plantilla de la hoja de cálculo seleccionada (se
  abordará en una iteración posterior).
- Visualización o procesamiento del contenido de la hoja de cálculo seleccionada
  (esta iteración llega solo hasta la selección).
- Edición de datos en la hoja de cálculo desde la aplicación.
- Creación de nuevas hojas de cálculo desde este flujo.
- Cambios en la pantalla actual de `OrdersTodayPage`.

## 4) Actores implicados

- **Usuario operador**: persona que gestiona los pedidos del día. Interactúa con
  el menú lateral y decide la fuente de datos.

## 5) Requisitos funcionales

- **RF-01**: Al pulsar el ítem "Pedidos de hoy" del menú lateral, se mostrará un
  diálogo modal con dos opciones claramente diferenciadas.
- **RF-02**: La primera opción del diálogo será "Pedidos de hoy (aplicación)" (o
  equivalente i18n). Al seleccionarla, se navegará a la pantalla
  `OrdersTodayPage` actual sin alteraciones.
- **RF-03**: La segunda opción del diálogo será "Abrir desde hoja de cálculo" (o
  equivalente i18n). Al seleccionarla, se iniciará el flujo de selección de hoja
  de cálculo.
- **RF-04**: El selector de hojas de cálculo mostrará los archivos de tipo
  Google Spreadsheet disponibles en Google Drive del usuario (dentro de la
  carpeta configurada en ajustes, si existe).
- **RF-05**: El usuario podrá seleccionar una hoja de cálculo de la lista. En
  esta iteración, tras la selección, se confirmará al usuario qué hoja ha
  seleccionado (sin procesamiento posterior).
- **RF-06**: Si el usuario cierra el diálogo de selección de origen (botón
  cerrar / tap fuera), no se producirá navegación y permanecerá en la pantalla
  actual.
- **RF-07**: Si el usuario cancela el selector de hojas de cálculo, volverá al
  diálogo de selección de origen o permanecerá en la pantalla actual.
- **RF-08**: Si Google Drive no está configurado (no hay cuenta autenticada ni
  carpeta seleccionada en ajustes), la opción de "Abrir desde hoja de cálculo"
  mostrará un mensaje indicando que es necesario configurar Google Drive en
  ajustes.

## 6) Criterios de aceptación

- **CA-01**: Al pulsar "Pedidos de hoy" en el menú lateral aparece un diálogo
  con exactamente dos opciones visibles.
- **CA-02**: Al seleccionar "Pedidos de hoy (aplicación)", se muestra la
  pantalla `OrdersTodayPage` actual y el diálogo se cierra.
- **CA-03**: Al seleccionar "Abrir desde hoja de cálculo" con Google Drive
  configurado, se muestra una lista de hojas de cálculo disponibles en la
  carpeta de Drive configurada.
- **CA-04**: Al seleccionar una hoja de cálculo de la lista, se confirma al
  usuario la selección (nombre del archivo e ID).
- **CA-05**: Al cerrar el diálogo sin elegir, el usuario permanece en la
  pantalla donde estaba antes de pulsar el ítem del menú.
- **CA-06**: Si Google Drive no está configurado y se pulsa "Abrir desde hoja de
  cálculo", se muestra un mensaje informativo que guía al usuario a la sección
  de Ajustes.
- **CA-07**: Todos los textos visibles al usuario están internacionalizados
  (i18n).

## 7) Flujos y comportamiento esperado

### Flujo principal — Opción aplicación

1. El usuario pulsa "Pedidos de hoy" en el menú lateral.
2. Aparece un diálogo modal con dos opciones: "Pedidos de hoy (aplicación)" y
   "Abrir desde hoja de cálculo".
3. El usuario selecciona "Pedidos de hoy (aplicación)".
4. El diálogo se cierra y se muestra `OrdersTodayPage`.

### Flujo principal — Opción hoja de cálculo

1. El usuario pulsa "Pedidos de hoy" en el menú lateral.
2. Aparece el diálogo modal con dos opciones.
3. El usuario selecciona "Abrir desde hoja de cálculo".
4. Se verifica que Google Drive esté configurado.
5. Se muestra el selector de hojas de cálculo con los spreadsheets disponibles
   en la carpeta configurada.
6. El usuario selecciona una hoja de cálculo.
7. Se confirma al usuario la selección (nombre e ID de la hoja).

### Flujos alternativos

- **FA-01 — Cancelación del diálogo**: El usuario cierra el diálogo (botón
  cerrar, Escape o tap fuera). No se navega; permanece en la pantalla actual.
- **FA-02 — Google Drive no configurado**: Al seleccionar "Abrir desde hoja de
  cálculo", si Google Drive no está configurado, se muestra un mensaje indicando
  que debe configurarlo en Ajustes. No se abre el selector de hojas.
- **FA-03 — Cancelación del selector de hojas**: El usuario cierra el selector
  de hojas de cálculo sin elegir. Vuelve al diálogo de selección de origen o
  permanece en la pantalla actual.
- **FA-04 — Sin hojas de cálculo disponibles**: El selector se muestra pero la
  lista está vacía. Se muestra un mensaje indicando que no se encontraron hojas
  de cálculo en la carpeta.

### Estados especiales / excepciones

- **Estado loading**: Mientras se cargan las hojas de cálculo de Google Drive,
  se muestra un indicador de carga dentro del selector.
- **Estado error**: Si ocurre un error al comunicarse con Google Drive (red,
  autenticación expirada, permisos), se muestra un mensaje de error con opción
  de reintentar.
- **Estado vacío**: Si la carpeta de Drive no contiene hojas de cálculo, se
  muestra un estado vacío descriptivo.
- **Sin permisos / autenticación expirada**: Se muestra un mensaje que invita al
  usuario a reconectarse en Ajustes.

## 8) Edge cases

- **EC-01**: El usuario pulsa "Pedidos de hoy" repetidamente — el diálogo no
  debe apilarse; si ya hay un diálogo abierto, no se abre otro.
- **EC-02**: El usuario está en la pantalla de "Pedidos de hoy" y vuelve a
  pulsar el ítem del menú — actualmente el `SideMenuShell` ignora pulsaciones al
  mismo índice (`if (index == state.selectedIndex) return`). Este comportamiento
  debería mantenerse o permitir reabrir el diálogo; se propone **mantener el
  comportamiento actual** (ignorar si ya está en índice 1).
- **EC-03**: Google Drive se desconecta entre la apertura del diálogo y la
  selección de "Abrir desde hoja de cálculo" — debe tratarse como "Google Drive
  no configurado" (FA-02).
- **EC-04**: La carpeta configurada en Google Drive ha sido eliminada
  externamente — el error de carpeta no encontrada se muestra en el selector.

## 9) Impacto funcional

- **Módulos afectados**:
  - `home` — `SideMenuShell`: la lógica de `onItemSelected` para índice 1 debe
    interceptarse para mostrar el diálogo.
  - `orders_today` — solo como destino de la opción 1; no se modifica
    internamente.
  - `settings` — se reutiliza la configuración de Google Drive existente y
    posiblemente el `GoogleDriveRemoteDataSource` para listar spreadsheets.
- **Impacto en usuario**: el usuario tiene un paso extra (diálogo) antes de
  acceder a "Pedidos de hoy". Esto es aceptable porque ofrece una nueva
  capacidad.
- **Impacto en experiencia de usuario**: el diálogo debe ser rápido, visualmente
  claro y fácil de descartar. Si el usuario casi siempre elige la misma opción,
  considerar en futuras iteraciones una preferencia "recordar elección".

## 10) Suposiciones

- **S-01**: El proyecto ya tiene Google Drive configurado y funcional (OAuth,
  selección de carpeta en Ajustes). Se reutilizará la infraestructura existente.
- **S-02**: El `GoogleDriveRemoteDataSource` ya dispone de
  `listSpreadsheets(String folderId)` que retorna hojas de cálculo dentro de una
  carpeta. Se usará este método.
- **S-03**: En esta iteración, el resultado de seleccionar una hoja de cálculo
  se limita a una confirmación visual (nombre + ID). El procesamiento posterior
  (validación de plantilla, visualización de datos) se definirá en iteraciones
  futuras.
- **S-04**: El diálogo de selección de origen es un diálogo modal estándar de
  Flutter (`showDialog`), no una nueva pantalla completa.

## 11) Preguntas abiertas

- **PA-01**: ¿Se desea que el diálogo tenga iconos o ilustraciones para cada
  opción, o basta con texto y un botón/tile por opción?
- **PA-02**: ¿Debe el selector de hojas de cálculo permitir navegar entre
  carpetas de Drive, o solo listar los spreadsheets de la carpeta raíz
  configurada?
- **PA-03**: Tras seleccionar la hoja de cálculo, ¿qué acción concreta debe
  realizarse en esta iteración? ¿Solo mostrar un mensaje de confirmación, o
  almacenar la selección para uso futuro?

## 12) Notas para análisis técnico

- La interceptación del ítem del menú lateral debe hacerse en
  `SideMenuShell.onItemSelected` (o en un nuevo handler) para el índice 1, antes
  de llamar a `SideMenuCubit.selectItem()`.
- Ya existe `GoogleDriveRemoteDataSource.listSpreadsheets()` que lista hojas de
  cálculo en una carpeta de Drive.
- La configuración de Google Drive (cuenta, carpeta raíz, subcarpetas) se lee
  desde `SettingsLocalDataSource` / `GoogleDriveConfig`.
- El `NavigationGuard` existente (para cambios no guardados) debe seguir
  funcionando correctamente con el nuevo flujo.
- Los textos del diálogo y del selector deben añadirse al archivo ARB de i18n.
- **Estado: Listo para análisis técnico**
