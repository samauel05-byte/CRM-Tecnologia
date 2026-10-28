# Dupla · CRM Tecnología

Gestión de proyectos y tareas en español, con Next.js en Vercel y Supabase para autenticación, base de datos y archivos.

## Funciones

- Proyectos, tareas, subtareas y listas de control.
- Lista, tablero con arrastre, calendario, tabla editable y Gantt.
- Estados personalizados, responsables, fechas, prioridades y etiquetas.
- Comentarios, dependencias, historial y registro de tiempo.
- Adjuntos privados de hasta 10 MB con subida directa a Supabase Storage.
- Papelera, restauración, filtros, exportación CSV y respaldo JSON.
- Sesiones verificadas en el servidor y acceso a los datos limitado por usuario mediante RLS.
- Control de revisión para evitar sobrescrituras entre pestañas o dispositivos.

El Gantt muestra las fechas guardadas; no recalcula automáticamente las dependencias. Esta versión no incluye espacios compartidos entre usuarios, automatizaciones ni IA. Las tareas iniciales son ejemplos.

## Desarrollo

Requiere Node.js 24.

```sh
npm ci
```

Copia `.env.example` a `.env.local` y configura:

```text
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

No se necesita ni debe utilizarse una clave `service_role` en el navegador. Las sesiones utilizan la clave publicable y las políticas de seguridad del usuario autenticado.

```sh
npm run dev
```

## Supabase

El proyecto conectado es `pos-multicaja` (`uvaotfqutfojokbnzgcs`). La aplicación utiliza únicamente sus tablas `crm_workspaces` y `crm_attachments` y el bucket privado `crm-attachments`. La migración correspondiente se conserva en `supabase/migrations/`.

Cada cuenta ve su propio espacio; iniciar sesión con otro correo no comparte automáticamente los datos. Para acceder por primera vez, crea una cuenta en la pantalla de entrada y confirma el correo si el proyecto lo solicita. Las credenciales de ChatGPT usadas por la versión anterior en Sites no se transfieren a Supabase.

Los adjuntos se suben mediante enlaces de carga firmados y se descargan mediante enlaces privados de corta duración. El límite del bucket es 10 MB por archivo.

## Vercel

El repositorio se publica como un proyecto Next.js. Configura las dos variables anteriores en Production y Development antes de ejecutar la aplicación. No se concede a los despliegues de Preview acceso a la base de datos de producción por defecto.

Los commits de `main` activan la integración de Git de Vercel. `vercel.json` especifica el framework, los comandos y la región de las funciones.

## Comprobaciones

```sh
npx tsc --noEmit
node --check public/app.js
node --check public/extended.js
npm run build
```

La interfaz se encuentra en `public/workspace.html`, `public/app.js` y `public/extended.js`. Los servicios están en `app/api/`, la entrada en `app/login/` y la renovación de sesión en `proxy.ts`.

No se incluyen contraseñas, claves privadas, datos de usuarios, archivos de prueba ni dependencias instaladas. Los componentes de terceros conservan sus licencias en el código y en `vendor/`.
