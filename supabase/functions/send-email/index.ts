// Correo transaccional via la API HTTP de Resend (no SMTP -- esta app no usa Supabase Auth, asi que el
// SMTP configurado en el panel de Supabase nunca se dispara desde aqui; se llama a Resend directo). La
// RESEND_API_KEY SOLO vive como secreto de Supabase (Deno.env.get), nunca en el repo ni en ningun archivo
// que el navegador descargue. Corre ANTES/fuera de cualquier sesion de usuario (igual que verify-recaptcha),
// asi que se despliega con --no-verify-jwt.
//
// El HTML de cada correo se arma SERVER-SIDE segun "type" -- el cliente nunca manda HTML libre (evita
// inyeccion de contenido arbitrario en el correo enviado desde la cuenta de Resend de Melonn).
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const FROM = "melonn fleet <onboarding@resend.dev>";

function layout(title: string, bodyHtml: string): string {
  return `<!doctype html><html><body style="margin:0;padding:0;background:#f4f4f7;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:32px 16px;">
    <tr><td align="center">
      <table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;">
        <tr><td style="background:#14095B;padding:24px 32px;">
          <span style="color:#ffffff;font-size:20px;font-weight:800;">melonn fleet</span>
        </td></tr>
        <tr><td style="padding:32px;">
          <h2 style="margin:0 0 16px;color:#14095B;font-size:18px;">${title}</h2>
          ${bodyHtml}
        </td></tr>
        <tr><td style="padding:16px 32px;background:#f4f4f7;color:#888;font-size:11px;">
          Plataforma externa e independiente a Órbita, de acceso exclusivo para la gestión operativa de aliados y proveedores de mensajería.
        </td></tr>
      </table>
    </td></tr>
  </table>
  </body></html>`;
}

function buildEmail(type: string, data: Record<string, unknown>): { subject: string; html: string } | null {
  if (type === "recovery") {
    const nombre = String(data.nombre ?? "");
    const link = String(data.link ?? "");
    return {
      subject: "Recuperación de contraseña — melonn fleet",
      html: layout(
        "Recuperación de contraseña",
        `<p style="color:#333;font-size:14px;line-height:1.5;">Hola ${nombre},</p>
         <p style="color:#333;font-size:14px;line-height:1.5;">Recibimos una solicitud para restablecer tu contraseña en melonn fleet. Usa el siguiente enlace para definir una nueva:</p>
         <p style="text-align:center;margin:24px 0;"><a href="${link}" style="background:#14095B;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:700;font-size:14px;">Restablecer contraseña</a></p>
         <p style="color:#888;font-size:12px;">Este enlace vence en 24 horas. Si no solicitaste este cambio, ignora este correo.</p>`
      ),
    };
  }
  if (type === "invitation") {
    const nombre = String(data.nombre ?? "");
    const email = String(data.email ?? "");
    const tempPassword = String(data.tempPassword ?? "");
    const link = String(data.link ?? "https://melonn-fleet.onrender.com");
    return {
      subject: "Tu acceso a melonn fleet está listo",
      html: layout(
        "Bienvenido a melonn fleet",
        `<p style="color:#333;font-size:14px;line-height:1.5;">Hola ${nombre},</p>
         <p style="color:#333;font-size:14px;line-height:1.5;">Se creó tu cuenta en melonn fleet. Estos son tus datos de acceso:</p>
         <p style="color:#333;font-size:14px;line-height:1.5;"><strong>Correo:</strong> ${email}<br><strong>Contraseña temporal:</strong> ${tempPassword}</p>
         <p style="color:#333;font-size:14px;line-height:1.5;">Se te pedirá definir una contraseña nueva en tu primer inicio de sesión.</p>
         <p style="text-align:center;margin:24px 0;"><a href="${link}" style="background:#14095B;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:700;font-size:14px;">Ir a melonn fleet</a></p>`
      ),
    };
  }
  if (type === "test") {
    return {
      subject: "Prueba de correo transaccional — melonn fleet",
      html: layout(
        "Prueba de correo",
        `<p style="color:#333;font-size:14px;line-height:1.5;">Este es un correo de prueba enviado desde el Edge Function <code>send-email</code> de melonn fleet, usando la API de Resend.</p>
         <p style="color:#333;font-size:14px;line-height:1.5;">Si lo recibiste, el transporte de correo quedó conectado correctamente.</p>`
      ),
    };
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: false, error: "method_not_allowed" }), {
      status: 405, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
  try {
    const body = await req.json();
    const to = typeof body?.to === "string" ? body.to : "";
    const type = typeof body?.type === "string" ? body.type : "";
    const data = typeof body?.data === "object" && body.data !== null ? body.data : {};
    if (!to || !type) {
      return new Response(JSON.stringify({ ok: false, error: "missing_to_or_type" }), {
        status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    const email = buildEmail(type, data);
    if (!email) {
      return new Response(JSON.stringify({ ok: false, error: "unknown_type" }), {
        status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    const apiKey = Deno.env.get("RESEND_API_KEY") ?? "";
    const resendResp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: FROM, to: [to], subject: email.subject, html: email.html }),
    });
    const resendData = await resendResp.json();
    if (!resendResp.ok) {
      return new Response(JSON.stringify({ ok: false, error: "resend_error", detail: resendData }), {
        status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ ok: true, id: resendData.id }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (_e) {
    return new Response(JSON.stringify({ ok: false, error: "server_error" }), {
      status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
