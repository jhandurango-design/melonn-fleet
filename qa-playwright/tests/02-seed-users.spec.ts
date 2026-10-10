import { expect } from '@playwright/test';
import { test } from '../fixtures/auth.fixture';
import { test as base } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';
import { AppShellPage } from '../pages/AppShellPage';
import { ForcePasswordModalPage } from '../pages/ForcePasswordModalPage';
import { SEED_USER_MX_BODEGA, SEED_USER_MX_ALIADO, SEED_USER_INACTIVE } from '../support/constants';
import { getCurrentUser } from '../support/state';

/**
 * Regresión: los usuarios semilla/demo (sin mustChangePassword) deben seguir entrando directo, sin que el
 * nuevo gate de "Implementación de Modelo de Seguridad First-Time Login" los afecte.
 */
test.describe('Usuarios semilla — sin gate de cambio obligatorio', () => {
  test('ADMIN (Jhan Durango) entra directo', async ({ adminPage }) => {
    const modal = new ForcePasswordModalPage(adminPage);
    expect(await modal.isOpen()).toBe(false);
    expect((await getCurrentUser(adminPage))?.role).toBe('ADMIN');
  });

  test('PLANNER (Diana Salcedo) entra directo', async ({ plannerPage }) => {
    expect(await new ForcePasswordModalPage(plannerPage).isOpen()).toBe(false);
    expect((await getCurrentUser(plannerPage))?.role).toBe('PLANNER');
  });

  test('BODEGA (Rocío Fajardo) entra directo', async ({ bodegaPage }) => {
    expect(await new ForcePasswordModalPage(bodegaPage).isOpen()).toBe(false);
    expect((await getCurrentUser(bodegaPage))?.role).toBe('BODEGA');
  });

  test('ALIADO (Andrés Peña) entra directo', async ({ aliadoPage }) => {
    expect(await new ForcePasswordModalPage(aliadoPage).isOpen()).toBe(false);
    expect((await getCurrentUser(aliadoPage))?.role).toBe('ALIADO');
  });

  test('AUDITOR (Marcela Uribe) entra directo', async ({ auditorPage }) => {
    expect(await new ForcePasswordModalPage(auditorPage).isOpen()).toBe(false);
    expect((await getCurrentUser(auditorPage))?.role).toBe('AUDITOR');
  });
});

/** Perfiles multi-país y el usuario inactivo no tienen fixture propio (no son 1 por rol) -- se prueban aparte. */
base.describe('Usuarios semilla — arquitectura multi-país y cuenta inactiva', () => {
  base('BODEGA México (Renata Cabrera) entra directo, sin gate', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.clickQuickProfile(SEED_USER_MX_BODEGA.id);
    const shell = new AppShellPage(page);
    await shell.waitForReady();
    expect(await new ForcePasswordModalPage(page).isOpen()).toBe(false);
    expect((await getCurrentUser(page))?.email).toBe(SEED_USER_MX_BODEGA.email);
  });

  base('ALIADO México (Emiliano Duarte) entra directo, sin gate', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.clickQuickProfile(SEED_USER_MX_ALIADO.id);
    const shell = new AppShellPage(page);
    await shell.waitForReady();
    expect(await new ForcePasswordModalPage(page).isOpen()).toBe(false);
    expect((await getCurrentUser(page))?.email).toBe(SEED_USER_MX_ALIADO.email);
  });

  base('u8 (Rodrigo Salinas, inactivo) no tiene tarjeta de Acceso Rápido y su login manual es rechazado', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    expect(await login.quickProfileCard(SEED_USER_INACTIVE.id).count()).toBe(0);

    await login.loginWithForm(SEED_USER_INACTIVE.email, 'melonn2026');
    await page.waitForTimeout(200);
    expect(await login.getErrorText()).toContain('inactivo');
    expect(await new AppShellPage(page).isVisible()).toBe(false);
  });
});
