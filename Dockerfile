# Imagen estática servida por nginx -- Melonn Fleet es vanilla JS/HTML/CSS sin build step, sin routing del
# lado del cliente (navigate() cambia de vista en memoria, nunca la URL), así que no necesita ni paso de
# compilación ni fallback de SPA: solo servir los 4 archivos + assets/ tal cual.
# Puerto configurable vía $PORT (Cloud Run lo inyecta automáticamente; App Runner también lo soporta) --
# default 8080 si se corre localmente sin definirlo.
FROM nginx:alpine

ENV PORT=8080

COPY nginx.conf.template /etc/nginx/templates/default.conf.template

COPY index.html auth.js app.js styles.css /usr/share/nginx/html/
COPY assets/ /usr/share/nginx/html/assets/

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
