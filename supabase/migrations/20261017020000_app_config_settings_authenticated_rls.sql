-- Fase 2 de Seguridad, Etapa B: piloto de RLS real sobre app_config_settings (tabla piloto elegida en vez
-- de app_security_events -- ver plan: app_security_events recibe INSERTs desde la pantalla de login, ANTES
-- de que exista ningun JWT, asi que no puede exigir `authenticated` sin romper "Olvide mi contraseña";
-- app_config_settings (fila unica 'global', solo la edita Admin, nunca se lee/escribe antes de login) no
-- tiene ningun caso de acceso anonimo legitimo que proteger).
--
-- IMPORTANTE (a proposito): las politicas "anon_*" existentes sobre esta tabla NO se tocan ni se borran en
-- esta migracion -- se agregan politicas NUEVAS para el rol `authenticated` EN PARALELO. anon sigue
-- funcionando exactamente igual mientras se confirma que el camino authenticated funciona de verdad contra
-- produccion (sin entorno de staging real disponible en este deploy). Cerrar anon de verdad sobre esta
-- tabla es un PR posterior, una vez verificado este piloto.
--
-- El JWT emitido por la Edge Function "session" (ver Etapa A) todavia NO lleva el rol elegido por el
-- usuario (bodegaId/aliadoId/app_role) -- solo prueba QUIEN (sub = id de usuario). Por eso estas politicas
-- todavia no distinguen Admin de cualquier otro rol -- cualquier sesion `authenticated` valida puede
-- leer/escribir esta tabla, igual que anon hoy. Es una mejora real (ya no basta con tener la anon key
-- publica -- hace falta una sesion valida de verdad), con la brecha de "no distingue Admin" documentada
-- para cerrarse en una etapa posterior, cuando el token lleve claims de rol.
grant select, insert, update on public.app_config_settings to authenticated;

drop policy if exists "authenticated_select_app_config_settings" on public.app_config_settings;
drop policy if exists "authenticated_insert_app_config_settings" on public.app_config_settings;
drop policy if exists "authenticated_update_app_config_settings" on public.app_config_settings;
create policy "authenticated_select_app_config_settings" on public.app_config_settings for select to authenticated using (true);
create policy "authenticated_insert_app_config_settings" on public.app_config_settings for insert to authenticated with check (true);
create policy "authenticated_update_app_config_settings" on public.app_config_settings for update to authenticated using (true) with check (true);
