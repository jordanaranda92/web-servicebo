# Technical Analysis: Carga unificada y búsqueda multi-campo en pantalla de clientes

- **Fecha:** 2026-05-11
- **Identificador:** clients-unified-load-and-search
- **Fuente:**
  docs/functional-analysis/2026-05-11-clients-unified-load-and-search.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

El cambio consiste en mover la carga de NIF/CIF (`GetFdFiscalIds`) desde el
widget `_ClientsPageState` al `ClientsCubit`, integrándolo en el state
(`ClientsState`) para que la tabla no se renderice hasta que ambas fuentes de
datos estén disponibles. El filtrado (`_applyFilter`) se amplía para buscar por
NIF/CIF, nombre y nombre Factura Directa usando el mapa de fiscal IDs que pasa a
residir en el state.

- **Áreas impactadas:** `ClientsCubit`, `ClientsState`, `ClientsPage`, DI module
- **Riesgo general:** Bajo — los cambios se concentran en la capa de
  presentación y no afectan modelos de Firestore ni contratos de dominio
  existentes

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC/Cubit, GetIt para DI y fpdart para
Either.

### Módulos relevantes

- `lib/features/clients/presentation/bloc/clients_cubit.dart` — lógica de estado
- `lib/features/clients/presentation/bloc/clients_state.dart` — clases de estado
- `lib/features/clients/presentation/pages/clients_page.dart` — UI
- `lib/features/clients/domain/usecases/get_fd_fiscal_ids.dart` — use case que
  obtiene UUID→fiscalId desde la API de FD
- `lib/app/di/modules/clients_module.dart` — registro de dependencias

### Flujo actual (problema)

1. `initState()` llama a `_cubit.watchClientsStream()` → emite `ClientsLoading`
   → luego `ClientsLoaded` cuando Firestore responde.
2. `initState()` también llama a `_loadFiscalIds()` que invoca `GetFdFiscalIds`
   y guarda el resultado en `_fiscalIdsByUuid` (variable local del widget) con
   `setState()`.
3. La tabla se renderiza cuando el cubit emite `ClientsLoaded` (paso 1), pero
   los fiscal IDs llegan después (paso 2) → se produce el "salto" visual.
4. El filtro `_applyFilter` solo busca por `c.name`.

### Restricciones

- **No modificar el modelo de Firestore** — los NIF/CIF no se persisten, se
  resuelven en caliente desde la API de FD.
- Los use cases de dominio (`GetFdFiscalIds`, `WatchClients`) no cambian su
  contrato.

## 3) Objetivo técnico

- Centralizar el mapa `fiscalIdsByUuid` en el `ClientsCubit`/`ClientsState` en
  lugar de tenerlo como variable local del widget.
- Coordinar la primera emisión de `ClientsLoaded` para que solo ocurra cuando
  tanto el stream de Firestore como la carga de fiscal IDs estén listos.
- Ampliar `_applyFilter` para buscar por NIF/CIF, nombre y nombre FD.
- Eliminar la gestión de fiscal IDs del widget (`_getFdFiscalIds`,
  `_fiscalIdsByUuid`, `_loadFiscalIds()`).

## 4) Diseño técnico de la solución

### Enfoque propuesto

Mover la responsabilidad de carga de fiscal IDs al `ClientsCubit`. El cubit
coordinará dos fuentes:

1. **Stream de clientes** (Firestore via `WatchClients`) — continuo
2. **Future de fiscal IDs** (API FD via `GetFdFiscalIds`) — one-shot al iniciar,
   recargable tras sync

El cubit mantendrá internamente el mapa de fiscal IDs cargado y no emitirá
`ClientsLoaded` hasta que ambas fuentes hayan respondido al menos una vez. Tras
ello, actualizaciones del stream de Firestore re-emiten `ClientsLoaded` con el
mapa de fiscal IDs ya en memoria.

### Componentes / módulos / servicios afectados

| Componente                            | Tipo de cambio                                                                                              |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `ClientsState` (`clients_state.dart`) | Añadir campo `fiscalIdsByUuid` a `ClientsLoaded`                                                            |
| `ClientsCubit` (`clients_cubit.dart`) | Añadir dependencia `GetFdFiscalIds`, coordinar carga, ampliar filtro                                        |
| `ClientsPage` (`clients_page.dart`)   | Eliminar `_getFdFiscalIds`, `_fiscalIdsByUuid`, `_loadFiscalIds()`; leer fiscal IDs desde el state del BLoC |
| `clients_module.dart`                 | Añadir `GetFdFiscalIds` como parámetro del `ClientsCubit`                                                   |

### Contratos e interfaces

No se modifican contratos de dominio (repositorios, use cases, entities). Los
cambios son internos a la capa de presentación + ajuste de DI.

**Cambio en `ClientsLoaded`:**

```dart
class ClientsLoaded extends ClientsState {
  final List<Client> allClients;
  final List<Client> filteredClients;
  final String nameFilter;
  final bool isSaving;
  final bool isSyncing;
  final Map<String, String> fiscalIdsByUuid; // NUEVO

  const ClientsLoaded({
    required this.allClients,
    required this.filteredClients,
    this.nameFilter = '',
    this.isSaving = false,
    this.isSyncing = false,
    this.fiscalIdsByUuid = const {}, // NUEVO
  });
}
```

### Flujo de datos o de control

```
initState() → cubit.watchClientsStream()
                ├─ 1. GetFdFiscalIds() → Future<Map<String,String>>
                └─ 2. WatchClients()   → Stream<List<Client>>

Internamente el cubit:
  - Almacena _fiscalIdsByUuid (variable interna)
  - Almacena _pendingFiscalIds = true (flag)
  - Lanza GetFdFiscalIds en paralelo con la suscripción al stream
  - Cuando el stream emite y _pendingFiscalIds == true → no emite ClientsLoaded, guarda los clients en buffer
  - Cuando GetFdFiscalIds completa:
    - _pendingFiscalIds = false
    - Si hay clients buffereados → emite ClientsLoaded con fiscalIds
  - Cuando el stream emite y _pendingFiscalIds == false → emite ClientsLoaded normalmente con fiscalIds ya en memoria
  - Si GetFdFiscalIds falla → _pendingFiscalIds = false con mapa vacío (degradación graceful) → emite lo que haya buffereado
```

### Flujo de filtrado

```
_applyFilter(clients, fiscalIds):
  query = _currentFilter.trim().toLowerCase()
  if query.isEmpty → return clients
  return clients.where((c) {
    final fiscalId = fiscalIds[c.facturaDirectaUuid]?.toLowerCase() ?? '';
    return c.name.toLowerCase().contains(query)
        || c.facturaDirectaName.toLowerCase().contains(query)
        || fiscalId.contains(query);
  })
```

### Gestión de errores y validaciones

- **Error en `GetFdFiscalIds`:** Se trata como degradación graceful. El mapa
  queda vacío y la tabla se muestra con "—" en la columna NIF/CIF. No se bloquea
  la pantalla.
- **Error en stream de clientes (Firestore):** Comportamiento actual sin cambios
  → emite `ClientsError`.
- **Ambos fallan:** Se muestra `ClientsError` (el error de Firestore tiene
  prioridad porque sin clientes no hay tabla).

### Consideraciones de compatibilidad o migración

- Ninguna. El campo `fiscalIdsByUuid` tiene valor por defecto `const {}` en
  `ClientsLoaded`, lo que mantiene compatibilidad si algún otro código instancia
  ese state sin proveerlo.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto | Propósito                   |
| --------- | --------------------------- |
| Ninguno   | No se crean archivos nuevos |

### Artefactos a modificar

| Artefacto                                                   | Cambio esperado                                                                                                                                                                                                                                         |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/presentation/bloc/clients_state.dart` | Añadir `fiscalIdsByUuid` a `ClientsLoaded` + `props`                                                                                                                                                                                                    |
| `lib/features/clients/presentation/bloc/clients_cubit.dart` | Añadir dependencia `GetFdFiscalIds`, coordinar carga paralela, buffer de primera emisión, ampliar `_applyFilter`, exponer método `reloadFiscalIds` para post-sync                                                                                       |
| `lib/features/clients/presentation/pages/clients_page.dart` | Eliminar `_getFdFiscalIds`, `_fiscalIdsByUuid`, `_loadFiscalIds()`; leer fiscal IDs de `ClientsLoaded.fiscalIdsByUuid`; en `_buildRow` usar `state.fiscalIdsByUuid` en vez de `_fiscalIdsByUuid`; tras `_syncFromFd` llamar a `cubit.reloadFiscalIds()` |
| `lib/app/di/modules/clients_module.dart`                    | Añadir `sl<GetFdFiscalIds>()` como 6.º parámetro del factory de `ClientsCubit`                                                                                                                                                                          |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                       |
| --------- | ---------------------------- |
| Ninguno   | No se elimina ningún archivo |

## 6) Estrategia de implementación

### Pasos ordenados

1. **Modificar `ClientsState`:** Añadir campo `fiscalIdsByUuid` a
   `ClientsLoaded` con valor por defecto vacío. Incluirlo en `props`.

2. **Modificar `ClientsCubit`:**
   - Añadir dependencia `GetFdFiscalIds` al constructor.
   - Añadir variables internas `_fiscalIdsByUuid` (mapa) y `_pendingFiscalIds`
     (bool flag) y `_bufferedClients` (lista nullable).
   - En `watchClientsStream()`: lanzar `_loadFiscalIds()` en paralelo. Modificar
     el listener del stream para que no emita `ClientsLoaded` hasta que
     `_pendingFiscalIds == false`.
   - Crear método privado `_loadFiscalIds()` que invoca `GetFdFiscalIds`,
     actualiza `_fiscalIdsByUuid`, pone `_pendingFiscalIds = false`, y si hay
     `_bufferedClients` los emite.
   - Crear método público `reloadFiscalIds()` para recargar fiscal IDs tras una
     sincronización.
   - Modificar `_applyFilter` para recibir el mapa de fiscal IDs y buscar en los
     tres campos.
   - Actualizar `filterByName` para pasar el mapa al emitir.

3. **Actualizar DI (`clients_module.dart`):** Añadir `sl<GetFdFiscalIds>()` como
   parámetro al factory de `ClientsCubit`.

4. **Modificar `ClientsPage`:**
   - Eliminar import de `GetFdFiscalIds`.
   - Eliminar campo `_getFdFiscalIds` y `_fiscalIdsByUuid`.
   - Eliminar llamada a `_loadFiscalIds()` en `initState()`.
   - Eliminar método `_loadFiscalIds()`.
   - En `_buildRow`: obtener fiscal ID desde el state (`ClientsLoaded`) del BLoC
     en vez de la variable local.
   - Tras `_syncFromFd` exitoso: llamar a `_cubit.reloadFiscalIds()`.

### Orden recomendado

1 → 2 → 3 → 4 (secuencial, cada paso depende del anterior)

### Dependencias entre pasos

- Paso 2 depende de paso 1 (el state debe tener el campo antes de emitirlo)
- Paso 3 depende de paso 2 (el constructor del cubit debe aceptar el nuevo
  parámetro)
- Paso 4 depende de paso 2 y 3 (la página consume el nuevo campo del state)

### Puntos delicados

- **Coordinación stream + future:** El cubit debe bufferear la primera emisión
  del stream de Firestore si los fiscal IDs aún no están listos. Si el stream
  emite múltiples veces antes de que los fiscal IDs lleguen, solo el último
  batch de clientes debe buferearse (sobrescribir, no acumular).
- **Reactividad del stream:** Tras la primera carga, las actualizaciones del
  stream de Firestore deben emitir inmediatamente usando los fiscal IDs ya en
  memoria, sin re-llamar a la API.
- **Consistencia del filtro:** `filterByName` debe usar el mapa de fiscal IDs
  del state actual para filtrar. Si el state no es `ClientsLoaded`, no filtra
  (comportamiento actual).
- **Post-sync:** Tras `syncClients()`, los fiscal IDs pueden haber cambiado
  (nuevos clientes). `reloadFiscalIds()` debe re-llamar a `GetFdFiscalIds` y
  re-emitir el state con el mapa actualizado.

## 7) Estrategia de validación

### Verificación automática

- **Test unitario de `ClientsCubit`:**
  - Verificar que no emite `ClientsLoaded` hasta que tanto el stream como
    `GetFdFiscalIds` completen.
  - Verificar que si `GetFdFiscalIds` falla, emite `ClientsLoaded` con mapa
    vacío (degradación graceful).
  - Verificar que `filterByName` con un NIF/CIF devuelve el cliente correcto.
  - Verificar que `filterByName` con nombre FD devuelve el cliente correcto.
  - Verificar que `filterByName` con nombre devuelve el cliente correcto
    (regresión).
  - Verificar que `reloadFiscalIds()` actualiza el mapa y re-emite el state.

- **Test unitario de `_applyFilter`:** Verificar búsqueda case-insensitive,
  parcial y combinada por los tres campos.

### Verificación manual

- Abrir la pantalla de clientes y confirmar que se ve el spinner hasta que la
  tabla aparezca completa con NIF/CIF.
- Verificar que no hay "salto" en la columna NIF/CIF.
- Probar búsqueda por NIF/CIF, nombre y nombre FD.
- Simular fallo de red en la API de FD y confirmar que la tabla se muestra con
  "—" sin bloquear.
- Sincronizar desde FD y confirmar que los NIF/CIF de nuevos clientes aparecen
  correctamente.

### Escenarios a cubrir

- Carga exitosa de ambas fuentes
- Fallo de `GetFdFiscalIds` con éxito de Firestore (degradación graceful)
- Fallo de Firestore (error screen existente)
- Búsqueda por cada campo individualmente
- Búsqueda vacía (muestra todos)
- Búsqueda sin resultados
- Cliente sin UUID de FD (muestra "—", no rompe)
- Actualización del stream de Firestore tras carga inicial (no re-llama a API de
  FD)

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                            | Probabilidad | Impacto                                                     |
| --------------------------------------------------------------------------------- | ------------ | ----------------------------------------------------------- |
| La API de FD es lenta y retrasa la carga inicial                                  | Media        | Medio — mitigado con degradación graceful y timeout         |
| El stream emite antes de que los fiscal IDs lleguen y no se buferea correctamente | Baja         | Alto — la tabla no se mostraría o mostraría datos parciales |

### Impacto potencial

- **Positivo:** UX mejorada con tabla completa desde el inicio y búsqueda más
  potente.
- **Negativo mínimo:** Tiempo de carga inicial ligeramente mayor al esperar a
  ambas fuentes.

### Mitigación

- El mecanismo de degradación graceful asegura que si `GetFdFiscalIds` falla, la
  tabla se muestra igualmente con "—" en NIF/CIF (idéntico al comportamiento
  actual ante fallo).
- Considerar un timeout razonable (ya gestionado por el use case / HTTP client
  subyacente).

### Plan de rollback

- Revertir los 4 archivos modificados a su estado anterior. No hay migraciones
  de datos ni cambios en Firestore.
- Git revert del commit es suficiente.

## 9) Suposiciones

- El mapa UUID→fiscalId obtenido de FD es estable durante la sesión y no
  necesita recargarse en cada emisión del stream de Firestore (solo al iniciar y
  tras sync).
- El rendimiento de `GetFdFiscalIds` es aceptable para el volumen actual
  (~decenas/centenares de clientes).
- `ClientsCubit` se instancia como `Factory` (no singleton), por lo que el nuevo
  parámetro no afecta a otras instancias.

## 10) Preguntas abiertas

- Ninguna bloqueante. Las preguntas del análisis funcional (PA-01, PA-02) se
  resolvieron con los supuestos indicados: recargar solo al entrar y tras sync;
  mantener filtrado instantáneo sin debounce.

## 11) Notas para implementación

- Respetar la convención existente de nombrado: el método público se llamará
  `reloadFiscalIds()`, el campo del state `fiscalIdsByUuid`, consistente con la
  nomenclatura actual del widget.
- El método `filterByName` mantiene su nombre público por compatibilidad, aunque
  ahora filtra por múltiples campos. Opcionalmente podría renombrarse a
  `filterClients` — pero eso requeriría actualizar la llamada en la página, y no
  fue solicitado. Mantener `filterByName` es aceptable.
- No añadir import de `GetFdFiscalIds` en el cubit hasta que se confirme que el
  DI lo inyecta correctamente (paso 3 antes de paso 4 en la compilación).
- Cuidar que `_bufferedClients` se limpie tras emitir para evitar retención de
  memoria.
- En `_buildRow` de la página, el acceso a `fiscalIdsByUuid` requiere pasar el
  mapa como parámetro al método o acceder al state desde el `BlocBuilder` que ya
  envuelve la tabla. El patrón actual pasa datos por parámetro; conviene
  mantenerlo.
- **Estado: Listo para implementación**
