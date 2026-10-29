import { createSupabaseServer } from '@/lib/supabase/server';
import { getCrmRole } from '@/lib/supabase/role';
export const dynamic='force-dynamic';
export async function GET(){
 const headers={'Cache-Control':'private, no-store'};
 const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
 if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 try{
  if((await getCrmRole(supabase,user.id)).role!=='admin')return Response.json({error:'Solo el administrador puede consultar las tareas del equipo.'},{status:403,headers});
  const [spaces,people]=await Promise.all([supabase.from('crm_workspaces').select('user_id,payload'),supabase.from('crm_user_roles').select('user_id,username')]);
  if(spaces.error||people.error)throw new Error('read');
  const names=new Map(people.data.map(person=>[person.user_id,person.username]));
  const tasks=spaces.data.flatMap(space=>(space.payload.tasks||[]).filter((task:{deletedAt?:string})=>!task.deletedAt).map((task:Record<string,unknown>)=>({...task,createdBy:names.get(space.user_id)||'Usuario del equipo'})));
  return Response.json({tasks},{headers});
 }catch{return Response.json({error:'No se pudieron cargar las tareas del equipo.'},{status:503,headers})}
}
