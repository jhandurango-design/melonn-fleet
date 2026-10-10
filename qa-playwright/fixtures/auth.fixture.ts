import { test as base, Page, Browser } from '@playwright/test';
import { APP_URL, SEED_USERS, Role } from '../support/constants';
import { LoginPage } from '../pages/LoginPage';
import { AppShellPage } from '../pages/AppShellPage';

type AuthFixtures = {
  adminPage: Page;
  plannerPage: Page;
  bodegaPage: Page;
  aliadoPage: Page;
  auditorPage: Page;
};

/**
 * Fixtures de autenticacion por rol: cada una abre un contexto/pagina nueva y hace el login real via la
 * tarjeta de "Acceso Rápido de Demostración" para ese rol -- una sola vez por test, sin que cada spec tenga
 * que repetir goto()+clickQuickProfile()+waitForReady() a mano. (Nota: se evaluo reusar sesiones guardadas
 * con context.storageState() para saltarse incluso ese clic, pero Playwright no restaura de forma
 * confiable el localStorage de paginas file:// entre contextos en este entorno -- login() aqui sigue
 * siendo el camino real y mas rapido es solo un clic.)
 */
export const test = base.extend<AuthFixtures>({
  adminPage: async ({ browser }, use) => await loginAs(browser, 'ADMIN', use),
  plannerPage: async ({ browser }, use) => await loginAs(browser, 'PLANNER', use),
  bodegaPage: async ({ browser }, use) => await loginAs(browser, 'BODEGA', use),
  aliadoPage: async ({ browser }, use) => await loginAs(browser, 'ALIADO', use),
  auditorPage: async ({ browser }, use) => await loginAs(browser, 'AUDITOR', use),
});

async function loginAs(browser: Browser, role: Role, use: (page: Page) => Promise<void>): Promise<void> {
  const context = await browser.newContext();
  const page = await context.newPage();
  const login = new LoginPage(page);
  await login.goto();
  await login.clickQuickProfile(SEED_USERS[role].id);
  await new AppShellPage(page).waitForReady();
  await use(page);
  await context.close();
}

export { expect } from '@playwright/test';
