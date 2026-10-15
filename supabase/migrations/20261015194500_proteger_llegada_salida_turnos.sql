-- MIGRACIÓN INCREMENTAL 2026-10-15d: Protección a nivel de base de datos contra reversión de
-- llegada/salida en app_turnos.
--
-- Contexto (incidente real): varias marcaciones de llegada/salida corregidas manualmente en producción
-- (Bogotá, Medellín, Cali, Barranquilla) fueron revertidas repetidamente a NULL por un snapshot completo
-- y desactualizado de state.turnos empujado desde una pestaña vieja (ver fix de app.js: scPushAll ahora
-- hace su propio scPullAll() antes de empujar, y registrarLlegadaBodega/registrarSalida empujan su propio
-- cambio de inmediato). Como defensa adicional, a nivel de base de datos, este trigger bloquea de raíz
-- cualquier UPDATE que intente volver NULL un llegada/salida que ya tenía un valor real guardado —
-- sin importar qué pestaña, con qué versión de código, envíe el UPDATE.
--
-- Diseño: en vez de RECHAZAR el UPDATE completo (lo que abortaría también cualquier otro campo legítimo
-- que viniera en el mismo objeto), se PRESERVA en silencio el valor anterior solo para ese campo puntual
-- (llegada/salida), dejando pasar el resto de la fila sin problema. Un cambio legítimo de un valor real A
-- OTRO valor real (ej. corregir 09:18 por 09:19) sigue permitido — solo se bloquea la transición
-- "tenía valor" -> "vacío".
--
-- Nunca se elimina nada existente (create-or-replace, igual que el resto de este archivo).

create or replace function app_turnos_proteger_llegada_salida()
returns trigger as $$
begin
  if (old.data->>'llegada') is not null and (new.data->>'llegada') is null then
    new.data = jsonb_set(new.data, '{llegada}', old.data->'llegada');
  end if;
  if (old.data->>'salida') is not null and (new.data->>'salida') is null then
    new.data = jsonb_set(new.data, '{salida}', old.data->'salida');
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_app_turnos_proteger_llegada_salida on app_turnos;

create trigger trg_app_turnos_proteger_llegada_salida
before update on app_turnos
for each row
execute function app_turnos_proteger_llegada_salida();
