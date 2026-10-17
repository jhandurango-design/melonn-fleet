-- Fase 2 de Seguridad, Etapa C: RLS real sobre app_cuotas_config (fila unica 'global' -- matriz de cuotas
-- por sede/aliado/dia/franja/vehiculo, franjas CO/MX, Proxima Cuota, banner y observaciones) para el rol
-- `authenticated`.
--
-- Esta tabla es, en terminos de alcance, igual a app_config_settings (Etapa B, commit 5da7866): una sola
-- fila de configuracion global, sin scoping por fila posible ni necesario.
--
-- LECTURA: TODOS los roles la necesitan -- impulsa checkCuotaExceso/evaluarAprobacionCuota/
-- turnosProgramadosCount en todo el motor de Programacion/Consolidado, consumida por ALIADO (su propio
-- avance de cuota en Programar Flota), PLANNER ("Avance y Carga T+1", matriz completa de todos los
-- aliados), BODEGA y AUDITOR. using(true) para cualquier authenticated.
--
-- ESCRITURA: rastreado cada funcion real que la modifica -- guardarCuotasMatriz, agregarCuotaFranja/
-- eliminarCuotaFranja, abrirEdicionCuotasBanner/guardarCuotasBanner/borrarCuotasBanner,
-- guardarCuotasObservaciones/borrarCuotasObservaciones -- TODAS gateadas por `canDo('users.manage')`,
-- exclusivo ADMIN (el propio comentario del codigo lo confirma letra por letra: "exclusivo Admin — misma
-- puerta que otros catalogos administrables"). PLANNER, pese a ser el principal consumidor operativo de
-- esta tabla, NO tiene ningun camino de escritura real -- por eso with check queda exclusivo a ADMIN.
--
-- Mismo criterio que las migraciones anteriores de esta etapa: las politicas "anon_*" existentes NO se
-- tocan, siguen en paralelo; esta migracion tampoco conecta ningun llamador de app.js todavia -- queda
-- agrupada en el paso dedicado de reconexion al final de la Etapa C.
grant select, insert, update on public.app_cuotas_config to authenticated;

drop policy if exists "authenticated_select_app_cuotas_config" on public.app_cuotas_config;
drop policy if exists "authenticated_insert_app_cuotas_config" on public.app_cuotas_config;
drop policy if exists "authenticated_update_app_cuotas_config" on public.app_cuotas_config;

create policy "authenticated_select_app_cuotas_config" on public.app_cuotas_config
  for select to authenticated
  using (true);

create policy "authenticated_insert_app_cuotas_config" on public.app_cuotas_config
  for insert to authenticated
  with check (auth.jwt()->>'app_role' = 'ADMIN');

create policy "authenticated_update_app_cuotas_config" on public.app_cuotas_config
  for update to authenticated
  using (true)
  with check (auth.jwt()->>'app_role' = 'ADMIN');
