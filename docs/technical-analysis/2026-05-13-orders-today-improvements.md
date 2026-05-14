# Technical Analysis: Mejoras en pantalla Pedidos de Hoy

- **Fecha:** 2026-05-13
- **Identificador:** orders-today-improvements
- **Fuente:** docs/functional-analysis/2026-05-13-orders-today-improvements.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

Tres cambios independientes que afectan a las features `orders_today`,
`settings` e `invoices`:

1. **Badge de usuario**: El `OrdersPresenceCubit` se crea con `userName: email`
   en el DI module. Se debe resolver el `userName` real desde Firestore (vía
   `AuthRepository.getUserName`) antes de instanciar el cubit.
2. **Placeholder móvil**: Añadir una comprobación de `MediaQuery` al inicio del
   `build` de `OrdersTodayPage` siguiendo el patrón ya establecido en toda la
   app.
3. **Serie de factura en Firestore**: Migrar la fuente de datos de
   `SharedPreferences` a Firestore. Implica un nuevo datasource remoto, cambio
   de la interfaz `SettingsRepository` (método síncrono → asíncrono),
   actualización del use case `CreateProvisionalInvoice` y del widget
   `InvoiceSeriesSection`.

- **Principales áreas impactadas**: DI module de `orders_today`,
  `OrdersTodayPage`, `SettingsRepository`, `SettingsLocalDataSource`,
  `CreateProvisionalInvoice`, `InvoiceSeriesSection`, `settings_module.dart`,
  i18n.
- **Riesgo general estimado**: Medio (el cambio de firma síncrona → asíncrona en
  `SettingsRepository` tiene impacto en cascada).

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt y fpdart.
- Patrón consistente: `DataSource` → `Repository` → `UseCase` → `Cubit/BLoC` →
  `Widget`.

### Módulos relevantes

- **`orders_today`**: Cubit de presencia (`OrdersPresenceCubit`) recibe `userId`
  y `userName` en constructor. Se instancia en `orders_today_module.dart` línea
  105–111 con `userName: email` (bug confirmado).
- **`settings`**: `SettingsRepository` expone `getInvoiceSeries()` (síncrono,
  devuelve `String`) y `saveInvoiceSeries(String)` (async). Implementado via
  `SettingsLocalDataSource` → `SharedPreferences`.
- **`invoices`**: `CreateProvisionalInvoice` usa
  `_settingsRepo.getInvoiceSeries()` de forma síncrona en línea 44 para
  construir el body de la factura.
- **`auth`**: `AuthRepository.getUserName(uid)` lee el `userName` desde
  Firestore collection `users`. Ya existe el use case `GetUserName`.

### Restricciones

- `ConfigNotFoundFailure` ya existe y está mapeado en `ProvisionalInvoiceCubit`
  como `configNotFound` → muestra al usuario que debe configurar FD en Ajustes.
- Breakpoint móvil: `AppSideMenu.mobileBreakpoint = 768` usado en 17+ lugares.
- Patrón Firestore datasource: `ClientCategoryFirestoreDataSourceImpl` como
  referencia (recibe `FirebaseFirestore`, accede a colección, lanza
  `ServerException`).

### Dependencias

- `cloud_firestore` (ya en el proyecto).
- `firebase_auth` (ya en el proyecto).
- No se introducen dependencias nuevas.

## 3) Objetivo técnico

- **Qué debe cambiar**: (1) El valor pasado como `userName` al crear
  `OrdersPresenceCubit`, (2) lógica responsive en `OrdersTodayPage`, (3) la
  fuente de datos de la serie de factura y la firma del método
  `getInvoiceSeries`.
- **Resultado técnico**: Badge muestra nombre real, pantalla bloqueada en móvil,
  serie de factura centralizada en Firestore.
- **Limitaciones**: El cambio de `getInvoiceSeries()` de síncrono a asíncrono
  provoca cambios en cascada en el repositorio, use case y widget. Se deben
  actualizar todos los consumidores.

## 4) Diseño técnico de la solución

### Enfoque propuesto

#### Cambio 1 — Badge de usuario (userName real)

El problema está en `orders_today_module.dart` línea 108:

```dart
userName: email,  // ← actualmente pasa el email
```

Se debe resolver el `userName` real. Dado que el cubit se registra como
`Factory` y `getUserName` es async, se debe obtener el `userName` **antes** de
que el cubit se cree, o hacerlo dentro del cubit en `init()`. La opción más
limpia: al registrar el cubit, obtener el nombre desde `AuthRepository` y
pasarlo. Sin embargo, las factories de GetIt son síncronas.

**Solución propuesta**: Modificar el factory para obtener el `userName`
almacenado previamente. Dado que `AppUser` ya tiene `userName` y se carga al
autenticarse, se puede:

- Almacenar el `AppUser` actual en el DI container al hacer login (ya se carga
  en `AuthCubit`).
- O bien, acceder a `AuthCubit.state` para obtener el `userName`.

Alternativa más simple y directa: en `orders_today_module.dart`, acceder a
`AuthRepository.getUserName(uid)` de forma previa. Pero como el factory es
síncrono, la mejor aproximación es:

**Opción elegida**: Modificar `OrdersTodayPage._OrdersTodayPageState` para
resolver el `userName` async antes de crear el cubit, pasándolo en la creación.
El patrón actual ya crea el cubit en `initState`/`build` del state. Se puede:

1. Leer `userName` desde `AuthRepository` al inicializar el page state.
2. Pasar ese `userName` al crear el `OrdersPresenceCubit` manualmente (como ya
   se hace: `_presenceCubit ??= sl<OrdersPresenceCubit>()`).

Sin embargo, el cubit se resuelve de GetIt donde el `userName` ya está
hardcodeado. La solución más limpia: **cambiar el factory del DI para que reciba
el `userName` como parámetro**, o directamente arreglar el factory para leer de
un valor ya cacheado.

**Solución final**: Registrar una instancia de `AppUser` (o el `userName` como
`String`) en el contenedor DI al completar el login. El `AuthCubit` ya resuelve
el `AppUser` al autenticarse. Se puede registrar
`sl.registerSingleton<AppUser>(user)` post-login y consumirlo en el factory del
cubit de presencia. Alternativamente, usar un parámetro nombrado en GetIt.

**Solución más pragmática y no invasiva**: En `orders_today_module.dart`,
cambiar la resolución para hacer un lookup síncrono del `userName` que ya se
almacena en el `users` collection. Dado que GetIt factories son síncronas, lo
más simple es:

- Registrar el `userName` como un `String` con instance name en DI al hacer
  login (en el flow de `AuthCubit`).
- O bien, usar `AuthRepository` para cachear el nombre localmente tras login.

Dado el análisis del código, la solución más limpia es: en la `OrdersTodayPage`
(donde ya se crea manualmente el cubit), obtener el `userName` de forma
asíncrona y pasarlo. Se puede hacer cambiando el registro del factory para
aceptar parámetros, o creando el cubit directamente sin GetIt para el parámetro
`userName`.

**Propuesta concreta**: No cambiar el factory de GetIt. En su lugar, en
`OrdersTodayPage._OrdersTodayPageState`, antes de crear `_presenceCubit`,
resolver el `userName` via `sl<AuthRepository>().getUserName(uid)` y usar ese
valor. Crear el cubit directamente:

```dart
_presenceCubit ??= OrdersPresenceCubit(
  repository: sl<OrdersPresenceRepository>(),
  userId: uid,
  userName: resolvedUserName ?? email, // fallback a email
)..init();
```

Esto requiere resolver `userName` en `initState` o `didChangeDependencies` del
state.

#### Cambio 2 — Placeholder móvil

Añadir al inicio del `build` de `_OrdersTodayPageState` (o del widget padre) la
comprobación de breakpoint:

```dart
final isMobile = MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;
if (isMobile) {
  return _buildMobilePlaceholder(context);
}
```

El widget placeholder sigue el mismo patrón visual que los estados vacíos
existentes (icono + título + descripción centrados).

#### Cambio 3 — Serie de factura en Firestore

**3a. Nuevo datasource remoto:**

Crear `SettingsRemoteDataSource` (abstract) y `SettingsRemoteDataSourceImpl` que
accede a la colección Firestore `factura_directa_configuration`, documento
`"default"`, campo `invoiceSeries`.

**3b. Cambio de interfaz del repositorio:**

```dart
// Antes (síncrono):
String getInvoiceSeries();
Future<Either<Failure, Unit>> saveInvoiceSeries(String series);

// Después (asíncrono):
Future<Either<Failure, String?>> getInvoiceSeries();
Future<Either<Failure, Unit>> saveInvoiceSeries(String series);
```

**3c. Actualización del repositorio impl:**

`SettingsRepositoryImpl` recibe el nuevo `SettingsRemoteDataSource` además del
local. Para `getInvoiceSeries` lee de Firestore; para `saveInvoiceSeries`
escribe en Firestore. Se eliminan los métodos de invoice series de
`SettingsLocalDataSource`.

**3d. Actualización de `CreateProvisionalInvoice`:**

El método `call` ya es async. Cambiar:

```dart
// Antes:
'docNumber': {'series': _settingsRepo.getInvoiceSeries()},

// Después:
final seriesResult = await _settingsRepo.getInvoiceSeries();
return seriesResult.fold(
  (failure) => Left(failure),
  (series) async {
    if (series == null || series.isEmpty) {
      return Left(ConfigNotFoundFailure());
    }
    // ... construir body con series ...
  },
);
```

**3e. Actualización de `InvoiceSeriesSection`:**

El widget pasa de lectura síncrona a lectura asíncrona con un `FutureBuilder` o
estado de carga en `initState`. El `_save()` ya es async.

**3f. Eliminación de invoice series de SharedPreferences:**

Eliminar `getInvoiceSeries()` y `saveInvoiceSeries()` de
`SettingsLocalDataSource` y su impl. Eliminar las constantes `_invoiceSeriesKey`
y `_defaultInvoiceSeries` de `SettingsLocalDataSourceImpl`.

### Componentes / módulos / servicios afectados

| Módulo         | Componentes afectados                                                                                                                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `orders_today` | `OrdersTodayPage`, `orders_today_module.dart`                                                                                                                                                     |
| `settings`     | `SettingsRepository`, `SettingsRepositoryImpl`, `SettingsLocalDataSource`, `SettingsLocalDataSourceImpl`, `InvoiceSeriesSection`, `settings_module.dart`, nuevo `SettingsRemoteDataSource` + impl |
| `invoices`     | `CreateProvisionalInvoice`                                                                                                                                                                        |
| `app`          | `app_es.arb` (i18n)                                                                                                                                                                               |

### Contratos e interfaces

**`SettingsRepository`** — cambio de firma:

```dart
abstract class SettingsRepository {
  int getPageSize();
  Future<Either<Failure, Unit>> savePageSize(int size);

  // Antes: String getInvoiceSeries();
  Future<Either<Failure, String?>> getInvoiceSeries();
  Future<Either<Failure, Unit>> saveInvoiceSeries(String series);
}
```

**`SettingsRemoteDataSource`** (nueva interfaz):

```dart
abstract class SettingsRemoteDataSource {
  Future<String?> getInvoiceSeries();
  Future<void> saveInvoiceSeries(String series);
}
```

**`SettingsLocalDataSource`** — se eliminan `getInvoiceSeries()` y
`saveInvoiceSeries()`.

### Flujo de datos o de control

**Serie de factura — lectura (Ajustes):**

```
InvoiceSeriesSection.initState()
  → _settingsRepo.getInvoiceSeries()
    → SettingsRepositoryImpl.getInvoiceSeries()
      → SettingsRemoteDataSourceImpl.getInvoiceSeries()
        → Firestore.collection('factura_directa_configuration').doc('default').get()
          → doc.data()?['invoiceSeries'] as String?
  → Actualizar TextField con valor obtenido (o vacío si null)
```

**Serie de factura — escritura (Ajustes):**

```
InvoiceSeriesSection._save()
  → _settingsRepo.saveInvoiceSeries(text)
    → SettingsRepositoryImpl.saveInvoiceSeries(text)
      → SettingsRemoteDataSourceImpl.saveInvoiceSeries(text)
        → Firestore.collection('factura_directa_configuration').doc('default').set({'invoiceSeries': text}, merge: true)
```

**Serie de factura — uso en factura provisional:**

```
CreateProvisionalInvoice.call(preview)
  → await _settingsRepo.getInvoiceSeries()
    → fold: Left(failure) → propagate
    → fold: Right(null/empty) → Left(ConfigNotFoundFailure())
    → fold: Right(series) → construir body con series → _fdApi.createInvoice(body)
```

**Badge userName:**

```
OrdersTodayPage.build()
  → (async init) AuthRepository.getUserName(uid)
    → userName ?? email (fallback)
  → OrdersPresenceCubit(userName: resolvedName)
```

### Gestión de errores y validaciones

- **Serie vacía en Firestore** → `getInvoiceSeries()` devuelve `Right(null)` →
  `CreateProvisionalInvoice` retorna `Left(ConfigNotFoundFailure())` → UI
  muestra "No se ha configurado Factura Directa. Ve a Ajustes para
  configurarla."
- **Error de lectura Firestore** → `ServerException` → `ServerFailure` → UI
  muestra error.
- **Error de escritura Firestore** → `ServerException` → `ServerFailure` →
  SnackBar con error.
- **userName null** → fallback a email (ya cubierto en `AppUser`).

### Consideraciones de compatibilidad o migración

- El valor existente en `SharedPreferences` se **ignora** (no se migra). El
  usuario debe configurar la serie en Ajustes (escritura en Firestore) la
  primera vez.
- El cambio de `getInvoiceSeries()` de síncrono a
  `Future<Either<Failure, String?>>` **rompe la compatibilidad** en el
  repositorio. Todos los consumidores deben adaptarse (solo
  `CreateProvisionalInvoice` y `InvoiceSeriesSection`).
- Si existen tests unitarios que mockean
  `SettingsRepository.getInvoiceSeries()`, deberán actualizarse a la nueva
  firma.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                             | Propósito                                                      |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `lib/features/settings/data/datasources/remote/settings_remote_data_source.dart`      | Interfaz del datasource remoto para configuración en Firestore |
| `lib/features/settings/data/datasources/remote/settings_remote_data_source_impl.dart` | Implementación Firestore del datasource remoto                 |

### Artefactos a modificar

| Artefacto                                                                               | Cambio esperado                                                                                                                       |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/app/di/modules/orders_today_module.dart`                                           | Eliminar el factory de `OrdersPresenceCubit` que hardcodea `userName: email` (se construye manualmente en la page)                    |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`                   | (1) Añadir comprobación de breakpoint móvil con placeholder. (2) Resolver `userName` async y crear `OrdersPresenceCubit` directamente |
| `lib/features/settings/domain/repositories/settings_repository.dart`                    | Cambiar `String getInvoiceSeries()` a `Future<Either<Failure, String?>> getInvoiceSeries()`                                           |
| `lib/features/settings/data/repositories/settings_repository_impl.dart`                 | Inyectar `SettingsRemoteDataSource`, implementar nuevo `getInvoiceSeries` y `saveInvoiceSeries` contra Firestore                      |
| `lib/features/settings/data/datasources/local/settings_local_data_source.dart`          | Eliminar `getInvoiceSeries()` y `saveInvoiceSeries()`                                                                                 |
| `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`     | Eliminar métodos y constantes de invoice series                                                                                       |
| `lib/features/settings/presentation/widgets/invoice_series_section.dart`                | Cambiar lectura síncrona a asíncrona; añadir estado de carga                                                                          |
| `lib/app/di/modules/settings_module.dart`                                               | Registrar `SettingsRemoteDataSource` y pasarlo a `SettingsRepositoryImpl`                                                             |
| `lib/features/invoices/domain/usecases/create_provisional_invoice.dart`                 | Cambiar `_settingsRepo.getInvoiceSeries()` a await + validación de resultado                                                          |
| `lib/app/localization/l10n/app_es.arb`                                                  | Añadir claves i18n para placeholder móvil de pedidos                                                                                  |
| Reglas de seguridad Firestore (`firestore.rules` si existe, o configuración en consola) | Permitir lectura/escritura en `factura_directa_configuration` a usuarios autenticados                                                 |

### Artefactos a retirar o reemplazar

| Artefacto                                                                                 | Motivo                                                     |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Constantes `_invoiceSeriesKey` y `_defaultInvoiceSeries` en `SettingsLocalDataSourceImpl` | La serie se gestiona en Firestore, no en SharedPreferences |

## 6) Estrategia de implementación

1. **Paso 1 — Crear datasource remoto de settings**: Crear la interfaz
   `SettingsRemoteDataSource` y su implementación `SettingsRemoteDataSourceImpl`
   accediendo a Firestore `factura_directa_configuration/default`.
2. **Paso 2 — Actualizar `SettingsRepository` y su impl**: Cambiar la firma de
   `getInvoiceSeries()` a async. Inyectar `SettingsRemoteDataSource` en
   `SettingsRepositoryImpl`. Implementar lectura/escritura contra Firestore.
   Eliminar invoice series de `SettingsLocalDataSource` e impl.
3. **Paso 3 — Actualizar DI (`settings_module.dart`)**: Registrar
   `SettingsRemoteDataSource` y pasar ambos datasources a
   `SettingsRepositoryImpl`.
4. **Paso 4 — Actualizar `CreateProvisionalInvoice`**: Hacer await del nuevo
   `getInvoiceSeries()`, validar resultado, emitir `ConfigNotFoundFailure` si no
   existe o está vacío.
5. **Paso 5 — Actualizar `InvoiceSeriesSection`**: Cambiar la carga inicial a
   async (FutureBuilder o estado en `initState`), y actualizar `_save()` si es
   necesario.
6. **Paso 6 — Placeholder móvil en `OrdersTodayPage`**: Añadir comprobación de
   `MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint` al inicio
   del build. Renderizar placeholder con icono y texto i18n.
7. **Paso 7 — Badge userName en `OrdersTodayPage`**: Resolver el `userName` real
   desde `AuthRepository.getUserName(uid)` de forma asíncrona al inicializar.
   Pasar el nombre resuelto al crear `OrdersPresenceCubit`. Eliminar o ajustar
   el factory de `OrdersPresenceCubit` en el DI module.
8. **Paso 8 — i18n**: Añadir claves de traducción para el placeholder móvil.
9. **Paso 9 — Actualizar tests afectados**: Adaptar mocks de
   `SettingsRepository` a la nueva firma asíncrona.

### Orden recomendado

1. Pasos 1-3 (datasource + repo + DI) — forman la base del cambio de serie.
2. Paso 4 (use case) — depende de pasos 1-3.
3. Paso 5 (widget settings) — depende de pasos 1-3.
4. Pasos 6-8 (placeholder + badge + i18n) — independientes entre sí y de los
   pasos 1-5.
5. Paso 9 (tests) — al final, una vez estabilizado.

### Dependencias entre pasos

- Pasos 4 y 5 dependen de pasos 1-3 (cambio de interfaz del repositorio).
- Pasos 6, 7 y 8 son independientes del resto y pueden ejecutarse en paralelo.
- Paso 9 depende de todos los anteriores.

### Puntos delicados

- **Cambio de firma síncrona → asíncrona**: `getInvoiceSeries()` pasa de
  `String` a `Future<Either<Failure, String?>>`. Esto rompe compilación en todos
  los consumidores. Se deben actualizar en la misma iteración.
- **Factory del DI module**: El factory actual de `OrdersPresenceCubit` en
  `orders_today_module.dart` hardcodea `userName: email`. Si se mantiene el
  factory, cualquier otro punto que cree el cubit via DI seguirá con email.
  Evaluar si hay otros consumidores. Si el cubit solo se crea en
  `OrdersTodayPage`, se puede eliminar el factory y crear directamente en la
  page.
- **Firestore rules**: Asegurar que la colección `factura_directa_configuration`
  permita lectura/escritura a usuarios autenticados. Esto puede requerir una
  actualización manual en la consola de Firebase si no hay archivo de reglas en
  el repo.

## 7) Estrategia de validación

### Verificación automática

- Tests unitarios de `SettingsRepositoryImpl` con mock de
  `SettingsRemoteDataSource`: verificar lectura/escritura correcta y manejo de
  errores.
- Tests unitarios de `CreateProvisionalInvoice`: verificar que emite
  `ConfigNotFoundFailure` cuando la serie es null o vacía.
- Tests existentes de `SettingsRepository`: actualizar mocks a la nueva firma
  async.

### Validación manual

- Abrir Ajustes > Factura Directa → verificar que el campo carga el valor desde
  Firestore (comprobar en consola Firebase que lee
  `factura_directa_configuration/default`).
- Guardar un nuevo valor de serie → verificar que se persiste en Firestore.
- Generar factura provisional → verificar que usa la serie de Firestore.
- Generar factura provisional sin serie configurada → verificar que muestra
  error "No se ha configurado Factura Directa".
- Acceder a "Pedidos de hoy" → verificar que el badge muestra el nombre del
  usuario, no el email.
- Acceder desde un navegador con ancho ≤ 768 px → verificar que se muestra el
  placeholder.
- Redimensionar el navegador de desktop a menos de 768 px → verificar transición
  reactiva al placeholder.

### Escenarios a cubrir

- Serie existe en Firestore → lectura correcta.
- Serie no existe en Firestore → campo vacío en Ajustes; error al generar
  factura.
- Error de red al leer/escribir serie → error propagado.
- `userName` configurado → badge muestra nombre.
- `userName` null → badge muestra email (fallback).
- Pantalla > 768 px → tabla normal.
- Pantalla ≤ 768 px → placeholder.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                     | Probabilidad | Impacto                 |
| ---------------------------------------------------------- | ------------ | ----------------------- |
| Cambio de firma rompe otros consumidores no detectados     | Baja         | Alto                    |
| Reglas Firestore no permiten acceso a la nueva colección   | Media        | Alto                    |
| El `userName` no está configurado para usuarios existentes | Baja         | Bajo (fallback a email) |

### Impacto potencial

- El cambio de firma de `getInvoiceSeries` es un breaking change interno. Si hay
  consumidores no detectados, no compilará hasta que se actualicen.
- Si las reglas de Firestore no están configuradas, la lectura/escritura de la
  serie fallará en producción.

### Mitigación

- Buscar exhaustivamente todos los usos de `getInvoiceSeries` antes de
  implementar (solo se han detectado 2: `CreateProvisionalInvoice` y
  `InvoiceSeriesSection`).
- Configurar reglas de Firestore como parte del paso de implementación.
- Verificar con `dart analyze` / `flutter build` que no hay errores de
  compilación.

### Plan de rollback

- Los cambios son puramente de código y configuración Firestore.
- Rollback: revertir los commits que introducen los cambios.
- Datos: la colección `factura_directa_configuration` en Firestore se puede
  eliminar sin impacto si se revierte.
- SharedPreferences: si se restaura, el usuario tiene que re-introducir el valor
  (pero ya era el caso antes).

## 9) Suposiciones

- El cubit `OrdersPresenceCubit` solo se crea desde `OrdersTodayPage`
  (confirmado: el factory en DI y la page son los únicos puntos).
- `getInvoiceSeries` solo se consume en `CreateProvisionalInvoice` (línea 44) y
  `InvoiceSeriesSection` (línea 25).
- No hay archivo `firestore.rules` en el repo; las reglas se configuran en la
  consola de Firebase.
- La colección `factura_directa_configuration` con documento `"default"` no
  existe aún en Firestore.
- `AppUser.userName` se carga correctamente al autenticarse y está disponible
  vía `AuthRepository.getUserName(uid)`.

## 10) Preguntas abiertas

- Ninguna. Todas las decisiones funcionales fueron resueltas en el análisis
  funcional.

## 11) Notas para implementación

- **No romper comportamiento existente**: El cambio 3 es el más invasivo.
  Asegurarse de que todos los consumidores de `getInvoiceSeries()` se actualizan
  en el mismo commit/PR.
- **Secuencia sugerida**: Implementar primero la infraestructura (datasource +
  repo + DI), después los consumidores (use case + widget), y finalmente los
  cambios de UI (placeholder + badge). Esto permite compilar y testear
  incrementalmente.
- **Reglas Firestore**: Añadir una regla que permita a usuarios autenticados
  leer y escribir en `factura_directa_configuration`:
  ```
  match /factura_directa_configuration/{docId} {
    allow read, write: if request.auth != null;
  }
  ```
- **i18n**: Se necesitan al menos 2 nuevas claves:
  - Título del placeholder móvil (ej: `ordersTodayMobileTitle`).
  - Descripción del placeholder móvil (ej: `ordersTodayMobileDescription`).
- **Restricción de serie vacía**: La validación de serie vacía al guardar ya
  existe en `InvoiceSeriesSection._save()`. Mantenerla.
- **Estado: Listo para implementación**
