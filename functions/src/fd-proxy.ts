import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

const fdApiToken = defineSecret("FD_API_TOKEN");
const FD_BASE_URL = "https://app.facturadirecta.com/api";

// Company ID autorizado
const ALLOWED_COMPANY_ID =
  "com_ba5a008b-d08a-4de7-9144-aa073248b267";

// Whitelist de paths permitidos (prefijos).
// Solo estos endpoints de la API de FD son accesibles a través del proxy.
const ALLOWED_PATH_PREFIXES = [
  "/contacts",
  "/products",
  "/invoices",
];

export const fdProxy = onCall(
  {secrets: [fdApiToken], region: "europe-west1", invoker: "public"},
  async (request) => {
    // 1. Verificar autenticación
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Autenticación requerida",
      );
    }

    const {
      path,
      method = "GET",
      body,
      queryParameters,
    } = request.data;

    // 2. Validar path — tipo y formato
    if (!path || typeof path !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Se requiere 'path'",
      );
    }

    // 3. Sanitizar path — bloquear traversal y caracteres peligrosos
    if (
      path.includes("..") ||
      path.includes("//") ||
      path.includes("\\") ||
      path.includes("\0") ||
      path.length > 200
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Path inválido",
      );
    }

    // 4. Validar path contra whitelist de endpoints permitidos
    const normalizedPath = path.startsWith("/") ? path : `/${path}`;
    const isAllowed = ALLOWED_PATH_PREFIXES.some((prefix) =>
      normalizedPath === prefix ||
      normalizedPath.startsWith(`${prefix}/`) ||
      normalizedPath.startsWith(`${prefix}?`),
    );
    if (!isAllowed) {
      throw new HttpsError(
        "invalid-argument",
        "Path no permitido",
      );
    }

    // 5. Inyectar company ID (siempre — el cliente nunca envía company ID)
    const resolvedPath =
      `/${ALLOWED_COMPANY_ID}${normalizedPath}`;

    // 6. Validar método
    const httpMethod = (method as string).toUpperCase();
    if (!["GET", "POST"].includes(httpMethod)) {
      throw new HttpsError(
        "invalid-argument",
        "Método no soportado",
      );
    }

    // 7. Construir URL con query parameters
    const url = new URL(`${FD_BASE_URL}${resolvedPath}`);
    if (
      queryParameters &&
      typeof queryParameters === "object"
    ) {
      for (const [key, value] of
        Object.entries(queryParameters)) {
        url.searchParams.append(key, String(value));
      }
    }

    // 8. Llamar a FacturaDirecta
    try {
      const fetchOptions: RequestInit = {
        method: httpMethod,
        headers: {
          "facturadirecta-api-key": fdApiToken.value(),
          "Content-Type": "application/json",
        },
      };

      if (httpMethod === "POST" && body) {
        fetchOptions.body = JSON.stringify(body);
      }

      const response = await fetch(
        url.toString(),
        fetchOptions,
      );
      const data = await response.json();

      if (!response.ok) {
        throw new HttpsError(
          "internal",
          `FD respondió ${response.status}`,
          data,
        );
      }

      return data;
    } catch (error: unknown) {
      if (error instanceof HttpsError) throw error;
      const msg = error instanceof Error ?
        error.message : "Error desconocido";
      throw new HttpsError(
        "internal",
        `Error al llamar a FD: ${msg}`,
      );
    }
  },
);
