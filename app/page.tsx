import { createSupabaseServer } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import {localMode,localUser} from '@/lib/local/api';
export const dynamic = 'force-dynamic';
export default async function Home(){let user;if(localMode())user=await localUser();else{const supabase=await createSupabaseServer();user=(await supabase.auth.getUser()).data.user}if(!user)redirect('/login');return <iframe src="/workspace.html" title="Tecnología · Proyectos y tareas" style={{position:'fixed',inset:0,width:'100%',height:'100%',border:0}}/>}
