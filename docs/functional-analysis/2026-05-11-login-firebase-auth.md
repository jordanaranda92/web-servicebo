# Functional Analysis: Login con Firebase Authentication

- **Fecha:** 2026-05-11
- **Identificador:** login-firebase-auth
- **Estado:** Ready for technical analysis

## 1) Resumen

Añadir una pantalla de Login a la aplicación Servicebo que permita el acceso
mediante email y contraseña usando Firebase Authentication. No habrá registro de
usuarios desde la app; las cuentas se gestionan manualmente en Firebase Console.
El nombre de usuario, actualmente almacenado en SharedPreferences, pasará a
estar en una colección de Firestore vinculada al UID del usuario autenticado. Se
incluirá funcionalidad de "Recordarme" (autologin) y un botón de "Cerrar sesión"
en la pantalla de Ajustes.

## 2) Contexto y objetivo

### Qué se solicita

- Implementar autenticación obligatoria para acceder a la aplicación.
- Pantalla de Login con diseño atractivo, mostrando el logo de la aplicación
  (`logo-servicebo.png`).
- Proveedor de autenticación: Firebase Authentication (email/password).
- Migrar el nombre de usuario de SharedPreferences a Firestore.
- Opción "Recordarme" en el Login para persistir la sesión entre reinicios.
- Botón "Cerrar sesión" en la pantalla de Ajustes.

### Qué problema resuelve

- Actualmente la aplicación es accesible sin ninguna autenticación. Cualquier
  persona con acceso al dispositivo puede usar la app.
- El nombre de usuario está almacenado localmente, lo que impide su portabilidad
  entre dispositivos y no lo vincula a una identidad real.

### Resultado funcional esperado

- Solo usuarios dados de alta manualmente en Firebase pueden acceder a la
  aplicación.
- El nombre de usuario se centraliza en Firestore y se asocia al usuario
  autenticado.
- El usuario puede elegir mantener su sesión activa entre reinicios de la app.
- El usuario puede cerrar sesión desde Ajustes.

## 3) Alcance

### En alcance

- **Pantalla de Login:** campos de email y contraseña, checkbox "Recordarme",
  botón de inicio de sesión, logo de la app.
- **Autenticación:** integración con Firebase Authentication (sign in con
  email/password).
- **Autologin:** persistencia de sesión controlada por checkbox "Recordarme"; si
  está activado, el usuario no verá la pantalla de Login en reinicios
  posteriores mientras la sesión de Firebase sea válida.
- **Colección de usuarios en Firestore:** documento por usuario (clave: UID de
  Firebase Auth) con al menos el campo `userName`.
- **Migración del nombre de usuario:** la sección de identidad en Ajustes
  (UserIdentitySection) leerá y escribirá el nombre de usuario desde/hacia
  Firestore en lugar de SharedPreferences.
- **Botón "Cerrar sesión":** en la pantalla de Ajustes, debajo del último panel,
  alineado a la derecha. Cierra la sesión de Firebase Auth, limpia el estado de
  autologin y redirige a la pantalla de Login.
- **Protección de rutas:** si el usuario no está autenticado, cualquier intento
  de acceder a la app redirige al Login.
- **Diseño de la pantalla de Login:** visualmente atractivo y llamativo,
  centrado, mostrando el logo `logo-servicebo.png`.

### Fuera de alcance

- Registro de nuevos usuarios desde la aplicación.
- Recuperación de contraseña / flujo "Olvidé mi contraseña".
- Autenticación con proveedores sociales (Google, Apple, etc.).
- Gestión de usuarios desde la aplicación (CRUD de cuentas).
- Roles o permisos diferenciados por usuario.
- Verificación de email.
- Creación automática de documentos de usuario en Firestore (se asume gestión
  manual o mediante script externo).

## 4) Actores implicados

| Actor                                | Descripción                                                                                                                              |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **Usuario final**                    | Persona que usa la aplicación Servicebo en el dispositivo. Necesita credenciales válidas para acceder.                                   |
| **Administrador (Firebase Console)** | Persona que da de alta manualmente cuentas de usuario en Firebase Authentication y crea/mantiene los documentos de usuario en Firestore. |

## 5) Requisitos funcionales

- **RF-01:** La aplicación debe mostrar una pantalla de Login como punto de
  entrada cuando el usuario no tiene sesión activa.
- **RF-02:** La pantalla de Login debe contener: logo de la aplicación
  (`logo-servicebo.png`), campo de email, campo de contraseña (con visibilidad
  togglable), checkbox "Recordarme" y botón "Iniciar sesión".
- **RF-03:** El sistema debe autenticar al usuario contra Firebase
  Authentication usando email y contraseña.
- **RF-04:** Si la autenticación es exitosa, el sistema debe navegar a la
  pantalla principal (SideMenuShell) y no debe ser posible volver atrás al
  Login.
- **RF-05:** Si la autenticación falla, el sistema debe mostrar un mensaje de
  error claro al usuario (credenciales incorrectas, usuario deshabilitado, sin
  conexión, etc.).
- **RF-06:** El checkbox "Recordarme" debe controlar la persistencia de la
  sesión. Si está marcado, al reiniciar la app el usuario accede directamente
  sin pasar por Login. Si no está marcado, cada reinicio requerirá Login.
- **RF-07:** En Firestore debe existir una colección `users` donde cada
  documento tenga como ID el UID del usuario de Firebase Auth, con al menos el
  campo `userName`.
- **RF-08:** La sección de identidad de usuario en Ajustes
  (`UserIdentitySection`) debe leer y guardar el `userName` desde/hacia
  Firestore (documento del usuario autenticado) en lugar de SharedPreferences.
- **RF-09:** La pantalla de Ajustes debe mostrar un botón "Cerrar sesión" debajo
  del último panel, alineado a la derecha.
- **RF-10:** Al pulsar "Cerrar sesión", el sistema debe: cerrar la sesión de
  Firebase Auth, desactivar el autologin (limpiar la preferencia de
  "Recordarme") y navegar a la pantalla de Login limpiando la pila de
  navegación.
- **RF-11:** La pantalla de Login debe tener un diseño visualmente atractivo y
  llamativo.
- **RF-12:** Si Firebase no está disponible (inicialización fallida), la
  pantalla de Login debe mostrar un error indicando que el servicio no está
  disponible.

## 6) Criterios de aceptación

- **CA-01:** Un usuario con credenciales válidas (email/password dados de alta
  en Firebase) puede iniciar sesión y acceder a la app.
- **CA-02:** Un usuario con credenciales inválidas ve un mensaje de error
  descriptivo y permanece en la pantalla de Login.
- **CA-03:** Con "Recordarme" activado, al cerrar y reabrir la app, el usuario
  accede directamente sin pantalla de Login.
- **CA-04:** Con "Recordarme" desactivado, al cerrar y reabrir la app, se
  muestra la pantalla de Login.
- **CA-05:** El nombre de usuario mostrado en Ajustes se lee del documento
  Firestore del usuario autenticado.
- **CA-06:** Al modificar el nombre de usuario en Ajustes, el cambio se persiste
  en Firestore.
- **CA-07:** Al pulsar "Cerrar sesión" en Ajustes, el usuario es redirigido al
  Login y no puede navegar atrás.
- **CA-08:** Tras "Cerrar sesión", un reinicio de la app muestra la pantalla de
  Login (independientemente de si "Recordarme" estaba activo).
- **CA-09:** La pantalla de Login muestra el logo `logo-servicebo.png`
  correctamente.
- **CA-10:** El campo de contraseña oculta los caracteres por defecto y permite
  alternar su visibilidad.
- **CA-11:** Sin conexión a internet, al intentar login se muestra un mensaje de
  error apropiado.

## 7) Flujos y comportamiento esperado

### Flujo principal — Inicio de sesión exitoso

1. El usuario abre la aplicación.
2. El sistema verifica si hay sesión activa de Firebase Auth Y la preferencia de
   "Recordarme" está activa.
3. **No hay sesión válida o "Recordarme" no está activo →** se muestra la
   pantalla de Login.
4. El usuario introduce email y contraseña.
5. (Opcional) El usuario marca el checkbox "Recordarme".
6. El usuario pulsa "Iniciar sesión".
7. El sistema muestra un indicador de carga.
8. Firebase Authentication valida las credenciales.
9. Autenticación exitosa → el sistema persiste la preferencia de "Recordarme" si
   fue marcada.
10. El sistema navega a la pantalla principal (SideMenuShell), limpiando la pila
    de navegación.

### Flujo alternativo — Autologin

1. El usuario abre la aplicación.
2. El sistema detecta una sesión activa de Firebase Auth Y la preferencia de
   "Recordarme" está activa.
3. El sistema navega directamente a la pantalla principal sin mostrar Login.

### Flujo alternativo — Credenciales incorrectas

1. El usuario introduce credenciales incorrectas y pulsa "Iniciar sesión".
2. Firebase Authentication rechaza las credenciales.
3. El sistema muestra un mensaje de error (ej: "Email o contraseña
   incorrectos").
4. El usuario permanece en la pantalla de Login y puede reintentar.

### Flujo alternativo — Cerrar sesión

1. El usuario navega a Ajustes.
2. El usuario pulsa "Cerrar sesión".
3. El sistema cierra la sesión de Firebase Auth.
4. El sistema limpia la preferencia de "Recordarme".
5. El sistema navega a la pantalla de Login limpiando toda la pila de
   navegación.

### Flujo alternativo — Editar nombre de usuario

1. El usuario autenticado navega a Ajustes.
2. El campo de nombre de usuario muestra el valor almacenado en Firestore para
   su UID.
3. El usuario modifica el nombre y confirma.
4. El sistema guarda el nuevo nombre en Firestore (`users/{uid}/userName`).
5. Se muestra confirmación visual de guardado exitoso.

### Estados especiales / excepciones

- **Estado loading:** durante la verificación de sesión al abrir la app y
  durante el proceso de login, mostrar indicador de carga.
- **Estado error de red:** si no hay conexión al intentar login, mostrar mensaje
  "Sin conexión a internet" o similar.
- **Estado Firebase no disponible:** si Firebase no se inicializó correctamente,
  mostrar mensaje indicando que el servicio no está disponible.
- **Estado usuario deshabilitado:** si la cuenta fue deshabilitada en Firebase,
  mostrar mensaje "Cuenta deshabilitada. Contacta al administrador."
- **Estado sesión expirada:** si la sesión de Firebase Auth expiró (token
  revocado desde consola), al detectarlo redirigir al Login.

## 8) Edge cases

- **EC-01:** El usuario marca "Recordarme", inicia sesión, y el administrador
  elimina o deshabilita su cuenta en Firebase Console. Al reabrir la app, el
  autologin debe fallar gracefully y mostrar la pantalla de Login con un mensaje
  apropiado.
- **EC-02:** El usuario no tiene documento en la colección `users` de Firestore.
  Al acceder a Ajustes, el campo de nombre de usuario debe mostrarse vacío o con
  un valor por defecto, y al guardar se debe crear el documento.
- **EC-03:** Múltiples intentos de login fallidos consecutivos. No se requiere
  bloqueo de cuenta desde la app (Firebase Auth gestiona rate-limiting
  automáticamente), pero la UI debe permanecer funcional.
- **EC-04:** El usuario cierra la app abruptamente durante el proceso de login
  (kill de proceso). Al reabrir, el estado debe ser consistente (no sesión
  parcial).
- **EC-05:** Firebase está disponible para Auth pero Firestore no responde al
  cargar el nombre de usuario. La app debe manejar este fallo sin bloquear el
  acceso — el nombre de usuario puede quedar vacío temporalmente.
- **EC-06:** El campo de email tiene espacios al inicio/final. El sistema debe
  trimear antes de enviar a Firebase Auth.
- **EC-07:** Email con formato inválido. Validar formato antes de enviar la
  petición a Firebase.

## 9) Impacto funcional

### Módulos o procesos afectados

| Módulo                                   | Impacto                                                                                                                      |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Navegación / Router**                  | Se añade ruta de Login. La ruta inicial dependerá del estado de autenticación. Protección de rutas contra acceso sin sesión. |
| **Settings (Ajustes)**                   | Se añade botón "Cerrar sesión". La sección `UserIdentitySection` cambia su fuente de datos de SharedPreferences a Firestore. |
| **Inicialización de la app (main.dart)** | La lógica de ruta inicial debe evaluar el estado de autenticación y la preferencia de "Recordarme".                          |
| **Dependencias (pubspec.yaml)**          | Se requiere añadir `firebase_auth` como dependencia.                                                                         |
| **DI (inyección de dependencias)**       | Nuevos servicios/repositorios de autenticación deben registrarse en GetIt.                                                   |

### Impacto en usuario o negocio

- Los usuarios existentes necesitarán credenciales (email/password) creadas
  manualmente en Firebase Console para seguir accediendo.
- El nombre de usuario almacenado localmente en SharedPreferences se perderá;
  deberá recrearse en Firestore para cada usuario.

### Impacto en experiencia de usuario

- Se añade un paso obligatorio de autenticación al acceder a la app.
- La opción "Recordarme" minimiza la fricción para uso recurrente.
- El diseño del Login debe ser acorde al branding de la app (logo + diseño
  atractivo).

## 10) Suposiciones

- **S-01:** Los usuarios y sus contraseñas serán dados de alta manualmente en
  Firebase Authentication Console por el administrador.
- **S-02:** Los documentos en la colección `users` de Firestore también serán
  creados manualmente por el administrador (o por un script externo).
  Alternativamente, la app podría crear el documento automáticamente tras el
  primer login si no existe — se marca como pregunta abierta.
- **S-03:** Firebase Authentication ya está configurado en el proyecto de
  Firebase vinculado, con el proveedor de email/password habilitado.
- **S-04:** La opción "Recordarme" se implementa mediante una flag en
  SharedPreferences; Firebase Auth ya persiste la sesión por defecto, así que
  "no recordar" implica hacer sign-out explícito al cerrar la app o al
  reiniciar.
- **S-05:** No se requiere validación de fuerza de contraseña en la pantalla de
  Login (la contraseña ya fue definida por el administrador).
- **S-06:** El logo `logo-servicebo.png` ya existe en `assets/images/` y está
  correctamente declarado en `pubspec.yaml`.
- **S-07:** Las reglas de seguridad de Firestore para la colección `users` se
  gestionarán externamente (fuera de alcance de esta funcionalidad).

## 11) Preguntas abiertas

- **PA-01:** ¿Debe la aplicación crear automáticamente el documento del usuario
  en Firestore (`users/{uid}`) tras el primer login exitoso si no existe, o se
  asume que siempre existirá porque el administrador lo crea junto con la cuenta
  de Auth?
- **PA-02:** ¿El comportamiento de "no Recordarme" implica cerrar sesión de
  Firebase Auth al cerrar la app (de modo que se requiera re-login), o
  simplemente mostrar la pantalla de Login pero reutilizar el token existente si
  sigue válido? (Supuesto actual: se hace sign-out al detectar que "Recordarme"
  no está activo al iniciar la app).
- **PA-03:** ¿Se desea algún texto o mensaje de bienvenida personalizado en la
  pantalla de Login además del logo (ej: nombre de la empresa, slogan)?

## 12) Notas para análisis técnico

- El proyecto ya usa **Clean Architecture feature-first** con BLoC, GetIt y
  fpdart. La nueva feature `auth` o `login` debe seguir esta misma estructura
  (`data/`, `domain/`, `presentation/`).
- **Firebase Auth no está en `pubspec.yaml`**: se debe añadir `firebase_auth`
  como dependencia.
- Firebase ya se inicializa en `main.dart` con manejo de fallback (la app
  funciona sin Firebase). Este comportamiento deberá ajustarse: sin Firebase
  Auth operativo, la app no puede funcionar si la autenticación es obligatoria.
- El router actual usa `Map<String, WidgetBuilder>` con rutas con nombre. Se
  necesitará añadir la ruta de Login y modificar la lógica de `initialRoute`
  para que dependa del estado de autenticación.
- `UserIdentitySection` actualmente usa `SettingsRepository` (que delega en
  `SettingsLocalDataSource` / SharedPreferences). El cambio a Firestore requiere
  un nuevo datasource remoto o un repositorio de usuario independiente.
- El nombre de usuario se genera automáticamente como código aleatorio de 6
  letras si no existe (ver `_generateUserCode()` en `SettingsRepositoryImpl`).
  Este comportamiento deberá reevaluarse al migrar a Firestore.
- La pantalla de Login debe ser responsive; la app actualmente fuerza
  orientación landscape.
- Considerar i18n: todos los textos de la pantalla de Login y mensajes de error
  deben estar internacionalizados (archivos ARB).
- La preferencia "Recordarme" puede almacenarse en SharedPreferences (ya
  disponible en el proyecto).
- **Estado: Listo para análisis técnico**
