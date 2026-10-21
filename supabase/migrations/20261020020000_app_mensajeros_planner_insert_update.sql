-- Fix "Bug Critico de Edicion y Persistencia en Supabase", extendido a la aprobacion de Solicitudes
-- Generales: la politica original de app_mensajeros (20261017040000) solo concedia INSERT/UPDATE a ALIADO
-- (propio) y BODEGA (propia sede) -- PLANNER quedo fuera por completo.
--
-- Esto es un hueco real, no una restriccion deliberada: aplicarSolicitudGeneral() crea/edita un mensajero
-- EN NOMBRE del aliado dueno de la solicitud (nuevo_turno, cupo_adicional, edicion_turno via
-- findOrCreateMensajeroParaAliado/forkMensajeroParaEdicion, reemplazo_alerta, reemplazo_cancelacion) --
-- pero quien ejecuta esa mutacion es la sesion de PLANNER que aprueba, no el Aliado (que no tiene sesion
-- activa en ese momento). Confirmado en produccion: Planner aprueba una solicitud de "Nuevo Turno", la
-- propia solicitud queda 'aceptada' (esa tabla SI concede UPDATE global a PLANNER, ver
-- 20261017050000), pero el INSERT del mensajero nuevo se rechaza con 42501 -- una desincronizacion
-- silenciosa: la solicitud dice "aprobada" pero el turno/mensajero reales nunca llegan a existir.
--
-- Mismo criterio ya usado en app_turnos/app_solicitudes_generales: PLANNER tiene alcance GLOBAL sin
-- scoping real (userEffectiveScope() es global para este rol) -- se le concede INSERT/UPDATE
-- incondicional, igual que a esas 2 tablas.
drop policy if exists "authenticated_insert_app_mensajeros" on public.app_mensajeros;
drop policy if exists "authenticated_update_app_mensajeros" on public.app_mensajeros;

create policy "authenticated_insert_app_mensajeros" on public.app_mensajeros
  for insert to authenticated
  with check (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
    or auth.jwt()->>'app_role' = 'PLANNER'
  );

create policy "authenticated_update_app_mensajeros" on public.app_mensajeros
  for update to authenticated
  using (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
    or auth.jwt()->>'app_role' = 'PLANNER'
  )
  with check (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
    or auth.jwt()->>'app_role' = 'PLANNER'
  );
