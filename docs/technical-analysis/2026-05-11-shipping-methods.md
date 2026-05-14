# Technical Analysis: Métodos de envío y mejoras en tabla de Clientes

- **Fecha:** 2026-05-11
- **Identificador:** shipping-methods
- **Fuente:** docs/functional-analysis/2026-05-11-shipping-methods-v2.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Crear la feature `shipping_methods` siguiendo la estructura Clean Architecture
  feature-first idéntica a `client_categories`.
- Ampliar el menú lateral (9 ítems, nuevo índice 5) y el `SideMenuShell` para
  incluir la nueva página.
- Ampliar la entidad `Client`, su modelo de datos Firestore, el repositorio y el
  cubit de clientes para soportar `shippingMethodsByDay`.
- Crear un diálogo de asignación día→método de envío (nuevo widget).
- Crear un use case de eliminación con limpieza de referencias en clientes
  (batch write cross-collection).
- Actualizar i18n (`.arb`) y regenerar clases de localización.
- Riesgo general estimado: **medio** (cross-collection cleanup en eliminación,
  nuevo widget de selección por día).

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first**: cada feature tiene `data/datasources/`,
  `data/repositories/`, `domain/entities/`, `domain/repositories/`,
  `domain/usecases/`, `presentation/bloc/`, `presentation/pages/`,
  `presentation/widgets/`.
- **State management**: BLoC/Cubit con `flutter_bloc`.
- **DI**: GetIt con módulos separados por feature en `lib/app/di/modules/`.
- **Functional error handling**: `fpdart` (`Either<Failure, T>`).
- **Persistencia**: Cloud Firestore.
- **i18n**: ARB-based con `AppLocalizations`.
- **Logging**: `AppLogger` inyectado en repositorios.
- **Base UseCase**: `UseCase<Type, Params>` en `core/usecase/usecase.dart`.
- **Excepciones**: `ServerException`, `NetworkException` en data layer →
  `Failure` en domain.

### Módulos relevantes

- `client_categories`: patrón de referencia directo para la feature
  `shipping_methods` (CRUD con Firestore, stream en tiempo real, edición inline,
  eliminación con diálogo).
- `clients`: módulo que necesita ampliación (nueva columna, nuevo campo en
  entidad/modelo, nuevo diálogo).
- `home`: menú lateral (`SideMenu`, `SideMenuShell`, `SideMenuCubit`) necesita
  nuevo ítem.

### Restricciones

- No existe operación cross-collection en el proyecto actualmente (la
  eliminación de una categoría no limpia referencias en clientes). La
  eliminación de un método de envío **sí** requiere limpiar referencias →
  necesita un datasource que acceda a la colección `clients`.
- La tabla de clientes tiene 4 columnas con flex/width fijos; añadir una 5ª
  columna requiere ajustar anchos.
- `SideMenuCubit._maxIndex` es `7`; debe pasar a `8`.
- Los separadores del menú lateral usan índices hardcoded
  (`index == 0 || index == 2 || index == 5 || index == 6`); necesitan
  actualizarse.

## 3) Objetivo técnico

- Crear toda la infraestructura para la feature `shipping_methods` (data →
  domain → presentation).
- Integrar la feature en el menú lateral.
- Ampliar la feature `clients` con el campo `shippingMethodsByDay` y su UI de
  selección.
- Implementar eliminación con limpieza cross-collection.
- Cambiar el texto i18n de `clientsColumnNameFd`.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Replicar el patrón de `client_categories` para la nueva feature
`shipping_methods`, con las siguientes diferencias:

- Entidad `ShippingMethod` con solo `id`, `name`, `phone` (sin `isActive`).
- Sin toggle activo/inactivo en la tabla.
- Con campo `phone` adicional (input numérico, 9 dígitos).
- Con limpieza de referencias al eliminar.

Para la integración en clientes, ampliar `Client`/`ClientModel` con
`shippingMethodsByDay` y crear un nuevo diálogo `ShippingMethodsByDayDialog`.

### Componentes / módulos / servicios afectados

| Componente                                                            | Impacto                                                   |
| --------------------------------------------------------------------- | --------------------------------------------------------- |
| `lib/features/shipping_methods/`                                      | **Nuevo** — feature completa                              |
| `lib/features/clients/domain/entities/client.dart`                    | Modificar — nuevo campo                                   |
| `lib/features/clients/data/models/client_model.dart`                  | Modificar — serialización del nuevo campo                 |
| `lib/features/clients/domain/repositories/clients_repository.dart`    | Modificar — nuevo parámetro en `saveClientsBatch`         |
| `lib/features/clients/data/repositories/clients_repository_impl.dart` | Modificar — manejar nuevo campo                           |
| `lib/features/clients/domain/usecases/save_clients_batch.dart`        | Modificar — nuevo parámetro                               |
| `lib/features/clients/presentation/bloc/clients_cubit.dart`           | Modificar — exponer métodos de envío                      |
| `lib/features/clients/presentation/pages/clients_page.dart`           | Modificar — nueva columna + diálogo                       |
| `lib/features/clients/presentation/widgets/`                          | Nuevo widget — `ShippingMethodsByDayDialog`               |
| `lib/features/home/presentation/widgets/side_menu.dart`               | Modificar — nuevo ítem + separadores                      |
| `lib/features/home/presentation/pages/side_menu_shell.dart`           | Modificar — nuevo case en switch                          |
| `lib/features/home/presentation/bloc/side_menu_cubit.dart`            | Modificar — `_maxIndex`                                   |
| `lib/app/di/injection.dart`                                           | Modificar — registrar nuevo módulo                        |
| `lib/app/di/modules/shipping_methods_module.dart`                     | **Nuevo** — módulo DI                                     |
| `lib/app/localization/l10n/app_es.arb`                                | Modificar — nuevas claves + cambiar `clientsColumnNameFd` |

### Contratos e interfaces

#### Entidad `ShippingMethod`

```
ShippingMethod {
  id: String
  name: String
  phone: String  // puede ser vacío
}
```

#### Colección Firestore `shipping_methods`

```json
{
    "name": "SEUR",
    "phone": "912345678"
}
```

#### Campo `shippingMethodsByDay` en documento de `clients`

```json
{
    "shippingMethodsByDay": {
        "monday": "<shipping_method_id>",
        "tuesday": "<shipping_method_id>",
        "wednesday": null,
        "thursday": "<shipping_method_id>",
        "friday": null,
        "saturday": null,
        "sunday": null
    }
}
```

Claves fijas: `monday`, `tuesday`, `wednesday`, `thursday`, `friday`,
`saturday`, `sunday`. Los días sin asignar se omiten del mapa o tienen valor
`null`.

#### Datasource interface `ShippingMethodFirestoreDataSource`

```
getAll() → Future<List<ShippingMethod>>
watchAll() → Stream<List<ShippingMethod>>
add({name, phone}) → Future<void>
update({id, name}) → Future<void>
updatePhone({id, phone}) → Future<void>
delete({id}) → Future<void>
```

#### Repositorio `ShippingMethodsRepository`

```
getShippingMethods() → Future<Either<Failure, List<ShippingMethod>>>
watchShippingMethods() → Stream<Either<Failure, List<ShippingMethod>>>
addShippingMethod({name, phone}) → Future<Either<Failure, Unit>>
updateShippingMethod({id, name}) → Future<Either<Failure, Unit>>
updateShippingMethodPhone({id, phone}) → Future<Either<Failure, Unit>>
deleteShippingMethod({id}) → Future<Either<Failure, Unit>>
cleanupShippingMethodReferences({shippingMethodId}) → Future<Either<Failure, Unit>>
```

#### Ampliación de `ClientsRepository`

```
saveClientsBatch({
  nameChanges,
  activeToggles,
  categoryChanges,
  shippingMethodsByDayChanges,  // ← NUEVO: Map<String, Map<String, String?>>
}) → Future<Either<Failure, Unit>>
```

Donde `shippingMethodsByDayChanges` es
`{clientId: {monday: "id", tuesday: null, ...}}`.

### Flujo de datos o de control

#### Flujo de eliminación con limpieza

1. UI → `ShippingMethodsCubit.deleteShippingMethod(id)`
2. Cubit → `DeleteShippingMethod` use case
3. Use case → `ShippingMethodsRepository.deleteShippingMethod(id)`
4. Repository → `ShippingMethodFirestoreDataSource.delete(id)` +
   `cleanupShippingMethodReferences(id)`
5. `cleanupShippingMethodReferences`: consulta a `clients` donde
   `shippingMethodsByDay` contiene el id → batch update para eliminar las
   entradas correspondientes del mapa.

**Nota sobre limpieza cross-collection:** Firestore no permite queries sobre
valores dentro de mapas directamente. Dos opciones:

- **Opción A**: Consultar **todos** los clientes, filtrar en cliente los que
  tienen el ID en algún valor de `shippingMethodsByDay`, y hacer batch update
  solo de esos. Viable si el número de clientes es manejable (< 500).
- **Opción B**: Mantener un índice inverso (array `shippingMethodIds` en cada
  cliente con los IDs únicos usados) y hacer query con `arrayContains`. Más
  complejo.

**Recomendación**: Opción A. El volumen de clientes en esta aplicación es bajo
(decenas-cientos) y la operación de eliminación es infrecuente.

#### Flujo de asignación día→método en cliente

1. UI → `ClientsPage` → abre `ShippingMethodsByDayDialog` con los métodos
   disponibles y la asignación actual del cliente.
2. Usuario selecciona/cambia método por día → confirma.
3. Dialog retorna `Map<String, String?>` con la asignación.
4. `ClientsPage` → `_saveField(clientId, shippingMethodsByDay: result)`
5. `ClientsCubit.saveBatchChanges(shippingMethodsByDayChanges: {clientId: result})`
6. `SaveClientsBatch` → `ClientsRepository.saveClientsBatch(...)` →
   `ClientFirestoreDataSource.batchUpdate(...)`.

### Gestión de errores y validaciones

- **Nombre vacío**: Validación en UI (formulario) + no enviar al backend si
  vacío.
- **Nombre > 50 caracteres**: `maxLength: 50` en `TextField` con
  `LengthLimitingTextInputFormatter`.
- **Teléfono no numérico**: `FilteringTextInputFormatter.digitsOnly` en el
  `TextField`.
- **Teléfono ≠ 9 dígitos**: Validación on blur — si
  `phone.isNotEmpty && phone.length != 9`, mostrar error visual y no guardar.
- **Errores Firestore**: Capturados como `ServerException` en datasource →
  `ServerFailure` en repository → mostrados como feedback en UI.
- **IDs huérfanos en `shippingMethodsByDay`**: La UI debe resolver los IDs
  contra la lista de métodos cargados y no mostrar métodos inexistentes (defensa
  ante fallos en la limpieza).

### Consideraciones de compatibilidad o migración

- **Documentos de clientes existentes**: No tienen campo `shippingMethodsByDay`.
  El modelo debe tratar la ausencia como mapa vacío (`{}`). No se requiere
  migración de datos.
- **Colección `shipping_methods`**: No existe. Se creará implícitamente al
  añadir el primer documento.
- **Índices Firestore**: No se necesitan índices compuestos para esta feature.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                                        | Propósito                   |
| ------------------------------------------------------------------------------------------------ | --------------------------- |
| `lib/features/shipping_methods/domain/entities/shipping_method.dart`                             | Entidad de dominio          |
| `lib/features/shipping_methods/domain/repositories/shipping_methods_repository.dart`             | Contrato del repositorio    |
| `lib/features/shipping_methods/domain/usecases/watch_shipping_methods.dart`                      | Stream de métodos           |
| `lib/features/shipping_methods/domain/usecases/get_shipping_methods.dart`                        | Lectura one-shot            |
| `lib/features/shipping_methods/domain/usecases/add_shipping_method.dart`                         | Crear método                |
| `lib/features/shipping_methods/domain/usecases/update_shipping_method.dart`                      | Actualizar nombre           |
| `lib/features/shipping_methods/domain/usecases/update_shipping_method_phone.dart`                | Actualizar teléfono         |
| `lib/features/shipping_methods/domain/usecases/delete_shipping_method.dart`                      | Eliminar método + limpieza  |
| `lib/features/shipping_methods/data/datasources/shipping_method_firestore_data_source.dart`      | Interfaz datasource         |
| `lib/features/shipping_methods/data/datasources/shipping_method_firestore_data_source_impl.dart` | Impl Firestore              |
| `lib/features/shipping_methods/data/repositories/shipping_methods_repository_impl.dart`          | Impl repositorio            |
| `lib/features/shipping_methods/presentation/bloc/shipping_methods_cubit.dart`                    | Cubit                       |
| `lib/features/shipping_methods/presentation/bloc/shipping_methods_state.dart`                    | Estados                     |
| `lib/features/shipping_methods/presentation/pages/shipping_methods_page.dart`                    | Página principal            |
| `lib/app/di/modules/shipping_methods_module.dart`                                                | Módulo DI                   |
| `lib/features/clients/presentation/widgets/shipping_methods_by_day_dialog.dart`                  | Diálogo selector día→método |

### Artefactos a modificar

| Artefacto                                                             | Cambio esperado                                                                                         |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/domain/entities/client.dart`                    | Añadir campo `shippingMethodsByDay: Map<String, String>` + actualizar `copyWith` y `props`              |
| `lib/features/clients/data/models/client_model.dart`                  | Añadir campo + `fromFirestore` + `toMap` + `toEntity`                                                   |
| `lib/features/clients/domain/repositories/clients_repository.dart`    | Nuevo parámetro `shippingMethodsByDayChanges` en `saveClientsBatch`                                     |
| `lib/features/clients/data/repositories/clients_repository_impl.dart` | Serializar `shippingMethodsByDay` en `saveClientsBatch` + resolver nombres de métodos en `watchClients` |
| `lib/features/clients/domain/usecases/save_clients_batch.dart`        | Nuevo campo en `SaveClientsBatchParams`                                                                 |
| `lib/features/clients/presentation/bloc/clients_cubit.dart`           | Nuevo parámetro en `saveBatchChanges` + método `fetchShippingMethods`                                   |
| `lib/features/clients/presentation/pages/clients_page.dart`           | Nueva columna en tabla + integración del diálogo + ajuste de anchos + cambio texto columna FD           |
| `lib/features/home/presentation/widgets/side_menu.dart`               | Nuevo ítem en `items` lista (índice 5) + actualizar separadores                                         |
| `lib/features/home/presentation/pages/side_menu_shell.dart`           | Nuevo import + case `5` en switch + desplazar los demás                                                 |
| `lib/features/home/presentation/bloc/side_menu_cubit.dart`            | `_maxIndex = 8`                                                                                         |
| `lib/app/di/injection.dart`                                           | Import + llamada a `registerShippingMethodsModule(sl)`                                                  |
| `lib/app/localization/l10n/app_es.arb`                                | Nuevas claves i18n + cambiar valor de `clientsColumnNameFd` a "Nombre Factura Directa"                  |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Pasos

1. **Crear entidad y repositorio del dominio** `shipping_methods`: entidad
   `ShippingMethod`, interfaz del repositorio, use cases.
2. **Crear capa de datos** `shipping_methods`: interfaz e impl del datasource
   Firestore, impl del repositorio (con lógica de limpieza cross-collection en
   delete).
3. **Crear capa de presentación** `shipping_methods`: cubit, states, página con
   tabla editable (nombre + teléfono + botón eliminar).
4. **Crear módulo DI** `shipping_methods_module.dart` y registrar en
   `injection.dart`.
5. **Integrar en menú lateral**: nuevo ítem en `SideMenu`, nuevo case en
   `SideMenuShell`, actualizar `_maxIndex` y separadores.
6. **Ampliar entidad `Client`** y modelo: añadir `shippingMethodsByDay`,
   actualizar serialización.
7. **Ampliar `ClientsRepository` y `SaveClientsBatch`**: nuevo parámetro para
   cambios de métodos de envío por día.
8. **Ampliar `ClientsCubit`**: exponer `fetchShippingMethods`, pasar nuevo
   parámetro a `saveBatchChanges`.
9. **Crear widget `ShippingMethodsByDayDialog`**: diálogo con 7 filas
   (Lunes–Domingo), cada una con dropdown de métodos.
10. **Ampliar `ClientsPage`**: nueva columna en tabla, botón para abrir diálogo,
    ajustar anchos de columnas, cambiar texto de columna FD.
11. **Actualizar i18n**: todas las nuevas claves + cambio de
    `clientsColumnNameFd`.
12. **Regenerar localización**: ejecutar `flutter gen-l10n`.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12

Los pasos 1–5 son el bloque "Métodos de envío" (feature autónoma). Los pasos
6–10 son el bloque "Integración en Clientes". El paso 11–12 es transversal pero
conviene hacerlo al final para incluir todas las claves.

### Dependencias entre pasos

- Paso 2 depende de 1 (domain antes que data).
- Paso 3 depende de 2 (data antes que presentación).
- Paso 4 depende de 2 y 3 (necesita registrar todo).
- Paso 5 depende de 3 y 4 (necesita la página y el cubit registrado).
- Paso 9 depende de 1 (necesita la entidad `ShippingMethod` y el use case
  `GetShippingMethods`).
- Paso 10 depende de 6, 7, 8, 9 (necesita todo el modelo ampliado y el diálogo).
- Paso 12 depende de 11.

### Puntos delicados

- **Limpieza cross-collection al eliminar**: La operación de leer todos los
  clientes y filtrar los afectados puede ser lenta si hay muchos clientes. Para
  el volumen esperado (decenas-cientos), es aceptable. Si el volumen creciera,
  considerar un índice inverso o Cloud Functions.
- **Separadores del menú lateral**: Los separadores usan índices hardcoded. Al
  insertar un ítem en posición 5, los índices `5` y `6` del `separatorBuilder`
  deben cambiar a `6` y `7`.
- **Anchos de columnas en tabla de clientes**: Actualmente las columnas usan
  `flex: 3` para nombre y nombre FD, `width: 60` para activo, `width: 250` para
  categoría. Añadir una 5ª columna requiere reducir algún flex o usar scroll
  horizontal. Recomendación: reducir a `flex: 2` para nombre FD y asignar
  `width: 250` a la nueva columna de métodos de envío (similar a categoría).
- **Resolución de nombres de métodos en la tabla de clientes**:
  `ClientsRepositoryImpl.watchClients` ya combina streams de clientes +
  categorías. Será necesario combinar también el stream de `shipping_methods`
  para resolver los IDs a nombres. Alternativa más simple: cargar los métodos
  una sola vez en el cubit (como se hace con categorías via `fetchCategories`) y
  resolver en la UI.

## 7) Estrategia de validación

### Verificación automática (tests recomendados)

- **Unit tests para `ShippingMethodsCubit`**: watchStream, addMethod,
  updateMethod, deleteMethod, filterByName.
- **Unit tests para `ShippingMethodsRepositoryImpl`**: mapeo de excepciones a
  failures, ordenación, limpieza de referencias.
- **Unit tests para `ShippingMethodFirestoreDataSourceImpl`**: (si se mockea
  Firestore con `fake_cloud_firestore`).
- **Unit tests para cambios en `Client` entity/model**: serialización de
  `shippingMethodsByDay`.
- **Unit tests para `SaveClientsBatch` con nuevo parámetro**.

### Validación manual

- Navegar al nuevo ítem del menú y verificar que la página carga.
- Crear, editar (nombre y teléfono) y eliminar un método de envío.
- Verificar feedback visual en todas las operaciones.
- Verificar filtro por nombre.
- Abrir selector de métodos de envío en un cliente, asignar métodos a distintos
  días, confirmar y verificar persistencia.
- Eliminar un método de envío asignado a un cliente y verificar que la
  asignación se limpia.
- Verificar que la columna "Nombre Factura Directa" aparece correctamente
  renombrada.
- Verificar que la tabla de clientes mantiene layout correcto con la nueva
  columna.

### Escenarios a cubrir

- CRUD completo de métodos de envío.
- Validaciones de nombre vacío, teléfono con formato incorrecto, nombre > 50
  caracteres.
- Asignación y desasignación de métodos por día en clientes.
- Eliminación de método con limpieza de referencias.
- Estados vacío, loading, error en la página de métodos de envío.
- Navegación entre ítems del menú con el nuevo índice.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                     | Probabilidad | Impacto |
| -------------------------------------------------------------------------- | ------------ | ------- |
| La limpieza cross-collection falle parcialmente (batch > 500 docs)         | Baja         | Medio   |
| Desajuste de índices del menú lateral cause navegación incorrecta          | Baja         | Alto    |
| La tabla de clientes se desborde horizontalmente con la nueva columna      | Media        | Bajo    |
| Conflicto de claves i18n si se regenera localización con cambios parciales | Baja         | Bajo    |

### Impacto potencial

- El menú lateral y la navegación afectan a toda la app; un error de índices
  rompería la navegación.
- La tabla de clientes es una de las pantallas más usadas; el layout debe
  mantenerse usable.

### Mitigación

- Verificar exhaustivamente los índices del menú y los separadores tras el
  cambio.
- Probar el layout de la tabla en distintos tamaños de ventana.
- Implementar la limpieza cross-collection con manejo de errores robusto (no
  bloquear la eliminación si la limpieza falla, pero loguear el error).
- Añadir los cambios i18n al final y ejecutar `flutter gen-l10n` una sola vez.

### Plan de rollback

- Los cambios son aditivos (nueva feature + campos opcionales). Para rollback:
  - Revertir los commits.
  - Los documentos Firestore con `shippingMethodsByDay` o la colección
    `shipping_methods` pueden quedar sin efecto (no afectan a la app sin el
    código).
  - No se requiere migración de datos para rollback.

## 9) Suposiciones

- El volumen de clientes es bajo (< 500), lo que hace viable la lectura completa
  para limpieza cross-collection.
- No se necesitan índices Firestore compuestos para la colección
  `shipping_methods`.
- El campo `phone` se almacena como `String` en Firestore (no como número).
- La resolución de nombres de métodos de envío en la tabla de clientes se hace
  en la UI (carga one-shot similar a categorías), no mediante combinación de
  streams adicionales en el repositorio.
- Los días se representan con claves en inglés en Firestore (`monday`–`sunday`)
  y se muestran localizados en la UI usando claves i18n.

## 10) Preguntas abiertas

- Ninguna. Todas las preguntas del análisis funcional están resueltas.

## 11) Notas para implementación

- **No romper el comportamiento existente**: los cambios en `Client`,
  `ClientModel`, `ClientsRepository` y `ClientsCubit` deben ser
  retrocompatibles. El nuevo campo `shippingMethodsByDay` es opcional (mapa
  vacío por defecto).
- **Secuencia sugerida**: implementar primero la feature `shipping_methods` de
  forma aislada (pasos 1–5), verificar que funciona, y luego integrar con
  clientes (pasos 6–10).
- **Respetar los patrones existentes**: usar los mismos patrones de UI (feedback
  cards, diálogos de confirmación, search bar) ya establecidos en
  `client_categories` y `clients`.
- **Consistencia de la tabla de clientes**: al modificar los anchos, verificar
  que la tabla sigue siendo legible tanto con el menú expandido como colapsado.
- **Limpieza cross-collection**: implementar como método en el repositorio, no
  en el use case. El datasource de `shipping_methods` necesitará acceso a la
  colección `clients` de Firestore para hacer la limpieza. Inyectar
  `FirebaseFirestore` directamente (ya se inyecta para la propia colección).
- **Estado: Listo para implementación**
