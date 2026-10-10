import { Page } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';
import { AppShellPage } from '../pages/AppShellPage';
import { UsersPage, NewUserInput } from '../pages/UsersPage';
import { SEED_USERS } from './constants';
import { findUserByEmail, callLogout } from './state';

/**
 * Flujo completo "Admin crea un usuario nuevo" reutilizado por varios specs del gate de seguridad: inicia
 * sesion como ADMIN (tarjeta de Acceso Rápido), crea el usuario via UsersPage/#formUsuario, lee la clave
 * temporal real resultante (ver support/state.ts -- lectura de window.state, nunca de la UI, porque la UI
 * nunca debe mostrarla) y cierra la sesion de Admin, dejando la pagina en la pantalla de login lista para
 * que el test continue como el usuario nuevo.
 */
export async function createPendingUserAsAdmin(
  page: Page,
  email: string,
  role: NewUserInput['role'] = 'PLANNER'
): Promise<{ email: string; password: string; id: string }> {
  const login = new LoginPage(page);
  await login.goto();
  await login.clickQuickProfile(SEED_USERS.ADMIN.id);
  await new AppShellPage(page).waitForReady();

  const users = new UsersPage(page);
  await users.open();
  await users.createUser({ nombre: 'Usuario QA ' + email.split('@')[0], email, role });
  await page.waitForTimeout(150);

  const created = await findUserByEmail(page, email);
  if (!created) throw new Error(`No se encontró el usuario recién creado: ${email}`);

  await callLogout(page);
  await page.waitForTimeout(150);

  return { email, password: created.password, id: created.id };
}
