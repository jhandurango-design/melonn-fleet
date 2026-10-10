# Melonn Fleet — Suite de QA Automatizada (Playwright + TypeScript)

Suite de pruebas E2E en **Page Object Model** para la app estática de Melonn Fleet
(`../index.html`, abierta directo por `file://`, sin servidor ni build). **No modifica el
código fuente de la aplicación** (`app.js` / `index.html` / `styles.css` / `auth.js`) —
solo la ejercita como caja negra a través del navegador.

## Instalar

```bash
npm install
npx playwright install chromium
```

## Correr

```bash
npm test                 # toda la suite
npm run test:headed      # con navegador visible
npm run test:security    # solo 01-security-gate.spec.ts
npm run test:seed        # solo 02-seed-users.spec.ts
npm run test:rbac        # solo 03-rbac-navigation.spec.ts
npm run report           # abre el último reporte HTML
```

## Estructura

- `pages/` — Page Objects: `LoginPage`, `ForcePasswordModalPage`, `AppShellPage`, `UsersPage`.
- `fixtures/auth.fixture.ts` — fixtures `adminPage`/`plannerPage`/`bodegaPage`/`aliadoPage`/`auditorPage`:
  cada una entrega una página ya autenticada para ese rol (vía la tarjeta de "Acceso Rápido"), para no
  repetir el flujo de login en cada test.
- `support/constants.ts` — espejo de las constantes reales de `app.js` (`ROLE_VIEWS`, `NAV_GROUPS`,
  usuarios semilla) usadas por las aserciones. Si esas constantes cambian en `app.js`, hay que
  actualizarlas aquí también.
- `support/state.ts` — helpers de solo lectura sobre el `state` global de la app (vía `page.evaluate`).
- `support/app-globals.d.ts` — tipos ambientales para que TypeScript entienda `state`/`logout`/etc.
  dentro de los callbacks de `page.evaluate` (son globales de un script clásico, no de un módulo).
- `tests/01-security-gate.spec.ts` — modelo de seguridad "First-Time Login" y no repudio de credenciales.
- `tests/02-seed-users.spec.ts` — regresión: los usuarios semilla/demo no deben verse afectados por el gate.
- `tests/03-rbac-navigation.spec.ts` — permisos y navegación real por rol (incluye los acordeones
  colapsables del sidebar).

## Nota sobre fixtures y `file://`

Se evaluó reutilizar sesiones guardadas con `context.storageState()` (un solo login real al inicio,
reutilizado por todos los tests de un rol) para evitar repetir el flujo de login en cada prueba, pero
Playwright no restaura de forma confiable el `localStorage` de páginas `file://` entre contextos en este
entorno. Las fixtures de `auth.fixture.ts` en su lugar hacen un login real (un clic en la tarjeta de
Acceso Rápido) por test — rápido (~1s) y 100% confiable.
