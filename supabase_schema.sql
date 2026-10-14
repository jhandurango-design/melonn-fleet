-- Melonn Fleet -- esquema Supabase para persistencia multiusuario.
-- Ejecutar completo en el SQL Editor de Supabase (Project > SQL Editor > New query).
--
-- Diseño: 3 tablas "espejo" (snapshot jsonb completo por fila), una por cada arreglo de state.* que
-- app.js sincroniza (ver scPullAll/scPushAll/scPullTable/scPushRows en app.js): app_users, app_mensajeros,
-- app_turnos. No se normalizan en columnas individuales a propósito -- estos objetos acumulan campos
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

alter table public.app_users enable row level security;
alter table public.app_mensajeros enable row level security;
alter table public.app_turnos enable row level security;

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
