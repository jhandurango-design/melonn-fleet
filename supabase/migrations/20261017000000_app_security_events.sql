-- Ver requerimiento "Sincronizacion de Solicitudes de Recuperacion al panel de Admin": state.securityEvents
-- (registrarEventoSeguridad) nunca se habia persistido a Supabase -- vivia solo en la memoria del navegador
-- de quien disparaba el evento (ej. un Aliado pidiendo "Olvide mi contraseña" desde el login), asi que el
-- Admin jamas lo veia en su propio panel de "Seguridad y Accesos" a menos que fuera la MISMA pestaña. Mismo
-- patron {id,data,updated_at} que el resto de tablas -- una fila por evento (bloqueo, fallo, recuperacion,
-- creacion, edicion, etc.), id = securityEvent.id generado client-side.
create table if not exists public.app_security_events (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

grant select, insert, update on public.app_security_events to anon;

alter table public.app_security_events enable row level security;

drop policy if exists "anon_select_app_security_events" on public.app_security_events;
drop policy if exists "anon_insert_app_security_events" on public.app_security_events;
drop policy if exists "anon_update_app_security_events" on public.app_security_events;
create policy "anon_select_app_security_events" on public.app_security_events for select to anon using (true);
create policy "anon_insert_app_security_events" on public.app_security_events for insert to anon with check (true);
create policy "anon_update_app_security_events" on public.app_security_events for update to anon using (true) with check (true);

drop trigger if exists trg_app_security_events_updated_at on public.app_security_events;
create trigger trg_app_security_events_updated_at before update on public.app_security_events
  for each row execute function public.set_updated_at();
