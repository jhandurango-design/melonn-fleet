-- FIX "Déficit de cuota sin cubrir hasta que la Bodega/Aliado dueño inicie sesión" (reporte real: DRN en
-- Bogotá #2 - Montevideo quedó en 11/13 sin generar los 2 "Pendiente/Por Confirmar" faltantes, mientras
-- Rapiboy en Medellín #2 si los recibio -- porque ya habia iniciado sesion alguien con alcance de escritura
-- en esa sede/aliado).
--
-- cierreCuotasCompletarDeficit() (ver app.js) corre para TODOS los aliados/sedes con deficit en CUALQUIER
-- login, pero el push a app_mensajeros queda acotado al alcance real de escritura de la sesion que lo
-- dispara: ALIADO solo su propio aliado, BODEGA solo su propia sede (ver migracion
-- 20261017040000_app_mensajeros_authenticated_rls.sql, y el FIX de ese mismo criterio aplicado del lado del
-- cliente en cierreCuotasPuedeEscribirMensajeroDe). PLANNER nunca tuvo NINGUN grant de escritura ahi, asi
-- que su login nunca cubria ningun deficit, sin importar la sede/aliado.
--
-- PLANNER ya tiene alcance global SIN restriccion de sede/aliado sobre app_turnos (ver migracion
-- 20261017080000_app_turnos_authenticated_rls.sql, 'PLANNER' sin condicion en insert/update) -- es el unico
-- rol que ve y gestiona el Consolidado de TODAS las bodegas/aliados a la vez, asi que tiene sentido de
-- negocio extenderle el mismo alcance global sobre app_mensajeros: su login debe poder cubrir cualquier
-- deficit de inmediato, sin depender de que la Bodega/Aliado puntual se conecte primero.
--
-- A diferencia del "Permiso de Contingencia" que se le dio y luego se revirtio a ADMIN (ver migracion
-- 20261030213000_app_turnos_revertir_admin_cuota_resolve.sql), este grant a PLANNER es consistente con un
-- permiso que PLANNER YA tenia en la tabla hermana (app_turnos) desde el diseno original de Fase 2 de
-- Seguridad -- no es una excepcion nueva ni puntual, es cerrar una asimetria entre las 2 tablas que el motor
-- de cierre automatico de cuotas siempre trato como una sola unidad (mensajero + turno que lo referencia).
drop policy if exists "authenticated_insert_app_mensajeros" on public.app_mensajeros;
drop policy if exists "authenticated_update_app_mensajeros" on public.app_mensajeros;

create policy "authenticated_insert_app_mensajeros" on public.app_mensajeros
  for insert to authenticated
  with check (
    auth.jwt()->>'app_role' = 'PLANNER'
    or (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
  );

create policy "authenticated_update_app_mensajeros" on public.app_mensajeros
  for update to authenticated
  using (
    auth.jwt()->>'app_role' = 'PLANNER'
    or (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
  )
  with check (
    auth.jwt()->>'app_role' = 'PLANNER'
    or (auth.jwt()->>'app_role' = 'ALIADO' and data->>'aliado' = auth.jwt()->>'aliadoId')
    or (auth.jwt()->>'app_role' = 'BODEGA' and data->>'sede' = auth.jwt()->>'bodegaId')
  );
