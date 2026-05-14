# Implementation Report: Cloud Function onUserCreated

- **Fecha:** 2026-05-14
- **Identificador:** on-user-created-trigger
- **Fuente:** Petición directa del usuario (sin análisis técnico formal previo)
- **Estado:** Completed

## 1) Resumen
- Se ha implementado una Cloud Function `onUserCreated` como trigger de Firebase Auth `onCreate`.
- Al dar de alta un usuario en Firebase Auth, se crea automáticamente un documento en `users/{uid}` con `userName` (parte local del email) y `role: "employee"`.
- La compilación TypeScript es exitosa sin errores.

## 2) Alcance ejecutado
- Creación de la Cloud Function trigger `onUserCreated`
- Registro del export en `index.ts`
- Validación de compilación

## 3) Artefactos tocados

### Creados
- `functions/src/on-user-created.ts`

### Modificados
- `functions/src/index.ts` (añadido export de `onUserCreated`)

### Retirados o reemplazados
- Ninguno

## 4) Validación ejecutada
- **Compilación TypeScript (`npm run build`):** ✅ Sin errores
- **Revisión de consistencia:** La función sigue el mismo patrón que `on-user-deleted.ts` (v1 auth trigger, región `europe-west1`, acceso a colección `users`)
- **Campos del documento:** `userName` y `role` coinciden con los campos que lee el datasource remoto de Flutter (`_fetchUserProfile`)
- **Pendiente:** Deploy a Firebase (`firebase deploy --only functions`) — requiere acción manual del usuario

## 5) Desviaciones respecto al análisis técnico
- No existía análisis técnico formal. La petición fue directa y acotada. Se usó como referencia el patrón existente en `on-user-deleted.ts` y la estructura de la colección `users` definida en el código Flutter.

## 6) Riesgos, incidencias y pendientes
- **Deploy:** La función debe desplegarse con `firebase deploy --only functions` para que esté activa en producción.
- **Usuarios existentes:** Los usuarios ya registrados en Auth que no tengan documento en `users` no se verán afectados por este trigger (solo aplica a nuevos registros). Si se necesita poblar documentos para usuarios existentes, sería necesario un script de migración aparte.
- **Reglas de Firestore:** Las reglas actuales ya bloquean `create` desde el cliente (`allow create: if false`), lo cual es coherente con que la creación se haga exclusivamente desde Cloud Functions con Admin SDK.

## 7) Resultado final
- Estado final: ✅ Completado
- Siguiente paso recomendado: deploy con `firebase deploy --only functions`
