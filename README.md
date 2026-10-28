# Dupla · Proyectos y tareas

Aplicación de gestión de proyectos inspirada en los flujos de ClickUp, en español.

[Aplicación privada publicada](https://dupla-tareas-samuel-281026.sam-x05.chatgpt.site)

## Funciones

- Proyectos y tareas con responsable, prioridad, etiquetas y fechas.
- Vistas de lista, tablero con arrastre, calendario, tabla editable y cronograma Gantt.
- Estados personalizados, tareas principales, subtareas y listas de control.
- Comentarios, historial, dependencias y registro de tiempo.
- Adjuntos de hasta 10 MB, papelera y restauración.
- Búsqueda, filtros, ordenación, exportación CSV y respaldo JSON.
- Persistencia en Cloudflare D1 y archivos en R2.
- Acceso privado con ChatGPT y control de revisión para evitar sobrescrituras simultáneas.

Los datos pertenecen al usuario autenticado. Esta versión no implementa colaboración entre usuarios, automatizaciones, IA ni integraciones externas. Las tareas iniciales son ejemplos. El Gantt muestra las fechas registradas y las dependencias son referencias; no recalcula automáticamente la planificación.

## Tecnología

Vinext, React, TypeScript, Cloudflare Workers, D1, R2 y Drizzle. La interfaz se encuentra en `public/workspace.html`, `public/app.js` y `public/extended.js`. Los servicios de datos y archivos están en `app/api/`.

## Desarrollo local

Requiere Node.js 22.13 o posterior y npm.

```sh
npm ci
npm run db:generate
npm run build
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0000_nasty_vin_gonzales.sql
npm run dev
```

La migración inicial ya está incluida; aplícala una sola vez por base de datos local. Para cambios posteriores, genera y aplica únicamente las nuevas migraciones. El servidor muestra su dirección al iniciar.

En desarrollo local, abre `/signin-with-chatgpt?return_to=/` desde el mismo sitio para usar la identidad de prueba del entorno. Esta simulación no forma parte de la autenticación de producción.

## Comprobaciones

```sh
npx tsc --noEmit
node --check public/app.js
node --check public/extended.js
npm run build
```

Se verificaron creación y persistencia de tareas, fechas y etiquetas, estados personalizados, subtareas, vistas, adjuntos, rechazo de acceso anónimo y control de cambios simultáneos.

## Publicación

La aplicación está configurada para Sites. `.openai/hosting.json` conserva el identificador del sitio y los bindings `DB` y `BUCKET`. Los cambios en GitHub no se publican automáticamente en el sitio: el flujo de publicación debe empaquetar y desplegar la versión correspondiente.

Las credenciales, datos locales, dependencias y archivos generados no se incluyen en este repositorio. Los componentes y herramientas de terceros conservan sus licencias en el código y en `scripts/vite/`.
