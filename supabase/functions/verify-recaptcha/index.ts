// Verificacion server-side de reCAPTCHA v2 Invisible -- recibe el token que el frontend obtuvo via
// grecaptcha.execute() y lo valida contra la API de Google usando la Secret Key, que SOLO vive aqui (como
// secreto de Supabase, nunca en el repo ni en ningun archivo que el navegador descargue). El frontend
// (app.js, intentarCredenciales/ejecutarVerificacionRecaptcha) llama a esta funcion sin JWT de usuario --
// corre ANTES de que exista una sesion, asi que se despliega con --no-verify-jwt.
// Ver requerimiento "Auditoria Integral de Seguridad", Fase 1, punto 1 (CORS): antes reflejaba "*" -- cualquier
// sitio (p.ej. un phishing clonando el login) podia llamar este endpoint desde el navegador de una victima y
// leer la respuesta. Se restringe a los origenes reales de esta plataforma + puertos locales de desarrollo
// habituales -- cualquier otro origen sigue pudiendo invocar el endpoint (Origin no es informacion secreta,
// el ataque real es que el NAVEGADOR de un tercero pueda LEER la respuesta), pero el navegador bloquea la
// lectura de la respuesta porque Access-Control-Allow-Origin no coincide con su origen.
const ALLOWED_ORIGINS = ["https://melonn-fleet.onrender.com"];
function isAllowedOrigin(origin: string): boolean {
  if (ALLOWED_ORIGINS.includes(origin)) return true;
  return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
}
function corsHeadersFor(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") || "";
  return {
    "Access-Control-Allow-Origin": isAllowedOrigin(origin) ? origin : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

Deno.serve(async (req: Request) => {
  const CORS_HEADERS = corsHeadersFor(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "method_not_allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const token = typeof body?.token === "string" ? body.token : "";
    if (!token) {
      return new Response(JSON.stringify({ success: false, error: "missing_token" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const secret = Deno.env.get("RECAPTCHA_SECRET_KEY") ?? "";
    const params = new URLSearchParams({ secret, response: token });
    const googleResp = await fetch("https://www.google.com/recaptcha/api/siteverify", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params.toString(),
    });
    const data = await googleResp.json();

    return new Response(
      JSON.stringify({
        success: data.success === true,
        score: typeof data.score === "number" ? data.score : null,
        action: typeof data.action === "string" ? data.action : null,
        errorCodes: data["error-codes"] ?? null,
      }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (_e) {
    return new Response(JSON.stringify({ success: false, error: "server_error" }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
