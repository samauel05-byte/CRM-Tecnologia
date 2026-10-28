import type { Metadata } from 'next';
export const metadata:Metadata={title:'Dupla · Proyectos y tareas',description:'Gestiona proyectos, tareas, calendarios y avances en un solo espacio.'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="es"><body style={{margin:0}}>{children}</body></html>}
