-- Revierte 20261028223000_app_turnos_admin_cuota_resolve.sql y 20261028224500_app_turnos_admin_cuota_resolve_upsert.sql.
--
-- Esas 2 migraciones habian dado a ADMIN permiso real de UPDATE sobre app_turnos, acotado a filas con
-- pendienteAprobacionPlanner=true (Aprobar/Rechazar Cuota/Festivo/Domingo/Tipologia -- "Permiso de
-- Contingencia", ver auth.js 'cuota.resolve' y el requerimiento "Reestructuracion y Optimizacion Integral de
-- Solicitudes y Cambios -- Rol Planner", punto 4).
--
-- Se confirma con el usuario (ver requerimiento "Auditoria y Depuracion del Concepto Heredado
-- 'Admin/Planner'..."): ADMIN no debe tener ninguna accion operativa, sin excepciones puntuales --
-- Solicitudes y Cambios (incluida la aprobacion de Cuota/Festivo) es 100% de PLANNER. Se restaura la misma
-- politica "authenticated_update_app_turnos" que ya tenia la migracion original 20261017080000_app_turnos_
-- authenticated_rls.sql, antes de la excepcion de ADMIN -- PLANNER/BODEGA(su sede)/ALIADO(el suyo), nunca
-- ADMIN. El resto de politicas de app_turnos (select/insert/delete) nunca tuvo esta excepcion y no se toca.
drop policy if exists "authenticated_update_app_turnos" on public.app_turnos;

create policy "authenticated_update_app_turnos" on public.app_turnos
  for update to authenticated
  using (
    auth.jwt()->>'app_role' = 'PLANNER'
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
    or (auth.jwt()->>'app_role' = 'BODEGA' and app_turnos.data->>'sede' = auth.jwt()->>'bodegaId')
    or (
      auth.jwt()->>'app_role' = 'ALIADO'
      and exists (
        select 1 from public.app_mensajeros m
        where m.id = app_turnos.data->>'mensajeroId' and m.data->>'aliado' = auth.jwt()->>'aliadoId'
      )
    )
  );
