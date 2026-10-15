-- Ver requerimiento "Auditoría de Discrepancia en Cuotas y Visibilidad de Datos" (supabase_schema.sql tiene
-- el mismo bloque, documentado ahí con más contexto -- esta migración es la forma de aplicarlo vía CLI en
-- vez de pegarlo a mano en el SQL Editor). state.cuotasMatriz y sus 6 campos hermanos (franjas, franjasMX,
-- matrizProxima, fechaProxima, bannerCO, observaciones) vivían EXCLUSIVAMENTE en localStorage -- nunca
-- sincronizados entre navegadores/usuarios. Una única fila 'global' en esta tabla (mismo patrón {id,data}
-- que app_users/app_mensajeros/app_turnos/app_solicitudes_generales) centraliza los 7 campos.
--
-- create table if not exists (nunca drop): las otras 4 tablas ya tienen datos reales de producción, y esta
-- migración no debe tocarlas en absoluto -- solo agrega la tabla nueva.
create table if not exists public.app_cuotas_config (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

grant select, insert, update on public.app_cuotas_config to anon;

alter table public.app_cuotas_config enable row level security;

drop policy if exists "anon_select_app_cuotas_config" on public.app_cuotas_config;
drop policy if exists "anon_insert_app_cuotas_config" on public.app_cuotas_config;
drop policy if exists "anon_update_app_cuotas_config" on public.app_cuotas_config;
create policy "anon_select_app_cuotas_config" on public.app_cuotas_config for select to anon using (true);
create policy "anon_insert_app_cuotas_config" on public.app_cuotas_config for insert to anon with check (true);
create policy "anon_update_app_cuotas_config" on public.app_cuotas_config for update to anon using (true) with check (true);

-- set_updated_at() ya existe (creada por el schema original aplicado manualmente) -- create or replace la
-- deja intacta si ya existe, y la crea si por algún motivo esta migración corriera contra un proyecto nuevo.
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_app_cuotas_config_updated_at on public.app_cuotas_config;
create trigger trg_app_cuotas_config_updated_at before update on public.app_cuotas_config
  for each row execute function public.set_updated_at();
