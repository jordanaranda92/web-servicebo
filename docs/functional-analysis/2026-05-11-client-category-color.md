# Functional Analysis: Color en categorías de cliente

- **Fecha:** 2026-05-11
- **Identificador:** client-category-color
- **Estado:** Ready for technical analysis

## 1) Resumen

Añadir un campo **color** a las categorías de cliente. El color se almacena en
hexadecimal en Firestore, se selecciona desde un picker con 10 opciones
predefinidas, se muestra como columna en la tabla de categorías y se aplica
visualmente al badge de categoría en la tabla de clientes y en el detalle de
cliente.

## 2) Contexto y objetivo

- **Qué se solicita:** Enriquecer la entidad `ClientCategory` con un atributo de
  color para diferenciar visualmente las categorías.
- **Qué problema resuelve:** Actualmente todos los badges de categoría usan el
  color `primary` del tema, lo que impide distinguirlas de un vistazo en la
  tabla de clientes y en el detalle.
- **Resultado funcional esperado:** Cada categoría de cliente tiene un color
  asociado. Ese color se refleja en todos los puntos de la UI donde se muestra
  la categoría.

## 3) Alcance

### En alcance

- Nuevo campo `color` en el documento Firestore de `client_categories` (formato
  hexadecimal, ej. `#FF5733`).
- Columna "Color" en la tabla de categorías (entre "Nombre" y "Acciones")
  mostrando una muestra visual del color.
- Selector de color con **10 colores predefinidos** en los diálogos de
  **añadir** y **editar** categoría.
- Badge de categoría en la **tabla de clientes** con el color de la categoría
  como fondo.
- Badge de categoría en el **detalle de cliente** con el color de la categoría
  como fondo.
- Propagación del color desde la categoría hasta los puntos de visualización del
  badge (análogo a como se resuelve `categoryName` actualmente).

### Fuera de alcance

- Selector de color libre (color picker arbitrario): solo se ofrecen 10 colores
  predefinidos.
- Cambio de colores predefinidos por el usuario (la paleta es fija en código).
- Migración de datos existentes: las categorías sin color usarán un fallback
  visual (color `primary` del tema, comportamiento actual).
- Impacto en pedidos, productos u otras entidades.
- Filtrado o agrupación de clientes por color de categoría.
- Uso del color de categoría en reportes, PDFs o exportaciones.

## 4) Actores implicados

| Actor                    | Rol                                                               |
| ------------------------ | ----------------------------------------------------------------- |
| Administrador / operador | Gestiona las categorías de cliente: crea, edita y asigna colores  |
| Usuario de consulta      | Visualiza los badges coloreados en la tabla de clientes y detalle |

## 5) Requisitos funcionales

- **RF-01:** La entidad categoría de cliente incluirá un campo `color` de tipo
  string en formato hexadecimal (ej. `#FF5733`).
- **RF-02:** El campo `color` es opcional. Si no tiene valor, se usa el color
  `primary` del tema como fallback.
- **RF-03:** Al crear una categoría, el diálogo mostrará un selector de color
  con 10 opciones predefinidas. El usuario puede elegir una o dejar sin
  seleccionar (fallback al color del tema).
- **RF-04:** Al editar una categoría, el diálogo mostrará el selector de color
  con el color actual preseleccionado (si tiene). El usuario puede cambiar el
  color o quitarlo mediante un botón explícito "Quitar color".
- **RF-05:** En la tabla de categorías, se mostrará una columna "Color" entre la
  columna "Nombre" y la columna "Acciones", con una muestra visual del color
  asignado (un círculo o cuadrado relleno). Si no tiene color, se muestra el
  fallback o un indicador vacío.
- **RF-06:** En la tabla de clientes, el badge de categoría usará como color de
  fondo el `color` de la categoría asociada (en lugar del fijo
  `colorScheme.primary`). Si la categoría no tiene color, mantiene el
  comportamiento actual.
- **RF-07:** En el detalle de cliente, el badge de categoría usará como color de
  fondo el `color` de la categoría asociada. Mismo fallback que RF-06.
- **RF-08:** El color se persiste en Firestore en el documento de la categoría,
  campo `color`, como string hexadecimal.
- **RF-09:** El color de la categoría se resuelve y propaga al cliente de forma
  análoga a como se resuelve `categoryName` actualmente (lookup por
  `clientCategoryId`).

## 6) Criterios de aceptación

- **CA-01:** Al crear una categoría seleccionando un color, el documento en
  Firestore contiene el campo `color` con el valor hexadecimal elegido.
- **CA-02:** Al editar una categoría y cambiar su color, el campo `color` en
  Firestore se actualiza correctamente.
- **CA-03:** La tabla de categorías muestra la columna "Color" entre "Nombre" y
  "Acciones" con la muestra visual correspondiente.
- **CA-04:** Al abrir el diálogo de edición de una categoría con color asignado,
  el selector muestra el color actual preseleccionado.
- **CA-05:** En la tabla de clientes, el badge de una categoría con color
  muestra dicho color como fondo. El texto del badge mantiene legibilidad (color
  de texto contrastante).
- **CA-06:** En el detalle de cliente, el badge usa el color de la categoría
  como fondo con texto legible.
- **CA-07:** Si una categoría no tiene color asignado, el badge usa
  `colorScheme.primary` (comportamiento actual sin regresión).
- **CA-08:** El selector de color muestra exactamente 10 opciones predefinidas.
- **CA-09:** El color seleccionado se persiste y recupera correctamente tras
  recargar la aplicación.

## 7) Flujos y comportamiento esperado

### Flujo principal — Crear categoría con color

1. El administrador pulsa "Añadir categoría".
2. Se abre el diálogo con campo "Nombre" y selector de color (10 opciones).
3. El usuario escribe el nombre y selecciona un color.
4. Pulsa "Guardar".
5. Se crea el documento en Firestore con `name` y `color`.
6. La tabla de categorías se actualiza mostrando la nueva fila con la muestra de
   color.
7. Los badges de clientes asignados a esa categoría reflejan el color.

### Flujo principal — Editar color de categoría existente

1. El administrador pulsa "Editar" en una categoría.
2. Se abre el diálogo con el nombre actual y el color actual preseleccionado.
3. El usuario cambia el color (o lo quita).
4. Pulsa "Guardar".
5. Se actualiza el documento en Firestore.
6. La tabla de categorías y los badges de clientes reflejan el cambio.

### Flujos alternativos

- **Sin selección de color:** El usuario crea o edita una categoría sin
  seleccionar color. El campo `color` queda `null` en Firestore. Los badges usan
  el fallback `colorScheme.primary`.
- **Categoría existente sin color (migración implícita):** Categorías creadas
  antes de este cambio no tienen campo `color`. Se comportan como si el color
  fuera `null` (fallback).

### Estados especiales / excepciones

- **Estado vacío:** No aplica (el color es un campo más de una categoría, no una
  vista nueva).
- **Estado loading/procesando:** El guardado ya gestiona un diálogo de progreso;
  no cambia.
- **Estado error:** Si falla la escritura en Firestore, se muestra el feedback
  de error existente; el color no se persiste.
- **Sin permisos:** Gestionado por las reglas de Firestore existentes; sin
  cambio funcional.

## 8) Edge cases

- **EC-01:** El usuario selecciona un color, luego pulsa "Quitar color" antes de
  guardar → se guarda sin color (`null`).
- **EC-02:** Dos categorías tienen el mismo color → permitido, no hay
  restricción de unicidad.
- **EC-03:** Se elimina una categoría con color → la eliminación funciona igual
  que ahora; los clientes huérfanos pierden badge (comportamiento actual).
- **EC-04:** El campo `color` en Firestore contiene un valor hexadecimal
  malformado (dato corrupto manual) → la UI debe manejar el fallo de parseo
  usando el color fallback.
- **EC-05:** Contraste de texto en badge: si el color de fondo es claro, el
  texto del badge debe ser oscuro (y viceversa) para mantener legibilidad.

## 9) Impacto funcional

- **Módulos afectados:**
  - `client_categories`: entidad, data source, repositorio, use cases, cubit, UI
    (tabla + diálogos).
  - `clients`: entidad (`Client` necesita recibir el color resuelto),
    repositorio (resolución de color), UI (tabla de clientes + detalle de
    cliente).
- **Impacto en usuario/negocio:** Mejora la capacidad de diferenciación visual
  de categorías. No hay cambio disruptivo.
- **Impacto en experiencia de usuario:** Los badges coloreados facilitan la
  identificación rápida de categorías en listados largos de clientes.

## 10) Suposiciones

- Los 10 colores predefinidos se definirán como constantes en código (no
  configurables desde Firestore ni desde ajustes de usuario).
- El formato hexadecimal incluye el prefijo `#` y 6 dígitos (ej. `#FF5733`), sin
  canal alfa.
- La selección de colores predefinidos (qué 10 colores concretos) se decidirá en
  análisis técnico o implementación, salvo que el usuario especifique una
  paleta.
- El color de texto del badge se calcula automáticamente para garantizar
  contraste (blanco sobre fondos oscuros, oscuro sobre fondos claros).

## 11) Preguntas abiertas

_Todas resueltas._

- **PA-01:** ¿La selección de color es obligatoria al crear/editar una
  categoría, o puede dejarse sin color? → **Confirmado:** es opcional, con
  fallback al color del tema.
- **PA-02:** ¿Hay una paleta de 10 colores específica deseada, o se deja a
  criterio del equipo de desarrollo? → **Confirmado:** a criterio del equipo.
- **PA-03:** ¿Al deseleccionar un color en edición, se espera un botón explícito
  "Quitar color" o basta con no tener ningún color seleccionado? →
  **Confirmado:** botón explícito "Quitar color".

## 12) Notas para análisis técnico

- La entidad `ClientCategory` actualmente solo tiene `id` y `name`. Requiere
  añadir `color` (String?).
- El data source Firestore (`ClientCategoryFirestoreDataSourceImpl`) lee/escribe
  solo `name`. Necesita incluir `color`.
- Los métodos `add` y `update` del repositorio y use cases actualmente solo
  aceptan `name`. Deben aceptar `color`.
- `ClientsRepositoryImpl` ya resuelve `categoryName` a partir de un mapa
  `id → name`. Debe extenderse para resolver también el color (`id → color`).
- La entidad `Client` necesita un nuevo campo opcional `categoryColor` (análogo
  a `categoryName`).
- El badge de categoría en `clients_page.dart` (líneas ~510-530) y
  `client_detail_page.dart` (líneas ~100-120) usa `colorScheme.primary` como
  color de fondo. Debe reemplazarse por el color de la categoría cuando esté
  disponible.
- Considerar calcular luminancia del color para decidir si el texto del badge es
  blanco o negro.
- Los diálogos de añadir y editar categoría están en
  `client_categories_page.dart` (métodos `_showAddCategoryDialog` y
  `_showEditDialog`). Requieren integrar el selector de color.
- **Estado: Listo para análisis técnico**
