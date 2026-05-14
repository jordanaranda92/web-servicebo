# Functional Analysis: Web-only + URL routing

- **Fecha:** 2026-05-11
- **Identificador:** web-only-url-routing
- **Estado:** Ready for technical analysis

## 1) Resumen

Dos cambios relacionados:

1. **Eliminar soporte para Windows, macOS y Android**, dejando la aplicación
   exclusivamente web.
2. **Implementar navegación basada en URL** para los ítems del menú lateral y
   las vistas de detalle/edición de cliente, de modo que cada sección tenga una
   ruta propia reflejada en la barra de direcciones del navegador.

## 2) Contexto y objetivo

### Situación actual

- La app tiene carpetas de plataforma para `web/`, `android/`, `macos/` y
  `windows/`.
- La navegación principal usa un `SideMenuCubit` basado en índices enteros. Al
  seleccionar un ítem del menú, se cambia el índice y un `switch` renderiza la
  página correspondiente. La URL del navegador no cambia (siempre es `/`).
- Las vistas de detalle y edición de cliente se gestionan con un enum
  `_ClientsViewMode` local al state de `ClientsPage`, sin generar una URL
  específica.
- El router actual (`AppRoutes`) solo define dos rutas: `/` (SideMenuShell) y
  `/login`.

### Problema

- Al no cambiar la URL, el usuario no puede usar el historial del navegador
  (back/forward), compartir enlaces directos a una sección, ni guardar
  bookmarks.
- Mantener plataformas desktop que no se usan añade complejidad innecesaria al
  proyecto.

### Resultado esperado

- La app funciona exclusivamente en web.
- Cada sección del menú lateral tiene su propia ruta URL.
- Las vistas de detalle y edición de cliente tienen rutas con parámetros.
- El navegador refleja la ruta actual, permitiendo deep linking, back/forward y
  bookmarks.

## 3) Alcance

### En alcance

- Eliminar soporte de plataforma Windows (carpeta `windows/` y configuraciones
  asociadas).
- Eliminar soporte de plataforma macOS (carpeta `macos/` y configuraciones
  asociadas).
- Eliminar soporte de plataforma Android (carpeta `android/` y configuraciones
  asociadas).
- Implementar rutas URL para las 9 secciones del menú lateral:
  - `/home` — Inicio
  - `/orders-today` — Pedidos de hoy
  - `/orders-history` — Historial de pedidos
  - `/clients` — Clientes
  - `/client-categories` — Categorías de clientes
  - `/shipping-methods` — Métodos de envío
  - `/products` — Productos
  - `/invoices` — Facturas
  - `/settings` — Ajustes
- Implementar rutas URL para vistas de cliente:
  - `/clients/<id_client>/detail` — Ver un cliente
  - `/clients/<id_client>/edit` — Editar un cliente
- Sincronización bidireccional: al pulsar un ítem del menú se actualiza la URL,
  y al navegar directamente a una URL se muestra la sección correcta con el ítem
  del menú seleccionado.
- Soporte de back/forward del navegador.
- La ruta `/login` existente se mantiene.

### Fuera de alcance

- Crear rutas URL para subvistas de otras secciones distintas de clientes (ej.:
  detalle de pedido, detalle de producto, etc.).
- Implementar guards de autenticación en las rutas (si no existen ya).
- Cambios en la lógica de negocio de las páginas existentes.
- Cambios visuales o de UX en el menú lateral más allá de la integración con la
  nueva navegación.

## 4) Actores implicados

- **Usuario final:** operador/administrador que usa la app web para gestionar
  pedidos, clientes, productos, etc.
- **Desarrollador:** responsable de la implementación y el mantenimiento del
  proyecto.

## 5) Requisitos funcionales

- **RF-01:** La aplicación debe compilar y ejecutarse exclusivamente para la
  plataforma web. No se generarán builds para Windows, macOS ni Android.
- **RF-02:** Cada ítem del menú lateral debe corresponder a una ruta URL única
  conforme a la tabla definida en el alcance.
- **RF-03:** Al pulsar un ítem del menú lateral, la URL del navegador debe
  actualizarse a la ruta correspondiente sin recarga completa de la página.
- **RF-04:** Al acceder directamente a una URL válida (deep link), la app debe
  mostrar la sección correcta con el ítem del menú lateral seleccionado.
- **RF-05:** Al pulsar "Ver" un cliente desde la lista, la URL debe cambiar a
  `/clients/<id_client>/detail`.
- **RF-06:** Al pulsar "Editar" un cliente, la URL debe cambiar a
  `/clients/<id_client>/edit`.
- **RF-07:** Los botones back/forward del navegador deben navegar correctamente
  entre las secciones visitadas.
- **RF-08:** La ruta raíz `/` debe redirigir a `/home`.
- **RF-09:** El diálogo de confirmación de cambios sin guardar (NavigationGuard)
  debe seguir funcionando al intentar navegar desde la edición de cliente a otra
  sección.
- **RF-11:** Al guardar o cancelar la edición de un cliente, la navegación debe
  volver al origen: si se accedió desde la lista (`/clients`) vuelve a la lista;
  si se accedió desde el detalle (`/clients/<id>/detail`) vuelve al detalle.
- **RF-10:** Las rutas no reconocidas deben mostrar una página de error 404
  dedicada.

## 6) Criterios de aceptación

- **CA-01:** Las carpetas `windows/`, `macos/` y `android/` han sido eliminadas
  del proyecto. El proyecto compila con `flutter build web` sin errores.
- **CA-02:** Al pulsar cada ítem del menú, la URL del navegador se actualiza a
  la ruta esperada (verificar las 9 rutas).
- **CA-03:** Al introducir directamente `/orders-today` en la barra de
  direcciones del navegador, se muestra la página de pedidos de hoy con el ítem
  correspondiente seleccionado en el menú.
- **CA-04:** Al navegar a `/clients/abc123/detail`, se muestra la vista de
  detalle del cliente con ID `abc123`.
- **CA-05:** Al navegar a `/clients/abc123/edit`, se muestra la vista de edición
  del cliente con ID `abc123`.
- **CA-06:** Tras navegar Inicio → Pedidos → Clientes, pulsar back dos veces
  devuelve a Inicio, y la URL refleja cada paso.
- **CA-07:** Si el usuario tiene cambios sin guardar en la edición de un cliente
  y pulsa otro ítem del menú o back, se muestra el diálogo de confirmación antes
  de navegar.
- **CA-08:** Acceder a `/` redirige a `/home`.
- **CA-09:** Acceder a una ruta inexistente (ej.: `/foo`) muestra una página de
  error 404 dedicada.
- **CA-10:** El comando `flutter build web` se ejecuta con éxito sin referencias
  a plataformas eliminadas.
- **CA-11:** Al editar un cliente accediendo desde la lista y guardar, se vuelve
  a `/clients`. Al editar desde el detalle y guardar, se vuelve a
  `/clients/<id>/detail`.

## 7) Flujos y comportamiento esperado

### Flujo principal — Navegación por menú

1. El usuario accede a la app (URL: `/` o `/home`).
2. Se muestra la página de inicio con el ítem "Inicio" seleccionado en el menú
   lateral.
3. El usuario pulsa "Pedidos de hoy" en el menú.
4. La URL cambia a `/orders-today`, se muestra la página de pedidos de hoy, el
   ítem "Pedidos de hoy" aparece seleccionado.
5. El usuario pulsa back en el navegador.
6. La URL vuelve a `/home`, se muestra la página de inicio, el ítem "Inicio"
   aparece seleccionado.

### Flujo principal — Deep link a sección

1. El usuario introduce `/settings` en la barra de direcciones.
2. Se carga la app, se muestra la página de ajustes con el ítem "Ajustes"
   seleccionado en el menú.

### Flujo principal — Detalle de cliente

1. El usuario está en `/clients`.
2. Pulsa en un cliente para ver su detalle.
3. La URL cambia a `/clients/<id_client>/detail`.
4. Se muestra la vista de detalle del cliente.
5. El usuario pulsa back → vuelve a `/clients`.

### Flujo principal — Edición de cliente

1. Desde la vista de detalle (`/clients/<id_client>/detail`), el usuario pulsa
   "Editar".
2. La URL cambia a `/clients/<id_client>/edit`.
3. Se muestra la vista de edición.
4. El usuario guarda o cancela → vuelve a `/clients/<id_client>/detail` (origen
   de la navegación).

### Flujo principal — Edición de cliente desde lista

1. Desde la lista de clientes (`/clients`), el usuario pulsa "Editar"
   directamente sobre un cliente.
2. La URL cambia a `/clients/<id_client>/edit`.
3. Se muestra la vista de edición.
4. El usuario guarda o cancela → vuelve a `/clients` (origen de la navegación).

### Flujos alternativos

- **Alt-01:** El usuario accede a `/clients/<id_inexistente>/detail` → se
  muestra un mensaje de error o se redirige a `/clients`.
- **Alt-02:** El usuario introduce una ruta no válida → se muestra una página de
  error 404 dedicada.
- **Alt-03:** El usuario navega a otra sección con cambios sin guardar en
  edición de cliente → se muestra diálogo de confirmación. Si elige quedarse, la
  URL no cambia. Si elige descartar, se navega a la nueva ruta.

### Estados especiales / excepciones

- **Estado loading:** Si la app se carga desde un deep link, mostrar estado de
  carga mientras se obtienen los datos necesarios (ej.: datos del cliente para
  `/clients/<id>/detail`).
- **Estado error:** Si un deep link referencia un recurso que no se puede cargar
  (ej.: cliente inexistente), mostrar error y ofrecer volver a la lista.
- **Sin autenticación:** Si el usuario no está autenticado y accede a cualquier
  ruta protegida, redirigir a `/login` (comportamiento existente; no se modifica
  en este alcance).

## 8) Edge cases

- **EC-01:** El usuario refresca la página (F5) en `/orders-today` → la app se
  recarga y muestra la sección correcta.
- **EC-02:** El usuario tiene dos pestañas abiertas en rutas distintas → cada
  pestaña funciona de forma independiente.
- **EC-03:** El usuario modifica manualmente la URL de `/clients/abc/detail` a
  `/clients/abc/edit` → se navega a la vista de edición.
- **EC-04:** El usuario navega a `/clients//detail` (ID vacío) → se muestra
  página 404.
- **EC-05:** El menú lateral expandido/colapsado se mantiene consistente al
  cambiar de ruta (persiste en SharedPreferences, no depende de la ruta).
- **EC-06:** El usuario accede a `/login` estando ya autenticado →
  comportamiento existente, fuera de alcance.

## 9) Impacto funcional

- **Módulos afectados:**
  - Router de la aplicación (`app/router/`): se reemplaza el sistema de rutas
    actual por un router declarativo con rutas anidadas.
  - Side menu shell (`side_menu_shell.dart`): deja de gestionar la página activa
    por índice y pasa a depender de la ruta actual.
  - Side menu cubit/state: el `selectedIndex` debe derivarse de la ruta activa,
    no almacenarse de forma aislada.
  - Clients page: deja de gestionar internamente los modos list/detail/edit y
    delega la navegación al router.
  - Configuración de plataformas: se eliminan Android, macOS y Windows.

- **Impacto en usuario:**
  - Mejora significativa de UX: URLs compartibles, deep linking, historial del
    navegador funcional.
  - No hay cambios visuales en la interfaz existente.

- **Impacto en experiencia de usuario:**
  - El usuario puede copiar la URL y compartirla con otro usuario para acceder
    directamente a una sección.
  - El flujo back/forward funciona como en cualquier aplicación web estándar.

## 10) Suposiciones

- Se asume que el flujo de autenticación existente (guard que redirige a
  `/login`) seguirá funcionando sin cambios con el nuevo sistema de routing.
- Se asume que la plataforma Android también se elimina; la app es
  exclusivamente web.
- Se asume que no se necesitan rutas paramétrizadas para otras entidades
  (productos, pedidos, etc.) en este alcance.
- Se asume que `/home` es la ruta por defecto y destino de la redirección desde
  `/`.

## 11) Preguntas abiertas

- Sin preguntas abiertas. Todas las ambigüedades han sido resueltas.

## 12) Notas para análisis técnico

- **Router declarativo:** Evaluar `go_router` como solución. Soporta rutas
  anidadas (shell routes), redirecciones, parámetros de ruta, y se integra bien
  con navegación web (URL strategy).
- **Shell route:** El `SideMenuShell` se convierte en un shell route que
  envuelve todas las secciones del menú. El contenido cambia según la ruta
  activa.
- **Derivación del índice seleccionado:** El `selectedIndex` del menú debe
  calcularse a partir de la ruta actual (location → index mapping), no
  almacenarse de forma independiente. El `SideMenuCubit` podría simplificarse o
  eliminarse en favor de la lectura directa de la ruta.
- **NavigationGuard:** El mecanismo actual de `NavigationGuard` con diálogo de
  confirmación debe integrarse con el nuevo router. `go_router` no tiene soporte
  nativo completo para `onBeforeNavigate`; evaluar la estrategia de integración.
- **Eliminación de plataformas:** Eliminar carpetas `android/`, `windows/` y
  `macos/` y cualquier configuración específica (ej.: archivos `.iml`, Podfiles,
  CMakeLists, build.gradle).
- **Página 404:** Crear una página de error 404 dedicada para rutas no
  reconocidas.
- **Navegación post-edición:** Al salir de la edición de un cliente, la
  navegación debe volver al origen (lista o detalle). Evaluar uso de `extra` en
  `go_router` o inspección del historial para determinar el origen.
- **URL strategy:** Usar `PathUrlStrategy` (URLs limpias sin `#`) ya que la app
  es exclusivamente web.
- **Dependencias visibles:** `flutter_bloc`, `shared_preferences`, `go_router`
  (a incorporar).
- **Estado: Listo para análisis técnico**
