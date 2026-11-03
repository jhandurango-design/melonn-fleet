-- Baseline: las 4 tablas base (app_users, app_mensajeros, app_turnos, app_solicitudes_generales) se crearon
-- originalmente fuera del sistema de migraciones (ver supabase_schema.sql en la raiz del repo, ejecutado
-- a mano en el SQL Editor cuando el proyecto empezo). Esta migracion las agrega al historial de migraciones
-- para que un proyecto nuevo (ver requerimiento "Migracion temporal de Supabase por excedente de Egress")
-- pueda levantarse desde cero con `supabase db push`, igual que ya pasa con app_cuotas_config/
-- app_flota_habitual/app_config_settings (que si tenian su propia migracion). IF NOT EXISTS: nunca toca un
-- proyecto que ya tenga estas tablas con datos reales.
create table if not exists public.app_users (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_mensajeros (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_turnos (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_solicitudes_generales (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

grant usage on schema public to anon;
grant select, insert, update on public.app_users to anon;
grant select, insert, update on public.app_mensajeros to anon;
grant select, insert, update, delete on public.app_turnos to anon;
grant select, insert, update, delete on public.app_solicitudes_generales to anon;

alter table public.app_users enable row level security;
alter table public.app_mensajeros enable row level security;
alter table public.app_turnos enable row level security;
alter table public.app_solicitudes_generales enable row level security;

drop policy if exists "anon_select_app_users" on public.app_users;
drop policy if exists "anon_insert_app_users" on public.app_users;
drop policy if exists "anon_update_app_users" on public.app_users;
create policy "anon_select_app_users" on public.app_users for select to anon using (true);
create policy "anon_insert_app_users" on public.app_users for insert to anon with check (true);
create policy "anon_update_app_users" on public.app_users for update to anon using (true) with check (true);

drop policy if exists "anon_select_app_mensajeros" on public.app_mensajeros;
drop policy if exists "anon_insert_app_mensajeros" on public.app_mensajeros;
drop policy if exists "anon_update_app_mensajeros" on public.app_mensajeros;
create policy "anon_select_app_mensajeros" on public.app_mensajeros for select to anon using (true);
create policy "anon_insert_app_mensajeros" on public.app_mensajeros for insert to anon with check (true);
create policy "anon_update_app_mensajeros" on public.app_mensajeros for update to anon using (true) with check (true);

drop policy if exists "anon_select_app_turnos" on public.app_turnos;
drop policy if exists "anon_insert_app_turnos" on public.app_turnos;
drop policy if exists "anon_update_app_turnos" on public.app_turnos;
drop policy if exists "anon_delete_app_turnos" on public.app_turnos;
create policy "anon_select_app_turnos" on public.app_turnos for select to anon using (true);
create policy "anon_insert_app_turnos" on public.app_turnos for insert to anon with check (true);
create policy "anon_update_app_turnos" on public.app_turnos for update to anon using (true) with check (true);
create policy "anon_delete_app_turnos" on public.app_turnos for delete to anon using (true);

drop policy if exists "anon_select_app_solicitudes_generales" on public.app_solicitudes_generales;
drop policy if exists "anon_insert_app_solicitudes_generales" on public.app_solicitudes_generales;
drop policy if exists "anon_update_app_solicitudes_generales" on public.app_solicitudes_generales;
drop policy if exists "anon_delete_app_solicitudes_generales" on public.app_solicitudes_generales;
create policy "anon_select_app_solicitudes_generales" on public.app_solicitudes_generales for select to anon using (true);
create policy "anon_insert_app_solicitudes_generales" on public.app_solicitudes_generales for insert to anon with check (true);
create policy "anon_update_app_solicitudes_generales" on public.app_solicitudes_generales for update to anon using (true) with check (true);
create policy "anon_delete_app_solicitudes_generales" on public.app_solicitudes_generales for delete to anon using (true);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_app_users_updated_at on public.app_users;
create trigger trg_app_users_updated_at before update on public.app_users
  for each row execute function public.set_updated_at();
drop trigger if exists trg_app_mensajeros_updated_at on public.app_mensajeros;
create trigger trg_app_mensajeros_updated_at before update on public.app_mensajeros
  for each row execute function public.set_updated_at();
drop trigger if exists trg_app_turnos_updated_at on public.app_turnos;
create trigger trg_app_turnos_updated_at before update on public.app_turnos
  for each row execute function public.set_updated_at();
drop trigger if exists trg_app_solicitudes_generales_updated_at on public.app_solicitudes_generales;
create trigger trg_app_solicitudes_generales_updated_at before update on public.app_solicitudes_generales
  for each row execute function public.set_updated_at();
