// Fase 2 de Seguridad, Etapa A ("mecanismo de token, sin tocar RLS todavia"): sustituye el actual
// localStorage.melonn_session (hoy un simple id de usuario en texto plano, trivialmente forjable --
// cualquiera puede escribir el id de OTRO usuario en su propio navegador y suplantarlo, porque nada lo
// verifica criptograficamente) por un JWT HS256 firmado server-side, verificable solo aqui (el secreto de
// firma -- APP_JWT_SECRET -- vive EXCLUSIVAMENTE como secreto de Supabase, nunca en el repo ni en ningun
// archivo que el navegador descargue).
//
// Tres acciones:
//   - "mint": recibe email+password, los verifica contra app_users con la SERVICE ROLE KEY (bypassa RLS
//     a proposito -- esta funcion es la unica autoridad real sobre "quien es quien"), y si son validos
//     firma un token nuevo. Se llama SOLO en los 3 momentos reales de prueba de credenciales frescas del
//     frontend (login normal, cambio obligatorio de primer ingreso, restablecimiento via enlace de
//     recuperacion) -- nunca reemplaza esa logica de negocio existente (lockouts, mustChangePassword,
//     multirol, etc., que siguen viviendo intactos en app.js), solo añade una prueba criptografica encima.
//     El token de "mint" NUNCA lleva el rol todavia -- ver "mint_with_role" abajo.
//   - "mint_with_role" (Fase 2, Etapa C): recibe un token YA VALIDO (emitido por "mint"/"verify") + el rol
//     que el usuario eligio operar (app.js ya decide esto -- login de un solo rol, o seleccion explicita
//     en el modal multirol/cambio en caliente). Verifica la firma+expiracion del token entrante, vuelve a
//     leer el registro FRESCO del usuario con la SERVICE ROLE KEY, confirma que `role` esta realmente en
//     user.roles (un cliente no puede pedir un rol que no tiene, aunque edite el payload de su propio
//     token -- la respuesta la decide esta funcion, no lo que el cliente mande), y firma un token NUEVO con
//     el rol + bodegaId/aliadoId segun corresponda (mismo criterio exacto que Auth.setCurrentUser en
//     app.js: bodegaId solo si role==='BODEGA', aliadoId solo si role==='ALIADO'). Este es el token que las
//     politicas RLS de tablas con scoping real (ver app_users) pueden leer via auth.jwt()->>'app_role'.
//   - "verify": recibe un token ya emitido (lo que el navegador guarda en localStorage) y, si la firma y
//     la expiracion son validas, vuelve a leer el registro FRESCO del usuario desde app_users (asi una
//     cuenta desactivada o editada despues de emitido el token deja de poder restaurar sesion de
//     inmediato, sin esperar a que el token expire). Reemplaza el `state.users.find(id => savedId)` que
//     hoy confia ciegamente en lo que haya en memoria/localStorage.
//
// IMPORTANTE (a proposito, Etapa A/B): el token emitido por "mint" NO se adjunta a ninguna llamada a
// PostgREST hasta que el rol real se conoce -- el rol `authenticated` solo tiene GRANT sobre las tablas que
// ya pasaron por su propia migracion de RLS (ver Etapa B: app_config_settings; Etapa C: app_users), nunca
// sobre las demas todavia.
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

// ---- Verificacion de contraseña: MISMO esquema que verifyPassword/isPasswordHashed en app.js (SHA-256 +
// salt, formato "sha256$<saltHex>$<hashHex>"), portado tal cual -- crypto.subtle es la misma Web Crypto API
// en el navegador y en Deno. Retrocompatible con cuentas que aun no hayan hecho login desde el deploy de
// hashing (texto plano legado) -- mismo criterio que el cliente, nunca bloquea un acceso valido. ----
const PASSWORD_HASH_PREFIX = "sha256$";
function isPasswordHashed(stored: string): boolean {
  return typeof stored === "string" && stored.indexOf(PASSWORD_HASH_PREFIX) === 0;
}
async function sha256Hex(texto: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(texto));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function verifyPassword(stored: string, plano: string): Promise<boolean> {
  if (!isPasswordHashed(stored)) return stored === plano;
  const partes = stored.split("$"); // ['sha256', saltHex, hashHex]
  const hash = await sha256Hex(partes[1] + ":" + plano);
  return hash === partes[2];
}

// ---- JWT HS256 minimo, sin dependencias externas (mismo criterio de "cero dependencias nuevas" que el
// resto de la plataforma) -- header.payload.firma, todo base64url, firmado con HMAC-SHA256. ----
function base64url(bytes: Uint8Array): string {
  let bin = "";
  bytes.forEach((b) => (bin += String.fromCharCode(b)));
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function base64urlJson(obj: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(obj)));
}
function base64urlDecodeToBytes(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((b64url.length + 3) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}
async function signSessionJwt(payload: Record<string, unknown>, secret: string): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const unsigned = base64urlJson(header) + "." + base64urlJson(payload);
  const key = await hmacKey(secret);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(unsigned));
  return unsigned + "." + base64url(new Uint8Array(sig));
}
async function verifySessionJwt(token: string, secret: string): Promise<Record<string, unknown> | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [headerB64, payloadB64, sigB64] = parts;
  const key = await hmacKey(secret);
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    base64urlDecodeToBytes(sigB64),
    new TextEncoder().encode(headerB64 + "." + payloadB64),
  );
  if (!valid) return null;
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(new TextDecoder().decode(base64urlDecodeToBytes(payloadB64)));
  } catch (_e) {
    return null;
  }
  if (typeof payload.exp !== "number" || Date.now() / 1000 >= payload.exp) return null;
  return payload;
}

// Mismo tiempo de vida que un turno completo de operacion (ver plan: "cubre un turno completo" sin
// obligar a re-loguearse a mitad de jornada).
const SESSION_TTL_SECONDS = 12 * 60 * 60;

function sanitizeUser(u: Record<string, unknown>): Record<string, unknown> {
  const { password: _password, recoveryToken: _rt, recoveryTokenExpiraEn: _rte, ...rest } = u;
  return rest;
}

Deno.serve(async (req: Request) => {
  const CORS_HEADERS = corsHeadersFor(req);
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: false, error: "method_not_allowed" }), {
      status: 405, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const jsonHeaders = { ...CORS_HEADERS, "Content-Type": "application/json" };
  const secret = Deno.env.get("APP_JWT_SECRET") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!secret || !supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ ok: false, error: "server_misconfigured" }), {
      status: 500, headers: jsonHeaders,
    });
  }

  try {
    const body = await req.json();
    const action = typeof body?.action === "string" ? body.action : "";

    if (action === "mint") {
      const email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
      const password = typeof body?.password === "string" ? body.password : "";
      if (!email || !password) {
        return new Response(JSON.stringify({ ok: false, error: "missing_credentials" }), { status: 400, headers: jsonHeaders });
      }
      const resp = await fetch(`${supabaseUrl}/rest/v1/app_users?select=data&limit=1000`, {
        headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` },
      });
      if (!resp.ok) {
        const detail = await resp.text().catch(() => "");
        return new Response(JSON.stringify({ ok: false, error: "lookup_failed", status: resp.status, detail }), { status: 502, headers: jsonHeaders });
      }
      const rows = (await resp.json()) as Array<{ data: Record<string, unknown> }>;
      const user = rows.map((r) => r.data).find((u) => typeof u.email === "string" && (u.email as string).toLowerCase() === email);
      if (!user || !user.activo) {
        return new Response(JSON.stringify({ ok: false, error: "invalid_credentials" }), { status: 401, headers: jsonHeaders });
      }
      const passwordOk = await verifyPassword(String(user.password ?? ""), password);
      if (!passwordOk) {
        return new Response(JSON.stringify({ ok: false, error: "invalid_credentials" }), { status: 401, headers: jsonHeaders });
      }
      const now = Math.floor(Date.now() / 1000);
      const token = await signSessionJwt({ sub: user.id, role: "authenticated", iat: now, exp: now + SESSION_TTL_SECONDS }, secret);
      return new Response(JSON.stringify({ ok: true, token, user: sanitizeUser(user) }), { headers: jsonHeaders });
    }

    if (action === "verify" || action === "mint_with_role") {
      const token = typeof body?.token === "string" ? body.token : "";
      if (!token) {
        return new Response(JSON.stringify({ ok: false, error: "missing_token" }), { status: 400, headers: jsonHeaders });
      }
      const payload = await verifySessionJwt(token, secret);
      if (!payload || typeof payload.sub !== "string") {
        return new Response(JSON.stringify({ ok: false, error: "invalid_token" }), { status: 401, headers: jsonHeaders });
      }
      const resp = await fetch(`${supabaseUrl}/rest/v1/app_users?select=data&id=eq.${encodeURIComponent(payload.sub)}&limit=1`, {
        headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` },
      });
      if (!resp.ok) {
        return new Response(JSON.stringify({ ok: false, error: "lookup_failed" }), { status: 502, headers: jsonHeaders });
      }
      const rows = (await resp.json()) as Array<{ data: Record<string, unknown> }>;
      const user = rows[0]?.data;
      if (!user || !user.activo) {
        return new Response(JSON.stringify({ ok: false, error: "inactive_or_missing" }), { status: 401, headers: jsonHeaders });
      }

      if (action === "mint_with_role") {
        const roleSolicitado = typeof body?.role === "string" ? body.role : "";
        const rolesReales = Array.isArray(user.roles) ? (user.roles as unknown[]) : [];
        /* El cliente NUNCA decide por si solo -- roleSolicitado tiene que estar realmente en user.roles,
           releido fresco con service role en esta misma llamada (nunca lo que el cliente afirme). Un
           intento de pedir un rol que no tiene queda rechazado aqui, no en el navegador. */
        if (!roleSolicitado || rolesReales.indexOf(roleSolicitado) === -1) {
          return new Response(JSON.stringify({ ok: false, error: "role_not_allowed" }), { status: 403, headers: jsonHeaders });
        }
        const now = Math.floor(Date.now() / 1000);
        const nuevoToken = await signSessionJwt({
          sub: user.id,
          role: "authenticated",
          app_role: roleSolicitado,
          bodegaId: roleSolicitado === "BODEGA" ? (user.sede ?? null) : null,
          aliadoId: roleSolicitado === "ALIADO" ? (user.aliado ?? null) : null,
          iat: now,
          exp: now + SESSION_TTL_SECONDS,
        }, secret);
        return new Response(JSON.stringify({ ok: true, token: nuevoToken, user: sanitizeUser(user) }), { headers: jsonHeaders });
      }

      return new Response(JSON.stringify({ ok: true, user: sanitizeUser(user) }), { headers: jsonHeaders });
    }

    return new Response(JSON.stringify({ ok: false, error: "unknown_action" }), { status: 400, headers: jsonHeaders });
  } catch (_e) {
    return new Response(JSON.stringify({ ok: false, error: "server_error" }), { status: 500, headers: jsonHeaders });
  }
});
