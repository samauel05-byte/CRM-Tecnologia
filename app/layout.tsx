import type { Metadata } from 'next';
export const metadata:Metadata={title:'Tecnología · Proyectos y tareas',description:'Gestiona proyectos, tareas, calendarios y avances en un solo espacio.',icons:{icon:[{url:'/favicon.svg?v=2',type:'image/svg+xml'},{url:'/favicon.ico?v=2',sizes:'any'}],apple:'/apple-touch-icon.png'}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="es"><body style={{margin:0}}>{children}</body></html>}
