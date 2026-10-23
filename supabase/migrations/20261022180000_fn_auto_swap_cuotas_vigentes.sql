-- Ver requerimiento "Transición Automática Servidor-Side de Cuotas": cuotasAutoSwapVigencia() (app.js) solo
-- corría en el cliente (al arrancar la app y en cada renderCuotas()) -- si nadie abre la plataforma el día
-- exacto en que vence cuotasFechaProxima, la Próxima Cuota nunca pasa a ser Cuota Vigente hasta que alguien
-- entra. Esta migración mueve el swap al servidor vía pg_cron, para que corra siempre, sin depender de que
-- haya un usuario con la app abierta. app.js conserva cuotasAutoSwapVigencia() sin cambios como fallback en
-- memoria (una pestaña abierta justo en el instante de corte, o un pull que llega antes de que el cron haya
-- corrido ese ciclo).
--
-- app_cuotas_config es una sola fila global (id='global'), con data jsonb = {matriz, franjas, franjasMX,
-- matrizProxima, fechaProxima, bannerCO, observaciones} -- ver scPushCuotasConfig() en app.js. El swap mueve
-- matrizProxima a matriz y limpia matrizProxima/fechaProxima, exactamente como cuotasAutoSwapVigencia() en JS.
--
-- Zona horaria: TODAY_STR en app.js se deriva SIEMPRE de la fecha real en America/Bogotá (bogotaTodayStr(),
-- re-derivada cada segundo -- ver requerimiento "Riesgo de Zona Horaria en TODAY_STR/TOMORROW_STR", y
-- "Desconexión del Reloj Simulado": ya no hay ningún reloj simulado/congelable en producción). Por eso esta
-- función compara contra (now() at time zone 'America/Bogota')::date, nunca contra CURRENT_DATE crudo (que en
-- Supabase corre en UTC) -- así el corte de día del servidor coincide exactamente con el que ya usa el cliente.

create extension if not exists pg_cron;

create or replace function public.fn_auto_swap_cuotas_vigentes()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fecha_proxima date;
  v_hoy_bogota date;
begin
  v_hoy_bogota := (now() at time zone 'America/Bogota')::date;

  select (data->>'fechaProxima')::date into v_fecha_proxima
  from public.app_cuotas_config
  where id = 'global';

  if v_fecha_proxima is not null and v_hoy_bogota >= v_fecha_proxima then
    update public.app_cuotas_config
    set data = jsonb_set(
      jsonb_set(
        jsonb_set(data, '{matriz}', coalesce(data->'matrizProxima', '[]'::jsonb)),
        '{matrizProxima}', '[]'::jsonb
      ),
      '{fechaProxima}', 'null'::jsonb
    )
    where id = 'global';
  end if;
end;
$$;

-- Idempotente (si fechaProxima ya es null o no venció, no hace nada) -- correrla cada 15 minutos es gratis y
-- auto-recuperable ante cualquier falla puntual de un solo tick (mantenimiento de Supabase, etc.), a
-- diferencia de un cron de "una sola vez al día" que perdería el swap entero si ese minuto exacto falla.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'auto-swap-cuotas-vigentes') then
    perform cron.unschedule('auto-swap-cuotas-vigentes');
  end if;
end;
$$;
select cron.schedule(
  'auto-swap-cuotas-vigentes',
  '*/15 * * * *',
  $$select public.fn_auto_swap_cuotas_vigentes();$$
);
