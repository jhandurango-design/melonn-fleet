-- Paso de Reconexion, Fix #4: cierra la brecha documentada desde la propia Etapa B (migracion
-- 20261017020000) -- en ese momento el JWT de la Etapa A todavia no llevaba el rol elegido
-- (bodegaId/aliadoId/app_role), asi que INSERT/UPDATE quedaron abiertos a CUALQUIER `authenticated`,
-- no solo Admin, como brecha menor aceptada "a cerrar en una etapa posterior, cuando el token lleve
-- claims de rol". Ese claim ya existe desde la Etapa C (mint_with_role) -- se cierra aqui.
--
-- Confirmado sin riesgo para ningun otro rol: la vista 'configuracion' (Ajustes Generales, la UNICA que
-- escribe esta tabla via persistConfigSettings/scPushConfigSettings) solo aparece en el
-- allowedViewsForUser de ADMIN (app.js:1656, 1689) -- ningun otro rol puede siquiera llegar a la pantalla.
-- Las 3 funciones que la escriben (guardarCuotasToggle y las del tab Catalogos/General, ver
-- app.js:17072-17084, 17700-17711, 18571, 20176-20204) estan TODAS gateadas por canDo('users.manage'),
-- exclusivo ADMIN en el catalogo PERMISSIONS de auth.js -- mismo patron ya usado para app_cuotas_config
-- (commit 0f8c9ee) y app_flota_habitual (commit 92858ba): la politica pasa a reflejar el permiso REAL.
--
-- Mismo criterio que todas las migraciones anteriores: las politicas "anon_*" NO se tocan, siguen en
-- paralelo; esta migracion es puramente de base de datos -- no depende de ningun cambio en app.js (ese es
-- el "Paso de Reconexion" en si, Fix #1/#2/#3, que se hace aparte).
drop policy if exists "authenticated_insert_app_config_settings" on public.app_config_settings;
drop policy if exists "authenticated_update_app_config_settings" on public.app_config_settings;

create policy "authenticated_insert_app_config_settings" on public.app_config_settings
  for insert to authenticated
  with check (auth.jwt()->>'app_role' = 'ADMIN');

create policy "authenticated_update_app_config_settings" on public.app_config_settings
  for update to authenticated
  using (true)
  with check (auth.jwt()->>'app_role' = 'ADMIN');
