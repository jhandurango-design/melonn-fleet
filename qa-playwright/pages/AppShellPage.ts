import { Page, Locator } from '@playwright/test';
import { NAV_GROUPS } from '../support/constants';

/** Mapa inverso viewId -> catId, derivado de NAV_GROUPS (ver support/constants.ts). */
const CAT_ID_BY_VIEW: Record<string, string> = {};
for (const group of Object.values(NAV_GROUPS)) {
  for (const id of group.ids) CAT_ID_BY_VIEW[id] = group.catId;
}

/**
 * Shell principal de la aplicacion autenticada (#appShell): sidebar, topbar y el area de vistas. No conoce
 * el contenido de cada vista en detalle (eso vive en Page Objects especificos como UsersPage) -- solo la
 * navegacion comun a todos los roles.
 */
export class AppShellPage {
  readonly page: Page;
  readonly shell: Locator;
  readonly loadingOverlay: Locator;
  readonly sidebarNav: Locator;
  readonly userNameBtn: Locator;
  readonly userDropdown: Locator;
  readonly logoutBtn: Locator;

  constructor(page: Page) {
    this.page = page;
    this.shell = page.locator('#appShell');
    this.loadingOverlay = page.locator('#loadingOverlay');
    this.sidebarNav = page.locator('#sidebarNav');
    this.userNameBtn = page.locator('#userName');
    this.userDropdown = page.locator('#userDropdown');
    this.logoutBtn = page.locator('#logoutBtn');
  }

  async waitForReady(): Promise<void> {
    await this.page.waitForFunction(() => (document.getElementById('loadingOverlay') as HTMLElement).hidden === true, { timeout: 5000 });
    await this.shell.waitFor({ state: 'visible' });
  }

  async isVisible(): Promise<boolean> {
    const hidden = await this.shell.getAttribute('hidden');
    return hidden === null;
  }

  navItem(viewId: string): Locator {
    return this.page.locator(`.nav-item[data-view="${viewId}"]`);
  }

  categoryHeader(catId: string): Locator {
    return this.page.locator(`.nav-category-header[data-cat="${catId}"]`);
  }

  async hasNavItem(viewId: string): Promise<boolean> {
    return (await this.navItem(viewId).count()) > 0;
  }

  /** Abre el acordeon colapsable que contiene viewId, si existe y esta colapsado. */
  async ensureGroupOpenFor(viewId: string): Promise<void> {
    const catId = CAT_ID_BY_VIEW[viewId];
    if (!catId) return;
    const header = this.categoryHeader(catId);
    if ((await header.count()) === 0) return;
    const items = header.locator('xpath=following-sibling::*[contains(@class,"nav-category-items")][1]');
    const collapsed = await items.evaluate((el) => el.classList.contains('collapsed'));
    if (collapsed) {
      await header.click();
      // .nav-category-items anima max-height/opacity en .2s (ver styles.css) -- un click inmediato sobre
      // el subitem puede toparse con el nav-item siguiente mientras el acordeón aun se esta expandiendo.
      // Se espera el fin real de la transicion (transitionend) en vez de un timeout fijo, que bajo carga
      // (varios workers de Playwright corriendo en paralelo) resulto insuficiente.
      await items.evaluate(
        (el) =>
          new Promise<void>((resolve) => {
            const done = () => {
              el.removeEventListener('transitionend', done);
              resolve();
            };
            el.addEventListener('transitionend', done);
            setTimeout(done, 700);
          })
      );
    }
  }

  /**
   * Navega a una vista por su id real, abriendo su acordeon padre primero si hace falta. El click se
   * dispara invocando el .click() nativo del nodo (vía evaluate) en vez del click por coordenadas de
   * Playwright: un acordeón de 4 items puede, por un par de px de diferencia en métricas de fuente bajo
   * contención de CPU (varios workers en paralelo), exceder el max-height fijo de .nav-category-items
   * (200px, ver styles.css) y quedar parcialmente recortado por su overflow:hidden. El bounding rect del
   * elemento (de donde Playwright calcula su punto de clic) no refleja ese recorte, asi que un click por
   * coordenadas (incluso con force:true) termina disparando sobre el elemento siguiente, realmente pintado
   * en ese punto. El .click() nativo dispara el evento sobre el nodo correcto sin depender de su geometría
   * visual, igual que ya haría el navegador si el usuario lo activara por teclado.
   */
  async clickNavItem(viewId: string): Promise<void> {
    await this.ensureGroupOpenFor(viewId);
    await this.navItem(viewId).evaluate((el) => (el as HTMLElement).click());
  }

  async currentViewId(): Promise<string> {
    return this.page.evaluate(() => state.currentView);
  }

  /** Todos los ids de vista presentes en el sidebar en este momento (de primer nivel y anidados). */
  async sidebarViewIds(): Promise<string[]> {
    return this.sidebarNav.locator('.nav-item[data-view]').evaluateAll((els) =>
      els.map((el) => el.getAttribute('data-view')).filter((v): v is string => !!v)
    );
  }

  async openUserMenu(): Promise<void> {
    await this.userNameBtn.click();
  }

  /** Flujo real de logout via UI (abre el menu de usuario y hace clic en "Cerrar sesión"). */
  async logout(): Promise<void> {
    await this.openUserMenu();
    await this.logoutBtn.click();
  }
}
