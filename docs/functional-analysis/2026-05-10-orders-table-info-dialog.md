# Functional Analysis: Icono de ayuda con diálogo informativo en la tabla de pedidos

- **Fecha:** 2026-05-10
- **Identificador:** orders-table-info-dialog
- **Estado:** Ready for technical analysis

## 1) Resumen

Añadir un icono de información ("Info") en la celda esquina inferior-derecha del
header de la tabla de pedidos (posición 2:2 — intersección de la fila "+ Añadir
producto" con la columna "+ Añadir cliente"). Al pulsarlo, se mostrará un
diálogo modal que explica al usuario cómo realizar las acciones principales
disponibles en la tabla de pedidos del día.

## 2) Contexto y objetivo

- **Qué se solicita:** Un punto de acceso de ayuda contextual dentro de la
  propia tabla de pedidos que informe al usuario sobre las acciones disponibles
  y cómo ejecutarlas.
- **Qué problema resuelve:** Los usuarios pueden no conocer todas las
  interacciones disponibles en la tabla (menús contextuales, gestos, flags,
  etc.), lo que reduce la descubribilidad de funcionalidades y aumenta la curva
  de aprendizaje.
- **Qué resultado funcional se espera:** El usuario puede consultar en cualquier
  momento una guía rápida de acciones sin salir de la pantalla de pedidos del
  día.

## 3) Alcance

### En alcance

- Icono de "Info" en la celda 2:2 de la tabla (esquina inferior-derecha del
  header de productos, actualmente un `Container` vacío con color primary).
- Diálogo modal que se muestra al pulsar el icono.
- Contenido del diálogo con instrucciones para las siguientes acciones:
  1. Cómo añadir un cliente
  2. Cómo añadir un producto
  3. Cómo modificar el stock
  4. Cómo poner el stock como estricto
  5. Cómo asignar cantidad de producto a un cliente
  6. Cómo marcar compensaciones de producto
  7. Cómo marcar reservas de producto
  8. Cómo quitar un cliente
  9. Cómo quitar un producto
  10. Cómo restablecer un pedido de un cliente
  11. Cómo generar una hoja de pedido
  12. Cómo generar una factura provisional de un cliente
- Los textos del diálogo deben estar internacionalizados (i18n).

### Fuera de alcance

- Tutoriales interactivos o guiados (onboarding/walkthrough).
- Tooltips individuales en cada celda o acción.
- Acceso a ayuda desde otras pantallas.
- Enlace a documentación externa o web.
- Vídeos o imágenes ilustrativas dentro del diálogo.

## 4) Actores implicados

- **Usuario final:** Cualquier usuario que accede a la pantalla de pedidos del
  día y necesita orientación sobre las acciones disponibles en la tabla.

## 5) Requisitos funcionales

- **RF-01:** Se debe mostrar un icono de información (ej. `Icons.info_outline`)
  en la celda 2:2 del header de la tabla de pedidos (esquina inferior-derecha,
  intersección entre la fila de "+ Añadir producto" y la columna de "+ Añadir
  cliente").
- **RF-02:** El icono debe ser visualmente coherente con la celda (color
  `onPrimary` sobre fondo `primary`, consistente con los botones adyacentes).
- **RF-03:** Al pulsar el icono, se debe abrir un diálogo modal (`showDialog` /
  `AlertDialog`) centrado en pantalla.
- **RF-04:** El diálogo debe contener un título descriptivo (ej. "Ayuda de la
  tabla de pedidos" o similar).
- **RF-05:** El cuerpo del diálogo debe listar las acciones disponibles con una
  breve explicación de cómo realizarlas. Las acciones a documentar son:
  - Añadir un cliente
  - Añadir un producto
  - Modificar el stock de un producto
  - Poner el stock como estricto
  - Asignar cantidad de producto a un cliente
  - Marcar compensaciones de producto
  - Marcar reservas de producto
  - Quitar un cliente
  - Quitar un producto
  - Restablecer un pedido de un cliente
  - Generar una hoja de pedido
  - Generar una factura provisional de un cliente
- **RF-08:** El diálogo debe tener un estilo cuidado y fácil de leer:
  - Cada acción debe presentarse con el **nombre en negrita** seguido de la
    descripción en peso normal.
  - Cada acción debe ir acompañada de un **icono representativo** a la izquierda
    (ej. `Icons.person_add` para añadir cliente, `Icons.delete` para quitar,
    etc.).
  - Debe haber **separación visual** entre cada acción (espaciado o dividers
    sutiles) para facilitar el escaneo visual.
  - El diálogo debe tener un **ancho generoso** (no estrecho) para que el texto
    no se comprima.
  - Usar jerarquía tipográfica clara: título prominente, descripciones en tamaño
    legible.
- **RF-06:** El diálogo debe tener un botón de cierre (ej. "Entendido" o
  "Cerrar") o poder cerrarse tocando fuera de él.
- **RF-07:** Todos los textos visibles al usuario deben estar
  internacionalizados mediante el sistema de i18n del proyecto
  (`AppLocalizations`).

## 6) Criterios de aceptación

- **CA-01:** Existe un icono de información visible en la celda 2:2 del header
  de la tabla de pedidos.
- **CA-02:** Al pulsar el icono se abre un diálogo modal con título y contenido
  informativo.
- **CA-03:** El diálogo lista las 12 acciones documentadas con instrucciones
  breves y comprensibles.
- **CA-04:** El diálogo se puede cerrar pulsando el botón de cierre o tocando
  fuera del diálogo.
- **CA-05:** Ningún texto visible al usuario está hardcodeado; todos utilizan
  claves de i18n.
- **CA-06:** El icono mantiene coherencia visual con el estilo de la tabla
  (colores del tema, tamaño proporcional a la celda).
- **CA-08:** Cada acción en el diálogo muestra un icono representativo y el
  nombre en negrita, con separación visual clara entre acciones.
- **CA-07:** El icono solo se muestra cuando los botones de "+ Añadir cliente" y
  "+ Añadir producto" están visibles (misma condición de visibilidad que la
  celda esquina actual).

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario accede a la pantalla de pedidos del día.
2. La tabla de pedidos se renderiza con el header (fecha, botones de añadir
   cliente/producto).
3. En la celda esquina (2:2) se muestra un icono de información.
4. El usuario pulsa el icono de información.
5. Se abre un diálogo modal con el título y la lista de instrucciones.
6. El usuario lee la información.
7. El usuario pulsa "Cerrar" o toca fuera del diálogo.
8. El diálogo se cierra y el usuario continúa trabajando en la tabla.

### Flujos alternativos

- **FA-01:** El usuario cierra el diálogo tocando fuera de él (barrier
  dismissible) → el diálogo se cierra normalmente.
- **FA-02:** El usuario pulsa el botón físico de retroceso (Android) → el
  diálogo se cierra.

### Estados especiales / excepciones

- **Estado sin callbacks:** Si `onAddClient` o `onAddProduct` son `null`, la
  celda esquina 2:2 no se muestra actualmente → el icono tampoco debe mostrarse.
- **Estado loading/procesando:** No aplica; el diálogo es estático y sin carga
  de datos.
- **Estado error:** No aplica; no hay operación que pueda fallar.

## 8) Edge cases

- **EC-01:** Pantalla muy pequeña → el diálogo debe ser scrollable si el
  contenido excede la altura disponible.
- **EC-02:** El icono no debe interferir con la funcionalidad de los botones
  adyacentes ("+ Añadir cliente" y "+ Añadir producto").
- **EC-03:** Si en el futuro se añaden más acciones a la tabla, el contenido del
  diálogo debería poder extenderse sin cambios estructurales (diseño extensible
  en el contenido i18n).

## 9) Impacto funcional

- **Módulos o procesos afectados:** Únicamente el widget `OrdersTable` en
  `features/orders_today/presentation/widgets/orders_table.dart`,
  específicamente la celda esquina del header.
- **Impacto en usuario o negocio:** Mejora la descubribilidad de funcionalidades
  y reduce la barrera de aprendizaje para nuevos usuarios.
- **Impacto en experiencia de usuario:** Positivo — proporciona ayuda contextual
  sin interrumpir el flujo de trabajo. La celda vacía actualmente desaprovechada
  gana utilidad.

## 10) Suposiciones

- El contenido descriptivo de cada acción (el "cómo") será redactado durante la
  implementación basándose en la mecánica real actual de la tabla (ej. "Pulsa el
  botón azul '+ Añadir cliente' en la parte superior derecha de la tabla", "Haz
  clic derecho sobre una celda para ver opciones de flags", etc.).
- Se asume que un `AlertDialog` o `SimpleDialog` estándar de Material es
  suficiente (no se requiere un diseño custom complejo).
- La celda 2:2 hace referencia a la esquina inferior-derecha del header de la
  tabla, actualmente un contenedor vacío de color primary que aparece cuando
  `onAddClient != null`.

## 11) Preguntas abiertas

- ~~**PA-01:**~~ Resuelta — El diálogo debe usar formato enriquecido: negrita
  para nombres de acción, icono representativo por cada entrada, separación
  visual clara.
- **PA-02:** ¿Hay alguna acción adicional más allá de las 12 listadas que deba
  documentarse en el diálogo?

## 12) Notas para análisis técnico

- La celda objetivo es el `SizedBox` + `Container(color: _colorScheme.primary)`
  en la línea ~658 de `orders_table.dart`, dentro de la fila inferior del
  `_buildProductHeader()`.
- Los textos deben añadirse al archivo ARB de i18n del proyecto.
- El diálogo debe usar `Theme.of(context)` para colores y tipografía (no
  hardcodear valores).
- Considerar usar un `ListView` dentro del diálogo para garantizar
  scrollabilidad en pantallas pequeñas (EC-01).
- Cada entrada del diálogo debe seguir un patrón visual tipo `ListTile` o
  similar: icono a la izquierda, título en negrita, subtítulo con la
  descripción. Separar con `Divider` sutil o espaciado vertical consistente.
- El diálogo debe tener un ancho mínimo generoso (ej. `maxWidth: 480`) para
  evitar que el texto se comprima.
- La condición de visibilidad del icono debe coincidir con
  `widget.onAddClient != null` (misma condición que la celda esquina actual).
- **Estado: Listo para análisis técnico**
