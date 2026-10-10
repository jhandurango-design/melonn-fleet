import { test, expect } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';
import { AppShellPage } from '../pages/AppShellPage';
import { UsersPage } from '../pages/UsersPage';
import { ForcePasswordModalPage } from '../pages/ForcePasswordModalPage';
import { SEED_USERS, SEED_PASSWORD } from '../support/constants';
import { findUserByEmail, getCurrentUser, getSecurityEvents, callLogout } from '../support/state';
import { createPendingUserAsAdmin } from '../support/testData';

/**
 * Ver requerimiento "Implementación de Modelo de Seguridad First-Time Login y No Repudio de Credenciales":
 * el Admin nunca define ni ve la contraseña de un usuario. Se genera una clave temporal automática,
 * mustChangePassword/isTemporaryPassword quedan en true, y startSession() bloquea el acceso a cualquier
 * módulo hasta que el usuario la reemplace en #modalCambioObligatorio.
 */

test.describe('Creación de usuario por Admin — no repudio de credenciales', () => {
  test('el formulario ya no pide contraseña y la clave temporal nunca se expone en la UI', async ({ page }) => {
    const email = 'paola.renteria@melonn.com';
    const login = new LoginPage(page);
    await login.goto();
    await login.clickQuickProfile(SEED_USERS.ADMIN.id);
    await new AppShellPage(page).waitForReady();

    const users = new UsersPage(page);
    await users.open();
    await users.openNewUserModal();
    expect(await users.hasPasswordField(), 'el campo #usuarioPassword debe haber sido eliminado del formulario').toBe(false);

    await users.fillNewUserForm({ nombre: 'Paola Rentería', email, role: 'PLANNER' });
    await users.submitNewUser();
    await page.waitForTimeout(150);

    const created = await findUserByEmail(page, email);
    expect(created).not.toBeNull();
    expect(created!.mustChangePassword).toBe(true);
    expect(created!.isTemporaryPassword).toBe(true);
    expect(created!.password).toMatch(/^Melonn\d{4}$/);

    const tempPassword = created!.password;
    const bodyText = await page.locator('body').innerText();
    expect(bodyText.includes(tempPassword), 'la clave temporal no debe aparecer en ningún texto visible de la página').toBe(false);

    const events = await getSecurityEvents(page);
    const creacion = events.find((e) => e.email === email && e.tipo === 'creacion');
    expect(creacion, 'debe quedar un evento de seguridad tipo "creacion"').toBeTruthy();
    expect(creacion!.detalle.includes(tempPassword)).toBe(false);

    await users.switchTab('seguridad');
    const eventRowsText = await users.seguridadEventosTbody.innerText();
    expect(eventRowsText).toContain('Usuario creado');
    expect(eventRowsText.includes(tempPassword)).toBe(false);
  });
});

test.describe('Gate de cambio obligatorio — resiliencia en los 3 caminos de entrada', () => {
  test('Camino 1: formulario de login (#loginForm → intentarCredenciales) bloquea el acceso con clave temporal', async ({ page }) => {
    const pending = await createPendingUserAsAdmin(page, 'ricardo.beltran@melonn.com');

    const login = new LoginPage(page);
    await login.loginWithForm(pending.email, pending.password);
    await page.waitForTimeout(250);

    const shell = new AppShellPage(page);
    expect(await shell.isVisible(), 'no debe iniciarse una sesión real mientras el cambio esté pendiente').toBe(false);
    expect(await getCurrentUser(page)).toBeNull();

    const modal = new ForcePasswordModalPage(page);
    expect(await modal.isOpen()).toBe(true);
    expect(await modal.hasCloseAffordance(), 'el modal obligatorio no debe tener botón de cierre/cancelar').toBe(false);
    expect(await modal.passwordFieldCount(), 'solo Nueva + Confirmar, nunca "contraseña actual"').toBe(2);
  });

  test('Camino 2: tarjeta de "Acceso Rápido" (startSession directo) tampoco evade el gate', async ({ page }) => {
    // El Acceso Rápido llama startSession(u) directamente, sin pasar por intentarCredenciales -- este test
    // existe porque ese es precisamente el camino que un gate puesto solo en intentarCredenciales dejaría
    // sin cubrir. Se fuerza mustChangePassword=true sobre un usuario semilla con tarjeta (u5, Diana
    // Salcedo/PLANNER) para simular que un Admin acaba de resetearle la clave.
    const login = new LoginPage(page);
    await login.goto();
    await page.evaluate((id) => {
      const u = state.users.find((x: any) => x.id === id);
      u.mustChangePassword = true;
      u.isTemporaryPassword = true;
    }, SEED_USERS.PLANNER.id);

    await login.clickQuickProfile(SEED_USERS.PLANNER.id);
    await page.waitForTimeout(250);

    const shell = new AppShellPage(page);
    expect(await shell.isVisible()).toBe(false);
    const modal = new ForcePasswordModalPage(page);
    expect(await modal.isOpen()).toBe(true);
  });

  test('Camino 3: rehidratación de sesión vía localStorage.melonn_session en page.reload()', async ({ page }) => {
    // Un usuario con sesión real ya iniciada (localStorage.melonn_session set) cuyo mustChangePassword
    // pasa a true "en otra pestaña" (p. ej. un reset del Admin) -- al recargar, la restauración de sesión
    // (savedId -> startSession(u)) debe volver a topar con el gate en vez de restaurar silenciosamente el
    // acceso previo.
    const login = new LoginPage(page);
    await login.goto();
    await login.clickQuickProfile(SEED_USERS.PLANNER.id);
    const shell = new AppShellPage(page);
    await shell.waitForReady();
    expect(await shell.isVisible()).toBe(true);

    await page.evaluate((id) => {
      const u = state.users.find((x: any) => x.id === id);
      u.mustChangePassword = true;
      u.isTemporaryPassword = true;
      persistUsers();
    }, SEED_USERS.PLANNER.id);

    await page.reload();
    await page.waitForTimeout(300);

    expect(await shell.isVisible(), 'la rehidratación de sesión no debe saltarse el gate').toBe(false);
    const modal = new ForcePasswordModalPage(page);
    expect(await modal.isOpen()).toBe(true);
  });
});

test.describe('Validaciones y ciclo de vida completo de la contraseña temporal', () => {
  test('clave corta y confirmación no coincidente muestran error sin desbloquear el acceso', async ({ page }) => {
    const pending = await createPendingUserAsAdmin(page, 'teresa.navarro@melonn.com');
    const login = new LoginPage(page);
    await login.loginWithForm(pending.email, pending.password);

    const modal = new ForcePasswordModalPage(page);
    await expect(modal.modal).toHaveClass(/open/);

    await modal.changePassword('abc12345', 'abc99999');
    expect(await modal.getErrorText()).toContain('no coincide');
    expect(await new AppShellPage(page).isVisible()).toBe(false);

    await modal.changePassword('ab1', 'ab1');
    expect(await modal.getErrorText()).toContain('al menos 6 caracteres');
    expect(await new AppShellPage(page).isVisible()).toBe(false);
  });

  test('tras completar el cambio: la clave vieja deja de funcionar y la nueva entra directo, sin modal', async ({ page }) => {
    const pending = await createPendingUserAsAdmin(page, 'oscar.mendieta@melonn.com');
    const login = new LoginPage(page);
    await login.loginWithForm(pending.email, pending.password);

    const modal = new ForcePasswordModalPage(page);
    await expect(modal.modal).toHaveClass(/open/);
    await modal.changePassword('claveDefinitiva9');

    const shell = new AppShellPage(page);
    await shell.waitForReady();
    const user = await getCurrentUser(page);
    expect(user?.mustChangePassword).toBe(false);
    expect(user?.isTemporaryPassword).toBe(false);
    expect(user?.password).toBe('claveDefinitiva9');

    await callLogout(page);
    await page.waitForTimeout(150);

    await login.loginWithForm(pending.email, pending.password);
    await page.waitForTimeout(200);
    expect(await login.getErrorText()).toContain('incorrect');

    await login.fillOnly(pending.email, 'claveDefinitiva9');
    await login.submit();
    await shell.waitForReady();
    expect(await modal.isOpen()).toBe(false);
    expect((await getCurrentUser(page))?.email).toBe(pending.email);
  });

  test('un reset de contraseña por Admin vuelve a forzar el cambio en el siguiente login', async ({ page }) => {
    const pending = await createPendingUserAsAdmin(page, 'ivonne.restrepo@melonn.com');

    // Vuelve a entrar como Admin para resetear la clave recién creada.
    const login = new LoginPage(page);
    await login.goto();
    await login.clickQuickProfile(SEED_USERS.ADMIN.id);
    const shell = new AppShellPage(page);
    await shell.waitForReady();

    const users = new UsersPage(page);
    await users.open();
    await users.switchTab('seguridad');
    await users.resetPasswordFor(pending.id);
    await page.waitForTimeout(150);

    const afterReset = await findUserByEmail(page, pending.email);
    expect(afterReset!.mustChangePassword).toBe(true);
    expect(afterReset!.isTemporaryPassword).toBe(true);
    expect(afterReset!.password).not.toBe(pending.password);
    const newTemp = afterReset!.password;

    await page.evaluate(() => closeModal());
    await callLogout(page);
    await page.waitForTimeout(150);

    await login.loginWithForm(pending.email, newTemp);
    await page.waitForTimeout(250);
    const modal = new ForcePasswordModalPage(page);
    expect(await modal.isOpen()).toBe(true);
    expect(await shell.isVisible()).toBe(false);
  });
});
