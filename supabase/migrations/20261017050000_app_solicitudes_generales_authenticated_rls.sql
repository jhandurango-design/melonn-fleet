-- Fase 2 de Seguridad, Etapa C: RLS real sobre app_solicitudes_generales (Prolongación de Flota, Nuevo
-- Turno/Cupo Adicional fuera de ventana, Reemplazo por Alerta/Cancelación, Reprogramación Masiva) para el
-- rol `authenticated`.
--
-- A diferencia de app_mensajeros (flujo unidireccional por aliado/sede), esta tabla es BIDIRECCIONAL:
-- ALIADO crea la mayoria de tipos (aliado: state.user.aliado) y Planner los resuelve
-- (canDo('solicitud.resolve.general')); pero 'reprogramacion_masiva' la crea PLANNER hacia un aliado
-- destino (origen:'planner', aliado: <aliado objetivo>) y la resuelve el PROPIO Aliado dueño -- confirmado
-- letra por letra en resolverSolicitudGeneral(id, aceptar):
--   var puedeResolver = sol.origen === 'planner'
--     ? (Auth.getUserRole() === 'ALIADO' && sol.aliado === state.user.aliado)
--     : canDo('solicitud.resolve.general');
-- Por eso la regla de escritura (insert/update) es simetrica: ALIADO sobre su PROPIA fila (data->>'aliado'),
-- o PLANNER sobre cualquiera -- cubre ambas direcciones sin casos especiales.
--
-- LECTURA, verificada contra el codigo real (no supuesta): ADMIN/PLANNER/AUDITOR ven todo (alcance GLOBAL).
-- ALIADO ve solo las suyas (data->>'aliado'). BODEGA SI lee esta tabla (a diferencia de app_mensajeros) --
-- confirmado en solicitudesPendientesUnificadas (app.js): `s.estado === 'pendiente' && s.tipo !==
-- 'prolongacion' && s.detalle && s.detalle.sede === state.user.sede` -- Bodega ve toda solicitud EN CURSO
-- de su propia sede, excepto 'prolongacion' (un tramite exclusivo Aliado<->Planner sin relevancia
-- operativa para Bodega). BODEGA no tiene NINGUN permiso de escritura sobre esta tabla (no aparece en
-- ningun 'solicitud.*' de PERMISSIONS en auth.js) -- solo lectura.
--
-- IMPORTANTE (mismo criterio que las migraciones anteriores de esta etapa): las politicas "anon_*"
-- existentes NO se tocan, siguen en paralelo; esta migracion tampoco conecta ningun llamador de app.js
-- todavia -- queda agrupado con app_users/app_mensajeros en el paso dedicado de reconexion al final de la
-- Etapa C.
grant select, insert, update on public.app_solicitudes_generales to authenticated;

drop policy if exists "authenticated_select_app_solicitudes_generales" on public.app_solicitudes_generales;
drop policy if exists "authenticated_insert_app_solicitudes_generales" on public.app_solicitudes_generales;
drop policy if exists "authenticated_update_app_solicitudes_generales" on public.app_solicitudes_generales;

create policy "authenticated_select_app_solicitudes_generales" on public.app_solicitudes_generales
  for select to authenticated
  using (
    auth.jwt()->>'app_role' in ('ADMIN', 'PLANNER', 'AUDITOR')
    or (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (
      auth.jwt()->>'app_role' = 'BODEGA'
      and data->>'tipo' <> 'prolongacion'
      and data->'detalle'->>'sede' = auth.jwt()->>'bodegaId'
    )
  );

create policy "authenticated_insert_app_solicitudes_generales" on public.app_solicitudes_generales
  for insert to authenticated
  with check (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or auth.jwt()->>'app_role' = 'PLANNER'
  );

create policy "authenticated_update_app_solicitudes_generales" on public.app_solicitudes_generales
  for update to authenticated
  using (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or auth.jwt()->>'app_role' = 'PLANNER'
  )
  with check (
    (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or auth.jwt()->>'app_role' = 'PLANNER'
  );
