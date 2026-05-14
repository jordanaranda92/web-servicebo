# Functional Analysis: Métodos de envío y mejoras en tabla de Clientes

- **Fecha:** 2026-05-11
- **Identificador:** shipping-methods
- **Estado:** Ready for technical analysis
- **Versión:** v2 (sustituye a `2026-05-11-shipping-methods.md`)

## Cambios respecto a v1

- Eliminado el campo "Días disponible" de la entidad método de envío.
- La asignación de métodos de envío a clientes pasa de ser un selector múltiple
  libre a un selector por día de la semana (Lunes–Domingo), donde se elige un
  método de envío por día.
- Resueltas preguntas abiertas PA-01 (limpiar referencias al eliminar) y PA-02
  (Lunes a Domingo).

---

## 1) Resumen

Se solicitan dos bloques de cambios:

1. **Nuevo módulo "Métodos de envío"**: crear un nuevo ítem en el menú lateral
   con su página asociada para gestionar métodos de envío almacenados en
   Firestore, siguiendo la estética y patrones de la página "Categorías de
   cliente".
2. **Mejoras en la tabla de Clientes**: renombrar la columna "Nombre FD" a
   "Nombre Factura Directa" y añadir una nueva columna "Métodos de envío" con un
   selector que asigna un método de envío por cada día de la semana.

## 2) Contexto y objetivo

- **Qué se solicita:** Ampliar la aplicación con la gestión de métodos de envío
  (CRUD) y asociar un método de envío por día de la semana a cada cliente.
- **Qué problema resuelve:** Actualmente no existe un lugar en la aplicación
  para gestionar los métodos de envío disponibles ni para planificar qué método
  de envío usa cada cliente en cada día. Además, la columna "Nombre FD" no es
  suficientemente descriptiva.
- **Resultado funcional esperado:**
  - El usuario puede crear, editar y eliminar métodos de envío desde una página
    dedicada.
  - El usuario puede asignar un método de envío a cada día de la semana para
    cada cliente.
  - La columna "Nombre FD" pasa a llamarse "Nombre Factura Directa".

## 3) Alcance

### En alcance

- Nuevo ítem "Métodos de envío" en el menú lateral (sidebar).
- Nueva página de gestión de métodos de envío con:
  - Listado de métodos de envío existentes.
  - Buscador/filtro por nombre.
  - Creación de nuevos métodos de envío.
  - Edición inline de los campos: Nombre y Teléfono.
  - Eliminación de métodos de envío (con limpieza automática de referencias en
    clientes).
- Persistencia en Firestore en la colección `shipping_methods`.
- En la tabla de Clientes:
  - Renombrado de columna "Nombre FD" → "Nombre Factura Directa".
  - Nueva columna "Métodos de envío" con selector que permite asignar un método
    de envío por cada día de la semana (Lunes a Domingo).
- Internacionalización (i18n) de todos los textos nuevos.

### Fuera de alcance

- Lógica de negocio adicional derivada de los métodos de envío (ej: cálculo de
  costes de envío, integración con transportistas).
- Validación de formato internacional de teléfono (se asume formato español de 9
  dígitos).
- Sincronización de métodos de envío con Factura Directa u otros sistemas
  externos.
- Ordenación drag-and-drop de los métodos de envío.
- Histórico/auditoría de cambios en métodos de envío.

## 4) Actores implicados

- **Usuario administrador**: gestiona los métodos de envío y asigna métodos por
  día a clientes.
- **Sistema (Firestore)**: persiste los datos de métodos de envío y la relación
  día→método en cada cliente.

## 5) Requisitos funcionales

### Bloque A — Módulo "Métodos de envío"

- **RF-A01**: El menú lateral debe incluir un nuevo ítem "Métodos de envío" con
  un icono apropiado (ej: `local_shipping`), ubicado después de "Categorías de
  cliente" y antes de "Productos".
- **RF-A02**: Al seleccionar el ítem, se muestra la página de métodos de envío.
- **RF-A03**: La página muestra un listado tabular de todos los métodos de envío
  almacenados en Firestore (`shipping_methods`), ordenados alfabéticamente por
  nombre.
- **RF-A04**: La página incluye un campo de búsqueda/filtro por nombre (igual
  que en Categorías de cliente).
- **RF-A05**: La página incluye un botón para añadir un nuevo método de envío.
  Al pulsarlo, se crea una nueva fila con los campos vacíos.
- **RF-A06**: Cada método de envío tiene los siguientes campos editables inline:
  - **Nombre** (texto, máximo 50 caracteres, obligatorio).
  - **Teléfono** (numérico, exactamente 9 dígitos, opcional).
- **RF-A07**: Los cambios en cada campo se guardan al perder el foco
  (comportamiento consistente con Categorías de cliente y Clientes).
- **RF-A08**: Cada fila incluye un botón/icono para eliminar el método de envío,
  con diálogo de confirmación previo.
- **RF-A09**: Al eliminar un método de envío, se deben limpiar automáticamente
  todas las referencias a ese método en los documentos de clientes en Firestore.
- **RF-A10**: Se debe mostrar feedback visual (mensaje de éxito/error) al
  guardar o eliminar, igual que en las páginas existentes.
- **RF-A11**: La página usa escucha en tiempo real (stream/listener) de la
  colección Firestore, igual que Categorías de cliente.

### Bloque B — Mejoras en tabla de Clientes

- **RF-B01**: Renombrar la cabecera de columna "Nombre FD" a "Nombre Factura
  Directa" (cambio en i18n, clave `clientsColumnNameFd`).
- **RF-B02**: Añadir una nueva columna "Métodos de envío" en la tabla de
  clientes, después de la columna "Categoría".
- **RF-B03**: La columna "Métodos de envío" muestra un resumen de los métodos
  asignados al cliente (ej: número de días asignados, o nombres abreviados).
- **RF-B04**: Al pulsar en la celda "Métodos de envío", se abre un
  diálogo/selector que muestra los 7 días de la semana (Lunes a Domingo) y para
  cada día permite seleccionar un método de envío de la colección
  `shipping_methods`.
- **RF-B05**: Cada día puede tener un método de envío asignado o estar vacío
  (sin asignar).
- **RF-B06**: El usuario puede limpiar la asignación de un día individual.
- **RF-B07**: Los métodos de envío asignados por día se persisten en el
  documento del cliente en Firestore (ej: campo `shippingMethodsByDay` como mapa
  `{monday: "<id>", tuesday: "<id>", ...}`).

## 6) Criterios de aceptación

### Bloque A

- **CA-A01**: El ítem "Métodos de envío" aparece en el menú lateral entre
  "Categorías de cliente" y "Productos".
- **CA-A02**: Al navegar a la página, se cargan y muestran los métodos de envío
  existentes en tiempo real.
- **CA-A03**: Se puede crear un nuevo método de envío con nombre obligatorio
  (máx. 50 caracteres); si se supera el límite, se rechaza.
- **CA-A04**: El campo teléfono solo acepta exactamente 9 dígitos numéricos. Se
  rechaza entrada no numérica.
- **CA-A05**: Se puede eliminar un método de envío tras confirmación; desaparece
  de la lista en tiempo real.
- **CA-A06**: Al eliminar un método de envío, todas las asignaciones de ese
  método en clientes se limpian automáticamente (los días que tenían ese método
  quedan sin asignar).
- **CA-A07**: Se muestra feedback visual (toast/card) tras guardar o eliminar
  (éxito o error).
- **CA-A08**: El buscador filtra los métodos de envío por nombre en tiempo real.

### Bloque B

- **CA-B01**: La cabecera de la columna que antes decía "Nombre FD" ahora dice
  "Nombre Factura Directa".
- **CA-B02**: La nueva columna "Métodos de envío" aparece en la tabla de
  clientes.
- **CA-B03**: Al pulsar en la celda de métodos de envío, se abre un selector con
  los 7 días de la semana, donde cada día tiene un dropdown/selector con los
  métodos de envío disponibles.
- **CA-B04**: Las asignaciones día→método se persisten correctamente en
  Firestore y se reflejan en la tabla en tiempo real.
- **CA-B05**: Se puede limpiar la asignación de un día concreto.
- **CA-B06**: Un cliente puede tener entre 0 y 7 días asignados con métodos de
  envío.

## 7) Flujos y comportamiento esperado

### Flujo principal — Gestionar métodos de envío

1. El usuario navega al ítem "Métodos de envío" en el menú lateral.
2. Se muestra la página con el listado de métodos existentes (o vacío si no
   hay).
3. El usuario pulsa "Añadir método de envío".
4. Aparece una nueva fila con campos vacíos (Nombre, Teléfono).
5. El usuario rellena el nombre (obligatorio) y opcionalmente el teléfono.
6. Al perder el foco de cada campo, el cambio se guarda en Firestore.
7. Se muestra feedback de éxito.

### Flujo principal — Asignar métodos de envío por día a un cliente

1. El usuario está en la página de Clientes.
2. El usuario pulsa en la celda "Métodos de envío" de un cliente.
3. Se abre un diálogo que muestra los 7 días de la semana (Lunes a Domingo).
4. Para cada día, el usuario puede seleccionar un método de envío de un dropdown
   con los métodos disponibles, o dejarlo vacío.
5. Al confirmar, se guardan las asignaciones en Firestore.
6. La tabla refleja los métodos asignados.

### Flujos alternativos

- **Eliminar método de envío**: El usuario pulsa el botón de eliminar → aparece
  diálogo de confirmación → al confirmar, se elimina de Firestore, se limpian
  las referencias en clientes y desaparece de la lista.
- **Buscar método de envío**: El usuario escribe en el buscador → la lista se
  filtra en tiempo real.
- **Limpiar asignación de un día**: En el diálogo de selección, el usuario
  selecciona la opción vacía/ninguno para un día concreto → se elimina esa
  asignación.

### Estados especiales / excepciones

- **Estado vacío (métodos de envío)**: Si no hay métodos de envío creados,
  mostrar mensaje indicativo (ej: "No hay métodos de envío. Añade uno.").
- **Estado vacío (selector de cliente)**: Si no hay métodos de envío creados, el
  selector de días muestra los días pero sin opciones disponibles en los
  dropdowns.
- **Estado loading/procesando**: Mostrar indicador de carga mientras se obtienen
  los datos o se guarda un cambio.
- **Estado error**: Si falla la conexión con Firestore, mostrar mensaje de error
  con opción de reintentar.
- **Validación de nombre vacío**: No permitir guardar un método de envío sin
  nombre.
- **Validación de teléfono**: Si el usuario introduce menos o más de 9 dígitos,
  mostrar error visual. Solo se permite input numérico.

## 8) Edge cases

- **EC-01**: El usuario intenta crear un método de envío con nombre vacío → no
  se permite guardar; se muestra feedback de validación.
- **EC-02**: El usuario introduce caracteres no numéricos en el campo teléfono →
  el input los rechaza (inputFormatter numérico).
- **EC-03**: El usuario introduce un teléfono con menos o más de 9 dígitos y
  pierde el foco → se muestra error de validación, no se guarda hasta que sea
  válido o vacío.
- **EC-04**: El usuario elimina un método de envío que está asignado a clientes
  → se elimina el método y se limpian automáticamente todas las asignaciones de
  ese método en los documentos de clientes (los días que lo tenían asignado
  quedan sin método).
- **EC-05**: Nombre de método de envío con exactamente 50 caracteres → se
  acepta. Con 51 → se rechaza.
- **EC-06**: Dos métodos de envío con el mismo nombre → se permite (no hay
  restricción de unicidad).
- **EC-07**: El usuario asigna el mismo método de envío a los 7 días →
  comportamiento válido.
- **EC-08**: El usuario no asigna ningún método a ningún día → comportamiento
  válido, se guarda con mapa vacío o sin el campo.
- **EC-09**: El usuario asigna métodos de envío y luego se elimina uno de los
  métodos asignados → la limpieza automática (RF-A09) garantiza que el día queda
  sin asignar. Si la limpieza falla o hay delay, la UI debe ignorar IDs de
  métodos que no existen.

## 9) Impacto funcional

- **Módulos afectados**:
  - Menú lateral (`side_menu.dart`, `side_menu_shell.dart`,
    `side_menu_cubit.dart`): nuevo ítem e índice; los ítems posteriores se
    desplazan.
  - Página de Clientes: nueva columna, nuevo diálogo de asignación día→método,
    nuevo campo en entidad `Client`.
  - Firestore: nueva colección `shipping_methods` y nuevo campo
    `shippingMethodsByDay` en documentos de `clients`.
  - Lógica de eliminación de métodos de envío: batch update para limpiar
    referencias en clientes.
  - i18n: nuevas claves de traducción + modificación de `clientsColumnNameFd`.
  - Inyección de dependencias: nuevo módulo DI para shipping_methods.
- **Impacto en usuario**: Funcionalidad nueva que amplía la gestión de clientes
  y logística.
- **Impacto en experiencia de usuario**: La tabla de clientes tendrá una columna
  adicional; considerar el espacio horizontal disponible.

## 10) Suposiciones

- **S-01**: El nombre de la colección Firestore es `shipping_methods`.
- **S-02**: No se requiere unicidad de nombre en los métodos de envío.
- **S-03**: El teléfono es formato español (9 dígitos numéricos, sin prefijo
  internacional).
- **S-04**: El campo teléfono es opcional (puede quedar vacío).
- **S-05**: La página de métodos de envío no tiene toggle de activo/inactivo (a
  diferencia de Categorías de cliente). Solo CRUD con eliminación.
- **S-06**: Cada día de la semana solo puede tener un método de envío asignado
  por cliente.
- **S-07**: Los días se almacenan con claves en inglés en Firestore (`monday`,
  `tuesday`, ..., `sunday`) y se muestran localizados en la UI.
- **S-08**: Al eliminar un método de envío, la limpieza de referencias en
  clientes se hace como batch en el servidor (no depende del cliente Flutter).

## 11) Preguntas abiertas

- Todas las preguntas abiertas de v1 han sido resueltas.

## 12) Notas para análisis técnico

- La feature `shipping_methods` debe seguir exactamente la estructura Clean
  Architecture feature-first usada en `client_categories`: `data/datasources/`,
  `data/repositories/`, `domain/entities/`, `domain/repositories/`,
  `domain/usecases/`, `presentation/bloc/`, `presentation/pages/`,
  `presentation/widgets/`.
- Entidad `ShippingMethod`: solo `id`, `name`, `phone`.
- El menú lateral actualmente tiene 8 ítems (índices 0–7). Al insertar "Métodos
  de envío" en el índice 5 (después de Categorías de cliente), los ítems
  posteriores (Productos, Facturas, Ajustes) se desplazan a índices 6, 7, 8.
  Actualizar `_maxIndex` en `SideMenuCubit` y los separadores en `SideMenu`.
- La entidad `Client` necesita un nuevo campo (ej:
  `shippingMethodsByDay: Map<String, String>` donde key es día en inglés y value
  es ID del método).
- El diálogo de asignación de métodos de envío a clientes es nuevo: muestra 7
  filas (una por día, Lunes–Domingo), cada una con un dropdown de métodos
  disponibles + opción vacía. Diferente al `CategorySelectorDialog` existente.
- El use case de eliminación de método de envío debe incluir un paso de
  limpieza: consultar todos los clientes que tengan ese método asignado en
  cualquier día y eliminar la referencia. Considerar usar batch writes de
  Firestore.
- Considerar el ancho de la tabla de clientes al añadir la nueva columna; puede
  requerir ajustar los `flex` de las columnas existentes.
- Las claves i18n a modificar: `clientsColumnNameFd` (cambiar valor a "Nombre
  Factura Directa"). Nuevas claves para: ítem de menú, títulos de página, labels
  de campos, mensajes de feedback, diálogo de asignación por día, confirmación
  de eliminación, nombres de días de la semana, etc.
- Dependencia funcional: la lista de métodos de envío en el selector de clientes
  se obtiene de la misma colección `shipping_methods`.
- **Estado: Listo para análisis técnico**
