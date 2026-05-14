# Technical Analysis: Añadir clientes desde Factura Directa con selección

- **Fecha:** 2026-05-11
- **Identificador:** add-clients-from-fd
- **Fuente:** docs/functional-analysis/2026-05-11-add-clients-from-fd.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Se reemplaza el flujo de sincronización automática de clientes desde Factura
Directa por un flujo interactivo de selección. Se crea un nuevo use case
`FetchNewFdContacts` que devuelve los contactos de FD no existentes en Firestore
(sin persistir). Un nuevo use case `AddSelectedFdContacts` persiste los
seleccionados. Un nuevo widget `SelectFdContactsDialog` presenta la lista con
selección múltiple. El cubit `ClientsCubit` reemplaza `syncClients()` por dos
métodos nuevos: `fetchNewContacts()` y `addSelectedContacts()`.

- **Áreas impactadas:** domain/usecases, presentation/bloc,
  presentation/widgets, presentation/pages, i18n, DI
- **Riesgo general estimado:** bajo — la lógica de comparación ya existe en
  `SyncClientsFromFd` y solo se refactoriza; `batchAdd` ya está implementado en
  el datasource.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first: `data/`, `domain/`, `presentation/` dentro
  de `lib/features/clients/`
- BLoC/Cubit con estados Equatable
- DI con GetIt en `lib/app/di/modules/clients_module.dart`
- fpdart `Either<Failure, T>` como retorno de use cases
- Clase base `UseCase<Type, Params>` en `lib/core/usecase/usecase.dart`

### Módulos relevantes

- **`SyncClientsFromFd`** — use case actual que descarga, compara y
  crea/actualiza en un solo paso. Usado en:
  - `ClientsCubit.syncClients()` (feature clients)
  - `FacturaDirectaCubit.syncClients()` (feature settings)
- **`ClientFirestoreDataSource`** — ya expone `getAll()`, `batchAdd()`, `add()`
- **`FacturaDirectaApiDataSource`** — expone `getContacts(companyId)`
- **`GetFdFiscalIds`** — ya implementa la lógica de obtener config FD +
  descargar contactos + extraer `fiscalId` por UUID. Patrón reutilizable.
- **`ClientModel`** — modelo con `toMap()`, sin campo `fiscalId` (correcto, no
  se añaden campos nuevos)
- **`FdContactData`** — entidad de dominio que ya incluye `uuid`, `name`,
  `fiscalId`

### Restricciones

- `SyncClientsFromFd` también se usa en `FacturaDirectaCubit` (settings). Ese
  flujo de sync completo debe mantenerse intacto allí.
- No se añaden campos nuevos al modelo de Firestore.
- i18n obligatorio — archivos `.arb` en `lib/app/localization/l10n/`.
- Firestore `batchAdd` es atómico (commit en batch).

## 3) Objetivo técnico

- **Qué debe cambiar:** El botón "Sincronizar desde FD" en `ClientsPage` se
  convierte en "Añadir desde FD" con un flujo de descarga → filtrado de nuevos →
  dialog de selección → `batchAdd` de seleccionados.
- **Resultado técnico:** Dos use cases desacoplados (fetch y add), un widget de
  selección reutilizable, y un cubit actualizado que orquesta el flujo.
- **Limitaciones:** No romper `FacturaDirectaCubit.syncClients()` en settings.
  No añadir campos a Firestore. No implementar búsqueda/paginación en el dialog.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Separar la lógica monolítica de `SyncClientsFromFd` en dos operaciones
independientes:

1. **`FetchNewFdContacts`** — obtiene config FD, descarga contactos, compara con
   Firestore, devuelve `List<FdNewContact>` (solo los nuevos, con datos para
   display).
2. **`AddSelectedFdContacts`** — recibe `List<FdNewContact>`, los mapea a
   `ClientModel` y hace `batchAdd`.

`SyncClientsFromFd` **no se modifica ni elimina** porque sigue usándose en
`FacturaDirectaCubit` (settings).

### Entidad nueva: `FdNewContact`

Entidad ligera de dominio para representar un contacto de FD candidato a
importar:

```dart
class FdNewContact extends Equatable {
  final String uuid;
  final String displayName; // título comercial o nombre fiscal
  final String fiscalName;  // nombre fiscal (para facturaDirectaName)
  final String fiscalId;    // NIF/CIF para display en dialog

  const FdNewContact({
    required this.uuid,
    required this.displayName,
    required this.fiscalName,
    required this.fiscalId,
  });

  @override
  List<Object?> get props => [uuid, displayName, fiscalName, fiscalId];
}
```

### Use case `FetchNewFdContacts`

- **Ubicación:**
  `lib/features/clients/domain/usecases/fetch_new_fd_contacts.dart`
- **Firma:** `UseCase<List<FdNewContact>, NoParams>`
- **Lógica:**
  1. Obtener config FD desde `SettingsRepository`
  2. Configurar API token
  3. Descargar contactos con `FacturaDirectaApiDataSource.getContacts()`
  4. Obtener clientes existentes con `ClientFirestoreDataSource.getAll()`
  5. Construir set de UUIDs existentes
  6. Filtrar contactos FD cuyo UUID no esté en el set (ignorar UUID vacío)
  7. Mapear a `List<FdNewContact>` con `displayName`, `fiscalName`, `fiscalId`
  8. Retornar `Right(list)` o `Left(failure)`
- **Dependencias:** `FacturaDirectaApiDataSource`, `SettingsRepository`,
  `ClientFirestoreDataSource` (mismas que `SyncClientsFromFd`)

### Use case `AddSelectedFdContacts`

- **Ubicación:**
  `lib/features/clients/domain/usecases/add_selected_fd_contacts.dart`
- **Firma:** `UseCase<int, AddSelectedFdContactsParams>` (retorna el número de
  añadidos)
- **Params:**

```dart
class AddSelectedFdContactsParams extends Equatable {
  final List<FdNewContact> contacts;
  const AddSelectedFdContactsParams({required this.contacts});
  @override
  List<Object?> get props => [contacts];
}
```

- **Lógica:**
  1. Mapear cada `FdNewContact` a
     `ClientModel(id: '', name: displayName, facturaDirectaUuid: uuid, facturaDirectaName: fiscalName, clientCategoryId: null)`
  2. Llamar a `ClientFirestoreDataSource.batchAdd(models)`
  3. Retornar `Right(contacts.length)`
- **Dependencias:** `ClientFirestoreDataSource`

### Widget `SelectFdContactsDialog`

- **Ubicación:**
  `lib/features/clients/presentation/widgets/select_fd_contacts_dialog.dart`
- **Tipo:** `StatefulWidget` que muestra un `AlertDialog`
- **Props de entrada:** `List<FdNewContact> contacts`
- **Retorno (pop):** `List<FdNewContact>?` — los seleccionados, o `null` si
  cancela
- **Diseño interno:**
  - Título: i18n key `clientsAddFromFdDialogTitle` ("Seleccionar contactos")
  - Subtítulo/contador: i18n key `clientsAddFromFdSelectedCount` ("N de M
    seleccionados")
  - Checkbox "Seleccionar todos" en la parte superior
  - `ListView.builder` scrollable con `CheckboxListTile` por contacto
    - Title: `displayName` (o `(Sin nombre)` si vacío, con i18n key
      `clientsAddFromFdNoName`)
    - Subtitle: `fiscalId` (NIF/CIF)
  - Botones de acción:
    - `TextButton` "Cancelar" → `Navigator.pop(context, null)`
    - `FilledButton` "Añadir seleccionados" (disabled si selección vacía) →
      `Navigator.pop(context, selectedList)`
  - Alto máximo del dialog: `MediaQuery.of(context).size.height * 0.7` para
    listas largas
  - Ancho: fijo ~480px o `constraints.maxWidth * 0.4`

### Integración con `ClientsCubit`

**Método `fetchNewContacts()`:**

- Invoca `FetchNewFdContacts(NoParams())`
- Retorna `Either<Failure, List<FdNewContact>>`
- No emite estados nuevos — la página maneja el resultado directamente (patrón
  ya usado con `syncClients()` que retorna `bool`)

**Método `addSelectedContacts(List<FdNewContact> contacts)`:**

- Invoca `AddSelectedFdContacts(params)`
- Retorna `bool` (éxito/fallo)
- En caso de fallo, emite `ClientsError`

**Cambios en el constructor:**

- Reemplazar `SyncClientsFromFd` por `FetchNewFdContacts` y
  `AddSelectedFdContacts`
- Eliminar `syncClients()` del cubit (ya no se usa desde la page)

> **Nota:** `SyncClientsFromFd` se mantiene registrado en DI porque
> `FacturaDirectaCubit` lo sigue usando. Solo se desacopla del `ClientsCubit`.

### Flujo en `ClientsPage`

El método `_syncFromFd()` se renombra a `_addFromFd()` con la siguiente lógica:

1. Mostrar dialog de loading (no dismissable) — "Buscando nuevos contactos…"
2. Llamar a `_cubit.fetchNewContacts()`
3. Cerrar dialog de loading
4. Si error → mostrar feedback de error
5. Si lista vacía → mostrar feedback informativo ("No hay contactos nuevos en
   Factura Directa")
6. Si hay contactos → mostrar `SelectFdContactsDialog(contacts: list)`
7. Si el usuario cancela → nada
8. Si el usuario confirma selección: a. Mostrar dialog de loading — "Añadiendo
   clientes…" b. Llamar a `_cubit.addSelectedContacts(selected)` c. Llamar a
   `_cubit.reloadFiscalIds()` d. Cerrar dialog de loading e. Mostrar feedback de
   éxito con conteo

### Gestión de errores y validaciones

| Escenario                 | Failure                    | Feedback al usuario                                  |
| ------------------------- | -------------------------- | ---------------------------------------------------- |
| Config FD no encontrada   | `ConfigNotFoundFailure`    | i18n: error de configuración                         |
| Error de red              | `NetworkFailure`           | i18n: error de red (reutilizar `fdNetworkError`)     |
| Error de servidor/API     | `ServerFailure`            | i18n: error de servidor (reutilizar `fdServerError`) |
| Error en batchAdd         | `ServerFailure`            | i18n: error al añadir clientes                       |
| Lista de nuevos vacía     | (no es error)              | i18n: no hay contactos nuevos                        |
| UUID vacío en contacto FD | (ignorado silenciosamente) | —                                                    |
| Contacto sin nombre       | Se guarda con `name: ''`   | Display en dialog: "(Sin nombre)"                    |

### Consideraciones de compatibilidad

- `SyncClientsFromFd` permanece intacto → no hay breaking change en
  `FacturaDirectaCubit`
- El `ClientsCubit` cambia su constructor (nuevos use cases en lugar de
  `SyncClientsFromFd`), lo que requiere actualizar su registro en DI y sus tests
- El stream `watchAll()` de Firestore se encarga automáticamente de refrescar la
  tabla tras `batchAdd`

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                  | Propósito                                                            |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `lib/features/clients/domain/entities/fd_new_contact.dart`                 | Entidad de dominio para contacto FD nuevo candidato a importar       |
| `lib/features/clients/domain/usecases/fetch_new_fd_contacts.dart`          | Use case: descarga contactos FD, filtra nuevos, retorna lista        |
| `lib/features/clients/domain/usecases/add_selected_fd_contacts.dart`       | Use case: persiste contactos seleccionados en Firestore via batchAdd |
| `lib/features/clients/presentation/widgets/select_fd_contacts_dialog.dart` | Dialog de selección múltiple de contactos FD                         |

### Artefactos a modificar

| Artefacto                                                   | Cambio esperado                                                                                                                                                              |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/presentation/bloc/clients_cubit.dart` | Reemplazar dependencia `SyncClientsFromFd` por `FetchNewFdContacts` + `AddSelectedFdContacts`. Reemplazar `syncClients()` por `fetchNewContacts()` y `addSelectedContacts()` |
| `lib/features/clients/presentation/pages/clients_page.dart` | Renombrar `_syncFromFd()` a `_addFromFd()`. Cambiar icono y texto del botón. Implementar nuevo flujo con dialog de selección                                                 |
| `lib/app/di/modules/clients_module.dart`                    | Registrar `FetchNewFdContacts` y `AddSelectedFdContacts`. Actualizar factory de `ClientsCubit`                                                                               |
| `lib/app/localization/l10n/app_es.arb`                      | Añadir ~10 claves nuevas de i18n. Modificar claves existentes de sync                                                                                                        |
| `lib/app/localization/l10n/app_localizations.dart`          | Se regenera automáticamente tras editar `.arb`                                                                                                                               |
| `lib/app/localization/l10n/app_localizations_es.dart`       | Se regenera automáticamente tras editar `.arb`                                                                                                                               |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                                                                                   |
| --------- | ---------------------------------------------------------------------------------------- |
| (ninguno) | `SyncClientsFromFd` se mantiene porque `FacturaDirectaCubit` en settings lo sigue usando |

## 6) Estrategia de implementación

### Paso 1: Crear entidad `FdNewContact`

Crear `lib/features/clients/domain/entities/fd_new_contact.dart` con los campos
`uuid`, `displayName`, `fiscalName`, `fiscalId`.

### Paso 2: Crear use case `FetchNewFdContacts`

Crear `lib/features/clients/domain/usecases/fetch_new_fd_contacts.dart`. Extraer
la lógica de comparación de `SyncClientsFromFd` (pasos 1-4: config, descarga,
carga existentes, filtrado) sin la parte de persistencia.

### Paso 3: Crear use case `AddSelectedFdContacts`

Crear `lib/features/clients/domain/usecases/add_selected_fd_contacts.dart`.
Mapea `FdNewContact` → `ClientModel` y llama a `batchAdd`.

### Paso 4: Actualizar `ClientsCubit`

Reemplazar `SyncClientsFromFd` por los dos nuevos use cases. Crear métodos
`fetchNewContacts()` y `addSelectedContacts()`. Eliminar `syncClients()`.

### Paso 5: Crear widget `SelectFdContactsDialog`

Crear `lib/features/clients/presentation/widgets/select_fd_contacts_dialog.dart`
con selección múltiple, select-all, contador, y botones de acción.

### Paso 6: Actualizar `ClientsPage`

Reemplazar `_syncFromFd()` por `_addFromFd()`. Cambiar icono
(`person_add_rounded`) y texto del botón. Integrar el dialog de selección en el
flujo.

### Paso 7: Actualizar i18n

Añadir las claves nuevas en `app_es.arb`. Ejecutar `flutter gen-l10n`.

### Paso 8: Actualizar DI (`clients_module.dart`)

Registrar los dos nuevos use cases. Actualizar la factory de `ClientsCubit` con
los nuevos parámetros.

### Paso 9: Actualizar tests

Actualizar tests del cubit con los nuevos use cases mockeados. Crear tests para
los dos use cases nuevos.

### Orden recomendado

1 → 2 → 3 → 4 → 8 → 5 → 6 → 7 → 9

### Dependencias entre pasos

- Paso 2 y 3 dependen de Paso 1 (entidad `FdNewContact`)
- Paso 4 depende de Pasos 2 y 3
- Paso 5 depende de Paso 1 (recibe `List<FdNewContact>`)
- Paso 6 depende de Pasos 4 y 5
- Paso 8 depende de Pasos 2, 3 y 4
- Paso 9 depende de todos los anteriores

### Puntos delicados

- **Constructor de `ClientsCubit`:** Cambiar de 6 a 7 parámetros (se añaden 2
  nuevos, se elimina 1). Verificar que el orden en `clients_module.dart`
  coincida con el constructor.
- **`FacturaDirectaCubit`:** No tocar. Confirmar que sigue resolviendo
  `SyncClientsFromFd` desde DI sin problemas.
- **Campo `fiscalId` en API FD:** En `GetFdFiscalIds` se accede como
  `main['fiscalId']`. Verificar que en `SyncClientsFromFd` el campo es
  `main['fiscal_id']` o `main['fiscalId']` y usar la misma clave. En
  `GetFdFiscalIds` se usa `main['fiscalId']` (camelCase), se debe mantener
  consistencia.

## 7) Estrategia de validación

### Verificación automática

- Tests unitarios para `FetchNewFdContacts`: mock del datasource y API,
  verificar que filtra correctamente nuevos vs existentes, manejo de UUID vacío,
  contactos sin nombre
- Tests unitarios para `AddSelectedFdContacts`: mock del datasource, verificar
  mapeo correcto a `ClientModel`, verify `batchAdd` llamado
- Tests unitarios para `ClientsCubit` actualizado: verificar
  `fetchNewContacts()` y `addSelectedContacts()` con mocks
- Widget test para `SelectFdContactsDialog`: verificar renderizado, selección,
  select-all, botón deshabilitado sin selección, retorno correcto

### Verificación manual

- Flujo completo: botón → loading → dialog con contactos nuevos → seleccionar →
  confirmar → verificar en Firestore
- Flujo sin nuevos: verificar mensaje informativo
- Flujo cancelación: verificar que no se persiste nada
- Flujo error: desconectar red y verificar feedback

### Escenarios a cubrir

- 0 contactos nuevos → mensaje informativo, sin dialog
- 1 contacto nuevo → dialog con un item
- N contactos nuevos → dialog scrollable, select-all funciona
- Contacto sin nombre → muestra "(Sin nombre)" en dialog
- Contacto con UUID vacío → ignorado
- Error de config → feedback de error
- Error de red → feedback de error
- Error en batchAdd → feedback de error
- Select-all + deseleccionar uno → contador actualizado, botón habilitado
- Cancelar dialog → sin cambios en Firestore

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Bajo:** El campo `fiscalId` en la respuesta de la API FD podría ser
  `fiscal_id` (snake_case) en lugar de `fiscalId` (camelCase). `GetFdFiscalIds`
  ya lo accede como `main['fiscalId']`, por lo que se debe usar la misma clave.
- **Bajo:** El constructor de `ClientsCubit` cambia, lo que afecta a todos los
  sitios que lo instancian (DI y tests).

### Impacto potencial

- El botón de sync desaparece de la pantalla de clientes; los usuarios ya no
  podrán actualizar datos de contactos existentes desde esa pantalla.
- El flujo de sync completo sigue disponible en Settings > Factura Directa.

### Mitigación

- Mantener `SyncClientsFromFd` y su uso en `FacturaDirectaCubit` intactos.
- Verificar manualmente que Settings > Factura Directa > Sincronizar sigue
  funcionando tras los cambios.

### Plan de rollback

- Revertir los commits. No hay migración de datos ni cambios en Firestore
  schema.

## 9) Suposiciones

- El campo `fiscalId` en la respuesta de la API de FD se accede como
  `main['fiscalId']` (consistente con `GetFdFiscalIds`).
- `SyncClientsFromFd` seguirá usándose en `FacturaDirectaCubit` y no debe
  modificarse.
- El dialog no necesita búsqueda ni paginación en esta iteración.
- El `batchAdd` de Firestore soporta el volumen esperado (máximo ~500 contactos
  por batch de Firestore).
- PA-01 resuelta: solo se añaden nuevos, no se actualizan existentes.
- PA-02 resuelta: se muestra nombre y NIF/CIF en el dialog.

## 10) Preguntas abiertas

(Ninguna — las preguntas abiertas del análisis funcional han sido resueltas en
el contexto adicional proporcionado.)

## 11) Notas para implementación

- **No modificar** `SyncClientsFromFd` ni `FacturaDirectaCubit`.
- El mapeo de contacto FD a `FdNewContact` debe extraer: `uuid` =
  `content.uuid`, `displayName` = `main.title ?? main.name`, `fiscalName` =
  `main.name`, `fiscalId` = `main.fiscalId ?? ''`.
- El mapeo de `FdNewContact` a `ClientModel` para persistencia: `name` =
  `displayName`, `facturaDirectaUuid` = `uuid`, `facturaDirectaName` =
  `fiscalName`, `clientCategoryId` = `null`, `shippingMethodsByDay` = `{}`.
- Claves i18n a añadir en `app_es.arb`:
  - `clientsAddFromFd`: "Añadir desde Factura Directa"
  - `clientsAddFromFdLoading`: "Buscando nuevos contactos en Factura Directa…"
  - `clientsAddFromFdDialogTitle`: "Seleccionar contactos"
  - `clientsAddFromFdSelectAll`: "Seleccionar todos"
  - `clientsAddFromFdSelectedCount`: "{selected} de {total} seleccionados" (con
    placeholders)
  - `clientsAddFromFdConfirm`: "Añadir seleccionados"
  - `clientsAddFromFdCancel`: "Cancelar"
  - `clientsAddFromFdNoNew`: "No hay contactos nuevos en Factura Directa"
  - `clientsAddFromFdSaving`: "Añadiendo clientes…"
  - `clientsAddFromFdSuccess`: "{count} clientes añadidos correctamente" (con
    placeholder)
  - `clientsAddFromFdError`: "Error al añadir clientes"
  - `clientsAddFromFdNoName`: "(Sin nombre)"
  - `clientsAddFromFdConfigError`: "Configure Factura Directa en Ajustes antes
    de continuar"
- Claves i18n existentes que se pueden reutilizar: `fdNetworkError`,
  `fdServerError`, `fdRetry`.
- Claves i18n existentes que ya no se usarán en `ClientsPage` (pero pueden
  seguir usándose en settings): `clientsSyncFromFd`, `clientsSyncingFromFd`,
  `clientsSyncSuccess`, `clientsSyncError`.
- Tras editar `app_es.arb`, ejecutar `flutter gen-l10n` para regenerar las
  clases Dart.
- **Estado: Listo para implementación**
