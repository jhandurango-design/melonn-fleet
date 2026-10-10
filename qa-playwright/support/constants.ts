/**
 * Espejo de constantes reales de la aplicacion (app.js), SOLO para que las aserciones de esta suite
 * sepan que esperar -- esta suite nunca importa ni ejecuta app.js directamente, solo lo abre en el
 * navegador como caja negra via file://. Si estos valores cambian en app.js, hay que actualizarlos aqui
 * tambien (no hay import real que los mantenga sincronizados automaticamente).
 */
import * as path from 'path';

export const APP_PATH = path.resolve(__dirname, '..', '..', 'index.html');
export const APP_URL = 'file:///' + APP_PATH.replace(/\\/g, '/');

export type Role = 'ADMIN' | 'PLANNER' | 'BODEGA' | 'ALIADO' | 'AUDITOR';
export const ROLES: Role[] = ['ADMIN', 'PLANNER', 'BODEGA', 'ALIADO', 'AUDITOR'];

/** Ver app.js, const USERS (linea ~282) -- usuarios semilla/demo, con password 'melonn2026'. */
export const SEED_USERS: Record<Role, { id: string; email: string; nombre: string }> = {
  ADMIN: { id: 'u1', email: 'jhan.durango@melonn.com', nombre: 'Jhan Durango' },
  PLANNER: { id: 'u5', email: 'diana.salcedo@melonn.com', nombre: 'Diana Salcedo' },
  BODEGA: { id: 'u2', email: 'rocio.fajardo@melonn.com', nombre: 'Rocío Fajardo' },
  ALIADO: { id: 'u3', email: 'andres.pena@cordiandina.co', nombre: 'Andrés Peña' },
  AUDITOR: { id: 'u4', email: 'marcela.uribe@melonn.com', nombre: 'Marcela Uribe' },
};
export const SEED_PASSWORD = 'melonn2026';

/** Usuarios semilla extra usados en specs puntuales (arquitectura multi-pais, usuario inactivo). */
export const SEED_USER_MX_BODEGA = { id: 'u6', email: 'bodega.cdmx@melonn.com', nombre: 'Renata Cabrera' };
export const SEED_USER_MX_ALIADO = { id: 'u7', email: 'aliado.mx@proveedor.com', nombre: 'Emiliano Duarte' };
export const SEED_USER_INACTIVE = { id: 'u8', email: 'flota.directa@melonn.com', nombre: 'Rodrigo Salinas' };

/** Ver app.js, const QUICK_PROFILE_IDS (linea ~300) -- u8 queda fuera a proposito (usuario inactivo). */
export const QUICK_PROFILE_IDS = ['u1', 'u5', 'u2', 'u3', 'u4', 'u6', 'u7'];

/**
 * Ver app.js, const ROLE_VIEWS (linea ~1014): catalogo ESTATICO de vistas que cada rol puede llegar a ver.
 * 'usuarios' aparece en ROLE_VIEWS.ADMIN pero NUNCA se renderiza como nav-item real en el sidebar (ver
 * renderSidebar: `item.id !== 'usuarios'`) -- es solo el identificador de permiso que controla la pestaña
 * "Usuarios" dentro de la vista real 'permisos' (#view-permisos, titulo "Gestión de Usuarios").
 */
export const ROLE_VIEWS: Record<Role, string[]> = {
  ADMIN: ['inicio', 'usuarios', 'vehiculos', 'bodegas-aliados', 'permisos', 'configuracion', 'ayuda', 'cuotas', 'comunicaciones'],
  PLANNER: ['inicio', 'consolidado', 'despacho', 'calculador', 'alertas', 'solicitudes', 'cumplimiento', 'ayuda', 'cuotas', 'comunicaciones'],
  BODEGA: ['inicio', 'despacho', 'alertas', 'solicitudes', 'flota-propia', 'ayuda'],
  ALIADO: ['inicio', 'programacion', 'seguimiento', 'alertas', 'solicitudes', 'cumplimiento', 'ayuda', 'cuotas'],
  AUDITOR: ['inicio', 'auditoria', 'despacho', 'cuotas', 'cumplimiento', 'ayuda'],
};

/** Vistas de ROLE_VIEWS que nunca llegan a ser un nav-item real del sidebar (ver comentario arriba). */
export const SIDEBAR_HIDDEN_VIEW_IDS = ['usuarios'];

/**
 * Ver app.js, const NAV_GROUPS (linea ~1076): acordeones colapsables del sidebar. Cada vista listada aqui
 * vive dentro de un `.nav-category` con cabecera `.nav-category-header[data-cat="<catId>"]` en vez de ser
 * un `.nav-item` de primer nivel suelto.
 */
export const NAV_GROUPS: Record<string, { catId: string; ids: string[] }> = {
  programacion: { catId: 'programacion', ids: ['consolidado', 'despacho', 'calculador', 'cuotas'] },
  aliado_prog_flota: { catId: 'aliado_prog_flota', ids: ['seguimiento', 'programacion', 'cuotas'] },
  auditor_programacion: { catId: 'auditor_programacion', ids: ['despacho', 'cuotas'] },
  admin_config: { catId: 'admin_config', ids: ['configuracion', 'cuotas', 'vehiculos'] },
};

/**
 * Muestra representativa (no exhaustiva) de vistas vedadas por rol -- un subconjunto de "todas las
 * vistas de OTROS roles que no aparecen en ROLE_VIEWS[role]", usada por el spec de RBAC para probar
 * negativos sin tener que enumerar el catalogo completo de NAV_ITEMS.
 */
export const FORBIDDEN_SAMPLE: Record<Role, string[]> = {
  ADMIN: ['despacho', 'alertas', 'solicitudes', 'cumplimiento', 'auditoria'],
  PLANNER: ['vehiculos', 'bodegas-aliados', 'permisos', 'auditoria', 'flota-propia'],
  BODEGA: ['cumplimiento', 'cuotas', 'comunicaciones', 'permisos', 'calculador'],
  ALIADO: ['despacho', 'permisos', 'vehiculos', 'auditoria', 'flota-propia'],
  AUDITOR: ['permisos', 'vehiculos', 'solicitudes', 'alertas', 'consolidado'],
};
