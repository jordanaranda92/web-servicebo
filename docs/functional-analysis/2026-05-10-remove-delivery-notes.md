# Functional Analysis: Eliminación completa de la funcionalidad de Albaranes

- **Fecha:** 2026-05-10
- **Identificador:** remove-delivery-notes
- **Estado:** Ready for technical analysis

## 1) Resumen

Eliminar por completo la funcionalidad de Albaranes (delivery notes) de la
aplicación Servicebo: suprimir la feature `delivery_notes`, retirar el ítem del
menú lateral, eliminar los métodos de albaranes del datasource de
FacturaDirecta, y eliminar la acción "Generar albarán" de la tabla de pedidos
del día.

## 2) Contexto y objetivo

- **Qué se solicita:** Retirar toda la funcionalidad de Albaranes que fue
  implementada como parte de la integración con FacturaDirecta, incluyendo la
  pantalla de listado, el ítem de navegación en el side menu, las llamadas al
  API de FacturaDirecta relacionadas con albaranes, y el botón/callback de
  "Generar albaranes" en la pantalla de Pedidos Hoy.
- **Qué problema resuelve:** La funcionalidad de Albaranes ya no es necesaria
  para el negocio. Mantenerla añade complejidad innecesaria al código,
  incrementa los puntos de contacto con la API externa y ocupa espacio en el
  menú lateral.
- **Qué resultado funcional se espera:** La aplicación funciona sin ninguna
  referencia a albaranes. El menú lateral pasa de 9 ítems a 8. La tabla de
  pedidos del día no ofrece la opción de generar albaranes. Las llamadas al API
  de FacturaDirecta para `deliveryNotes` dejan de existir.

## 3) Alcance

### En alcance

- Eliminar la feature completa `lib/features/delivery_notes/` (entity, DTO,
  repository, use case, cubit, state, page, widgets)
- Eliminar el módulo DI `delivery_notes_module.dart` y su registro en
  `injection.dart`
- Eliminar el ítem "Albaranes" del menú lateral (`side_menu.dart`)
- Ajustar los índices de navegación en `SideMenuShell` y `SideMenuCubit` (de 9 a
  8 ítems)
- Eliminar los métodos `getDeliveryNotes`, `getDeliveryNoteById` y
  `createDeliveryNote` de la interfaz `FacturaDirectaApiDataSource` y de su
  implementación
- Eliminar el callback `onGenerateDeliveryNotes` de `OrdersTable` y
  `OrdersTableToolbar`
- Eliminar la referencia a albaranes en `onGenerateDeliveryNotes` de
  `OrdersTodayPage`
- Eliminar las referencias a `DeliveryNote`/`GetDeliveryNotes` en
  `FdCountersCubit` y `FdCountersState` (dashboard de inicio)
- Eliminar la referencia al contador de albaranes y sus diffs en `HomePage`
- Eliminar las claves i18n relacionadas exclusivamente con albaranes (ARB files)
- Eliminar tests asociados a delivery_notes (si existen)

### Fuera de alcance

- Modificaciones a las funcionalidades de Contactos, Productos o Facturas (no se
  tocan)
- Eliminación de la configuración de FacturaDirecta en Ajustes (se mantiene para
  las demás features)
- Eliminación del datasource `FacturaDirectaApiDataSource` en sí (se mantiene,
  solo se eliminan los métodos de albaranes)
- Cambios en la lógica de negocio de Pedidos Hoy más allá de retirar la acción
  de generar albaranes

## 4) Actores implicados

- **Usuario final:** Deja de ver la sección "Albaranes" en el menú lateral y
  deja de tener la opción de generar albaranes desde Pedidos Hoy.
- **Desarrollador/mantenedor:** Se reduce la superficie de código a mantener.

## 5) Requisitos funcionales

- **RF-01:** El menú lateral no debe contener el ítem "Albaranes". Debe pasar de
  9 ítems a 8: Inicio, Pedidos Hoy, Historial Pedidos, Clientes, Categorías
  Clientes, Productos, Facturas, Ajustes.
- **RF-02:** Los índices de navegación deben reajustarse para que Facturas ocupe
  el índice 6 y Ajustes el índice 7 (anteriormente 7 y 8).
- **RF-03:** La API de FacturaDirecta no debe ser invocada para endpoints de
  `deliveryNotes` (`GET`, `GET/{id}`, `POST`).
- **RF-04:** La tabla de pedidos del día (OrdersTable) no debe ofrecer la acción
  "Generar albarán/albaranes" en su toolbar.
- **RF-05:** El dashboard de inicio (HomePage) no debe mostrar el contador de
  albaranes ni las comparativas (diffs) asociadas a albaranes.
- **RF-06:** No debe existir ningún archivo bajo `lib/features/delivery_notes/`.
- **RF-07:** No debe existir el módulo DI `delivery_notes_module.dart`.
- **RF-08:** Las claves i18n exclusivas de albaranes deben eliminarse de los
  archivos ARB y generados.

## 6) Criterios de aceptación

- **CA-01:** Al abrir la app, el menú lateral muestra exactamente 8 ítems:
  Inicio, Pedidos Hoy, Historial Pedidos, Clientes, Categorías Clientes,
  Productos, Facturas, Ajustes.
- **CA-02:** Al navegar entre todos los ítems del menú, cada uno muestra su
  página correspondiente sin errores. Los índices son correctos.
- **CA-03:** En la tabla de Pedidos Hoy, al seleccionar columnas de clientes, la
  toolbar no muestra botón de "Generar albarán/albaranes".
- **CA-04:** El dashboard de Inicio no muestra tarjeta, contador ni comparativa
  de albaranes.
- **CA-05:** La aplicación compila sin errores ni warnings relacionados con
  delivery notes.
- **CA-06:** No hay referencias a `delivery_notes`, `DeliveryNote`,
  `DeliveryNotesCubit` ni `getDeliveryNotes` en el código fuente (salvo
  análisis/docs).
- **CA-07:** Los tests existentes siguen pasando (excluyendo los que se eliminen
  junto con la feature).

## 7) Flujos y comportamiento esperado

### Flujo principal — Navegación sin Albaranes

1. El usuario abre la aplicación.
2. El menú lateral muestra 8 ítems.
3. El usuario puede navegar a cualquiera de los 8 ítems sin problemas.
4. La sección de Facturas (ahora índice 6) y Ajustes (ahora índice 7) funcionan
   correctamente.

### Flujo principal — Pedidos Hoy sin generar albaranes

1. El usuario entra a Pedidos Hoy.
2. Selecciona una o más columnas de clientes en la tabla.
3. La toolbar muestra las acciones disponibles (eliminar, resetear) pero NO
   "Generar albarán/albaranes".

### Flujos alternativos

- No aplican flujos alternativos significativos; se trata de eliminación pura de
  funcionalidad.

### Estados especiales / excepciones

- **Estado vacío:** No aplica (se elimina la funcionalidad, no hay estado vacío
  nuevo).
- **Estado loading/error:** El dashboard de Inicio puede seguir mostrando
  loading/error para el contador de Facturas; ya no incluirá albaranes.
- **Sin permisos/sin datos:** No aplica directamente a la eliminación.

## 8) Edge cases

- **EC-01:** Un usuario que tenía el menú posicionado en el índice 6 (Albaranes)
  o superior antes de la actualización → al actualizar, el `SideMenuCubit` puede
  tener un `selectedIndex` persistido de 6, 7 u 8. Tras la eliminación, el
  índice 6 es Facturas, el 7 es Ajustes, y el 8 es inválido → si el índice
  persistido es 8 (antiguo Ajustes), el cubit no debe fallar (el `_maxIndex`
  pasa a 7, por lo que un índice 8 guardado debería caer al default o ser
  rechazado sin crash).
- **EC-02:** El `FdCountersCubit` deja de recibir datos de albaranes → el
  constructor y el método `load()` deben funcionar sin `GetDeliveryNotes`. Si se
  elimina, el `home_module.dart` también debe dejar de inyectar esa dependencia.
- **EC-03:** Los separadores visuales en el `SideMenu` usan índices fijos (0, 2,
  5, 7) para posicionar las líneas divisorias → deben reajustarse para la nueva
  lista de 8 ítems (índices 0, 2, 5, 6 — o revisarse manualmente).

## 9) Impacto funcional

- **Módulos afectados:**
  - `lib/features/delivery_notes/` — se elimina por completo
  - `lib/features/home/` — se modifica menú lateral (side_menu,
    side_menu_shell), navegación (side_menu_cubit) y dashboard (home_page,
    fd_counters_cubit, fd_counters_state)
  - `lib/features/orders_today/` — se eliminan callbacks y botón de generar
    albaranes (orders_table, orders_table_toolbar, orders_today_page)
  - `lib/core/data/datasources/` — se eliminan 3 métodos de la interfaz y su
    implementación
  - `lib/app/di/` — se elimina delivery_notes_module y su registro
  - `lib/app/localization/` — se eliminan claves i18n de albaranes
- **Impacto en usuario:** El usuario pierde la capacidad de consultar albaranes
  y de generar albaranes desde pedidos. El menú es más limpio y con un ítem
  menos.
- **Impacto en experiencia de usuario:** Positivo si la funcionalidad no se usa;
  simplifica la interfaz.

## 10) Suposiciones

- **S-01:** La funcionalidad de albaranes no es utilizada activamente por ningún
  usuario y su eliminación está aprobada por el negocio.
- **S-02:** Las demás features de FacturaDirecta (Contactos, Productos,
  Facturas) deben seguir funcionando sin cambios.
- **S-03:** No existe un proceso backend o integración externa que dependa de la
  creación de albaranes desde Servicebo.
- **S-04:** Las claves i18n de albaranes no son compartidas con otras features.
  Si alguna clave es compartida, se mantendrá.

## 11) Preguntas abiertas

- **PA-01:** ¿Se desea eliminar también los documentos de análisis y reportes
  existentes en `docs/` que hacen referencia a albaranes, o solo el código
  fuente? (Supuesto: se mantienen los docs existentes como histórico)
- **PA-02:** ¿El campo `deliveryNotesCount` en el widget de comparativa del
  dashboard debe sustituirse por otra métrica, o simplemente se elimina la
  tarjeta/sección? (Supuesto: se elimina)

## 12) Notas para análisis técnico

- La eliminación requiere reindexar los ítems del menú lateral y del
  `IndexedStack` en `SideMenuShell` (los ítems posteriores a Albaranes bajan un
  índice)
- `SideMenuCubit._maxIndex` debe pasar de 8 a 7
- Los separadores en `SideMenu` usan índices hardcodeados que deberán ajustarse
- `FdCountersCubit` depende de `GetDeliveryNotes` inyectado; debe eliminarse esa
  dependencia y adaptarse el cubit, el state y el DI (`home_module.dart`)
- La interfaz `FacturaDirectaApiDataSource` pierde 3 métodos; la implementación
  HTTP pierde los métodos correspondientes
- En `OrdersTable` y `OrdersTableToolbar`, el callback `onGenerateDeliveryNotes`
  se elimina. El botón asociado en la toolbar desaparece
- Verificar que la persistencia de `selectedIndex` en `SharedPreferences` no
  cause crashes si el valor guardado es 8 (ahora fuera de rango)
- **Estado: Listo para análisis técnico**
