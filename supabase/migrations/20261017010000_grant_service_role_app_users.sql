-- Fase 2 de Seguridad, Etapa A: la nueva Edge Function "session" (mint/verify de tokens de sesion) lee
-- app_users con la SERVICE ROLE KEY -- confirmado en vivo que esta falla con 42501 "permission denied for
-- table app_users": este esquema (ver supabase_schema.sql) nunca otorgo ningun GRANT a service_role, solo
-- a anon. service_role SI bypassa RLS por defecto (BYPASSRLS), pero el GRANT de tabla es una capa aparte
-- (ver mismo comentario ya existente en supabase_schema.sql junto a los GRANT de anon) -- sin el, Postgres
-- rechaza la consulta antes de llegar siquiera a evaluar RLS.
grant select on public.app_users to service_role;
