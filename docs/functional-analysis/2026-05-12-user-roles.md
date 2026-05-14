# Functional Analysis: Roles de usuario (employee / admin)

- **Fecha:** 2026-05-12
- **Identificador:** user-roles
- **Estado:** Ready for technical analysis

## 1) Resumen

Incorporar el concepto de rol de usuario en la aplicación. Al hacer login (y al
restaurar sesión automática) se debe obtener el campo `role` del documento del
usuario en la colección `users` de Firestore. Los roles posibles son `employee`
y `admin`. El rol condiciona la visibilidad de ciertas secciones de la app: el
admin verá un nuevo ítem "Estadísticas" en el menú lateral, mientras que el
empleado no. Además, la arquitectura debe exponer el rol de forma accesible para
condicionar comportamiento en cualquier punto de la aplicación.

## 2) Contexto y objetivo

- **Qué se solicita:** ampliar el modelo de usuario con un rol (`employee` o
  `admin`) obtenido desde Firestore durante el flujo de autenticación, y
  reflejar ese rol en la navegación y la estructura de la app.
- **Qué problema resuelve:** actualmente todos los usuarios tienen las mismas
  capacidades y visibilidad. Se necesita diferenciar administradores de
  empleados para restringir el acceso a funcionalidades sensibles (comenzando
  por "Estadísticas").
- **Qué resultado funcional se espera:**
  - Tras un login exitoso, la app conoce el rol del usuario.
  - El menú lateral muestra u oculta ítems según el rol.
  - El rol queda disponible de forma centralizada para futuras comprobaciones en
    otros módulos.

## 3) Alcance

### En alcance

- Lectura del campo `role` del documento `users/{uid}` de Firestore durante
  sign-in y auto-login.
- Ampliación de la entidad `AppUser` para incluir el rol.
- Nuevo ítem "Estadísticas" en el menú lateral, visible solo para usuarios con
  rol `admin`.
  - Ubicado debajo de "Facturas" (índice 7 actual).
  - Un divisor visual por encima del ítem.
- Exposición centralizada del rol del usuario autenticado para su uso en
  cualquier punto de la app.
- Página placeholder / vacía para "Estadísticas" (solo para que la ruta exista y
  sea navegable).
- Tratamiento de estados especiales: usuario sin campo `role` en Firestore,
  valor inesperado del campo.

### Fuera de alcance

- Contenido real de la pantalla de Estadísticas (se entregará como página vacía
  o stub).
- CRUD de roles (asignación, modificación de roles desde la app).
- Permisos granulares más allá de visibilidad de menú (p.ej. restricciones a
  nivel de API o Firestore Security Rules).
- Gestión de múltiples roles por usuario.
- Pantalla de administración de usuarios.

## 4) Actores implicados

| Actor               | Descripción                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| Usuario employee    | Empleado con acceso estándar a la aplicación                                                     |
| Usuario admin       | Administrador con acceso extendido (sección Estadísticas y futuras funcionalidades restringidas) |
| Firestore (sistema) | Fuente de verdad del campo `role` en la colección `users`                                        |

## 5) Requisitos funcionales

- **RF-01:** Al realizar sign-in con email y contraseña, la app debe leer el
  campo `role` del documento `users/{uid}` en Firestore y almacenarlo en la
  entidad de usuario.
- **RF-02:** Al restaurar sesión automáticamente (auto-login / remember me), la
  app debe leer igualmente el campo `role` del documento del usuario.
- **RF-03:** Los valores válidos de `role` son `"employee"` y `"admin"`.
  Cualquier otro valor o ausencia del campo se tratará como `employee` por
  defecto (principio de mínimo privilegio).
- **RF-04:** El menú lateral debe mostrar el ítem "Estadísticas" (icono: gráfico
  de barras o similar) únicamente cuando el usuario autenticado tenga rol
  `admin`.
- **RF-05:** El ítem "Estadísticas" se posiciona inmediatamente después de
  "Facturas", precedido por un divisor visual.
- **RF-06:** El ítem "Ajustes" se mantiene como último ítem del menú, después de
  "Estadísticas" (si se muestra) o después de "Facturas" (si no se muestra).
- **RF-07:** El rol del usuario debe estar accesible de forma centralizada (a
  través del estado de autenticación global) para poder ser consultado desde
  cualquier feature o widget de la aplicación.
- **RF-08:** Debe existir una ruta navegable `/statistics` asociada al ítem
  "Estadísticas", con una página placeholder.
- **RF-09:** Si un usuario con rol `employee` intenta acceder directamente a la
  ruta `/statistics` (por URL), debe ser redirigido al home.

## 6) Criterios de aceptación

- **CA-01:** Dado un usuario con `role: "admin"` en Firestore, cuando hace login
  exitoso, entonces el menú lateral muestra el ítem "Estadísticas" entre
  "Facturas" y "Ajustes" con un divisor encima.
- **CA-02:** Dado un usuario con `role: "employee"` en Firestore, cuando hace
  login exitoso, entonces el menú lateral NO muestra el ítem "Estadísticas".
- **CA-03:** Dado un usuario cuyo documento en Firestore no tiene campo `role`,
  cuando hace login, entonces se comporta como `employee` (sin "Estadísticas"
  visible).
- **CA-04:** Dado un usuario con `role: "admin"`, cuando la sesión se restaura
  automáticamente (remember me), entonces el menú lateral muestra
  "Estadísticas".
- **CA-05:** Dado un usuario con `role: "employee"`, cuando navega directamente
  a `/statistics` por URL, entonces es redirigido a `/home`.
- **CA-06:** Dado un usuario con `role: "admin"`, cuando selecciona
  "Estadísticas" en el menú, entonces navega a la página de estadísticas
  (placeholder).
- **CA-07:** La entidad de usuario expone el rol de forma que cualquier módulo
  de la app pueda consultarlo sin depender del menú lateral.

## 7) Flujos y comportamiento esperado

### Flujo principal — Login con rol admin

1. El usuario introduce email y contraseña y pulsa "Iniciar sesión".
2. Firebase Auth valida las credenciales.
3. Tras autenticación exitosa, la app lee el documento `users/{uid}` de
   Firestore.
4. Se extrae el campo `role` → `"admin"`.
5. Se construye la entidad `AppUser` con el rol incluido.
6. Se navega al home.
7. El menú lateral renderiza incluyendo el ítem "Estadísticas" entre "Facturas"
   y "Ajustes", con divisor encima.

### Flujo principal — Login con rol employee

1-3. Igual que el flujo anterior. 4. Se extrae el campo `role` → `"employee"`.
5. Se construye la entidad `AppUser` con rol employee. 6. Se navega al home. 7.
El menú lateral renderiza sin el ítem "Estadísticas".

### Flujos alternativos

- **Auto-login (remember me):** Al abrir la app, si hay sesión activa y remember
  me activado, se obtiene el `currentUser` de Firebase Auth y se lee su `role`
  de Firestore. El menú se renderiza acorde al rol.
- **Campo `role` ausente:** Se asume `employee`. Log informativo (no error al
  usuario).
- **Campo `role` con valor inesperado** (ni `"employee"` ni `"admin"`): Se asume
  `employee`. Log informativo.

### Estados especiales / excepciones

- **Estado loading:** Mientras se obtiene el rol de Firestore, la app puede
  mostrar su estado de carga habitual del login. No se debe navegar hasta tener
  el rol resuelto.
- **Estado error Firestore:** Si falla la lectura del documento de usuario en
  Firestore (error de red, permisos, etc.), se debe tratar como `employee` y
  permitir el acceso con funcionalidad restringida, logueando el error.
  Alternativa: mostrar error y no permitir login (a decidir — ver pregunta
  abierta PA-01).
- **Sin conexión:** Si la lectura de Firestore falla por red, aplicar la misma
  política que el caso anterior.

## 8) Edge cases

- **EC-01:** El documento `users/{uid}` no existe en Firestore (solo existe en
  Firebase Auth). → Tratar como `employee`.
- **EC-02:** El campo `role` existe pero está vacío (`""`). → Tratar como
  `employee`.
- **EC-03:** El campo `role` tiene un valor futuro no contemplado (p.ej.
  `"supervisor"`). → Tratar como `employee`.
- **EC-04:** El rol del usuario cambia en Firestore mientras la sesión está
  activa. → No se requiere actualización en tiempo real; el rol se lee al hacer
  login/auto-login. Un cambio de rol será efectivo en el próximo login.
- **EC-05:** Acceso directo por URL a `/statistics` sin autenticación. →
  Redirigir a login (comportamiento existente del router guard).
- **EC-06:** Menú en modo móvil (drawer). → El ítem "Estadísticas" debe seguir
  las mismas reglas de visibilidad por rol.

## 9) Impacto funcional

- **Módulos afectados:**
  - `auth` — Entidad `AppUser`, datasource (lectura de rol), repositorio, use
    cases `SignIn` y `CheckAutoLogin`.
  - `home` — Widget `SideMenu` (nuevo ítem condicional), `SideMenuShell`
    (adaptación de índices y títulos mobile).
  - `app/router` — Nueva ruta `/statistics`, guard de rol, adaptación de
    `menuPaths` e `indexFromLocation`.
  - `app/di` — Registro del nuevo módulo/ruta si aplica.
  - `i18n` — Nuevas claves de traducción: `menuStatistics`.
- **Impacto en usuario:** Los administradores verán una nueva opción en el menú.
  Los empleados no perciben cambio alguno.
- **Impacto en experiencia de usuario:** El menú lateral puede tener distinto
  número de ítems según el rol, lo que afecta a los índices de selección y los
  divisores visuales.

## 10) Suposiciones

- **S-01:** El campo `role` ya existe (o existirá) en los documentos de la
  colección `users` de Firestore. Su provisión (cómo se asigna inicialmente)
  está fuera de alcance.
- **S-02:** Solo existen dos roles: `employee` y `admin`. No se contempla un
  sistema de roles más complejo.
- **S-03:** El rol no cambia durante una sesión activa; se lee únicamente al
  hacer login o al restaurar sesión.
- **S-04:** La lectura del campo `role` puede hacerse en la misma operación que
  ya lee `userName` del documento del usuario, reutilizando la referencia a
  `users/{uid}`.
- **S-05:** La página "Estadísticas" se entregará como placeholder (contenido
  real fuera de alcance).
- **S-06:** El texto del menú "Estadísticas" se internacionaliza siguiendo el
  patrón existente (`menuStatistics`).

## 11) Preguntas abiertas

- **PA-01:** Si la lectura del `role` en Firestore falla (error de red /
  permisos), ¿se debe bloquear el login o permitir acceso como `employee`? —
  _Suposición actual: permitir acceso como employee y loguear el error._

## 12) Notas para análisis técnico

- La entidad `AppUser` ya contiene `uid`, `email` y `userName`. Se necesita
  añadir el campo `role` (preferiblemente como enum).
- El datasource `AuthRemoteDataSourceImpl` ya accede a la colección `users`
  (métodos `getUserName` / `saveUserName`). La lectura de `role` puede
  integrarse ahí.
- El `LoginCubit` no expone actualmente el `AppUser` tras login exitoso (emite
  `LoginSuccess` sin datos). Para que el rol esté disponible globalmente, habrá
  que evaluar si exponer el usuario en el estado del cubit o utilizar un
  mecanismo global (p.ej. un `AuthCubit` / `AuthBloc` ya existente o nuevo).
- El `SideMenu` construye los ítems como lista estática; habrá que hacerla
  dinámica según el rol.
- Los `menuPaths` en `AppRoutes` y los índices del `separatorBuilder` en
  `SideMenu` son estáticos y asumen un número fijo de ítems. Habrá que adaptar
  la lógica de mapeo de índices para ser dinámica.
- Guard de ruta: el router ya redirige usuarios no autenticados. Se necesitará
  un guard adicional para `/statistics` basado en rol.
- **Estado: Listo para análisis técnico**
