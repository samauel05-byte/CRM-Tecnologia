import { createSupabaseServer } from '@/lib/supabase/server';
import { getCrmRole } from '@/lib/supabase/role';
export const dynamic='force-dynamic';
export async function GET(){
 const headers={'Cache-Control':'private, no-store'};
 const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
 if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 try{
  const role=await getCrmRole(supabase,user.id);
  if(!role.username)return Response.json({error:'No tienes acceso al equipo.'},{status:403,headers});
  const [spaces,people,projects]=await Promise.all([supabase.from('crm_workspaces').select('user_id,payload,revision'),supabase.rpc('crm_list_members'),supabase.from('crm_projects').select('name').order('name')]);
  if(spaces.error||people.error||projects.error)throw new Error('read');
  const names=new Map((people.data as {user_id:string;username:string}[]).map(person=>[person.user_id,person.username]));
  const tasks=spaces.data.flatMap(space=>(space.payload.tasks||[]).filter((task:{deletedAt?:string})=>!task.deletedAt).map((task:Record<string,unknown>)=>({...task,workspaceId:space.user_id,workspaceRevision:space.revision,workspaceProjects:projects.data.map(project=>project.name),workspaceStatuses:space.payload.statuses||['Pendiente','En curso','Completado','Sin asignar'],createdBy:names.get(space.user_id)||'Usuario del equipo'})));
  return Response.json({tasks,canEdit:role.role==='admin'},{headers});
 }catch{return Response.json({error:'No se pudieron cargar las tareas del equipo.'},{status:503,headers})}
}
