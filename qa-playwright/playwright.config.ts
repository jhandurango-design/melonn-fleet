import { defineConfig, devices } from '@playwright/test';

/**
 * Suite de QA automatizada para Melonn Fleet (app estatica, sin build ni servidor -- se abre directo via
 * file://). No hay webServer que levantar: cada test navega al index.html real del proyecto (ver
 * support/constants.ts, APP_URL) exactamente como lo haria un usuario abriendo el archivo en Chrome.
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1500, height: 950 } },
    },
  ],
});
