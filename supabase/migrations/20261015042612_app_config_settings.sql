-- Ver requerimiento "Cuotas activada por Admin no se reflejaba en ninguna otra sesión" -- mismo hueco
-- arquitectónico que app_cuotas_config/app_flota_habitual (ver esas 2 migraciones). state.configSettings
-- (cuotasActivoCO/MX, catálogos de Sedes/Aliados, Gravity, Notificaciones, Comunicados) vivía EXCLUSIVAMENTE
-- en localStorage -- una sola fila 'global' sincroniza el objeto completo.
create table if not exists public.app_config_settings (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

grant select, insert, update on public.app_config_settings to anon;

alter table public.app_config_settings enable row level security;

drop policy if exists "anon_select_app_config_settings" on public.app_config_settings;
drop policy if exists "anon_insert_app_config_settings" on public.app_config_settings;
drop policy if exists "anon_update_app_config_settings" on public.app_config_settings;
create policy "anon_select_app_config_settings" on public.app_config_settings for select to anon using (true);
create policy "anon_insert_app_config_settings" on public.app_config_settings for insert to anon with check (true);
create policy "anon_update_app_config_settings" on public.app_config_settings for update to anon using (true) with check (true);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_app_config_settings_updated_at on public.app_config_settings;
create trigger trg_app_config_settings_updated_at before update on public.app_config_settings
  for each row execute function public.set_updated_at();
