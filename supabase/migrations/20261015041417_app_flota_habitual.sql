-- Ver requerimiento "Guardar/Cargar Flota Habitual solo vivía en localStorage" (mismo hueco arquitectónico ya
-- corregido para Cuotas, ver migración app_cuotas_config). Una fila por aliado (id = nombre del aliado, mismo
-- patrón {id,data} que el resto) -- cada Aliado gestiona su propia plantilla de Flota Recurrente de forma
-- independiente.
create table if not exists public.app_flota_habitual (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

grant select, insert, update on public.app_flota_habitual to anon;

alter table public.app_flota_habitual enable row level security;

drop policy if exists "anon_select_app_flota_habitual" on public.app_flota_habitual;
drop policy if exists "anon_insert_app_flota_habitual" on public.app_flota_habitual;
drop policy if exists "anon_update_app_flota_habitual" on public.app_flota_habitual;
create policy "anon_select_app_flota_habitual" on public.app_flota_habitual for select to anon using (true);
create policy "anon_insert_app_flota_habitual" on public.app_flota_habitual for insert to anon with check (true);
create policy "anon_update_app_flota_habitual" on public.app_flota_habitual for update to anon using (true) with check (true);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_app_flota_habitual_updated_at on public.app_flota_habitual;
create trigger trg_app_flota_habitual_updated_at before update on public.app_flota_habitual
  for each row execute function public.set_updated_at();
