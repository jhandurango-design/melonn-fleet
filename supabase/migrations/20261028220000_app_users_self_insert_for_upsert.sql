-- FIX "Cambio Obligatorio de Contraseña atascado sin salida para cuentas nuevas" (reporte real: Carol
-- Paredes, carol.paredes@external.cabify.com, Cabify -- confirmado 100% reproducible con una cuenta QA
-- desechable del mismo perfil: ALIADO recién creada, nunca logueada antes).
--
-- Causa raíz confirmada en producción, con el cuerpo de respuesta crudo de PostgREST en mano: el guardado
-- de #formCambioObligatorio/#formRecuperarCuenta hacia app_users usa SIEMPRE .upsert() (scPushRows, nunca
-- un UPDATE plano). Para Postgres, un INSERT ... ON CONFLICT (id) DO UPDATE sigue siendo, a nivel de RLS,
-- una sentencia INSERT -- el motor exige que la política de INSERT (WITH CHECK) pase también para la fila
-- en conflicto, aunque el resultado final termine siendo un UPDATE. La política de UPDATE
-- (20261017030000_app_users_authenticated_rls.sql) ya permitía correctamente que un usuario autenticado
-- edite su PROPIA fila (auth.jwt()->>'sub' = id) -- pero la política de INSERT de esa misma migración era
-- EXCLUSIVA de ADMIN, sin esa misma excepción de autoedición.
--
-- Resultado real: CUALQUIER usuario no-Admin que cambia su propia clave por primera vez (Cambio Obligatorio
-- o Recuperación por enlace) recibía sistemáticamente "42501: new row violates row-level security policy
-- for table app_users" -- 100% determinista, nunca intermitente (confirmado también que ningún timeout ni
-- reintento de red lo resuelve, porque no es una falla de conexión).
--
-- Fix: la política de INSERT ahora espeja exactamente la misma excepción de autoedición que ya tiene la de
-- UPDATE -- nunca permite crear una fila para OTRO id distinto al propio (eso sigue siendo exclusivo de
-- Admin vía #formUsuario), solo deja pasar el caso upsert-sobre-la-propia-fila-ya-existente que este bug
-- bloqueaba.
drop policy if exists "authenticated_insert_app_users" on public.app_users;

create policy "authenticated_insert_app_users" on public.app_users
  for insert to authenticated
  with check (auth.jwt()->>'app_role' = 'ADMIN' or auth.jwt()->>'sub' = id);
