import { createSupabaseServer } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
export const dynamic = 'force-dynamic';
export default async function Home(){const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect('/login');return <iframe src="/workspace.html" title="Dupla · Proyectos y tareas" style={{position:'fixed',inset:0,width:'100%',height:'100%',border:0}}/>}
