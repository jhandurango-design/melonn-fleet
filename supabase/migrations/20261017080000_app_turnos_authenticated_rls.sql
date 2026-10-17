-- Fase 2 de Seguridad, Etapa C: RLS real sobre app_turnos (espejo de state.turnos -- cada fila es un turno/
-- ruta real: sede, fecha, mensajeroId, vehiculo, hora, llegada/salida/retirado, route.solicitud embebida
-- para reprogramacion/cancelacion, etc.) para el rol `authenticated`.
--
-- ULTIMA tabla de la hoja de ruta de la Etapa C, y la mas delicada: es el camino de "Programar Flota"
-- (submitTurno, carga rapida de Flota Habitual -- carga masiva de hasta decenas de filas en un solo
-- upsert, ver cargarFlotaHabitual) y de Consolidado/Seguimiento/Despacho. Por eso esta politica usa
-- EXCLUSIVAMENTE comparaciones literales baratas para BODEGA/ADMIN/PLANNER/AUDITOR -- la UNICA excepcion,
-- justificada abajo, es ALIADO.
--
-- Rastreado canDo(...) en toda la app + PERMISSIONS (auth.js) para cada mutacion real sobre esta tabla:
-- - 'schedule.aliado.manage' (ALIADO): submitTurno, cargarFlotaHabitual (carga masiva), eliminarTurnoPendiente,
--   desasignarMensajero -- crea/edita/borra EXCLUSIVAMENTE turnos de mensajeros de su PROPIO aliado.
-- - 'despacho.manage' / 'arrival.register' / 'departure.register' / 'incumplimiento.justify' (BODEGA):
--   registrarLlegadaBodega, registrarSalida, justificar, confirmarMensajeroEnBodega, retiro, observaciones,
--   retirarTurnoPendienteFlotaPropiaHoy -- EXCLUSIVAMENTE turnos de su PROPIA sede (data->>'sede').
-- - 'consolidado.manage' (PLANNER): aprobarCuotaPlanner/rechazarCuotaPlanner, resolverArriboAprobar,
--   reprogramaciones y cancelaciones (route.solicitud embebida vía UPDATE, nunca DELETE) -- SIN scoping real
--   (userEffectiveScope() es GLOBAL para Planner; scopeSedes()=[state.activeSede] es solo un filtro de UI,
--   nunca un limite real de permiso -- mismo hallazgo ya confirmado en app_solicitudes_generales/
--   app_mensajeros). Acceso global de lectura Y escritura.
-- - 'schedule.create' / 'schedule.edit' / 'schedule.cancel' (ADMIN, catalogo PERMISSIONS): CONFIRMADO
--   codigo muerto -- openRutaModal (acción 'editar') y la rama 'cancelar' (acción 'cancelar') nunca se
--   renderizan desde ninguna plantilla de fila real (grep de 'data-act="editar"'/'data-act="cancelar"' en
--   app.js: cero resultados, el propio comentario de auth.js ya lo documentaba: "legado pre-separación
--   Aliado/Planner, fuera del alcance de esta auditoría puntual de roles"). Mismo criterio que
--   app_cuotas_config/app_flota_habitual: la política refleja el permiso REAL, no el máximo teórico -- ADMIN
--   NO recibe ningún GRANT de escritura/borrado sobre esta tabla.
-- - AUDITOR: ningún permiso de escritura en PERMISSIONS -- solo lectura, igual que en el resto de tablas.
--
-- EXCEPCION DELIBERADA a "nunca subconsultas" (ver plan Fase 2, Etapa C): a diferencia de app_mensajeros/
-- app_solicitudes_generales (que SI llevan 'aliado'/'data->>aliado' embebido en su propia fila), el turno
-- NUNCA guarda el aliado directamente -- solo mensajeroId (ver routesInScope: el alcance de Aliado se
-- resuelve siempre vía getMensajero(r.mensajeroId).aliado). Por eso la unica forma correcta de aislar a
-- ALIADO es un EXISTS contra app_mensajeros por id -- PERO ese id es primary key (ver supabase_schema.sql:
-- "id text primary key"), así que es un lookup indexado O(log n) por fila, no un join costoso ni un escaneo
-- -- mismo costo que cualquier FK constraint que Postgres ya evalúa en cada INSERT con FK real. Se verifica
-- explícitamente abajo con un upsert masivo cronometrado antes de dar esta migración por cerrada.
--
-- CUIDADO (encontrado durante la verificación en producción de esta misma migración, antes de darla por
-- buena -- nunca llegó a desplegarse rota de forma permanente): dentro del EXISTS, una referencia SIN
-- calificar a "data" es ambigua entre app_turnos.data (tabla externa de la política) y app_mensajeros.data
-- (alias m, tabla del propio EXISTS) -- Postgres la resuelve SIEMPRE contra la tabla del scope más interno
-- (m.data), nunca contra la externa, sin avisar con ningún error. El resultado real observado fue
-- "m.id = (m.data->>'mensajeroId')" -- comparación que nunca es cierta (un mensajero no tiene esa clave en
-- su propio data), por lo que el EXISTS daba SIEMPRE falso y ALIADO quedaba bloqueado de TODO -- lectura,
-- creación y borrado -- sobre su propia flota. Por eso aquí la tabla externa se referencia siempre
-- calificada como "app_turnos.data", nunca como "data" a secas, dentro de cualquier EXISTS/subconsulta.
--
-- RIESGO DETECTADO, A DOCUMENTAR PARA EL PASO DE RECONEXIÓN (no bloqueante hoy -- ningún llamador de app.js
-- usa todavía el cliente authenticated para app_turnos/app_mensajeros): cargarFlotaHabitual() dispara el
-- push de app_mensajeros (mensajeros nuevos) y el push de app_turnos (turnos nuevos que los referencian) EN
-- PARALELO (Promise.all, no secuencial) -- ver líneas 13810-13811 de app.js. Si algún día esto corre bajo
-- RLS, el EXISTS de la política de INSERT de un turno podría evaluarse ANTES de que el INSERT del mensajero
-- nuevo correspondiente haya comprometido su transacción, bloqueando el turno por una carrera, no por un
-- permiso real. Cuando llegue el paso dedicado de reconexión, esto exige o bien esperar (await) el push de
-- mensajeros antes de lanzar el de turnos, o combinarlos en una única llamada transaccional.
--
-- SEGUNDO RIESGO DETECTADO, mismo destino (paso de reconexión): asegurarFlotaPropiaSembrada() (llamada desde
-- syncAndRender en CUALQUIER sesión con state.user, sin importar su rol) siembra turnos nuevos de Flota
-- Propia (mensajeros de Bodega) directamente en state.turnos EN MEMORIA, sin filtrar por rol -- el próximo
-- scPushAll() periódico de ESA sesión (sea ADMIN, AUDITOR, Planner o Aliado) intentaría insertarlos. Esta
-- política solo concede INSERT real a BODEGA/ALIADO(propio)/PLANNER -- una sesión ADMIN o AUDITOR que
-- dispare ese autoguardado fallaría silenciosamente en ESA fila puntual (scPushRows ya tolera fallos
-- parciales sin romper nada más), quedando pendiente de que una sesión BODEGA/PLANNER la sincronice después.
-- No es un hueco de seguridad -- es solo un retraso de sincronización -- pero debe quedar en la lista del
-- paso de reconexión, no resuelto aquí.
--
-- Mismo criterio que las migraciones anteriores: las politicas "anon_*" existentes NO se tocan, siguen en
-- paralelo; esta migracion tampoco conecta ningun llamador de app.js todavia -- queda agrupada en el paso
-- dedicado de reconexion al final de la Etapa C.
grant select, insert, update, delete on public.app_turnos to authenticated;

drop policy if exists "authenticated_select_app_turnos" on public.app_turnos;
drop policy if exists "authenticated_insert_app_turnos" on public.app_turnos;
drop policy if exists "authenticated_update_app_turnos" on public.app_turnos;
drop policy if exists "authenticated_delete_app_turnos" on public.app_turnos;

create policy "authenticated_select_app_turnos" on public.app_turnos
  for select to authenticated
  using (
    auth.jwt()->>'app_role' in ('ADMIN', 'PLANNER', 'AUDITOR')
    or (auth.jwt()->>'app_role' = 'BODEGA' and app_turnos.data->>'sede' = auth.jwt()->>'bodegaId')
    or (
      auth.jwt()->>'app_role' = 'ALIADO'
      and exists (
        select 1 from public.app_mensajeros m
        where m.id = app_turnos.data->>'mensajeroId' and m.data->>'aliado' = auth.jwt()->>'aliadoId'
      )
    )
  );

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
  );

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

create policy "authenticated_delete_app_turnos" on public.app_turnos
  for delete to authenticated
  using (
    (auth.jwt()->>'app_role' = 'BODEGA' and app_turnos.data->>'sede' = auth.jwt()->>'bodegaId')
    or (
      auth.jwt()->>'app_role' = 'ALIADO'
      and exists (
        select 1 from public.app_mensajeros m
        where m.id = app_turnos.data->>'mensajeroId' and m.data->>'aliado' = auth.jwt()->>'aliadoId'
      )
    )
  );
