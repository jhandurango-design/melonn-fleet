import { expect } from '@playwright/test';
import { test } from '../fixtures/auth.fixture';
import { test as base, Page } from '@playwright/test';
import { AppShellPage } from '../pages/AppShellPage';
import { LoginPage } from '../pages/LoginPage';
import { ROLE_VIEWS, SIDEBAR_HIDDEN_VIEW_IDS, FORBIDDEN_SAMPLE, Role, SEED_USER_MX_BODEGA } from '../support/constants';

/**
 * Permisos y navegación por rol: para cada uno de los 5 roles reales (ROLE_VIEWS, app.js linea ~1014), el
 * sidebar debe exponer exactamente sus vistas permitidas y ninguna otra. 'usuarios' es un caso especial: esta
 * en ROLE_VIEWS.ADMIN pero NUNCA se renderiza como nav-item (ver renderSidebar, filtra item.id!=='usuarios')
 * -- solo gobierna la pestaña "Usuarios" dentro de la vista real 'permisos'.
 */

async function assertAllowedViewsPresent(page: Page, role: Role, extraExclude: string[] = []) {
  const shell = new AppShellPage(page);
  for (const viewId of ROLE_VIEWS[role]) {
    if (SIDEBAR_HIDDEN_VIEW_IDS.includes(viewId) || extraExclude.includes(viewId)) continue;
    expect(await shell.hasNavItem(viewId), `${role} debería tener "${viewId}" en el sidebar`).toBe(true);
  }
}

async function assertForbiddenViewsAbsent(page: Page, role: Role) {
  const shell = new AppShellPage(page);
  for (const viewId of FORBIDDEN_SAMPLE[role]) {
    expect(await shell.hasNavItem(viewId), `${role} NO debería tener "${viewId}" en el sidebar`).toBe(false);
  }
}

test.describe('RBAC — vistas permitidas y vedadas por rol', () => {
  test('ADMIN: ve sus módulos de plataforma y no ve módulos operativos de otros roles', async ({ adminPage }) => {
    await assertAllowedViewsPresent(adminPage, 'ADMIN');
    await assertForbiddenViewsAbsent(adminPage, 'ADMIN');

    const shell = new AppShellPage(adminPage);
    // 'usuarios' nunca es un nav-item real; el acceso real a "Gestión de Usuarios" es la vista 'permisos'.
    expect(await shell.hasNavItem('usuarios')).toBe(false);
    expect(await shell.hasNavItem('permisos')).toBe(true);
    expect(await shell.currentViewId(), 'DEFAULT_VIEW debe aterrizar en inicio').toBe('inicio');
  });

  test('PLANNER: ve sus módulos operativos y no ve administración ni auditoría', async ({ plannerPage }) => {
    await assertAllowedViewsPresent(plannerPage, 'PLANNER');
    await assertForbiddenViewsAbsent(plannerPage, 'PLANNER');
    expect(await new AppShellPage(plannerPage).currentViewId()).toBe('inicio');
  });

  test('BODEGA: ve solo su operación diaria, sin Cumplimiento/Cuotas/Comunicaciones', async ({ bodegaPage }) => {
    // 'flota-propia' esta en ROLE_VIEWS.BODEGA pero es ademas condicional al PAIS de la sede del usuario
    // (ver app.js, allowedViewsForUser/esFlotaPropia): solo la ve la Bodega de Ciudad de México. El fixture
    // bodegaPage usa a Rocío Fajardo (u2, Bogotá/CO), asi que se excluye aqui y se prueba aparte abajo.
    await assertAllowedViewsPresent(bodegaPage, 'BODEGA', ['flota-propia']);
    expect(await new AppShellPage(bodegaPage).hasNavItem('flota-propia'), 'Bodega CO no debe ver Flota Propia').toBe(false);
    await assertForbiddenViewsAbsent(bodegaPage, 'BODEGA');
    expect(await new AppShellPage(bodegaPage).currentViewId()).toBe('inicio');
  });

  base('BODEGA México (Renata Cabrera) sí ve "Flota Propia", exclusiva de esa sede', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.clickQuickProfile(SEED_USER_MX_BODEGA.id);
    const shell = new AppShellPage(page);
    await shell.waitForReady();
    expect(await shell.hasNavItem('flota-propia')).toBe(true);
  });

  test('ALIADO: ve su programación y seguimiento, sin administración ni auditoría', async ({ aliadoPage }) => {
    await assertAllowedViewsPresent(aliadoPage, 'ALIADO');
    await assertForbiddenViewsAbsent(aliadoPage, 'ALIADO');
    expect(await new AppShellPage(aliadoPage).currentViewId()).toBe('inicio');
  });

  test('AUDITOR: ve su set de solo consulta, sin Solicitudes/Alertas/Consolidado', async ({ auditorPage }) => {
    await assertAllowedViewsPresent(auditorPage, 'AUDITOR');
    await assertForbiddenViewsAbsent(auditorPage, 'AUDITOR');
    expect(await new AppShellPage(auditorPage).currentViewId()).toBe('inicio');
  });
});

test.describe('RBAC — navegación real dentro de los acordeones colapsables (NAV_GROUPS)', () => {
  test('PLANNER puede navegar a "Cuotas de Flota" dentro del acordeón "Programación"', async ({ plannerPage }) => {
    const shell = new AppShellPage(plannerPage);
    await shell.clickNavItem('cuotas');
    await plannerPage.waitForTimeout(150);
    expect(await shell.currentViewId()).toBe('cuotas');
  });

  test('ALIADO puede navegar a "Cuotas de Flota" dentro del acordeón "Programación de Flota"', async ({ aliadoPage }) => {
    const shell = new AppShellPage(aliadoPage);
    await shell.clickNavItem('cuotas');
    await aliadoPage.waitForTimeout(150);
    expect(await shell.currentViewId()).toBe('cuotas');
  });

  test('AUDITOR puede navegar a "Programación" (despacho) dentro de su acordeón', async ({ auditorPage }) => {
    const shell = new AppShellPage(auditorPage);
    await shell.clickNavItem('despacho');
    await auditorPage.waitForTimeout(150);
    expect(await shell.currentViewId()).toBe('despacho');
  });

  test('ADMIN puede navegar a "Gestión de Vehículos" dentro del acordeón "Configuración"', async ({ adminPage }) => {
    const shell = new AppShellPage(adminPage);
    await shell.clickNavItem('vehiculos');
    await adminPage.waitForTimeout(150);
    expect(await shell.currentViewId()).toBe('vehiculos');
  });

  test('BODEGA (sin acordeón) navega directo a "Programación" (despacho)', async ({ bodegaPage }) => {
    const shell = new AppShellPage(bodegaPage);
    await shell.clickNavItem('despacho');
    await bodegaPage.waitForTimeout(150);
    expect(await shell.currentViewId()).toBe('despacho');
  });
});
