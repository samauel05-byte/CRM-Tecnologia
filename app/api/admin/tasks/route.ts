import { createSupabaseServer } from '@/lib/supabase/server';
import { getCrmRole } from '@/lib/supabase/role';
import { isSameOrigin } from '@/lib/http';
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
export async function PATCH(request:Request){
 const headers={'Cache-Control':'private, no-store'};
 if(!isSameOrigin(request))return Response.json({error:'Origen inválido.'},{status:403,headers});
 const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
 if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 try{
  if(!(await getCrmRole(supabase,user.id)).username)return Response.json({error:'No tienes acceso al equipo.'},{status:403,headers});
  const raw=await request.text();if(raw.length>20000)return Response.json({error:'La tarea es demasiado extensa.'},{status:400,headers});
  let body;try{body=JSON.parse(raw)}catch{return Response.json({error:'Solicitud inválida.'},{status:400,headers})}
  if(typeof body.workspaceId!=='string'||!/^[0-9a-f-]{36}$/i.test(body.workspaceId)||typeof body.taskId!=='string'||body.taskId.length>100||!Number.isSafeInteger(body.revision)||body.revision<1||!body.patch||typeof body.patch!=='object'||Array.isArray(body.patch))return Response.json({error:'Datos inválidos.'},{status:400,headers});
  const {data,error}=await supabase.rpc('crm_edit_team_task',{workspace_id:body.workspaceId,task_id:body.taskId,expected_revision:body.revision,patch:body.patch});
  if(error){const known=['22023','40001','P0002'].includes(error.code);return Response.json({error:known?error.message:'No se pudo guardar la tarea.'},{status:error.code==='40001'?409:error.code==='42501'?403:400,headers})}
  return Response.json({ok:true,revision:data},{headers});
 }catch{return Response.json({error:'No se pudo guardar la tarea.'},{status:503,headers})}
}
