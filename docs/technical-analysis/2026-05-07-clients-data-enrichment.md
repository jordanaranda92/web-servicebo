# Technical Analysis: Enriquecimiento de datos de Clientes con Google Sheets

- **Fecha:** 2026-05-07
- **Identificador:** clients-data-enrichment
- **Fuente:** docs/functional-analysis/2026-05-07-clients-data-enrichment.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Extender la feature `clients` para que su repositorio obtenga datos de dos
  fuentes en paralelo (Factura Directa API + Google Sheets API) y los fusione
  por UUID.
- Crear un nuevo datasource en `core` para lectura de Google Sheets (Sheets API
  `spreadsheets.values.get`).
- Ampliar la entidad `Client` con 4 campos de enriquecimiento y añadir una
  entidad auxiliar `ClientCategory`.
- Introducir estado parcial en el cubit para soportar degradación funcional
  (Factura Directa OK + Sheets KO).
- Actualizar la UI (columnas de la tabla y filtro de búsqueda).
- Riesgo general estimado: **medio** — la lectura de Sheets API es nueva pero el
  patrón de integración con Google APIs ya existe en el proyecto.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first: `data/` → `domain/` → `presentation/`.
- State management con Cubit (flutter_bloc).
- DI con GetIt, módulos por feature en `lib/app/di/modules/`.
- Manejo de errores con `Either<Failure, T>` (fpdart).
- Excepciones tipadas en `core/error/exceptions.dart`, failures en
  `core/error/failure.dart`.

### Módulos relevantes

- `lib/features/clients/` — Feature target.
- `lib/features/settings/` — Provee `GoogleDriveConfig` (con `internoFolderId`),
  `SettingsRepository`, `GoogleDriveRemoteDataSource`.
- `lib/core/data/datasources/factura_directa_api_data_source.dart` — API de
  contactos.
- `lib/core/services/google_auth_service.dart` — Autenticación Google OAuth.

### Dependencias existentes

- `googleapis: ^14.0.0` — incluye `sheets/v4.dart`.
- `googleapis_auth: ^2.0.0` — `AutoRefreshingAuthClient`.
- Scope `SheetsApi.spreadsheetsScope` ya se solicita en el login de Google
  Drive.

### Restricciones

- No existe un datasource para lectura de celdas/valores de Google Sheets. Solo
  se usan Drive API (listado de carpetas y archivos) y Excel API (lectura local
  de xlsx).
- `GoogleDriveRemoteDataSource` sabe listar carpetas y spreadsheets, pero NO
  leer contenido de hojas.
- `internoFolderId` ya se persiste en `GoogleDriveConfig` → disponible para
  localizar el spreadsheet `configuracion`.

## 3) Objetivo técnico

- **Qué debe cambiar:** El flujo de carga de clientes debe incorporar una
  segunda fuente de datos (Google Sheets) y fusionar resultados.
- **Resultado técnico:** `ClientsRepositoryImpl.getClients()` devuelve una lista
  de `Client` enriquecidos. El cubit expone un estado que diferencia carga
  exitosa completa vs. parcial.
- **Limitaciones:** Solo lectura del sheet. No se introduce escritura. No se
  modifican otras features.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear un datasource de lectura de Google Sheets en `core/` (reutilizable),
inyectarlo en `ClientsRepositoryImpl` para leer las pestañas `clientes` y
`categorias_clientes` del spreadsheet `configuracion`, y fusionar con los datos
de Factura Directa.

### Componentes / módulos / servicios afectados

| Capa                           | Componente                                        | Cambio                                         |
| ------------------------------ | ------------------------------------------------- | ---------------------------------------------- |
| Core - Data                    | Nuevo: `GoogleSheetsDataSource` (interfaz + impl) | Lectura genérica de valores de un sheet        |
| Feature clients - Domain       | `Client` entity                                   | +4 campos de enriquecimiento                   |
| Feature clients - Domain       | Nuevo: `ClientCategory` entity                    | Modelo para categoría (id, name)               |
| Feature clients - Data         | `ClientDto`                                       | +4 campos, merge con datos del sheet           |
| Feature clients - Data         | Nuevo: `ClientSheetDto`                           | Parseo de fila del sheet `clientes`            |
| Feature clients - Data         | Nuevo: `ClientCategorySheetDto`                   | Parseo de fila del sheet `categorias_clientes` |
| Feature clients - Data         | `ClientsRepositoryImpl`                           | Nueva dependencia, lógica de merge             |
| Feature clients - Domain       | `ClientsRepository` (interfaz)                    | Sin cambio (sigue devolviendo `List<Client>`)  |
| Feature clients - Domain       | `GetClients` use case                             | Sin cambio                                     |
| Feature clients - Presentation | `ClientsState`                                    | Nuevo campo `warning` para error parcial       |
| Feature clients - Presentation | `ClientsCubit`                                    | Adaptar filtro (`title` + `fiscalId`)          |
| Feature clients - Presentation | `ClientsPage`                                     | Nuevas columnas, eliminar antiguas             |
| App - DI                       | `clients_module.dart`                             | Inyectar `GoogleSheetsDataSource`              |
| App - DI                       | `core_module.dart` o similar                      | Registrar `GoogleSheetsDataSource`             |

### Contratos e interfaces

**Nuevo: `GoogleSheetsDataSource`** (en `lib/core/data/datasources/`):

```dart
abstract class GoogleSheetsDataSource {
  /// Lee valores de un rango de un spreadsheet.
  /// [spreadsheetId] — ID del spreadsheet en Google Drive.
  /// [range] — Rango A1 notation, ej: "clientes!A3:G".
  /// Retorna lista de filas (cada fila es List<String>).
  Future<List<List<String>>> readRange(String spreadsheetId, String range);
}
```

**Entidad `Client` extendida:**

```dart
class Client extends Equatable {
  // Existentes (de Factura Directa)
  final String id;
  final String name;
  final String? title;
  final String? fiscalId;
  // ... (email, phone, country, city se mantienen internamente)
  
  // Nuevos (de Google Sheets)
  final bool? isActive;
  final String? categoryName;  // Nombre resuelto, no ID
  final bool? showInNewOrders;
  final int? orderInNewOrders;
}
```

**Nuevo: `ClientCategory`:**

```dart
class ClientCategory extends Equatable {
  final int id;
  final String name;
  final bool isActive;
}
```

### Flujo de datos o de control

```
ClientsCubit.loadClients()
  └─ GetClients(NoParams)
       └─ ClientsRepositoryImpl.getClients()
            ├─ [paralelo A] FacturaDirectaApiDataSource.getContacts()
            │    → List<Map<String, dynamic>> → List<ClientDto> → List<Client> (base)
            │
            └─ [paralelo B] _loadSheetData()
                 ├─ SettingsRepository.getGoogleDriveConfig()
                 │    → internoFolderId
                 ├─ GoogleDriveRemoteDataSource.listSpreadsheets(internoFolderId)
                 │    → Localizar spreadsheet "configuracion" por nombre
                 ├─ GoogleSheetsDataSource.readRange(spreadsheetId, "categorias_clientes!A3:D")
                 │    → Map<int, String> categoryMap (ID → nombre)
                 └─ GoogleSheetsDataSource.readRange(spreadsheetId, "clientes!A3:G")
                      → Map<String, ClientSheetDto> sheetMap (UUID → datos enriquecimiento)
            
            → Merge: por cada Client base, buscar UUID en sheetMap,
              resolver categoryId via categoryMap, construir Client enriquecido
            → Right(List<Client>)  // éxito completo
            → Right(List<Client>) + warning  // si Sheets falló (degradación)
```

### Gestión de errores y validaciones

| Escenario                                                      | Comportamiento                                               |
| -------------------------------------------------------------- | ------------------------------------------------------------ |
| Factura Directa falla                                          | `Left(Failure)` — error bloqueante (sin cambio)              |
| Google Drive no configurado (`internoFolderId == null`)        | Se devuelven clientes sin enriquecimiento. Se marca warning. |
| Spreadsheet `configuracion` no encontrado                      | Ídem — warning, datos parciales.                             |
| Pestaña `clientes` o `categorias_clientes` vacía o inexistente | Ídem — warning, datos parciales.                             |
| Error de red/auth al leer Sheets                               | Ídem — warning, datos parciales.                             |
| UUID del sheet no matchea ningún contacto                      | Fila del sheet ignorada.                                     |
| ID categoría no encontrado en mapa                             | `categoryName` = `null`.                                     |
| Valores no parseables en sheet                                 | Campo queda `null`.                                          |

Para soportar el warning, el repositorio devolverá un tipo que incluya tanto la
lista como un warning opcional:

```dart
// Opción: Wrapper para resultado con warning
class ClientsResult {
  final List<Client> clients;
  final String? sheetWarning;  // mensaje de aviso si Sheets falló
}
```

O alternativamente, se puede propagar el warning a través de un campo en
`ClientsLoaded` state.

**Decisión propuesta:** Modificar `ClientsRepository` para devolver
`Either<Failure, ClientsResult>` en lugar de `Either<Failure, List<Client>>`.
Esto es un cambio menor y permite propagar el warning sin romper el patrón.

### Consideraciones de compatibilidad o migración

- La interfaz `ClientsRepository` cambia su tipo de retorno. Esto impacta
  `GetClients` use case y `ClientsCubit`. El cambio es acotado a esta feature.
- La entidad `Client` se extiende con campos opcionales (`null` por defecto), lo
  que es backward compatible.
- No se eliminan campos existentes de `Client` (email, phone, country, city se
  mantienen aunque no se muestren en la tabla).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                       | Propósito                                               |
| --------------------------------------------------------------- | ------------------------------------------------------- |
| `lib/core/data/datasources/google_sheets_data_source.dart`      | Interfaz abstracta para lectura de Google Sheets        |
| `lib/core/data/datasources/google_sheets_data_source_impl.dart` | Implementación usando `googleapis` Sheets API           |
| `lib/features/clients/domain/entities/client_category.dart`     | Entidad para categoría de cliente                       |
| `lib/features/clients/domain/entities/clients_result.dart`      | Wrapper para resultado con warning                      |
| `lib/features/clients/data/dto/client_sheet_dto.dart`           | DTO para parseo de fila del sheet `clientes`            |
| `lib/features/clients/data/dto/client_category_sheet_dto.dart`  | DTO para parseo de fila del sheet `categorias_clientes` |

### Artefactos a modificar

| Artefacto                                                             | Cambio esperado                                                                                                                                                               |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/domain/entities/client.dart`                    | Añadir 4 campos: `isActive`, `categoryName`, `showInNewOrders`, `orderInNewOrders`                                                                                            |
| `lib/features/clients/data/dto/client_dto.dart`                       | Añadir método `toEnrichedEntity()` o extender `toEntity()` con parámetros opcionales de enriquecimiento                                                                       |
| `lib/features/clients/domain/repositories/clients_repository.dart`    | Cambiar retorno a `Either<Failure, ClientsResult>`                                                                                                                            |
| `lib/features/clients/data/repositories/clients_repository_impl.dart` | Añadir dependencia de `GoogleSheetsDataSource`, `GoogleDriveRemoteDataSource`, `SettingsRepository` (GDrive config). Implementar lógica de merge                              |
| `lib/features/clients/domain/usecases/get_clients.dart`               | Adaptar tipo de retorno a `ClientsResult`                                                                                                                                     |
| `lib/features/clients/presentation/bloc/clients_state.dart`           | Añadir campo `sheetWarning` a `ClientsLoaded`                                                                                                                                 |
| `lib/features/clients/presentation/bloc/clients_cubit.dart`           | Adaptar mapeo de resultado, adaptar `filterByName()` para filtrar por `title` y `fiscalId`                                                                                    |
| `lib/features/clients/presentation/pages/clients_page.dart`           | Reemplazar columnas de la tabla (NIF/CIF, Nombre, Activo, Categoría, Mostrar en nuevos pedidos, Orden en nuevos pedidos). Mostrar banner de warning si `sheetWarning != null` |
| `lib/app/di/modules/clients_module.dart`                              | Registrar `GoogleSheetsDataSource`, pasar nuevas dependencias a `ClientsRepositoryImpl`                                                                                       |
| `lib/app/di/injection.dart` o módulo core                             | Registrar `GoogleSheetsDataSourceImpl` si se centraliza en core                                                                                                               |

### Artefactos a retirar o reemplazar

Ninguno. Solo se sustituyen las columnas visibles en la UI, no se eliminan
archivos.

## 6) Estrategia de implementación

1. **Paso 1 — Datasource Google Sheets (core)** Crear `GoogleSheetsDataSource`
   (interfaz) y `GoogleSheetsDataSourceImpl` (impl con `googleapis` Sheets API
   v4). Método `readRange(spreadsheetId, range)` → `List<List<String>>`.

2. **Paso 2 — Entidades de dominio** Extender `Client` con los 4 campos
   opcionales. Crear `ClientCategory` y `ClientsResult`.

3. **Paso 3 — DTOs de sheet** Crear `ClientSheetDto` (parsea una fila de la
   pestaña `clientes` identificando columnas por cabecera) y
   `ClientCategorySheetDto` (parsea una fila de `categorias_clientes`).

4. **Paso 4 — Interfaz del repositorio** Cambiar
   `ClientsRepository.getClients()` → `Future<Either<Failure, ClientsResult>>`.

5. **Paso 5 — Implementación del repositorio** Modificar
   `ClientsRepositoryImpl`: añadir dependencias, implementar lectura paralela,
   merge, resolución de categorías, manejo de degradación.

6. **Paso 6 — Use case** Adaptar `GetClients` al nuevo tipo de retorno.

7. **Paso 7 — State y Cubit** Añadir `sheetWarning` a `ClientsLoaded`. Adaptar
   cubit para propagar warning y ajustar filtro de búsqueda.

8. **Paso 8 — UI (ClientsPage)** Reemplazar columnas de la tabla. Añadir banner
   de warning opcional. Adaptar buscador.

9. **Paso 9 — DI** Registrar `GoogleSheetsDataSourceImpl` en el contenedor.
   Actualizar `ClientsRepositoryImpl` constructor y su registro.

10. **Paso 10 — Tests** Tests unitarios para: `GoogleSheetsDataSourceImpl`,
    DTOs, lógica de merge en repositorio, cubit (estado parcial/completo),
    filtro.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

### Dependencias entre pasos

- Paso 5 depende de 1, 2, 3 y 4.
- Pasos 6, 7, 8 dependen de 4.
- Paso 9 depende de 1 y 5.
- Paso 10 puede ir en paralelo con pasos 7-9 (tests de capas inferiores).

### Puntos delicados

- **Localización del spreadsheet `configuracion`:** Se debe buscar por nombre en
  la carpeta `internal/`. Si hay varios spreadsheets con ese nombre, tomar el
  primero. Usar `GoogleDriveRemoteDataSource.listSpreadsheets(internoFolderId)`
  que ya existe.
- **Identificación de columnas por cabecera (EC-07):** Los DTOs de sheet deben
  parsear la fila de cabecera para construir un mapa columna→índice, no asumir
  posiciones fijas.
- **Cambio en el contrato del repositorio:** Impacta use case, cubit y tests
  existentes. Debe hacerse de forma coordinada.

## 7) Estrategia de validación

### Tests automáticos (unitarios)

- **`GoogleSheetsDataSourceImpl`**: mock de `SheetsApi`, verificar que se llama
  con el range correcto y se parsean los valores.
- **`ClientSheetDto`**: parseo de filas con datos completos, parciales, vacíos,
  valores inesperados.
- **`ClientCategorySheetDto`**: parseo de filas de categorías.
- **`ClientsRepositoryImpl`**: mock de ambos datasources y `SettingsRepository`:
  - Caso éxito total (ambas fuentes OK).
  - Caso degradación (Factura Directa OK, Sheets KO → warning).
  - Caso error total (Factura Directa KO).
  - Merge correcto por UUID.
  - Resolución de categoría ID→nombre.
  - Contactos sin match en sheet.
  - Filas de sheet sin match en Factura Directa.
- **`ClientsCubit`**: emisión de estados con y sin warning, filtro por
  `title`/`fiscalId`.

### Validación manual

- Verificar que la tabla muestra las 6 columnas correctas.
- Verificar degradación: desconectar Google Drive y verificar que se muestran
  clientes sin enriquecimiento con aviso.
- Verificar que el buscador filtra por nombre y NIF/CIF.
- Verificar que la categoría se muestra como nombre (no como ID numérico).

### Escenarios a cubrir

- Google Drive configurado y spreadsheet accesible → datos completos.
- Google Drive configurado pero spreadsheet `configuracion` no existe →
  degradación.
- Google Drive no configurado → degradación.
- Spreadsheet existe pero pestaña `clientes` vacía → degradación silenciosa.
- Pestaña `categorias_clientes` vacía → columna categoría vacía.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                                 | Probabilidad                                        | Impacto                        |
| -------------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------ |
| La Sheets API requiere scopes adicionales no solicitados                               | Baja (ya se solicita `SheetsApi.spreadsheetsScope`) | Medio                          |
| El UUID en el sheet no coincide con el formato del `uuid` de la API de Factura Directa | Media                                               | Alto — el merge no funcionaría |
| Tiempo de carga percibido aumenta significativamente                                   | Baja (llamadas en paralelo)                         | Bajo                           |
| Cambio en contrato del repositorio rompe tests existentes                              | Segura                                              | Bajo (cambio mecánico)         |

### Impacto potencial

- Feature `clients` cambia de una fuente de datos a dos fuentes.
- El contrato del repositorio cambia, afectando use case y cubit (scope acotado
  a la feature).
- Se introduce un nuevo datasource en `core/` que puede reutilizarse en otras
  features.

### Mitigación

- Verificar formato del UUID del sheet vs. API antes de implementar el merge
  (validación en paso 5).
- Las llamadas al sheet se hacen en paralelo con Factura Directa para minimizar
  impacto en tiempo de carga.
- Degradación funcional garantiza que si Sheets falla, la pantalla sigue
  operativa.

### Plan de rollback

- Revertir `ClientsRepositoryImpl` a su versión anterior (solo Factura Directa).
- Revertir `ClientsRepository` interfaz al tipo de retorno `List<Client>`.
- El datasource `GoogleSheetsDataSource` puede quedarse en core sin impacto.
- Cambios en UI (columnas) se revertirían junto con la lógica.

## 9) Suposiciones

- **S-01:** El scope `SheetsApi.spreadsheetsScope` ya solicitado en el login es
  suficiente para leer valores del spreadsheet con `spreadsheets.values.get`.
- **S-02:** El `internoFolderId` persiste correctamente y es accesible desde
  `SettingsRepository.getGoogleDriveConfig()`.
- **S-03:** `GoogleDriveRemoteDataSource.listSpreadsheets(folderId)` devuelve
  spreadsheets nativos de Google Sheets, y el `DriveFileInfo.id` sirve como
  `spreadsheetId` para la Sheets API.
- **S-04:** El `uuid` devuelto por la API de Factura Directa en `content.uuid`
  tiene el mismo formato que la columna UUID del sheet (ej:
  `con_4ba57cf7-469d-4df5-afd1-7721066df1fd`).

## 10) Preguntas abiertas

Ninguna.

## 11) Notas para implementación

- **No eliminar campos existentes de `Client`** (email, phone, country, city).
  Solo dejan de mostrarse en la tabla, pero podrían usarse en otros contextos.
- **La lectura de Sheets debe ser robusta**: si `readRange` devuelve filas con
  menos columnas de las esperadas, rellenar con `null`. No lanzar excepciones
  por datos parciales.
- **Identificar columnas por cabecera** (fila 3 del sheet), no por posición
  fija. Esto protege contra reordenación de columnas por parte del usuario.
- **El `GoogleSheetsDataSource` se ubica en `core/`** porque es un datasource
  genérico reutilizable, igual que `FacturaDirectaApiDataSource`.
- **Secuencia sugerida:** Implementar primero el datasource + entidades (pasos
  1-3), luego integrar en repositorio (pasos 4-5), y finalmente adaptar
  presentación (pasos 6-8). DI y tests al final.
- **No romper el flujo existente:** La carpeta `internal/` y la config de Google
  Drive pueden no estar disponibles. Todo el código de enriquecimiento debe ser
  tolerante a fallos y no bloquear la carga de Factura Directa.
- **Estado: Listo para implementación**
