-- Fase 2 de Seguridad, Etapa C (siguiente tabla de la hoja de ruta): RLS real sobre app_mensajeros
-- (roster de mensajeros/couriers -- cedula, telefono, placa) para el rol `authenticated`, usando los claims
-- app_role/bodegaId/aliadoId que el Edge Function "session" ya agrega desde "mint_with_role" (ver
-- migracion 20261017030000 / commit b302ec8).
--
-- Alcance de las politicas, verificado contra el codigo real (no supuesto):
-- - LECTURA: mismo criterio que mensajerosInScope() en app.js -- ADMIN/PLANNER/AUDITOR ven TODO (los 3
--   caen en alcance GLOBAL segun userEffectiveScope(); el filtro de sede que AUDITOR aplica en su propia
--   UI es una conveniencia de pantalla, no un limite de seguridad -- su propio codigo cliente ya lo trata
--   asi hoy). ALIADO ve solo mensajeros de su PROPIO aliado (data->>'aliado'); BODEGA ve solo los de su
--   PROPIA sede (data->>'sede').
-- - ESCRITURA: rastreado cada llamador real de scPushRows('app_mensajeros', ...) en app.js -- TODOS pasan
--   por findOrCreateMensajero/findOrCreateMensajeroParaAliado/crearMensajeroPendiente (submitTurno,
--   cargarFlotaHabitual -- gateados por canDo('schedule.aliado.manage'), exclusivo ALIADO) o por
--   toggleFlotaPropiaActivo (gateado por canDo('flotaPropia.manage'), exclusivo BODEGA). auth.js/PERMISSIONS
--   confirma que AUDITOR no tiene NINGUN permiso de escritura en toda la plataforma, y que ADMIN/PLANNER no
--   aparecen en ningun permiso de gestion de mensajeros -- por eso la escritura queda scopeada SOLO a
--   ALIADO (su propio aliado) y BODEGA (su propia sede), sin acceso de escritura blanco para ADMIN/PLANNER/
--   AUDITOR (principio de menor privilegio: si en el futuro aparece un llamador real que lo necesite, debe
--   fallar visible -- nunca quedar silenciosamente abierto de mas).
--
-- IMPORTANTE (mismo criterio que Etapa C parte 1, app_users): las politicas "anon_*" existentes NO se
-- tocan -- siguen en paralelo. Esta migracion tampoco cambia ningun llamador de app.js para app_mensajeros
-- todavia -- scPullTable/scPushRows de esa tabla siguen con el cliente anon de siempre. Riesgo real
-- detectado al disenar esto (razon para no conectarlo aqui mismo): scPushAll() (autoguardado periodico +
-- logout) reempuja state.mensajeros COMPLETO sin filtrar por alcance -- hoy ese arreglo en memoria contiene
-- mensajeros de TODOS los aliados/sedes (el filtrado por mensajerosInScope() es solo para RENDER, nunca
-- reduce lo que vive en memoria). Conectar el cliente authenticated sin antes acotar ese reempuje blindo a
-- filas dentro del alcance real del usuario arriesgaria que ese push masivo choque contra RLS en cuanto
-- intente reescribir filas fuera de su propio aliado/sede -- queda documentado para resolverlo junto con el
-- mismo paso dedicado de app_users, no mezclado aqui.
grant select, insert, update on public.app_mensajeros to authenticated;

drop policy if exists "authenticated_select_app_mensajeros" on public.app_mensajeros;
drop policy if exists "authenticated_insert_app_mensajeros" on public.app_mensajeros;
drop policy if exists "authenticated_update_app_mensajeros" on public.app_mensajeros;

create policy "authenticated_select_app_mensajeros" on public.app_mensajeros
  for select to authenticated
  using (
    auth.jwt()->>'app_role' in ('ADMIN', 'PLANNER', 'AUDITOR')
    or (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
  );

create policy "authenticated_insert_app_mensajeros" on public.app_mensajeros
  for insert to authenticated
  with check (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
  );

create policy "authenticated_update_app_mensajeros" on public.app_mensajeros
  for update to authenticated
  using (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
  )
  with check (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
  );
