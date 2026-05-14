# Functional Analysis: Reordenación de productos por drag & drop

- **Fecha:** 2026-05-11
- **Identificador:** product-drag-reorder
- **Estado:** Ready for technical analysis

## 1) Resumen

Sustituir la edición manual del campo "Orden" (input numérico fila por fila) por
un botón "Ordenar productos" que abre un diálogo modal con una lista reordenable
mediante drag & drop. Al confirmar, se persisten los nuevos valores de orden de
todos los productos afectados en un solo lote.

## 2) Contexto y objetivo

### Qué se solicita

Actualmente cada producto tiene una columna "Orden" en la tabla de
`ProductsPage` donde el usuario introduce manualmente un número entero por cada
fila. Este mecanismo es lento, propenso a errores (duplicados, huecos) y no
ofrece retroalimentación visual del resultado final.

### Qué problema resuelve

- **Fricción de uso:** introducir un número por cada producto es tedioso,
  especialmente con muchos productos.
- **Errores de coherencia:** el usuario puede asignar el mismo orden a dos
  productos o dejar huecos en la secuencia.
- **Falta de contexto:** al editar un número en una fila no se ve cómo queda el
  orden global hasta que se recarga la vista.

### Resultado funcional esperado

Un flujo intuitivo donde el usuario arrastra productos para ordenarlos
visualmente y confirma el resultado, eliminando la necesidad de pensar en
números.

## 3) Alcance

### En alcance

- Nuevo botón "Ordenar productos" en la barra de acciones de `ProductsPage`,
  junto al botón "Añadir producto"
- Diálogo modal con lista reordenable por drag & drop que muestra todos los
  productos activos e inactivos
- Asignación automática de valores de orden secuenciales (1, 2, 3, …) según la
  posición resultante del drag
- Persistencia del nuevo orden en lote mediante la infraestructura existente
  (`saveBatchChanges` / `orderChanges`)
- Feedback visual al usuario tras guardar con éxito o error
- Eliminación de la columna "Orden" de la tabla principal (ya no es necesaria la
  edición manual)

### Fuera de alcance

- Reordenación directa en la tabla (inline drag de filas en la tabla)
- Reordenación desde dispositivos móviles (el producto es web/desktop)
- Filtrado o agrupación dentro del diálogo de reordenación
- Cambios en el modelo de datos de `Product` (el campo `order: int?` ya existe y
  se reutiliza)
- Ordenación automática por nombre, precio u otro criterio

## 4) Actores implicados

| Actor                 | Rol                                                                                           |
| --------------------- | --------------------------------------------------------------------------------------------- |
| Usuario administrador | Abre la página de productos, invoca el diálogo de reordenación, arrastra productos y confirma |
| Sistema (Firestore)   | Persiste los nuevos valores de orden en batch                                                 |

## 5) Requisitos funcionales

- **RF-01:** La barra de acciones de `ProductsPage` debe mostrar un botón
  "Ordenar productos" a la derecha del botón "Añadir producto".
- **RF-02:** Al pulsar "Ordenar productos" se abre un diálogo modal centrado con
  la lista de **todos los productos** (activos e inactivos), ordenados por su
  valor de `order` actual (productos sin orden al final).
- **RF-03:** Cada elemento de la lista muestra al menos: nombre del producto,
  indicador de color y estado activo/inactivo.
- **RF-04:** El usuario puede arrastrar cualquier elemento para reposicionarlo
  dentro de la lista.
- **RF-05:** Un handle de arrastre (icono grip/drag) visible a la izquierda de
  cada elemento indica que es arrastrable.
- **RF-06:** El diálogo tiene dos acciones: "Cancelar" (cierra sin cambios) y
  "Guardar" (aplica el nuevo orden).
- **RF-07:** Al pulsar "Guardar", el sistema asigna valores secuenciales de
  orden (1, 2, 3, …) a todos los productos según su posición final en la lista.
- **RF-08:** Solo se envían a `saveBatchChanges` los productos cuyo valor de
  `order` haya cambiado respecto al original, para minimizar escrituras.
- **RF-09:** Si ningún producto cambió de posición, "Guardar" cierra el diálogo
  sin llamar al backend.
- **RF-10:** Tras persistir con éxito, se muestra el feedback de éxito existente
  y la tabla refleja el nuevo orden.
- **RF-11:** Eliminar la columna "Orden" (input numérico) de la tabla de
  productos, ya que el diálogo la reemplaza.
- **RF-12:** Eliminar la lógica de `_orderControllers` y el guardado de orden
  por focus-change en la tabla, ya que ya no aplica.

## 6) Criterios de aceptación

- **CA-01:** El botón "Ordenar productos" es visible junto a "Añadir producto"
  cuando la lista de productos está cargada.
- **CA-02:** Al abrir el diálogo, los productos aparecen en el mismo orden que
  en la tabla principal (por `order` ascendente, sin orden al final).
- **CA-03:** Se puede arrastrar un producto de la posición 5 a la posición 1 y
  la lista se actualiza visualmente en tiempo real.
- **CA-04:** Al cancelar el diálogo no se produce ninguna escritura a Firestore
  y la tabla mantiene el orden original.
- **CA-05:** Al confirmar, los productos reordenados reciben valores de `order`
  consecutivos empezando en 1.
- **CA-06:** Solo los productos cuyo `order` cambió generan escrituras a
  Firestore.
- **CA-07:** Si la escritura falla, se muestra el feedback de error existente y
  el diálogo permanece abierto (o se muestra el error tras cerrarse, según UX
  preferida).
- **CA-08:** La columna "Orden" con input numérico ya no aparece en la tabla de
  productos.
- **CA-09:** El botón "Ordenar productos" está correctamente internacionalizado
  (i18n).

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario navega a la página de productos (`ProductsPage`).
2. Los productos se cargan y se muestran en la tabla.
3. El usuario pulsa el botón "Ordenar productos".
4. Se abre un diálogo modal con la lista de productos en el orden actual.
5. El usuario arrastra uno o más productos a nuevas posiciones.
6. El usuario pulsa "Guardar".
7. El sistema calcula los cambios de orden, envía solo los que cambiaron a
   `saveBatchChanges`.
8. Se muestra un indicador de progreso mientras se guarda.
9. Tras éxito, el diálogo se cierra y se muestra el feedback de éxito.
10. La tabla refleja el nuevo orden automáticamente (gracias al stream de
    Firestore ya existente).

### Flujos alternativos

- **FA-01 — Cancelar:** El usuario abre el diálogo, opcionalmente arrastra
  productos, y pulsa "Cancelar". El diálogo se cierra sin cambios.
- **FA-02 — Sin cambios:** El usuario abre el diálogo, no mueve nada y pulsa
  "Guardar". El sistema detecta que no hay cambios y cierra el diálogo sin
  llamar al backend.
- **FA-03 — Cierre por fuera:** El usuario pulsa fuera del diálogo (si
  `barrierDismissible` es true). Se comporta como "Cancelar".

### Estados especiales / excepciones

- **Estado vacío:** Si no hay productos, el botón "Ordenar productos" está
  deshabilitado o no aparece.
- **Estado loading:** Mientras se guarda, se muestra un indicador de progreso
  (spinner + texto). Los botones del diálogo se deshabilitan para evitar doble
  envío.
- **Estado error:** Si `saveBatchChanges` falla, se muestra el feedback de
  error. El usuario puede reintentar o cancelar.
- **Productos sin orden previo:** Los productos con `order == null` se colocan
  al final de la lista al abrir el diálogo. Tras confirmar, reciben un valor de
  orden secuencial como el resto.

## 8) Edge cases

- **EC-01:** Todos los productos tienen `order == null` (nunca se ordenaron). El
  diálogo los muestra en el orden en que llegan del stream y al guardar se
  asignan órdenes secuenciales a todos.
- **EC-02:** Solo hay un producto. El botón "Ordenar productos" puede mostrarse
  pero no habrá reordenación posible (aceptable, es un caso trivial).
- **EC-03:** Dos productos tienen el mismo valor de `order`. El diálogo los
  muestra en el orden que devuelva Firestore y al guardar se corrige la
  duplicación.
- **EC-04:** Se añade un producto mientras el diálogo está abierto. El diálogo
  trabaja con una copia snapshot; el nuevo producto no aparecerá hasta la
  próxima apertura. Esto es aceptable.
- **EC-05:** Se elimina un producto mientras el diálogo está abierto. Si el
  usuario confirma, la llamada a `saveBatchChanges` con un ID inexistente debe
  manejarse sin error (la infraestructura actual ya lo soporta).

## 9) Impacto funcional

- **Módulos afectados:** `ProductsPage` (UI de tabla y barra de acciones),
  `ProductsCubit` (se reutiliza `saveBatchChanges` sin cambios).
- **Impacto en usuario:** Experiencia muy mejorada para ordenar productos — pasa
  de una operación manual y propensa a errores a un gesto intuitivo de drag &
  drop.
- **Impacto en experiencia de usuario:** Se elimina una columna de la tabla (más
  limpia), se añade un botón de acción y un diálogo nuevo. El flujo es más
  rápido y menos propenso a errores.
- **Impacto en datos:** No hay cambio de modelo; se sigue usando el campo
  `order: int?` de `Product`. Los valores se normalizan a secuencia consecutiva.

## 10) Suposiciones

- El campo `order` existente en `Product` es suficiente y no requiere cambios de
  modelo.
- La infraestructura de `saveBatchChanges` con `orderChanges` soporta actualizar
  el orden de todos los productos en lote sin limitaciones de rendimiento
  (tamaño de batch razonable).
- La aplicación es web/desktop, por lo que el drag & drop con ratón es el
  mecanismo principal.
- El stream de Firestore existente refrescará la tabla automáticamente tras
  persistir los cambios.

## 11) Preguntas abiertas

_Sin preguntas abiertas — todas resueltas._

### Decisiones confirmadas

- **PA-01 (resuelta):** Sí, distinguir visualmente productos activos de
  inactivos en la lista del diálogo (p. ej. opacidad reducida, badge de estado).
- **PA-02 (resuelta):** Sí, ancho fijo moderado (~480px), consistente con otros
  diálogos del proyecto.

## 12) Notas para análisis técnico

- Reutilizar `ProductsCubit.saveBatchChanges(orderChanges: ...)` — no requiere
  nuevos use cases ni cambios en repositorio.
- Flutter proporciona `ReorderableListView` como widget nativo para drag & drop
  en listas.
- Eliminar `_orderControllers`, la columna "Orden" de `_buildTable` /
  `_buildRow`, y la lógica de guardado por focus-change del campo orden.
- Añadir nueva clave i18n para el botón ("Ordenar productos" / "Reorder
  products") y para el título del diálogo.
- El diálogo debe trabajar con una copia local de la lista de productos
  (snapshot), no con el estado reactivo del cubit, para evitar interferencias
  durante el drag.
- **Estado: Listo para análisis técnico**
