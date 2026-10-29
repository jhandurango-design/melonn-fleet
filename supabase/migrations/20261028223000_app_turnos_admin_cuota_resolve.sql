-- Ver requerimiento "Reestructuración y Optimización Integral de Solicitudes y Cambios -- Rol Planner",
-- punto 4 (Permisos de Contingencia en Excepciones de Cuota/Festivo): el frontend ya gana un permiso nuevo y
-- dedicado -- 'cuota.resolve': ['PLANNER', 'ADMIN'] (ver auth.js), usado SOLO por
-- aprobarCuotaPlanner/rechazarCuotaPlanner -- pero sin esta migración, ADMIN vería el botón habilitado y el
-- guardado fallaría siempre: la política "authenticated_update_app_turnos" (ver migración 20261017080000)
-- solo concede UPDATE sobre app_turnos a PLANNER/BODEGA(su sede)/ALIADO(el suyo), nunca a ADMIN -- exactamente
-- el tipo de "éxito falso" ya corregido hoy mismo en aprobarCuotaPlanner/rechazarCuotaPlanner (res.ok).
--
-- Alcance deliberadamente ESTRECHO, no un GRANT genérico: ADMIN solo puede UPDATE una fila de app_turnos cuyo
-- estado ANTES del update (evaluado por la cláusula USING, que en un UPDATE de Postgres se evalúa contra la
-- fila PRE-existente) tuviera pendienteAprobacionPlanner=true -- es decir, exactamente un turno con una
-- aprobación de Cuota/Festivo/Domingo/Tipología pendiente. ADMIN sigue sin poder editar hora/mensajero/sede ni
-- ninguna otra mutación de un turno sano -- esa capacidad sigue siendo exclusiva de PLANNER/BODEGA/ALIADO tal
-- cual. El WITH CHECK (estado DESPUÉS del update) se deja permisivo para ADMIN una vez pasó esa compuerta --
-- mismo criterio de confianza en la lógica de aplicación que ya usa el resto de este archivo (RLS protege QUÉ
-- FILAS puede tocar un rol, nunca valida la forma exacta del payload que escribe).
drop policy if exists "authenticated_update_app_turnos" on public.app_turnos;

create policy "authenticated_update_app_turnos" on public.app_turnos
  for update to authenticated
  using (
    auth.jwt()->>'app_role' = 'PLANNER'
    or (
      auth.jwt()->>'app_role' = 'ADMIN'
      and coalesce((app_turnos.data->>'pendienteAprobacionPlanner')::boolean, false) is true
    )
    or (auth.jwt()->>'app_role' = 'BODEGA' and app_turnos.data->>'sede' = auth.jwt()->>'bodegaId')
    or (
      auth.jwt()->>'app_role' = 'ALIADO'
      and exists (
        select 1 from public.app_mensajeros m
        where m.id = app_turnos.data->>'mensajeroId' and m.data->>'aliado' = auth.jwt()->>'aliadoId'
      )
    )
  )
  with check (
    auth.jwt()->>'app_role' = 'PLANNER'
    or auth.jwt()->>'app_role' = 'ADMIN'
    or (auth.jwt()->>'app_role' = 'BODEGA' and app_turnos.data->>'sede' = auth.jwt()->>'bodegaId')
    or (
      auth.jwt()->>'app_role' = 'ALIADO'
      and exists (
        select 1 from public.app_mensajeros m
        where m.id = app_turnos.data->>'mensajeroId' and m.data->>'aliado' = auth.jwt()->>'aliadoId'
      )
    )
  );
