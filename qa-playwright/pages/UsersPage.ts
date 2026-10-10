import { Page, Locator } from '@playwright/test';
import { AppShellPage } from './AppShellPage';

export type NewUserInput = {
  nombre: string;
  email: string;
  role: 'ADMIN' | 'PLANNER' | 'BODEGA' | 'ALIADO' | 'AUDITOR';
  sede?: string;
  aliado?: string;
};

export type UsersTab = 'usuarios' | 'permisos' | 'seguridad';

/**
 * Vista "Gestión de Usuarios" (#view-permisos -- el id interno de la vista real es 'permisos', no
 * 'usuarios'; ver support/constants.ts). Agrupa las 3 pestañas: Usuarios, Roles y Permisos, Seguridad y
 * Accesos.
 */
export class UsersPage {
  readonly page: Page;
  readonly shell: AppShellPage;

  readonly btnNuevoUsuario: Locator;
  readonly modalUsuario: Locator;
  readonly formUsuario: Locator;
  readonly nombreInput: Locator;
  readonly emailInput: Locator;
  readonly rolSelect: Locator;
  readonly sedeSelect: Locator;
  readonly aliadoSelect: Locator;
  readonly submitUsuarioBtn: Locator;

  readonly seguridadUsuariosTbody: Locator;
  readonly seguridadEventosTbody: Locator;
  readonly modalResetPassword: Locator;
  readonly resetPasswordConfirmStep: Locator;
  readonly resetPasswordDoneStep: Locator;
  readonly btnConfirmarResetPassword: Locator;

  constructor(page: Page) {
    this.page = page;
    this.shell = new AppShellPage(page);

    this.btnNuevoUsuario = page.locator('#btnNuevoUsuario');
    this.modalUsuario = page.locator('#modalUsuario');
    this.formUsuario = page.locator('#formUsuario');
    this.nombreInput = page.locator('#usuarioNombre');
    this.emailInput = page.locator('#usuarioEmail');
    this.rolSelect = page.locator('#usuarioRol');
    this.sedeSelect = page.locator('#usuarioSede');
    this.aliadoSelect = page.locator('#usuarioAliado');
    this.submitUsuarioBtn = this.formUsuario.locator('button[type="submit"]');

    this.seguridadUsuariosTbody = page.locator('#seguridadUsuariosTbody');
    this.seguridadEventosTbody = page.locator('#seguridadEventosTbody');
    this.modalResetPassword = page.locator('#modalResetPassword');
    this.resetPasswordConfirmStep = page.locator('#resetPasswordConfirmStep');
    this.resetPasswordDoneStep = page.locator('#resetPasswordDoneStep');
    this.btnConfirmarResetPassword = page.locator('#btnConfirmarResetPassword');
  }

  async open(): Promise<void> {
    await this.shell.clickNavItem('permisos');
  }

  async switchTab(tab: UsersTab): Promise<void> {
    await this.page.locator(`[data-tab="${tab}"]`).click();
  }

  async openNewUserModal(): Promise<void> {
    await this.btnNuevoUsuario.click();
  }

  /** Ver requerimiento de no-repudio: este campo NUNCA debe existir en el formulario. */
  async hasPasswordField(): Promise<boolean> {
    return (await this.page.locator('#usuarioPassword').count()) > 0;
  }

  async fillNewUserForm(input: NewUserInput): Promise<void> {
    await this.nombreInput.fill(input.nombre);
    await this.emailInput.fill(input.email);
    await this.rolSelect.selectOption(input.role);
    if (input.role === 'BODEGA' && input.sede) await this.sedeSelect.selectOption(input.sede);
    if (input.role === 'ALIADO' && input.aliado) await this.aliadoSelect.selectOption(input.aliado);
  }

  async submitNewUser(): Promise<void> {
    await this.submitUsuarioBtn.click();
  }

  async createUser(input: NewUserInput): Promise<void> {
    await this.openNewUserModal();
    await this.fillNewUserForm(input);
    await this.submitNewUser();
  }

  resetPasswordButton(userId: string): Locator {
    return this.page.locator(`[data-act="restablecer-clave"][data-id="${userId}"]`);
  }

  async resetPasswordFor(userId: string): Promise<void> {
    await this.resetPasswordButton(userId).click();
    await this.btnConfirmarResetPassword.click();
  }
}
