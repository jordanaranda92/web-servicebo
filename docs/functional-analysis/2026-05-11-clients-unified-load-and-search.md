# Functional Analysis: Carga unificada y búsqueda multi-campo en pantalla de clientes

- **Fecha:** 2026-05-11
- **Identificador:** clients-unified-load-and-search
- **Estado:** Ready for technical analysis

## 1) Resumen

La pantalla de clientes presenta actualmente una carga en dos fases: primero
aparecen los datos almacenados en Firestore (nombre, nombre FD, categoría) y
posteriormente se cargan los NIF/CIF desde la API de Factura Directa. El usuario
solicita que toda la información se muestre al mismo tiempo. Adicionalmente, el
buscador actual solo filtra por nombre del cliente y debe ampliarse para buscar
también por NIF/CIF y Nombre Factura Directa.

## 2) Contexto y objetivo

### Qué se solicita

1. **Carga unificada:** Que la tabla de clientes no se renderice hasta que todos
   los datos (incluidos los NIF/CIF provenientes de Factura Directa) estén
   disponibles, eliminando la carga en dos fases.
2. **Búsqueda multi-campo:** Que el buscador filtre simultáneamente por NIF/CIF,
   Nombre y Nombre Factura Directa.

### Qué problema resuelve

- **Experiencia visual inconsistente:** Los usuarios ven la columna NIF/CIF con
  guiones "—" durante un breve periodo antes de que se rellenen los valores
  reales, lo cual transmite una sensación de carga incompleta o error.
- **Buscador limitado:** El usuario no puede localizar clientes por su
  identificación fiscal ni por el nombre registrado en Factura Directa, lo que
  obliga a buscar en otra fuente o recorrer manualmente la lista.

### Qué resultado funcional se espera

- La tabla se muestra completa (con NIF/CIF) desde el primer renderizado,
  precedida por un estado de carga (spinner/loading) si es necesario.
- El buscador devuelve resultados que coincidan con cualquiera de los tres
  campos: NIF/CIF, Nombre o Nombre Factura Directa.

## 3) Alcance

### En alcance

- Unificar la carga de datos de clientes (Firestore) y NIF/CIF (API Factura
  Directa) para que la tabla no se muestre hasta que ambos estén disponibles.
- Ampliar el filtro de búsqueda para que busque por NIF/CIF, Nombre y Nombre
  Factura Directa.
- Mantener el estado de carga (loading spinner) visible hasta que todos los
  datos estén listos.

### Fuera de alcance

- Añadir nuevos campos al modelo almacenado en Firestore (restricción explícita
  del usuario).
- Modificar la estructura de columnas de la tabla (no se añaden ni eliminan
  columnas).
- Cambiar la fuente de datos de los NIF/CIF (seguirá viniendo de la API de
  Factura Directa).
- Paginación, ordenación por columna u otras mejoras de tabla no solicitadas.
- Modificaciones en la pantalla de detalle o edición del cliente.

## 4) Actores implicados

- **Usuario final (operador de la aplicación):** Visualiza y busca clientes en
  la pantalla de listado.
- **Sistema externo (API Factura Directa):** Provee los NIF/CIF de los
  contactos.
- **Sistema interno (Firestore):** Almacena los datos base de los clientes
  (nombre, UUID FD, nombre FD, categoría, métodos de envío).

## 5) Requisitos funcionales

- **RF-01:** La tabla de clientes no debe renderizarse hasta que tanto los datos
  de Firestore como los NIF/CIF de Factura Directa estén disponibles.
- **RF-02:** Mientras se cargan los datos, se debe mostrar un indicador de carga
  (spinner) en la zona de la tabla.
- **RF-03:** Si la carga de NIF/CIF falla pero los datos de Firestore están
  disponibles, la tabla debe mostrarse igualmente con la columna NIF/CIF
  mostrando "—" para todos los registros (degradación graceful).
- **RF-04:** El campo de búsqueda debe filtrar la lista de clientes buscando la
  coincidencia del texto introducido en cualquiera de los siguientes campos:
  NIF/CIF, Nombre o Nombre Factura Directa.
- **RF-05:** La búsqueda debe ser case-insensitive.
- **RF-06:** La búsqueda debe ser por coincidencia parcial (contiene), no
  exacta.

## 6) Criterios de aceptación

- **CA-01:** Al acceder a la pantalla de clientes, se muestra un spinner de
  carga hasta que todos los datos (clientes + NIF/CIF) están disponibles;
  después la tabla aparece completa.
- **CA-02:** Nunca se observa la tabla con la columna NIF/CIF en blanco o "—"
  seguida de una actualización posterior con los valores reales (salvo error de
  carga de NIF/CIF, ver CA-04).
- **CA-03:** Al escribir un NIF/CIF (ej. "B42696591") en el buscador, la tabla
  muestra únicamente los clientes cuyo NIF/CIF contenga ese texto.
- **CA-04:** Al escribir un nombre parcial (ej. "ADELMAR") en el buscador, la
  tabla muestra clientes cuyo Nombre O Nombre Factura Directa contenga ese
  texto.
- **CA-05:** La búsqueda funciona combinando los tres campos: un texto que
  coincida con cualquiera de ellos muestra al cliente correspondiente.
- **CA-06:** Si la carga de NIF/CIF falla, la tabla se renderiza igualmente con
  los datos de Firestore y "—" en la columna NIF/CIF, sin bloquear la pantalla.
- **CA-07:** El buscador sigue funcionando aunque los NIF/CIF no estén
  disponibles (busca solo por Nombre y Nombre Factura Directa en ese caso).

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario accede a la pantalla de clientes.
2. Se muestra un indicador de carga (spinner).
3. El sistema carga en paralelo los datos de clientes desde Firestore y los
   NIF/CIF desde la API de Factura Directa.
4. Cuando ambas fuentes responden, la tabla se renderiza completa con todas las
   columnas rellenas.
5. El usuario puede escribir en el buscador y la tabla se filtra en tiempo real
   por NIF/CIF, Nombre o Nombre Factura Directa.

### Flujos alternativos

- **FA-01 — Fallo en carga de NIF/CIF:** Si la API de Factura Directa falla o no
  responde, la tabla se muestra con los datos de Firestore y "—" en la columna
  NIF/CIF. La búsqueda opera solo sobre Nombre y Nombre Factura Directa.
- **FA-02 — Fallo en carga de clientes (Firestore):** Se muestra la pantalla de
  error existente con opción de reintentar.
- **FA-03 — Sincronización desde FD:** Tras sincronizar, se recargan los datos.
  La tabla debe seguir el mismo principio: no mostrarse parcialmente.

### Estados especiales / excepciones

- **Estado vacío:** Si no hay clientes, se muestra el mensaje "No hay clientes"
  actual.
- **Estado loading/procesando:** Spinner centrado en el área de la tabla.
- **Estado error:** Pantalla de error con botón de reintentar (comportamiento
  actual para errores de Firestore).
- **Error parcial (solo NIF/CIF):** Degradación graceful — tabla visible con "—"
  en NIF/CIF.

## 8) Edge cases

- **EC-01:** Un cliente sin UUID de Factura Directa no tendrá NIF/CIF; debe
  mostrar "—" y no debe causar error.
- **EC-02:** Un cliente cuyo UUID no tiene fiscal ID registrado en FD debe
  mostrar "—".
- **EC-03:** El buscador con texto que no coincide con ningún campo muestra la
  tabla vacía con el mensaje correspondiente.
- **EC-04:** Búsqueda con caracteres especiales (tildes, ñ, guiones en NIF) debe
  funcionar correctamente con coincidencia parcial case-insensitive.
- **EC-05:** Si la lista de clientes se actualiza vía stream de Firestore
  mientras los NIF/CIF ya están cargados, los NIF/CIF deben seguir asociados
  correctamente (el mapeo UUID→NIF/CIF permanece válido).
- **EC-06:** Si el usuario escribe en el buscador durante la carga, el filtro
  debe aplicarse cuando la tabla esté lista.

## 9) Impacto funcional

- **Módulos o procesos afectados:**
  - Pantalla de listado de clientes (`clients_page.dart`)
  - Lógica de carga y filtrado en el cubit/state de clientes
  - Caso de uso `GetFdFiscalIds` (actualmente invocado desde la página, deberá
    coordinarse con la carga principal)

- **Impacto en usuario o negocio:**
  - Mejora percepción de calidad: la tabla se muestra completa.
  - Mayor eficiencia en búsqueda de clientes al poder buscar por NIF/CIF.

- **Impacto en experiencia de usuario:**
  - El tiempo de carga inicial podría ser ligeramente superior (se espera a
    ambas fuentes), pero la percepción es mejor al evitar el "salto" visual de
    la columna NIF/CIF.

## 10) Suposiciones

- **S-01:** El mapeo UUID→NIF/CIF obtenido de Factura Directa es estable durante
  la sesión y no necesita recargarse al actualizarse el stream de Firestore.
- **S-02:** El rendimiento de la llamada a `GetFdFiscalIds` es aceptable para el
  volumen de clientes actual y no requiere caché persistente.
- **S-03:** "Cargar todo a la vez" significa no renderizar la tabla hasta que
  ambas fuentes estén disponibles, no que se haga una única llamada (se admiten
  llamadas paralelas).

## 11) Preguntas abiertas

- **PA-01:** ¿Se desea refrescar los NIF/CIF periódicamente o solo al entrar a
  la pantalla y al sincronizar? (Supuesto: solo al entrar y al sincronizar.)
- **PA-02:** ¿Debe el buscador tener un debounce (retraso) para evitar filtrados
  excesivos mientras el usuario escribe, o el filtrado instantáneo actual es
  correcto? (Supuesto: mantener comportamiento actual, filtrado instantáneo.)

## 12) Notas para análisis técnico

- Los NIF/CIF se obtienen actualmente en `_loadFiscalIds()` de la página, usando
  `GetFdFiscalIds` que llama a la API de FD. Este dato se almacena como
  `Map<String, String>` (UUID→fiscalId) en el state del widget, **no** en el
  BLoC/Cubit.
- La restricción de **no añadir campos al modelo Firestore** implica que los
  NIF/CIF deben seguir resolviéndose desde la API de FD en tiempo de
  presentación, no persistirse.
- El filtro actual está en `ClientsCubit._applyFilter()` y solo busca por
  `name`. Deberá ampliarse para incluir los tres campos, lo que requiere que el
  cubit tenga acceso al mapeo de fiscal IDs o que el filtrado se realice en la
  capa de presentación con acceso a dicho mapa.
- Considerar mover el mapeo UUID→fiscalId al Cubit/State para centralizar la
  lógica y facilitar el filtrado multi-campo.
- El stream de Firestore (`watchClients`) sigue emitiendo actualizaciones; la
  coordinación con la carga de NIF/CIF debe contemplar que la tabla no se
  muestre hasta la primera carga exitosa de ambos.
- **Estado: Listo para análisis técnico**
