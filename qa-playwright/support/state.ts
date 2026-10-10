/**
 * Puente de solo lectura hacia el `state` global de app.js (es un script clasico, no un modulo: `const
 * state = {...}` NO cuelga de `window.state`, pero si queda accesible como identificador suelto dentro de
 * page.evaluate() -- ver support/app-globals.d.ts para los tipos ambientales que hacen esto compilar).
 * Estos helpers nunca escriben en el DOM ni disparan nada que el usuario no pueda disparar el mismo desde
 * la UI; solo leen banderas internas (mustChangePassword, securityEvents, etc.) que no siempre tienen un
 * reflejo visible 1:1 en el DOM.
 */
import { Page } from '@playwright/test';

export interface AppUser {
  id: string;
  nombre: string;
  email: string;
  password: string;
  role: string;
  activo: boolean;
  mustChangePassword?: boolean;
  isTemporaryPassword?: boolean;
  [key: string]: unknown;
}

export interface SecurityEvent {
  id: string;
  tipo: string;
  email: string;
  detalle: string;
  ts: string;
  fecha: string;
}

export async function getCurrentUser(page: Page): Promise<AppUser | null> {
  return page.evaluate(() => state.user ?? null);
}

export async function findUserByEmail(page: Page, email: string): Promise<AppUser | null> {
  return page.evaluate(
    (e) => state.users.find((x: AppUser) => x.email.toLowerCase() === e.toLowerCase()) ?? null,
    email
  );
}

export async function getSecurityEvents(page: Page): Promise<SecurityEvent[]> {
  return page.evaluate(() => state.securityEvents as SecurityEvent[]);
}

export async function callLogout(page: Page): Promise<void> {
  await page.evaluate(() => logout());
}

export async function callCloseModal(page: Page): Promise<void> {
  await page.evaluate(() => closeModal());
}
