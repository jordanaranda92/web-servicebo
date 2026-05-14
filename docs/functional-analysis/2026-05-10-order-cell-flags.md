# Functional Analysis: Flags de celda en pedidos (compensación, reserva, stock estricto)

- **Fecha:** 2026-05-10
- **Identificador:** order-cell-flags
- **Estado:** Ready for technical analysis

## 1) Resumen

Añadir menú contextual (click derecho) en las celdas de cantidad de
producto/cliente y de stock en la pantalla de pedidos de hoy, permitiendo
marcar/desmarcar estados visuales (compensación, reserva, stock estricto) que se
persisten en Firestore y se propagan en tiempo real a todos los usuarios
conectados.

## 2) Contexto y objetivo

**Qué se solicita:** Los operadores necesitan anotar información contextual
sobre ciertas celdas de la tabla de pedidos:

- **Compensación**: una cantidad que se entrega como compensación (no es un
  pedido normal). Se indica visualmente con fondo verde pastel.
- **Reserva**: una cantidad reservada para un cliente específico. Se indica
  visualmente con fondo azul pastel.
- **Stock estricto**: un producto cuyo stock no debe sobrepasarse bajo ningún
  concepto. Se indica visualmente con fuente en color rojo.

**Qué problema resuelve:** Actualmente no existe una forma de distinguir
visualmente ni semánticamente celdas que representan compensaciones, reservas o
stocks estrictos. Esta información se gestiona de forma verbal o en notas
externas, lo que genera errores y descoordinación entre los operadores que
trabajan simultáneamente.

**Resultado funcional esperado:** Cada celda de cantidad (producto × cliente)
puede tener flags independientes de "compensación" y "reserva" que alteran su
aspecto visual. Cada celda de stock puede tener un flag de "stock estricto" que
cambia el color de la fuente. Estos estados se persisten y se sincronizan en
tiempo real con todos los usuarios.

## 3) Alcance

### En alcance

- Menú contextual (click derecho) en celdas de cantidad de cliente con opciones:
  marcar/desmarcar compensación, marcar/desmarcar reserva
- Menú contextual (click derecho) en celdas de stock con opción:
  marcar/desmarcar stock estricto
- Indicadores visuales diferenciados por cada flag:
  - Compensación → fondo verde pastel
  - Reserva → fondo azul pastel
  - Stock estricto → color de fuente rojo
- Texto del menú contextual dinámico según el estado actual ("Marcar como..." /
  "Desmarcar como...")
- Persistencia de los flags en Firestore
- Propagación en tiempo real a otros usuarios conectados a la pantalla de
  pedidos

### Fuera de alcance

- Lógica de negocio que impida pedidos cuando el stock estricto se agota (es
  solo un indicador visual, no un bloqueo funcional)
- Historial de cambios de flags
- Filtrado o agrupación de celdas por flag
- Notificaciones o alertas al marcar/desmarcar un flag
- Flags para las columnas de resumen (PEDIDOS, QUEDAN)
- Interacción con el sistema de generación de albaranes/facturas

## 4) Actores implicados

| Actor                           | Rol                                                                       |
| ------------------------------- | ------------------------------------------------------------------------- |
| **Operador de pedidos**         | Marca/desmarca flags en celdas de la tabla de pedidos del día             |
| **Otros operadores conectados** | Reciben los cambios de flags en tiempo real y ven las celdas actualizadas |
| **Sistema (Firestore)**         | Persiste y propaga los flags entre clientes                               |

## 5) Requisitos funcionales

- **RF-01**: Al hacer click derecho sobre una celda de cantidad (producto ×
  cliente), se muestra un menú contextual con las opciones "Marcar como
  compensación" / "Desmarcar como compensación" y "Marcar como reserva" /
  "Desmarcar como reserva", según el estado actual de la celda.
- **RF-02**: Al seleccionar "Marcar como compensación", la celda se sombreará
  con fondo verde pastel. Al desmarcar, recupera su color por defecto.
- **RF-03**: Al seleccionar "Marcar como reserva", la celda se sombreará con
  fondo azul pastel. Al desmarcar, recupera su color por defecto.
- **RF-04**: Compensación y reserva son mutuamente excluyentes en una misma
  celda. Al activar uno se desactiva automáticamente el otro si estaba activo.
- **RF-05**: Al hacer click derecho sobre una celda de stock, se muestra un menú
  contextual con la opción "Marcar como stock estricto" / "Desmarcar como stock
  estricto", según el estado actual.
- **RF-06**: Al seleccionar "Marcar como stock estricto", el texto de la celda
  de stock cambia a color rojo. Al desmarcar, recupera su color de fuente por
  defecto.
- **RF-07**: Los cambios de flags se persisten en Firestore inmediatamente tras
  la acción del usuario.
- **RF-08**: Los cambios de flags se propagan en tiempo real a todos los
  usuarios conectados a la pantalla de pedidos del mismo día, a través de los
  listeners de Firestore ya existentes.
- **RF-09**: El menú contextual no debe interferir con la edición de celdas
  existente (tap para editar valor numérico).
- **RF-10**: El menú contextual solo aparece en celdas editables (cantidad de
  cliente y stock). No aparece en celdas de PEDIDOS ni QUEDAN.

## 6) Criterios de aceptación

- **CA-01**: Click derecho sobre una celda de cantidad muestra un menú
  contextual con exactamente dos opciones relativas a compensación y reserva,
  con texto dinámico según estado actual.
- **CA-02**: Marcar una celda como compensación la pinta con fondo verde pastel;
  desmarcar la devuelve al color por defecto (respetando alternancia de filas).
- **CA-03**: Marcar una celda como reserva la pinta con fondo azul pastel;
  desmarcar la devuelve al color por defecto.
- **CA-04**: Click derecho sobre una celda de stock muestra un menú contextual
  con una opción de stock estricto con texto dinámico.
- **CA-05**: Marcar stock estricto cambia el color de la fuente a rojo;
  desmarcar lo restaura.
- **CA-06**: Cerrar la app y volver a abrirla conserva todos los flags activos
  (persistencia en Firestore).
- **CA-07**: Un segundo usuario conectado simultáneamente ve el cambio de flag
  en menos de 3 segundos tras la acción del primer usuario.
- **CA-08**: Editar el valor numérico de una celda con flag activo no elimina el
  flag.
- **CA-09**: Eliminar un cliente o producto que tiene flags activos no provoca
  errores (los flags se eliminan con el subdocumento correspondiente).

## 7) Flujos y comportamiento esperado

### Flujo principal — Marcar compensación

1. El operador hace click derecho sobre una celda de cantidad (producto ×
   cliente).
2. Se muestra un menú contextual con:
   - "Marcar como compensación"
   - "Marcar como reserva"
3. El operador selecciona "Marcar como compensación".
4. El sistema actualiza el flag en Firestore.
5. La celda se pinta con fondo verde pastel.
6. Otros usuarios ven el cambio a través del listener de Firestore.

### Flujo principal — Desmarcar compensación

1. El operador hace click derecho sobre una celda que ya tiene el flag de
   compensación activo.
2. Se muestra un menú contextual con:
   - "Desmarcar como compensación"
   - "Marcar como reserva" (o "Desmarcar..." si también estuviera activa)
3. El operador selecciona "Desmarcar como compensación".
4. El sistema elimina el flag en Firestore.
5. La celda vuelve a su color por defecto.

### Flujo principal — Stock estricto

1. El operador hace click derecho sobre una celda de stock.
2. Se muestra un menú contextual con "Marcar como stock estricto".
3. El operador selecciona la opción.
4. El sistema actualiza el flag en Firestore.
5. La fuente de la celda de stock cambia a rojo.
6. Otros usuarios ven el cambio.

### Flujos alternativos

- **FA-01**: El usuario hace click derecho pero cierra el menú sin seleccionar →
  no se produce ningún cambio.
- **FA-02**: El usuario está desconectado → la escritura a Firestore se encola
  (offline persistence de Firestore) y se sincroniza al reconectar.

### Estados especiales / excepciones

- **Estado sin conexión**: Firestore offline persistence gestiona la escritura
  pendiente. El flag se aplica visualmente de forma optimista.
- **Estado error de escritura**: Si la escritura falla, revertir el indicador
  visual y mostrar un SnackBar de error.
- **Celda en edición**: Si la celda está siendo editada (campo de texto activo),
  el menú contextual debe poder mostrarse igualmente (o bien, mostrar el menú
  contextual del sistema nativo y no el custom).
- **Celda bloqueada por otro usuario**: El menú contextual de flags debe
  funcionar independientemente del bloqueo de edición (un usuario puede marcar
  un flag sin necesidad de editar el valor).

## 8) Edge cases

- **EC-01**: Una celda tiene valor 0 y se marca como compensación → se muestra
  el fondo verde con la celda vacía (sin número visible, como es el
  comportamiento actual para valor 0).
- **EC-02**: ~~Ambos flags activos~~ — No aplica: compensación y reserva son
  mutuamente excluyentes.
- **EC-03**: Se marca stock estricto y luego se cambia el valor de stock a 0 →
  el flag permanece, la fuente sigue en rojo mostrando "0".
- **EC-04**: Se elimina un producto o cliente → los flags asociados desaparecen
  con los datos del subdocumento (no requiere limpieza adicional).
- **EC-05**: Se crea una nueva hoja de pedidos del día → todas las celdas parten
  sin flags.
- **EC-06**: Un operador marca un flag mientras otro está editando el valor de
  la misma celda → el flag y el valor son campos independientes, no hay
  conflicto.

## 9) Impacto funcional

- **Módulos afectados**: Feature `orders_today` — capa de datos (modelos,
  datasources Firestore), capa de dominio (entidades), capa de presentación
  (widget de tabla, BLoC/estados).
- **Impacto en usuario**: Los operadores obtienen una forma visual e inmediata
  de comunicar información contextual (compensación, reserva, stock estricto) a
  todos los compañeros conectados, sin necesidad de comunicación verbal.
- **Impacto en experiencia de usuario**: Mínima curva de aprendizaje — menú
  contextual estándar activado con click derecho, con etiquetas claras y
  retroalimentación visual inmediata.
- **Impacto en datos**: Se amplía la estructura de Firestore para almacenar
  flags por celda (ver Notas para análisis técnico).

## 10) Suposiciones

- **S-01**: Compensación y reserva son mutuamente excluyentes. Al marcar
  compensación en una celda con reserva, se desmarca automáticamente la reserva,
  y viceversa. _(Confirmado por el usuario — ver PA-01 resuelta.)_
- **S-02**: El menú contextual es nativo de la plataforma (usa `showMenu` de
  Flutter), no un widget custom.
- **S-03**: Los textos del menú contextual deben estar internacionalizados
  (i18n), aunque inicialmente solo en español.
- **S-04**: El flag de stock estricto es por producto (por fila de stock), no
  varía por día (aunque al estar en la subcolección `rows` bajo la fecha, es
  específico por hoja de pedidos/día).
- **S-05**: No se necesita permiso especial para marcar/desmarcar flags;
  cualquier operador con acceso a la pantalla de pedidos puede hacerlo.

## 11) Preguntas abiertas

- ~~**PA-01**~~: **Resuelta** — Son mutuamente excluyentes. Al marcar uno se
  desmarca el otro.
- ~~**PA-02**~~: **Resuelta** — Solo afecta a la celda de stock, no a la fila
  completa.
- ~~**PA-03**~~: **Resuelta** — Siempre celda a celda, sin selección múltiple.

## 12) Notas para análisis técnico

### Estructura Firestore propuesta

Los flags deben almacenarse dentro del subdocumento de fila existente
(`orders/{YYYY-MM-DD}/rows/{productId}`). Se proponen dos campos adicionales en
`OrderRowModel`:

- **`flags`** (Map<String, String>): mapa `clientId → flagType` donde `flagType`
  es `"compensation"` o `"reservation"`. Almacenar como mapa sparse (solo celdas
  con flag activo).
- **`strictStock`** (bool): flag a nivel de fila que indica si el stock de ese
  producto es estricto.

Ejemplo de documento expandido:

```json
{
    "quantities": { "client1": 5, "client2": 3 },
    "stock": 20,
    "flags": { "client1": "compensation", "client2": "reservation" },
    "strictStock": true
}
```

> Compensación y reserva son mutuamente excluyentes (PA-01 resuelta), por lo que
> el valor de `flags` es siempre un string simple (`"compensation"` o
> `"reservation"`).

### Impacto en RTDB

**No se requiere modificación en RTDB.** La base de datos en tiempo real solo se
usa para presencia (cursores y locks de edición). Los flags son datos
persistentes del pedido y deben vivir en Firestore, donde ya existe el listener
en tiempo real (`watchOrderRows`) que propagará los cambios automáticamente.

### Dependencias visibles

- `OrderRowModel`: necesita nuevos campos `flags` y `strictStock`
- `OrderSheet`: necesita transportar los flags hasta la capa de presentación
- `OrderFirestoreDataSource`: necesita métodos para actualizar flags
  individuales
- `_buildDataCell` en `OrdersTable`: necesita incorporar la lógica de color
  según flags
- `_dataCellColor`: necesita nuevas ramas para los estados de compensación y
  reserva
- Internacionalización: nuevas claves para los textos del menú contextual

### Restricciones funcionales

- El menú contextual debe coexistir con el tap-to-edit existente sin conflictos
- Los flags no deben afectar cálculos (PEDIDOS, QUEDAN) — son solo indicadores
  visuales
- La propagación usa los listeners Firestore existentes; no se necesita nuevo
  canal de comunicación

### Consideraciones no técnicas

- El verde pastel y azul pastel deben ser suficientemente diferenciables del
  color de fila par/impar y del color de highlight de celda seleccionada
- El rojo de stock estricto debe ser diferenciable del rojo de QUEDAN negativo

**Estado: Listo para análisis técnico**
