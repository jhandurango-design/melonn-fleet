import { Page, Locator, expect } from '@playwright/test';
import { APP_URL } from '../support/constants';

/**
 * Pantalla de login real de la aplicacion (#loginScreen, index.html). Cubre los DOS caminos de entrada que
 * existen hoy en app.js: el formulario de email/password (#loginForm -> intentarCredenciales()) y las
 * tarjetas de "Acceso Rápido de Demostración" (.profile-card -> startSession() directo, sin pasar por el
 * formulario -- ver support/README en los specs de seguridad para por que eso importa).
 */
export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitBtn: Locator;
  readonly errorText: Locator;
  readonly quickPanel: Locator;
  readonly toggleQuickPanelBtn: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.locator('#loginEmail');
    this.passwordInput = page.locator('#loginPassword');
    this.submitBtn = page.locator('#loginSubmitBtn');
    this.errorText = page.locator('#loginError');
    this.quickPanel = page.locator('.login-quick-panel');
    this.toggleQuickPanelBtn = page.locator('#btnToggleQuickPanel');
  }

  async goto(): Promise<void> {
    await this.page.goto(APP_URL);
    await expect(this.page.locator('#loginScreen')).toBeVisible();
  }

  /** Llena y envia el formulario real -- ejercita intentarCredenciales(). */
  async loginWithForm(email: string, password: string): Promise<void> {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitBtn.click();
  }

  async fillOnly(email: string, password: string): Promise<void> {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
  }

  async submit(): Promise<void> {
    await this.submitBtn.click();
  }

  /** Tarjeta de Acceso Rápido -- ejercita el camino que llama startSession() directamente. */
  quickProfileCard(userId: string): Locator {
    return this.page.locator(`.profile-card[data-user="${userId}"]`);
  }

  async clickQuickProfile(userId: string): Promise<void> {
    await this.quickProfileCard(userId).click();
  }

  async getErrorText(): Promise<string> {
    return (await this.errorText.textContent())?.trim() ?? '';
  }

  async isLoaded(): Promise<boolean> {
    return this.page.locator('#loginScreen').isVisible();
  }
}
