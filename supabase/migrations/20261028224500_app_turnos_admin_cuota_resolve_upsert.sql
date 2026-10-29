-- Complemento a la migración 20261028223000_app_turnos_admin_cuota_resolve.sql -- CORRIGE un hallazgo real
-- de la verificación en producción de esa misma migración (antes de darla por buena -- nunca llegó a
-- desplegarse rota de forma permanente, mismo criterio de disciplina que las migraciones anteriores de este
-- archivo): esa migración solo ampliaba la política de UPDATE, pero scPushRows (app.js) NUNCA emite un
-- UPDATE puro -- siempre usa .upsert(payload), que Postgres ejecuta como
-- "INSERT ... ON CONFLICT (id) DO UPDATE". Para ESE comando, RLS exige que la fila propuesta pase también el
-- WITH CHECK de la política de INSERT (no solo la de UPDATE) -- aunque conceptualmente sea "solo actualizar"
-- una fila que ya existe. Confirmado con una prueba SQL directa (set local role authenticated; set local
-- request.jwt.claims con app_role=ADMIN; UPDATE puro) que SÍ funcionaba, mientras el flujo real de la app
-- (aprobarCuotaPlanner -> scPushRows -> upsert) seguía fallando -- la única diferencia era justo ese segundo
-- gate de INSERT, sin tocar todavía.
--
-- Alcance: igual de estrecho que la migración anterior, pero evaluado sobre la fila PROPUESTA (WITH CHECK de
-- INSERT no tiene fila "antes", a diferencia de USING en UPDATE) -- se exige que la fila que ADMIN intenta
-- escribir ya traiga cuotaAprobacion poblado, que es EXACTAMENTE lo que aprobarCuotaPlanner/
-- rechazarCuotaPlanner escriben siempre (en ambos desenlaces, aprobado o rechazado) y nada más en el código
-- actual de app.js escribe ese campo. ADMIN no gana permiso para insertar un turno "en blanco" cualquiera --
-- solo para confirmar, vía upsert, una fila que ya es resultado de resolver una excepción de cuota/festivo.
drop policy if exists "authenticated_insert_app_turnos" on public.app_turnos;

create policy "authenticated_insert_app_turnos" on public.app_turnos
  for insert to authenticated
  with check (
    (auth.jwt()->>'app_role' = 'BODEGA' and app_turnos.data->>'sede' = auth.jwt()->>'bodegaId')
    or (
      auth.jwt()->>'app_role' = 'ALIADO'
      and exists (
        select 1 from public.app_mensajeros m
        where m.id = app_turnos.data->>'mensajeroId' and m.data->>'aliado' = auth.jwt()->>'aliadoId'
      )
    )
    or auth.jwt()->>'app_role' = 'PLANNER'
    or (
      auth.jwt()->>'app_role' = 'ADMIN'
      and app_turnos.data ? 'cuotaAprobacion'
      and app_turnos.data->'cuotaAprobacion' is not null
    )
  );

-- Reconstruida en la migración anterior; el reload de abajo cubre las 2 juntas igual.
NOTIFY pgrst, 'reload schema';
