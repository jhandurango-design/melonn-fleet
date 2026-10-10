import { Page, Locator } from '@playwright/test';

/**
 * Modal de Cambio Obligatorio de Contraseña (#modalCambioObligatorio, ver requerimiento "Implementación de
 * Modelo de Seguridad First-Time Login y No Repudio de Credenciales"). Se abre desde startSession() cuando
 * user.mustChangePassword === true, bloqueando el acceso a #appShell hasta completarlo. A proposito NO tiene
 * boton de cierre/cancelar ni campo "contraseña actual".
 */
export class ForcePasswordModalPage {
  readonly page: Page;
  readonly modal: Locator;
  readonly form: Locator;
  readonly newPasswordInput: Locator;
  readonly confirmPasswordInput: Locator;
  readonly errorText: Locator;
  readonly submitBtn: Locator;

  constructor(page: Page) {
    this.page = page;
    this.modal = page.locator('#modalCambioObligatorio');
    this.form = page.locator('#formCambioObligatorio');
    this.newPasswordInput = page.locator('#passObligatoriaNueva');
    this.confirmPasswordInput = page.locator('#passObligatoriaConfirmar');
    this.errorText = page.locator('#passwordObligatoriaError');
    this.submitBtn = this.form.locator('button[type="submit"]');
  }

  async isOpen(): Promise<boolean> {
    return this.modal.evaluate((el) => el.classList.contains('open'));
  }

  /** Debe ser exactamente 2 (nueva + confirmar) -- nunca una tercera para "contraseña actual". */
  async passwordFieldCount(): Promise<number> {
    return this.form.locator('input[type="password"]').count();
  }

  async hasCloseAffordance(): Promise<boolean> {
    const closeButtons = await this.modal.locator('[data-close], .modal-close').count();
    return closeButtons > 0;
  }

  async fill(newPassword: string, confirmPassword: string): Promise<void> {
    await this.newPasswordInput.fill(newPassword);
    await this.confirmPasswordInput.fill(confirmPassword);
  }

  async submit(): Promise<void> {
    await this.submitBtn.click();
  }

  async changePassword(newPassword: string, confirmPassword = newPassword): Promise<void> {
    await this.fill(newPassword, confirmPassword);
    await this.submit();
  }

  async getErrorText(): Promise<string> {
    return (await this.errorText.textContent())?.trim() ?? '';
  }
}
