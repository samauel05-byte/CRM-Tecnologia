import { requireChatGPTUser } from './chatgpt-auth';
export const dynamic = 'force-dynamic';
export default async function Home(){await requireChatGPTUser('/');return <iframe src="/workspace.html" title="Dupla · Proyectos y tareas" style={{position:'fixed',inset:0,width:'100%',height:'100%',border:0}}/>}
