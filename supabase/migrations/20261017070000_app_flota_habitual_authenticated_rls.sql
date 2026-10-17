-- Fase 2 de Seguridad, Etapa C: RLS real sobre app_flota_habitual (una fila por Aliado, id = nombre del
-- aliado, con su plantilla de mensajeros/vehiculos/horarios recurrente -- ver scPushFlotaHabitual,
-- commit "Guardar/Cargar Flota Habitual solo vivia en localStorage") para el rol `authenticated`.
--
-- Penultima tabla de la hoja de ruta tras app_cuotas_config (commit 0f8c9ee). A diferencia de esa tabla
-- (fila global unica), esta es la mas simple de alcance de toda la Etapa C: CADA fila le pertenece a UN
-- solo Aliado, y rastreando cargarFlotaHabitual()/scPushFlotaHabitual() en app.js se confirma que NINGUN
-- otro rol lee o escribe esta tabla jamas -- "Programar Flota" es, letra por letra, el modulo exclusivo
-- ALIADO (ver index.html, comentario "<!-- PROGRAMAR FLOTA (ALIADO) -->"), y ambos caminos (carga rapida
-- "Cargar Flota Recurrente" / guardado "Guardar como Flota Recurrente") solo tocan
-- state.flotaHabitual[state.user.aliado] -- nunca la fila de otro aliado. No existe ninguna pantalla de
-- Admin/Planner/Bodega/Auditor que lea o liste las plantillas de flota recurrente de los aliados.
--
-- Politicas resultantes: SELECT/INSERT/UPDATE, todas exclusivas a la fila propia del Aliado
-- (auth.jwt()->>'app_role' = 'ALIADO' and id = auth.jwt()->>'aliadoId'). Sin alcance global para ningun
-- otro rol -- a diferencia de app_cuotas_config (lectura abierta) y app_solicitudes_generales/
-- app_mensajeros (ADMIN/PLANNER/AUDITOR ven todo), aqui ni siquiera ADMIN tiene un camino real de lectura
-- en la UI, asi que no se le concede ninguno a nivel de politica tampoco (principio de minimo privilegio
-- ya aplicado en las migraciones anteriores: la politica refleja el permiso real, no el maximo posible).
--
-- Mismo criterio que las migraciones anteriores de esta etapa: las politicas "anon_*" existentes NO se
-- tocan, siguen en paralelo; esta migracion tampoco conecta ningun llamador de app.js todavia -- queda
-- agrupada en el paso dedicado de reconexion al final de la Etapa C.
grant select, insert, update on public.app_flota_habitual to authenticated;

drop policy if exists "authenticated_select_app_flota_habitual" on public.app_flota_habitual;
drop policy if exists "authenticated_insert_app_flota_habitual" on public.app_flota_habitual;
drop policy if exists "authenticated_update_app_flota_habitual" on public.app_flota_habitual;

create policy "authenticated_select_app_flota_habitual" on public.app_flota_habitual
  for select to authenticated
  using (auth.jwt()->>'app_role' = 'ALIADO' and id = auth.jwt()->>'aliadoId');

create policy "authenticated_insert_app_flota_habitual" on public.app_flota_habitual
  for insert to authenticated
  with check (auth.jwt()->>'app_role' = 'ALIADO' and id = auth.jwt()->>'aliadoId');

create policy "authenticated_update_app_flota_habitual" on public.app_flota_habitual
  for update to authenticated
  using (auth.jwt()->>'app_role' = 'ALIADO' and id = auth.jwt()->>'aliadoId')
  with check (auth.jwt()->>'app_role' = 'ALIADO' and id = auth.jwt()->>'aliadoId');
