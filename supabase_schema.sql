-- Melonn Fleet -- esquema Supabase para persistencia multiusuario.
-- Ejecutar completo en el SQL Editor de Supabase (Project > SQL Editor > New query).
--
-- Diseño: 4 tablas "espejo" (snapshot jsonb completo por fila), una por cada arreglo de state.* que
-- app.js sincroniza (ver scPullAll/scPushAll/scPullTable/scPushRows en app.js): app_users, app_mensajeros,
-- app_turnos, app_solicitudes_generales. No se normalizan en columnas individuales a propósito -- estos objetos acumulan campos
-- opcionales con el tiempo (ver turnos: llegadaScript, novedadElementos, arriboResolucion, etc.) y mapearlos
-- 1:1 a columnas obligaría a migrar el esquema cada vez que el modelo de datos del front crezca. `id` es el
-- mismo id que ya usa cada registro en memoria (u1, m-qa-..., TUR-1001, etc.).
--
-- ADVERTENCIA DE SEGURIDAD: el login de la app sigue siendo el propio (NO Supabase Auth, ver app.js) --
-- Postgres no tiene forma de saber QUIÉN llama, así que las políticas de abajo abren lectura/escritura al
-- rol "anon" (cualquiera con la URL + Anon Key del proyecto, ambos ya visibles en el código fuente del
-- navegador). Es el mismo nivel de protección que localStorage (ninguno más allá del login de la UI), pero
-- ahora alcanzable por internet. Si más adelante se quiere cerrar esto de verdad, el paso natural es migrar
-- a Supabase Auth real (requiere la Service Role Key, no solo el Anon Key) y condicionar las políticas a
-- auth.uid().
--
-- Ver "Diagnóstico en vivo, 2026-10-13" (segundo hallazgo): si estas 3 tablas ya existían de antes bajo
-- estos mismos nombres (p.ej. creadas con el editor visual de Supabase, con columnas id/created_at por
-- defecto), "CREATE TABLE IF NOT EXISTS" las deja TAL CUAL -- nunca les agrega la columna `data` que este
-- script espera, y cada select/upsert de app.js falla con "column ... data does not exist" (42703).
-- Confirmado en producción: las 3 estaban así, y las 3 estaban vacías (0 filas) -- por eso se botan y
-- recrean aquí sin riesgo de perder nada. Si en el futuro SÍ llegan a tener filas reales, cambiar estos
-- DROP por una migración (ALTER TABLE ... ADD COLUMN) en vez de volver a correr este bloque tal cual.
drop table if exists public.app_users cascade;
drop table if exists public.app_mensajeros cascade;
drop table if exists public.app_turnos cascade;
drop table if exists public.app_solicitudes_generales cascade;

create table public.app_users (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table public.app_mensajeros (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table public.app_turnos (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

-- Ver requerimiento "Persistencia Crítica: Aprobar Prolongación de Tiempo en Supabase": state.solicitudesGenerales
-- (Prolongación de Flota, Nuevo Turno/Cupo Adicional fuera de ventana, Reemplazo por Alerta/Cancelación,
-- Reprogramación Masiva, etc.) nunca tuvo tabla espejo -- vivía 100% en memoria y se perdía por completo en
-- cada recarga (incluyendo cualquier Aceptar/Rechazar ya resuelto por Planner/Admin).
create table public.app_solicitudes_generales (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

-- Ver "Diagnóstico en vivo, 2026-10-13": las políticas RLS de abajo NO bastan por sí solas -- en Postgres,
-- el GRANT de tabla y las políticas RLS son 2 capas distintas. RLS decide QUÉ FILAS puede ver/tocar un rol
-- que YA tiene permiso sobre la tabla; sin el GRANT, Postgres rechaza la consulta ANTES de llegar a evaluar
-- ninguna política, con "permission denied for table ..." (código 42501) -- exactamente el error real
-- confirmado en producción contra este proyecto. Faltaba esto desde la versión original de este script.
grant usage on schema public to anon;
grant select, insert, update on public.app_users to anon;
grant select, insert, update on public.app_mensajeros to anon;
-- app_turnos también lleva DELETE (ver requerimiento "Auditoría: Sincronización en Vivo y Persistencia de
-- Programación de Flota"): a diferencia de usuarios/mensajeros (nunca se borran, solo se inactivan), un
-- turno cancelado/eliminado por el Aliado SÍ se quita de verdad -- sin este GRANT, scDeleteRows() fallaba en
-- silencio y la fila quedaba huérfana, resucitada por el siguiente scPullAll().
grant select, insert, update, delete on public.app_turnos to anon;
-- app_solicitudes_generales también lleva DELETE por simetría con app_turnos, aunque app.js hoy solo
-- hace upsert (ninguna solicitud se borra de verdad, solo cambia de estado) -- deja la puerta abierta sin
-- requerir otra migración si eso cambia más adelante.
grant select, insert, update, delete on public.app_solicitudes_generales to anon;

alter table public.app_users enable row level security;
alter table public.app_mensajeros enable row level security;
alter table public.app_turnos enable row level security;
alter table public.app_solicitudes_generales enable row level security;

-- drop+create (no "if not exists" para policies en Postgres) -- hace el script seguro de volver a correr
-- completo en el futuro sin fallar por "policy already exists".
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

-- Mantiene updated_at al día en cada upsert (informativo -- nada en app.js lo lee todavía).
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_app_users_updated_at before update on public.app_users
  for each row execute function public.set_updated_at();
create trigger trg_app_mensajeros_updated_at before update on public.app_mensajeros
  for each row execute function public.set_updated_at();
create trigger trg_app_turnos_updated_at before update on public.app_turnos
  for each row execute function public.set_updated_at();
create trigger trg_app_solicitudes_generales_updated_at before update on public.app_solicitudes_generales
  for each row execute function public.set_updated_at();

-- ============================================================================
-- MIGRACIÓN INCREMENTAL (2026-10-15) -- NO vuelvas a correr el bloque de arriba completo: los 4 "drop table
-- ... cascade" de la línea 26-29 ya tienen datos reales de producción (usuarios, mensajeros, turnos,
-- solicitudes) y los borrarían sin forma de recuperarlos. Para aplicar esta migración, copia y ejecuta
-- SOLO lo que sigue desde esta línea en adelante -- usa "create table if not exists" (nunca drop) a
-- propósito, así que también es seguro volver a correr únicamente este bloque más de una vez por error.
--
-- Ver requerimiento "Auditoría de Discrepancia en Cuotas y Visibilidad de Datos": state.cuotasMatriz (y sus
-- 6 campos hermanos -- franjas, franjasMX, matrizProxima, fechaProxima, bannerCO, observaciones) vivían
-- EXCLUSIVAMENTE en localStorage, nunca sincronizados entre navegadores/usuarios -- de ahí que Jhan y Yair
-- (2 sesiones/dispositivos distintos) vieran 2 configuraciones de Cuotas completamente distintas. Una única
-- fila 'global' en esta tabla (mismo patrón {id,data} que el resto) centraliza los 7 campos.
-- ============================================================================
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

drop trigger if exists trg_app_cuotas_config_updated_at on public.app_cuotas_config;
create trigger trg_app_cuotas_config_updated_at before update on public.app_cuotas_config
  for each row execute function public.set_updated_at();

-- ============================================================================
-- MIGRACIÓN INCREMENTAL (2026-10-15b) -- igual que la de arriba: create table if not exists, nunca drop.
-- Ver requerimiento "Guardar/Cargar Flota Habitual solo vivía en localStorage" (mismo hueco que Cuotas) --
-- una fila por aliado (id = nombre del aliado) con su plantilla de Flota Recurrente.
-- ============================================================================
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

drop trigger if exists trg_app_flota_habitual_updated_at on public.app_flota_habitual;
create trigger trg_app_flota_habitual_updated_at before update on public.app_flota_habitual
  for each row execute function public.set_updated_at();

-- ============================================================================
-- MIGRACIÓN INCREMENTAL (2026-10-15c) -- igual que las de arriba: create table if not exists, nunca drop.
-- Ver requerimiento "Cuotas activada por Admin no se reflejaba en ninguna otra sesión" -- state.configSettings
-- completo (cuotasActivoCO/MX, catálogos de Sedes/Aliados, Gravity, Notificaciones, Comunicados) vivía
-- EXCLUSIVAMENTE en localStorage. Una sola fila 'global'.
-- ============================================================================
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

drop trigger if exists trg_app_config_settings_updated_at on public.app_config_settings;
create trigger trg_app_config_settings_updated_at before update on public.app_config_settings
  for each row execute function public.set_updated_at();
