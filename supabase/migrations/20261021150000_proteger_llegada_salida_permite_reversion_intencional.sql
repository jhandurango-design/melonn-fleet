-- MIGRACIÓN INCREMENTAL 2026-10-21: Afina app_turnos_proteger_llegada_salida() para permitir la
-- reversión INTENCIONAL de llegada/salida (ver migración 20261015194500), sin perder la protección
-- original contra un snapshot completo/desactualizado empujado desde una pestaña vieja.
--
-- Bug encontrado en vivo (reporte real): el botón "Retroceder Estado" del Planner (revertirEstado() en
-- app.js) -- y, por el mismo motivo, la reasignación de mensajero tras un retiro/no-autoriza-despacho
-- (aplicarSolicitudGeneral(), ramas 'reemplazo_alerta'/'reemplazo_cancelacion', que reabren el ciclo del
-- turno limpiando llegada/salida para el mensajero de reemplazo) -- quedaban SILENCIOSAMENTE bloqueados
-- por este mismo trigger: el Planner confirmaba la reversión, el toast decía "Estado revertido", pero el
-- valor nunca cambiaba en Supabase porque el trigger original restauraba ciegamente cualquier intento de
-- volver NULL un llegada/salida ya poblado, sin distinguir una corrección intencional (con su propia
-- entrada nueva en el Historial del Turno) de un empuje ciego de una pestaña vieja (sin ninguna entrada
-- nueva, solo repite lo que ya tenía en caché).
--
-- Señal usada para distinguir ambos casos: TODA mutación intencional de llegada/salida en el código de la
-- app (revertirEstado, aplicarSolicitudGeneral) SIEMPRE llama primero a registrarHistorialCambio(), que
-- hace .push() de una entrada nueva a route.historialCambios -- así que el array de historial del UPDATE
-- entrante es estrictamente MÁS LARGO que el que ya existe en la fila. Un empuje ciego de una pestaña
-- vieja (el caso que esta protección existe para bloquear) nunca trae un historial más largo que el ya
-- guardado -- en el peor caso, igual; nunca más corto, porque un historial solo crece. Si el historial
-- entrante creció, se confía en el UPDATE completo (incluida la reversión de llegada/salida); si no
-- creció, se mantiene exactamente el comportamiento de blindaje original.
create or replace function app_turnos_proteger_llegada_salida()
returns trigger as $$
declare
  old_hist_len int := coalesce(jsonb_array_length(old.data->'historialCambios'), 0);
  new_hist_len int := coalesce(jsonb_array_length(new.data->'historialCambios'), 0);
begin
  if new_hist_len > old_hist_len then
    return new;
  end if;
  if (old.data->>'llegada') is not null and (new.data->>'llegada') is null then
    new.data = jsonb_set(new.data, '{llegada}', old.data->'llegada');
  end if;
  if (old.data->>'salida') is not null and (new.data->>'salida') is null then
    new.data = jsonb_set(new.data, '{salida}', old.data->'salida');
  end if;
  return new;
end;
$$ language plpgsql;
