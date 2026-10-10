/**
 * app.js declara sus globales con `const`/`function` a nivel de script clasico (sin `type="module"`):
 * `const state = {...}` NO cuelga de `window.state` (solo lo hacen los `var`/declaraciones de funcion), pero
 * SI queda accesible como identificador suelto desde cualquier otro script que comparta el mismo entorno
 * lexical global -- que es exactamente el contexto en el que corren los callbacks de page.evaluate(). Estas
 * declaraciones ambientales solo le dan tipos a TypeScript para esos identificadores; no crean nada real.
 */
declare const state: any;
declare function logout(): void;
declare function closeModal(): void;
declare function persistUsers(): void;
