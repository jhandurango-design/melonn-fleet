-- Fase 2 de Seguridad, Etapa C (primera tabla, la de mayor sensibilidad -- credenciales/PII): RLS real
-- sobre app_users para el rol `authenticated`, consumiendo los claims app_role/sub que el Edge Function
-- "session" ahora agrega en su accion "mint_with_role" (ver supabase/functions/session/index.ts) una vez
-- el usuario elige/confirma su rol activo.
--
-- IMPORTANTE (a proposito, mismo criterio que Etapa B): las politicas "anon_*" existentes sobre esta tabla
-- NO se tocan ni se borran -- siguen en paralelo. Dos razones reales, no solo cautela: (1) el login en si
-- mismo (resolverCredenciales en app.js) busca al usuario por correo en state.users ANTES de que exista
-- ninguna sesion -- depende del pull anonimo de SIEMPRE; (2) #formRecuperarCuenta (restablecimiento via
-- enlace) actualiza la fila de un usuario que puede no tener NINGUNA sesion previa en ese navegador (el
-- enlace suele abrirse en un dispositivo/navegador distinto al que origino la solicitud) -- exigir
-- `authenticated` ahi rompería la recuperacion de contraseña por enlace.
--
-- Por eso esta migracion NO cambia ningun llamador de app.js todavia (scPullTable/scPushRows de app_users
-- siguen exactamente igual, con el cliente anon de siempre) -- solo deja la politica correcta YA
-- verificada y lista, para conectarla en un paso posterior una vez confirmado que ningun flujo de un
-- usuario no-Admin depende de ver el listado COMPLETO de app_users (ver nota en el PR).
grant select, insert, update on public.app_users to authenticated;

drop policy if exists "authenticated_select_app_users" on public.app_users;
drop policy if exists "authenticated_insert_app_users" on public.app_users;
drop policy if exists "authenticated_update_app_users" on public.app_users;

-- SELECT: cualquier sesion autenticada ve su PROPIA fila (auth.jwt()->>'sub' = id -- los ids de esta tabla
-- son texto, "u3"/"u18"/etc., nunca auth.uid(), que castea a uuid y revienta); Admin ve todas.
create policy "authenticated_select_app_users" on public.app_users
  for select to authenticated
  using (auth.jwt()->>'sub' = id or auth.jwt()->>'app_role' = 'ADMIN');

-- INSERT: crear cuentas nuevas es exclusivo de Admin en la app (ver canDo('users.manage')/#formUsuario).
create policy "authenticated_insert_app_users" on public.app_users
  for insert to authenticated
  with check (auth.jwt()->>'app_role' = 'ADMIN');

-- UPDATE: una sesion autenticada puede editar su PROPIA fila (cambio de contraseña voluntario, etc.);
-- Admin puede editar cualquiera.
create policy "authenticated_update_app_users" on public.app_users
  for update to authenticated
  using (auth.jwt()->>'sub' = id or auth.jwt()->>'app_role' = 'ADMIN')
  with check (auth.jwt()->>'sub' = id or auth.jwt()->>'app_role' = 'ADMIN');
