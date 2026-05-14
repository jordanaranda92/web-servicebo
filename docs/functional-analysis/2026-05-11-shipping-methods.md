# Functional Analysis: Métodos de envío y mejoras en tabla de Clientes

- **Fecha:** 2026-05-11
- **Identificador:** shipping-methods
- **Estado:** Ready for technical analysis

## 1) Resumen

Se solicitan dos bloques de cambios:

1. **Nuevo módulo "Métodos de envío"**: crear un nuevo ítem en el menú lateral
   con su página asociada para gestionar métodos de envío almacenados en
   Firestore, siguiendo la estética y patrones de la página "Categorías de
   cliente".
2. **Mejoras en la tabla de Clientes**: renombrar la columna "Nombre FD" a
   "Nombre Factura Directa" y añadir una nueva columna "Métodos de envío" con
   selector múltiple.

## 2) Contexto y objetivo

- **Qué se solicita:** Ampliar la aplicación con la gestión de métodos de envío
  (CRUD) y asociar dichos métodos a los clientes existentes.
- **Qué problema resuelve:** Actualmente no existe un lugar en la aplicación
  para gestionar los métodos de envío disponibles ni para asignarlos a los
  clientes. Además, la columna "Nombre FD" no es suficientemente descriptiva.
- **Resultado funcional esperado:**
  - El usuario puede crear, editar y eliminar métodos de envío desde una página
    dedicada.
  - El usuario puede asignar uno o varios métodos de envío a cada cliente desde
    la tabla de clientes.
  - La columna "Nombre FD" pasa a llamarse "Nombre Factura Directa" para mayor
    claridad.

## 3) Alcance

### En alcance

- Nuevo ítem "Métodos de envío" en el menú lateral (sidebar).
- Nueva página de gestión de métodos de envío con:
  - Listado de métodos de envío existentes.
  - Buscador/filtro por nombre.
  - Creación de nuevos métodos de envío.
  - Edición inline de los campos: Nombre, Teléfono, Días disponible.
  - Eliminación de métodos de envío.
- Persistencia en Firestore en la colección `shipping_methods`.
- En la tabla de Clientes:
  - Renombrado de columna "Nombre FD" → "Nombre Factura Directa".
  - Nueva columna "Métodos de envío" con selector múltiple para
    asignar/desasignar métodos de envío a cada cliente.
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

- **Usuario administrador**: gestiona los métodos de envío y asigna métodos a
  clientes.
- **Sistema (Firestore)**: persiste los datos de métodos de envío y la relación
  con clientes.

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
  Al pulsarlo, se crea una nueva fila (o se abre un formulario) con los campos
  vacíos.
- **RF-A06**: Cada método de envío tiene los siguientes campos editables inline:
  - **Nombre** (texto, máximo 50 caracteres, obligatorio).
  - **Teléfono** (numérico, exactamente 9 dígitos, opcional).
  - **Días disponible** (selector múltiple de días de la semana: Lunes, Martes,
    Miércoles, Jueves, Viernes, Sábado, Domingo).
- **RF-A07**: Los cambios en cada campo se guardan al perder el foco
  (comportamiento consistente con Categorías de cliente y Clientes).
- **RF-A08**: Cada fila incluye un botón/icono para eliminar el método de envío,
  con diálogo de confirmación previo.
- **RF-A09**: Se debe mostrar feedback visual (mensaje de éxito/error) al
  guardar o eliminar, igual que en las páginas existentes.
- **RF-A10**: La página usa escucha en tiempo real (stream/listener) de la
  colección Firestore, igual que Categorías de cliente.

### Bloque B — Mejoras en tabla de Clientes

- **RF-B01**: Renombrar la cabecera de columna "Nombre FD" a "Nombre Factura
  Directa" (cambio en i18n, clave `clientsColumnNameFd`).
- **RF-B02**: Añadir una nueva columna "Métodos de envío" en la tabla de
  clientes, después de la columna "Categoría".
- **RF-B03**: La columna "Métodos de envío" muestra los métodos asignados al
  cliente (nombres separados, chips, o similar).
- **RF-B04**: Al pulsar en la celda de "Métodos de envío", se abre un
  diálogo/selector que permite seleccionar uno o varios métodos de envío de la
  colección `shipping_methods`. El comportamiento debe ser análogo al selector
  de categoría existente, pero con selección múltiple.
- **RF-B05**: El usuario puede desasignar métodos de envío individualmente o
  limpiar todos.
- **RF-B06**: Los métodos de envío asignados se persisten en el documento del
  cliente en Firestore (ej: campo `shippingMethodIds` como array de IDs).

## 6) Criterios de aceptación

### Bloque A

- **CA-A01**: El ítem "Métodos de envío" aparece en el menú lateral entre
  "Categorías de cliente" y "Productos".
- **CA-A02**: Al navegar a la página, se cargan y muestran los métodos de envío
  existentes en tiempo real.
- **CA-A03**: Se puede crear un nuevo método de envío con nombre obligatorio
  (máx. 50 caracteres); si se supera el límite, se trunca o se muestra error.
- **CA-A04**: El campo teléfono solo acepta exactamente 9 dígitos numéricos. Se
  rechaza entrada no numérica.
- **CA-A05**: El selector de días permite seleccionar/deseleccionar cualquier
  combinación de los 7 días de la semana.
- **CA-A06**: Se puede eliminar un método de envío tras confirmación; desaparece
  de la lista en tiempo real.
- **CA-A07**: Se muestra feedback visual (toast/card) tras guardar o eliminar
  (éxito o error).
- **CA-A08**: El buscador filtra los métodos de envío por nombre en tiempo real.

### Bloque B

- **CA-B01**: La cabecera de la columna que antes decía "Nombre FD" ahora dice
  "Nombre Factura Directa".
- **CA-B02**: La nueva columna "Métodos de envío" aparece en la tabla de
  clientes.
- **CA-B03**: Al pulsar en la celda de métodos de envío, se abre un selector
  múltiple con los métodos disponibles.
- **CA-B04**: Los métodos seleccionados se persisten correctamente en Firestore
  y se reflejan en la tabla al recargar o en tiempo real.
- **CA-B05**: Se pueden desasignar métodos de envío de un cliente.

## 7) Flujos y comportamiento esperado

### Flujo principal — Gestionar métodos de envío

1. El usuario navega al ítem "Métodos de envío" en el menú lateral.
2. Se muestra la página con el listado de métodos existentes (o vacío si no
   hay).
3. El usuario pulsa "Añadir método de envío".
4. Aparece una nueva fila con campos vacíos (Nombre, Teléfono, Días disponible).
5. El usuario rellena el nombre (obligatorio), opcionalmente el teléfono y
   selecciona días.
6. Al perder el foco de cada campo, el cambio se guarda en Firestore.
7. Se muestra feedback de éxito.

### Flujo principal — Asignar métodos de envío a un cliente

1. El usuario está en la página de Clientes.
2. El usuario pulsa en la celda "Métodos de envío" de un cliente.
3. Se abre un diálogo con la lista de métodos de envío disponibles (con
   búsqueda).
4. El usuario marca/desmarca los métodos deseados.
5. Al confirmar, se guardan las asociaciones en Firestore.
6. La tabla refleja los métodos asignados.

### Flujos alternativos

- **Eliminar método de envío**: El usuario pulsa el botón de eliminar → aparece
  diálogo de confirmación → al confirmar, se elimina de Firestore y desaparece
  de la lista.
- **Buscar método de envío**: El usuario escribe en el buscador → la lista se
  filtra en tiempo real.
- **Desasignar método de envío de un cliente**: El usuario abre el selector de
  un cliente → desmarca métodos → confirma → se actualiza Firestore.

### Estados especiales / excepciones

- **Estado vacío**: Si no hay métodos de envío creados, mostrar mensaje
  indicativo (ej: "No hay métodos de envío. Añade uno.").
- **Estado loading/procesando**: Mostrar indicador de carga mientras se obtienen
  los datos o se guarda un cambio.
- **Estado error**: Si falla la conexión con Firestore, mostrar mensaje de error
  con opción de reintentar (patrón existente en la app).
- **Validación de nombre vacío**: No permitir guardar un método de envío sin
  nombre. Mostrar indicación visual.
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
- **EC-04**: El usuario elimina un método de envío que está asignado a uno o
  varios clientes → el método desaparece de la colección; las referencias en los
  clientes quedan huérfanas. **Decisión necesaria**: ¿se deben limpiar
  automáticamente las referencias en los clientes o simplemente se ignoran al
  mostrar? (Ver Pregunta abierta PA-01).
- **EC-05**: El usuario selecciona los 7 días de la semana → comportamiento
  válido, se guardan todos.
- **EC-06**: El usuario no selecciona ningún día → comportamiento válido, se
  guarda con array vacío.
- **EC-07**: Nombre de método de envío con exactamente 50 caracteres → se
  acepta. Con 51 → se rechaza o trunca.
- **EC-08**: Dos métodos de envío con el mismo nombre → se permite (no hay
  restricción de unicidad definida). **Supuesto**: no se requiere unicidad de
  nombre.

## 9) Impacto funcional

- **Módulos afectados**:
  - Menú lateral (`side_menu.dart`, `side_menu_shell.dart`,
    `side_menu_cubit.dart`): nuevo ítem e índice.
  - Página de Clientes: nueva columna, nuevo selector, nuevo campo en entidad
    `Client`.
  - Firestore: nueva colección `shipping_methods` y nuevo campo en documentos de
    `clients`.
  - i18n: nuevas claves de traducción + modificación de `clientsColumnNameFd`.
  - Inyección de dependencias: nuevo módulo DI para shipping_methods.
- **Impacto en usuario**: Funcionalidad nueva que amplía la gestión de clientes
  y logística.
- **Impacto en experiencia de usuario**: La tabla de clientes tendrá una columna
  adicional; considerar el espacio horizontal disponible.

## 10) Suposiciones

- **S-01**: El nombre de la colección Firestore es `shipping_methods` (el
  usuario mencionó "shippong_methods" inicialmente, pero luego usó
  "shipping_methods"; se asume este último como correcto).
- **S-02**: No se requiere unicidad de nombre en los métodos de envío.
- **S-03**: El teléfono es formato español (9 dígitos numéricos, sin prefijo
  internacional).
- **S-04**: El campo teléfono es opcional (puede quedar vacío).
- **S-05**: Los días disponibles se almacenan como array de strings o enteros
  representando los días de la semana.
- **S-06**: La página de métodos de envío no tiene toggle de activo/inactivo (a
  diferencia de Categorías de cliente). Solo CRUD completo con eliminación.
- **S-07**: El selector de métodos de envío en la tabla de clientes es de
  selección múltiple (a diferencia del selector de categoría que es de selección
  única).
- **S-08**: Al eliminar un método de envío asignado a clientes, las referencias
  huérfanas se ignoran silenciosamente en la UI (no se muestran métodos
  inexistentes).

## 11) Preguntas abiertas

- **PA-01**: Cuando se elimina un método de envío que está asignado a clientes,
  ¿se deben limpiar automáticamente las referencias en los documentos de los
  clientes, o se ignoran al renderizar? (Supuesto actual: se ignoran al
  renderizar, S-08).
- **PA-02**: ¿Se necesita un orden específico de los días de la semana en el
  selector (ej: Lunes primero) o sigue el orden cultural estándar español
  (Lunes–Domingo)?

## 12) Notas para análisis técnico

- La feature `shipping_methods` debe seguir exactamente la estructura Clean
  Architecture feature-first usada en `client_categories`: `data/datasources/`,
  `data/repositories/`, `domain/entities/`, `domain/repositories/`,
  `domain/usecases/`, `presentation/bloc/`, `presentation/pages/`,
  `presentation/widgets/`.
- El menú lateral actualmente tiene 8 ítems (índices 0–7). Al insertar "Métodos
  de envío" en el índice 5 (después de Categorías de cliente), los ítems
  posteriores (Productos, Facturas, Ajustes) se desplazan a índices 6, 7, 8.
  Actualizar `_maxIndex` en `SideMenuCubit` y los separadores en `SideMenu`.
- La entidad `Client` necesita un nuevo campo (ej:
  `shippingMethodIds: List<String>`) y su modelo de datos correspondiente.
- El selector múltiple para métodos de envío en la tabla de clientes es distinto
  al selector de categoría (que es selección única). Se necesita un nuevo widget
  de diálogo de selección múltiple, o adaptar `CategorySelectorDialog` para
  soportar multi-selección.
- Considerar el ancho de la tabla de clientes al añadir la nueva columna; puede
  requerir ajustar los `flex` de las columnas existentes.
- Las claves i18n a modificar: `clientsColumnNameFd` (cambiar valor a "Nombre
  Factura Directa"). Nuevas claves para: ítem de menú, títulos de página, labels
  de campos, mensajes de feedback, diálogo de selección múltiple, confirmación
  de eliminación, días de la semana, etc.
- Dependencia funcional: la lista de métodos de envío en el selector de clientes
  se obtiene de la misma colección `shipping_methods`.
- **Estado: Listo para análisis técnico**
