/* ==========================================================================
   Melonn Fleet — Módulo de Autenticación y Permisos (desacoplado)
   No depende de `state` ni de ningún otro global de app.js: guarda su propia
   copia de los claims de sesión y se limita a responder preguntas de rol y
   permiso. app.js es quien lo alimenta (Auth.setCurrentUser) al iniciar o
   cerrar sesión — el resto de la app solo lo consulta.

   Los claims replican la forma de un idToken de AWS Cognito para que, el día
   que se conecte Cognito/Amplify de verdad, solo haya que reemplazar
   setCurrentUser() por el resultado real de Auth.currentAuthenticatedUser()
   (o el decode del idToken), sin tocar a los consumidores (hasPermission,
   getUserRole, getUserScopes).
   ========================================================================== */
(function (global) {
  var currentClaims = null;

  /* Único catálogo de permisos de la app — antes vivía duplicado como un
     switch dentro de canDo() en app.js; ahora es la fuente única de verdad. */
  /* Ver requerimiento "Auditoría y Depuración del Concepto Heredado 'Admin/Planner' en Textos y Lógica de
     Roles": ADMIN es exclusivamente configuración de plataforma y administración de usuarios -- NUNCA
     gestión ni decisiones operativas en vivo (eso es 100% de PLANNER, o de BODEGA en lo físico de su propia
     sede). 'schedule.create/edit/cancel' quedan ADMIN-only sin tocar: no son una fusión con otro rol
     operativo, y no tienen ningún llamador vivo en la UI actual (openRutaModal/#modalRuta -- legado
     pre-separación Aliado/Planner, fuera del alcance de esta auditoría puntual de roles). */
  var PERMISSIONS = {
    'schedule.create': ['ADMIN'],
    'schedule.edit': ['ADMIN'],
    'schedule.cancel': ['ADMIN'],
    'arrival.register': ['BODEGA'],
    'departure.register': ['BODEGA'],
    'incumplimiento.justify': ['BODEGA'],
    'consolidado.manage': ['PLANNER'],
    'solicitud.resolve': ['PLANNER', 'ALIADO'],
    'solicitud.resolve.general': ['PLANNER'],
    /* Ver requerimiento "Reestructuración y Optimización Integral de Solicitudes y Cambios -- Rol Planner",
       punto 4 (Permisos de Contingencia en Excepciones de Cuota/Festivo): permiso DEDICADO, deliberadamente
       separado de 'solicitud.resolve.general' -- ese sigue siendo PLANNER-only para Nuevo Turno/Cupo
       Adicional/Edición/Reemplazos/Prolongación (Mecanismo B), donde ADMIN nunca debe gestionar ni decidir
       operativamente (ver nota de ADMIN más abajo). Ampliar el permiso compartido en vez de crear este nuevo
       habría abierto ADMIN a TODO el Mecanismo B sin que se haya pedido ni evaluado eso. Solo cubre
       aprobarCuotaPlanner/rechazarCuotaPlanner (Mecanismo C) -- requiere además la migración SQL que concede
       a ADMIN el UPDATE real sobre app_turnos para este caso (ver supabase/migrations/..._app_turnos_admin_cuota.sql);
       sin ella, el botón se vería habilitado pero el guardado fallaría siempre por RLS. */
    'cuota.resolve': ['PLANNER', 'ADMIN'],
    'solicitud.create.aliado': ['ALIADO'],
    'solicitud.create.planner': ['PLANNER'],
    'despacho.manage': ['BODEGA'],
    'flotaPropia.manage': ['BODEGA'],
    'schedule.aliado.manage': ['ALIADO'],
    'users.manage': ['ADMIN'],
    /* Visibilidad de selectores del formulario de filtros de Alertas (por rol). */
    'alertas.filter.bodega': ['ADMIN', 'PLANNER', 'ALIADO'],
    'alertas.filter.aliado': ['ADMIN', 'PLANNER', 'BODEGA'],
    /* Gestor de Avisos a Aliados -- ver requerimiento "Ajustes Integrales de Arquitectura, UX y Filtros en el
       Módulo de Comunicaciones", Bloque 2: ADMIN ya no gestiona ni recibe comunicados operativos (antes sí,
       ver historial de este permiso) -- PLANNER queda como único redactor/publicador. */
    'avisos.manage': ['PLANNER'],
  };

  /* claims: { username, role, bodegaId, aliadoId } — forma de un idToken de Cognito. */
  function setCurrentUser(claims) { currentClaims = claims; }
  function clearCurrentUser() { currentClaims = null; }
  function getCurrentClaims() { return currentClaims; }

  function getUserRole() { return currentClaims ? currentClaims.role : null; }

  function getUserScopes() {
    return {
      bodegaId: currentClaims ? (currentClaims.bodegaId || null) : null,
      aliadoId: currentClaims ? (currentClaims.aliadoId || null) : null,
    };
  }

  function hasPermission(permissionName) {
    if (!currentClaims) return false;
    var allowedRoles = PERMISSIONS[permissionName];
    return !!allowedRoles && allowedRoles.indexOf(currentClaims.role) !== -1;
  }

  global.Auth = {
    setCurrentUser: setCurrentUser,
    clearCurrentUser: clearCurrentUser,
    getCurrentClaims: getCurrentClaims,
    getUserRole: getUserRole,
    getUserScopes: getUserScopes,
    hasPermission: hasPermission,
  };
})(window);
