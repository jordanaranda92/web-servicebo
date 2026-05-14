# Functional Analysis: Mejoras en pantalla Pedidos de Hoy

- **Fecha:** 2026-05-13
- **Identificador:** orders-today-improvements
- **Estado:** Ready for technical analysis

## 1) Resumen

Se solicitan tres modificaciones en la pantalla "Pedidos de hoy" y su entorno de
configuración:

1. **Badge de usuario conectado**: Mostrar el `userName` del usuario (almacenado
   en la colección Firestore de usuarios) en lugar del email.
2. **Placeholder para pantallas pequeñas**: Cuando se accede desde un
   dispositivo con pantalla reducida (móvil), mostrar un mensaje indicando que
   la funcionalidad solo está disponible en pantallas de mayor tamaño.
3. **Serie de factura en Firestore**: Migrar el almacenamiento de la letra de
   serie de facturas de Factura Directa desde SharedPreferences (local) a una
   colección Firestore `factura_directa_configuration`, de modo que el valor sea
   compartido entre todos los usuarios/dispositivos. El valor se utiliza al
   generar facturas provisionales.

## 2) Contexto y objetivo

- **Qué se solicita**: Tres mejoras funcionales para la pantalla de pedidos del
  día y el módulo de ajustes.
- **Qué problema resuelve**:
  - El badge inferior muestra actualmente el email del usuario conectado, que es
    menos legible y no personalizado. Mostrar el nombre mejora la experiencia.
  - La pantalla de pedidos es una tabla compleja con edición colaborativa que no
    es funcional en dispositivos móviles. Se necesita comunicar esto al usuario
    de forma clara.
  - La serie de factura se almacena localmente (SharedPreferences), lo que
    provoca que cada dispositivo o navegador tenga su propia configuración. Al
    ser un dato de negocio compartido (la serie que identifica las facturas en
    Factura Directa), debe residir en Firestore para que todos los usuarios
    trabajen con el mismo valor.
- **Resultado funcional esperado**: Mejora de UX en identificación de usuario,
  bloqueo informativo en móvil, y configuración centralizada de serie de
  factura.

## 3) Alcance

### En alcance

- RF-01: Cambiar el badge de usuario conectado en el footer de "Pedidos de hoy"
  para mostrar `userName` en lugar del email.
- RF-02: Mostrar un placeholder informativo en "Pedidos de hoy" cuando el ancho
  de pantalla sea ≤ breakpoint móvil (768 px).
- RF-03: Migrar el almacenamiento de la serie de factura de SharedPreferences a
  Firestore (colección `factura_directa_configuration`).
- RF-04: El campo de serie en la pantalla de Ajustes debe leer y escribir en
  Firestore.
- RF-05: La generación de factura provisional debe leer la serie desde
  Firestore. Si no existe o está vacía, se interrumpe el proceso y se informa al
  usuario de que debe configurarla en Ajustes.

### Fuera de alcance

- Adaptar la tabla de pedidos completa para uso en móvil (solo se muestra
  placeholder).
- Modificar la lógica de presencia/colaboración en tiempo real.
- Cambiar la lógica de generación de facturas más allá de la fuente de la serie.
- Migración de datos existentes en SharedPreferences a Firestore (se asume que
  el usuario re-introduce el valor una vez).

## 4) Actores implicados

- **Usuario final (empleado/admin)**: Interactúa con la pantalla de pedidos y la
  de ajustes.
- **Sistema (Firestore)**: Almacena la configuración de serie de factura de
  forma centralizada.
- **API Factura Directa**: Consumidora del valor de serie al crear facturas
  provisionales.

## 5) Requisitos funcionales

- **RF-01**: El badge de usuario conectado en el footer de la pantalla "Pedidos
  de hoy" debe mostrar el `userName` del usuario (proveniente de la colección de
  usuarios en Firestore), no el email.
- **RF-02**: Si el ancho de pantalla es ≤ 768 px (breakpoint móvil existente),
  la pantalla "Pedidos de hoy" debe mostrar un placeholder centrado con un icono
  y un mensaje indicando que esta funcionalidad solo está disponible para
  pantallas de mayor tamaño. No se debe renderizar la tabla ni el footer en este
  caso.
- **RF-03**: En la pantalla de Ajustes, la sección "Factura Directa" debe
  almacenar y leer la serie de factura desde un documento en la colección
  Firestore `factura_directa_configuration`. La estructura del documento debe
  contener al menos el campo `invoiceSeries` (String).
- **RF-04**: El valor de la serie almacenado en Firestore debe ser el que se
  utilice al generar una factura provisional (use case
  `CreateProvisionalInvoice`).
- **RF-05**: Si no existe configuración en Firestore (primer uso o documento
  inexistente), se debe usar un valor por defecto razonable (actualmente `"B"`)
  y/o mostrar al usuario que debe configurarlo.

## 6) Criterios de aceptación

- **CA-01**: Al acceder a "Pedidos de hoy", el badge en el footer muestra el
  nombre del usuario (ej. "Jordán") y no el email (ej.
  "jordan.aranda@servicebo.com").
- **CA-02**: Si otro usuario está conectado, su badge también muestra su
  `userName`, no su email.
- **CA-03**: Accediendo desde un dispositivo con pantalla ≤ 768 px, se muestra
  un placeholder con icono y mensaje informativo. No se muestra la tabla de
  pedidos.
- **CA-04**: En Ajustes, al modificar la serie de factura y guardar, el valor se
  persiste en Firestore en la colección `factura_directa_configuration`.
- **CA-05**: Al generar una factura provisional, la serie utilizada corresponde
  al valor almacenado en Firestore, no al valor local de SharedPreferences.
- **CA-06**: Si dos usuarios acceden a Ajustes, ambos ven el mismo valor de
  serie de factura (dato centralizado).
- **CA-07**: Si no existe el documento de configuración en Firestore, el campo
  en Ajustes aparece vacío. Al intentar generar una factura provisional sin
  serie configurada, se muestra un error informando al usuario que debe
  configurarla en Ajustes.

## 7) Flujos y comportamiento esperado

### Flujo principal — Badge de usuario

1. El usuario accede a "Pedidos de hoy".
2. El sistema carga el `userName` del usuario autenticado desde la colección de
   usuarios en Firestore.
3. El footer muestra un badge con el `userName` del usuario conectado y su color
   asignado.
4. Si hay otros usuarios conectados, cada badge remoto muestra el `userName`
   correspondiente.

### Flujo principal — Placeholder móvil

1. El usuario accede a "Pedidos de hoy" desde un dispositivo con pantalla ≤ 768
   px.
2. En lugar de la tabla de pedidos, se muestra un placeholder centrado con:
   - Un icono representativo (ej. `Icons.desktop_windows_outlined` o similar).
   - Un texto indicando que esta funcionalidad solo está disponible en pantallas
     de mayor tamaño.
3. No se renderiza la tabla, el footer, ni los controles de acción.

### Flujo principal — Serie de factura en Firestore

1. El usuario accede a Ajustes > Factura Directa.
2. El sistema lee el valor de serie desde Firestore
   (`factura_directa_configuration`).
3. El campo de texto muestra el valor actual (ej. "B").
4. El usuario modifica el valor (ej. "A") y pulsa guardar.
5. El sistema persiste el nuevo valor en Firestore.
6. Se muestra feedback de éxito.

### Flujo principal — Uso de la serie al generar factura

1. El usuario, desde "Pedidos de hoy", selecciona un cliente y decide generar
   una factura provisional.
2. El sistema lee la serie de factura desde Firestore.
3. Se construye el body de la factura con la serie obtenida.
4. Se envía a la API de Factura Directa.

### Flujos alternativos

- **FA-01**: Si el `userName` del usuario no está configurado (es `null`), el
  badge debe mostrar el email como fallback.
- **FA-02**: Si la lectura de Firestore falla al obtener la serie, se informa al
  usuario del error. No se usa fallback local.
- **FA-03**: Si la escritura en Firestore falla al guardar la serie, se muestra
  un mensaje de error al usuario.
- **FA-04**: Si al generar una factura provisional no existe el valor de serie
  en Firestore (documento inexistente o campo vacío), se interrumpe el proceso y
  se informa al usuario de que debe configurar la serie en Ajustes antes de
  generar facturas.

### Estados especiales / excepciones

- **Estado vacío**: No existe el documento en `factura_directa_configuration` →
  el campo en Ajustes aparece vacío; al generar factura, se muestra error
  indicando que debe configurar la serie primero.
- **Estado loading**: Mientras se carga la serie desde Firestore, el campo de
  texto en ajustes muestra un indicador de carga o se deshabilita temporalmente.
- **Estado error**: Si Firestore no es accesible, se muestra error tanto en
  Ajustes como al intentar generar factura.
- **Sin permisos**: No aplica (cualquier usuario autenticado puede leer/escribir
  la configuración).

## 8) Edge cases

- **EC-01**: El `userName` contiene caracteres especiales o es muy largo → el
  badge debe truncar o manejar el overflow correctamente.
- **EC-02**: El usuario cambia la serie mientras otro usuario está generando una
  factura → la factura usa la serie vigente en el momento de la lectura
  (eventual consistency es aceptable).
- **EC-03**: El campo de serie se deja vacío → validación: no permitir guardar
  serie vacía (ya implementado en el widget actual).
- **EC-04**: Redimensionamiento de ventana en desktop: si el usuario reduce el
  ancho del navegador por debajo de 768 px, la pantalla debe cambiar a
  placeholder en tiempo real (reactive con `MediaQuery`).
- **EC-05**: El usuario tiene el valor antiguo en SharedPreferences pero no en
  Firestore → SharedPreferences ya no se usa para este campo; el usuario debe
  configurar la serie en Firestore desde Ajustes.

## 9) Impacto funcional

- **Módulos afectados**:
  - `orders_today` — presentación (footer badge + placeholder móvil).
  - `settings` — presentación y datos (migración de almacenamiento de serie).
  - `invoices` — dominio (lectura de serie desde nueva fuente).
- **Impacto en usuario**: Mejora de legibilidad del badge, comunicación clara de
  limitaciones en móvil, consistencia en la configuración de serie entre
  dispositivos.
- **Impacto en experiencia de usuario**: Positivo en los tres cambios. El
  placeholder evita confusión en móvil; el nombre en badge es más personal; la
  serie centralizada evita inconsistencias.

## 10) Suposiciones

- El `userName` ya está almacenado correctamente en Firestore para cada usuario
  y se carga al autenticarse (la entidad `AppUser` ya tiene el campo
  `userName`).
- El valor `userName` ya se propaga al `OrdersPresenceCubit` (confirmado en el
  código: el cubit recibe `userName` como parámetro).
- El breakpoint de 768 px ya está definido como `AppSideMenu.mobileBreakpoint` y
  se usa en otras pantallas para la misma decisión responsive.
- La colección `factura_directa_configuration` usa un documento con ID fijo
  `"default"` (app mono-empresa). **Decisión confirmada.**
- Todos los usuarios autenticados tienen permiso de lectura/escritura en dicha
  colección (o se configurarán las reglas de seguridad de Firestore).
- SharedPreferences se elimina como fuente de datos para la serie de factura.
  **Decisión confirmada.**
- El usuario debe re-introducir manualmente el valor de serie en Firestore desde
  Ajustes. No hay migración automática. **Decisión confirmada.**

## 11) Preguntas abiertas

Todas las preguntas han sido resueltas:

- ~~**PA-01**~~: **Resuelto** — Se usa ID fijo `"default"`.
- ~~**PA-02**~~: **Resuelto** — El usuario re-introduce el valor manualmente. Si
  no existe al generar factura, se informa al usuario.
- ~~**PA-03**~~: **Resuelto** — Se elimina el uso de SharedPreferences para la
  serie de factura.

## 12) Notas para análisis técnico

- El `OrdersPresenceCubit` ya recibe `userName` y lo usa en los cursores
  remotos. El badge en el footer (`OrdersTableFooter`) ya accede a
  `presenceCubit.userName`. Verificar qué valor se pasa realmente al construir
  el cubit (¿email o userName real?).
- El placeholder móvil puede implementarse con el mismo patrón que `PageHeader`,
  que ya comprueba
  `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.
- La serie de factura se elimina de
  `SharedPreferences`/`SettingsLocalDataSource`. Se necesita un nuevo datasource
  remoto para Firestore (colección `factura_directa_configuration`, documento
  `"default"`, campo `invoiceSeries`) y actualizar el `SettingsRepository`.
- `CreateProvisionalInvoice` ya depende de
  `SettingsRepository.getInvoiceSeries()`. Al cambiar la fuente a Firestore, el
  método pasa a ser asíncrono. Además, debe validar que el valor exista y no
  esté vacío; si no, emitir un `ConfigNotFoundFailure` (ya existe este tipo de
  failure en el código).
- Las reglas de seguridad de Firestore deben permitir lectura/escritura en
  `factura_directa_configuration` para usuarios autenticados.
- i18n: se necesitan nuevas claves de traducción para el mensaje del placeholder
  móvil.
- **Estado: Listo para análisis técnico**
