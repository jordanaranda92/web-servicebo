# Functional Analysis: Migración de productos a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** products-firestore-migration
- **Estado:** Ready for technical analysis

## 1) Resumen

Migrar la fuente de datos de productos desde Google Sheets + Factura Directa a
**Firestore** como fuente única, siguiendo el mismo patrón implementado en la
feature de clientes. Se elimina la sincronización de productos desde la página
de ajustes.

## 2) Contexto y objetivo

### Qué se solicita

Actualmente los productos se cargan mediante una combinación de:

- **Google Sheets** como fuente primaria de datos (tabla "productos" en un
  spreadsheet de configuración)
- **Factura Directa API** como fuente de enriquecimiento (nombres FD, precios,
  moneda)

Se quiere migrar a un modelo donde:

- **Firestore** sea la única fuente de datos de productos (colección `products`)
- Se elimine la dependencia de Google Sheets y Factura Directa API para esta
  feature
- Se elimine el botón "Sincronizar productos" de la página de ajustes

### Qué problema resuelve

- Simplifica la arquitectura eliminando dos fuentes de datos externas (Google
  Sheets + FD API)
- Unifica el patrón de acceso a datos con la feature de clientes (ya migrada a
  Firestore)
- Elimina la complejidad del parsing de hojas de cálculo y la lógica de
  enriquecimiento FD
- Reduce latencia al no necesitar llamadas a Google Sheets API ni a Factura
  Directa API

### Qué resultado funcional se espera

Una pantalla de productos que carga y persiste datos exclusivamente desde/hacia
Firestore, con una UI similar a la pantalla de clientes (guardado individual por
campo), sin funcionalidad de sincronización.

## 3) Alcance

### En alcance

- **Nueva entidad de producto** adaptada a Firestore con campos: `name`,
  `facturaDirectaUuid`, `facturaDirectaName`, `isActive`, `color`, `order`
- **Nuevo datasource Firestore** para la colección `products` (lectura,
  actualización individual y batch)
- **Nuevo repositorio** que lee exclusivamente de Firestore
- **Adaptación de la UI** de productos para:
  - Usar IDs tipo `String` (document ID de Firestore) en lugar de `int`
  - Mostrar columnas: Nombre, Nombre FD, Activo, Color, Orden
  - Guardado individual por campo (al cambiar nombre, toggle active, cambiar
    orden) similar a la pantalla de clientes
  - Eliminar columnas y funcionalidades de FD (selector de producto FD, precio,
    moneda)
  - Eliminar botón "Añadir producto" y "Eliminar producto" (los datos se
    gestionan desde Firestore)
  - Eliminar botón "Guardar" y "Descartar cambios" (guardado individual)
  - Eliminar el banner de warning de FD
- **Eliminación del botón "Sincronizar productos"** de la sección Factura
  Directa en la página de ajustes
- **Adaptación del cubit** para reflejar las nuevas operaciones (sin
  getFdProducts, linkFdProduct, addProduct, deleteProduct)
- **Limpieza de use cases** obsoletos (GetFdProducts, LinkFdProduct, AddProduct,
  DeleteProduct, ToggleProductField, UpdateProduct, UpdateProductOrder)
- **Actualización del módulo DI** para registrar las nuevas dependencias

### Fuera de alcance

- Migración de datos existentes de Google Sheets a Firestore (se asume que la
  colección `products` en Firestore ya estará pre-populada)
- Creación de una herramienta de importación/sincronización desde Factura
  Directa a Firestore para productos
- Adaptación completa de la feature `orders_today` (será objeto de un análisis
  funcional/técnico separado si es necesario, pero se señala como dependencia)
- Eliminación de los datasources de Google Sheets y Factura Directa API a nivel
  de `core/` (podrían ser usados por otras features)

## 4) Actores implicados

- **Usuario administrador**: Interactúa con la pantalla de productos para ver,
  editar nombre, activar/desactivar, y cambiar orden de productos
- **Sistema Firestore**: Fuente de verdad para los datos de productos

## 5) Requisitos funcionales

- **RF-01**: La pantalla de productos carga todos los productos desde la
  colección `products` de Firestore al abrirse
- **RF-02**: La tabla muestra las columnas: Nombre (editable), Nombre Factura
  Directa (solo lectura), Activo (toggle), Orden (editable). El campo `color` se
  almacena en Firestore (valor por defecto `#FFFFFF`) pero no se muestra en la
  tabla
- **RF-03**: Al editar el nombre de un producto y pulsar Enter o perder foco, el
  cambio se guarda individualmente en Firestore
- **RF-04**: Al cambiar el toggle de activo, el cambio se guarda individualmente
  en Firestore
- **RF-05**: Al editar el orden de un producto y pulsar Enter, el cambio se
  guarda individualmente en Firestore
- **RF-06**: Cada guardado individual muestra un diálogo de progreso mientras se
  ejecuta y un feedback de éxito/error al finalizar
- **RF-07**: La pantalla incluye un buscador por nombre de producto
- **RF-08**: Los productos se ordenan por el campo `order` (nulls al final), y
  luego alfabéticamente por nombre
- **RF-09**: El botón "Sincronizar productos" se elimina de la sección Factura
  Directa en la página de ajustes
- **RF-10**: No existe funcionalidad de añadir o eliminar productos desde la UI
  (la gestión de la colección se hace directamente en Firestore)
- **RF-11**: No existe funcionalidad de sincronizar productos desde Factura
  Directa

## 6) Criterios de aceptación

- **CA-01**: Al abrir la pantalla de productos, se muestra un spinner de carga y
  luego la tabla con los productos de Firestore
- **CA-02**: Al editar el nombre de un producto y confirmar, el valor se
  actualiza en Firestore y se muestra feedback visual de éxito
- **CA-03**: Al activar/desactivar un producto, el valor se actualiza en
  Firestore inmediatamente con feedback visual
- **CA-04**: Al cambiar el orden y confirmar, el valor se actualiza en Firestore
  con feedback visual
- **CA-05**: Al buscar por nombre, la tabla se filtra mostrando solo los
  productos cuyo nombre contenga el texto buscado
- **CA-06**: Si hay error de conexión o servidor, se muestra un mensaje de error
  con opción de reintentar
- **CA-07**: El botón "Sincronizar productos" ya no aparece en la página de
  ajustes
- **CA-08**: El campo `color` no se muestra en la tabla; se mantiene en
  Firestore con valor por defecto `#FFFFFF`
- **CA-09**: Si la lista de productos está vacía, se muestra un mensaje
  indicándolo

## 7) Flujos y comportamiento esperado

### Flujo principal — Carga de productos

1. El usuario navega a la pantalla de productos
2. El sistema muestra un indicador de carga
3. El sistema consulta la colección `products` en Firestore
4. El sistema ordena los productos por `order` (nulls al final), luego
   alfabéticamente
5. El sistema muestra la tabla con los productos

### Flujo — Edición de nombre

1. El usuario modifica el texto del campo nombre de un producto
2. El usuario pulsa Enter o el foco sale del campo
3. Si el texto es vacío, no se guarda (se ignora)
4. Si el texto es igual al original, no se guarda
5. El sistema muestra diálogo de progreso
6. El sistema actualiza el campo `name` del documento en Firestore
7. El sistema cierra el diálogo y muestra feedback de éxito/error

### Flujo — Toggle activo

1. El usuario cambia el switch de activo/inactivo
2. El sistema muestra diálogo de progreso
3. El sistema actualiza el campo `isActive` del documento en Firestore
4. El sistema cierra el diálogo y muestra feedback de éxito/error

### Flujo — Edición de orden

1. El usuario modifica el valor del campo orden
2. El usuario pulsa Enter
3. Si el valor no es un número válido ≥ 1 o es igual al original, se ignora
4. El sistema muestra diálogo de progreso
5. El sistema actualiza el campo `order` del documento en Firestore
6. El sistema cierra el diálogo y muestra feedback de éxito/error

### Flujo — Búsqueda

1. El usuario escribe en el campo de búsqueda
2. La tabla se filtra en tiempo real mostrando productos cuyo `name` contenga el
   texto (case-insensitive)
3. Si se limpia el buscador, se muestran todos los productos

### Flujos alternativos

- **Error de red**: Se muestra pantalla de error con icono, mensaje y botón
  "Reintentar"
- **Error de servidor**: Se muestra pantalla de error con icono, mensaje y botón
  "Reintentar"

### Estados especiales / excepciones

- **Estado vacío**: Mensaje centrado "No hay productos" cuando la colección está
  vacía o el filtro no devuelve resultados
- **Estado loading**: Spinner centrado mientras se cargan los productos
- **Estado error**: Pantalla de error con icono, mensaje descriptivo y botón de
  reintento
- **Guardado en progreso**: Diálogo modal no dismissable con spinner y texto
  "Guardando..." (mínimo 500ms visible)

## 8) Edge cases

- **EC-01**: El campo `color` tiene un valor vacío o nulo — mostrar celda vacía
- **EC-02**: El campo `order` es nulo — el producto aparece al final de la lista
- **EC-03**: El campo `facturaDirectaName` es vacío o nulo — mostrar celda vacía
- **EC-04**: El campo `facturaDirectaUuid` es vacío o nulo — el producto no
  tiene vinculación con FD, no afecta la visualización
- **EC-05**: Múltiples productos tienen el mismo valor de `order` — se ordenan
  entre sí alfabéticamente por nombre
- **EC-06**: El usuario edita el nombre y pone solo espacios — se trata como
  vacío, no se guarda
- **EC-07**: Error durante el guardado de un campo individual — se muestra
  feedback de error, el valor en el campo de texto permanece (el usuario puede
  reintentar)

## 9) Impacto funcional

- **Módulos afectados**:
  - `features/products/` — Reestructuración completa de data layer, adaptación
    de domain y presentation
  - `features/settings/` — Eliminación del botón de sincronización de productos
    en la UI
  - `app/di/modules/products_module.dart` — Actualización de registros DI
  - `features/orders_today/` — El método `_readActiveProducts` en
    `OrdersTodayRepositoryImpl` lee productos activos desde Google Sheets (hoja
    `productos`) para crear el sheet del día. Debe adaptarse para leer desde
    Firestore (colección `products`, filtrado por `isActive == true`, ordenados
    por `order`)
- **Impacto en usuario**: El usuario pierde la capacidad de añadir/eliminar
  productos y vincular productos con Factura Directa desde la UI. La gestión
  CRUD se delega a Firestore directamente
- **Impacto en experiencia de usuario**: Guardado individual más inmediato (sin
  acumular cambios), similar a la experiencia ya existente en la pantalla de
  clientes
- **Otras features que consumen productos**: La feature `orders_today` consume
  productos directamente al crear el sheet del día. Deberá adaptarse para leer
  desde Firestore

## 10) Suposiciones

- La colección `products` en Firestore ya estará pre-populada con los datos
  migrados desde Google Sheets antes de desplegar este cambio
- El esquema de la colección `products` en Firestore es:
  `{ name: String, facturaDirectaUuid: String, facturaDirectaName: String, isActive: bool, color: String, order: int, facturaDirectaSalesPrice: double?, facturaDirectaCurrency: String? }`
- El campo `color` se almacena como string hexadecimal (ej: `#FFFFFF`) según la
  captura proporcionada
- El campo `order` determina el orden de visualización del producto (entero,
  ≥ 1)
- Los IDs de los documentos en Firestore son auto-generados por Firebase
- Las reglas de seguridad de Firestore ya permiten lectura y escritura sobre la
  colección `products`
- No hay otras pantallas o procesos que dependan de la lectura de productos
  desde Google Sheets de forma que se rompan con este cambio

## 11) Preguntas abiertas

- ~~**PA-01**~~: Resuelto — El campo `color` no se muestra en la tabla por ahora
- ~~**PA-02**~~: Resuelto — El campo `color` no es editable desde la UI; valor
  por defecto `#FFFFFF`
- ~~**PA-03**~~: Resuelto — La feature `orders_today` consume productos (método
  `_readActiveProducts` en `OrdersTodayRepositoryImpl`) leyendo desde Google
  Sheets. Deberá adaptarse para leer desde Firestore
- ~~**PA-04**~~: Resuelto — Se mantienen como campos `facturaDirectaSalesPrice`
  (double) y `facturaDirectaCurrency` (String) en Firestore para uso futuro

## 12) Notas para análisis técnico

- **Patrón de referencia**: La implementación de la feature de clientes
  (`features/clients/`) es el modelo a seguir. Tiene datasource Firestore,
  modelo con `fromFirestore`/`toMap`, repositorio simple, cubit con
  `saveBatchChanges` individual, y UI con guardado por campo
- **Campos Firestore**: `name` (String), `facturaDirectaUuid` (String),
  `facturaDirectaName` (String), `isActive` (bool), `color` (String), `order`
  (int), `facturaDirectaSalesPrice` (double, opcional), `facturaDirectaCurrency`
  (String, opcional)
- **Cambio de tipo de ID**: Los IDs pasan de `int` (de Google Sheets) a `String`
  (document ID de Firestore). Esto impacta entidad, repositorio, cubit y UI
- **Elementos a eliminar**:
  - `data/dto/product_dto.dart` (DTO de Factura Directa API)
  - `data/dto/product_sheet_dto.dart` (DTO de Google Sheets)
  - `domain/entities/fd_product.dart` (entidad FD)
  - `domain/entities/products_result.dart` (wrapper con fdWarning)
  - `domain/usecases/get_fd_products.dart`
  - `domain/usecases/link_fd_product.dart`
  - `domain/usecases/add_product.dart`
  - `domain/usecases/delete_product.dart`
  - `domain/usecases/toggle_product_field.dart`
  - `domain/usecases/update_product.dart`
  - `domain/usecases/update_product_order.dart`
  - Botón `settingsSyncProductsButton` en `factura_directa_section.dart`
- **Dependencias externas eliminadas**: `GoogleSheetsDataSource`,
  `GoogleDriveRemoteDataSource`, `FacturaDirectaApiDataSource`,
  `SettingsRepository` (del repositorio de productos)
- **Restricción**: No incluir funcionalidad de sincronización desde FD (a
  diferencia de clientes que sí la tiene)
- **Estado: Listo para análisis técnico**
