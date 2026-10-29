import { getCrmRole } from '@/lib/supabase/role';
import { isSameOrigin } from '@/lib/http';
import { createSupabaseServer } from '@/lib/supabase/server';
export const dynamic='force-dynamic';
const respond=(body:unknown,status=200)=>Response.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
export async function GET(){
  const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
  if(!user)return respond({error:'Inicia sesión para acceder.'},401);
  const {data:row,error}=await supabase.from('crm_workspaces').select('payload,revision').eq('user_id',user.id).maybeSingle();
  if(error){console.error('Workspace read failed',error.code);return respond({error:'No se pudo cargar el espacio. Intenta de nuevo.'},503)}
  let permissions;try{permissions=await getCrmRole(supabase,user.id)}catch{return respond({error:'No se pudieron verificar los permisos.'},503)}
  return respond({data:row?.payload||null,revision:row?.revision||0,user:{name:permissions.username||user.user_metadata?.full_name||user.email,email:user.email,role:permissions.role}});
}
export async function PUT(request:Request){
  if(!isSameOrigin(request))return respond({error:'Origen inválido.'},403);
  const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();if(!user)return respond({error:'Inicia sesión para guardar.'},401);
  const raw=await request.text();if(raw.length>1500000)return respond({error:'El espacio supera el tamaño permitido.'},413);
  let body;try{body=JSON.parse(raw)}catch{return respond({error:'Datos inválidos.'},400)}
  const {data,revision}=body;const statuses=data?.statuses||['Pendiente','En curso','Completado'];
  if(!Array.isArray(statuses)||statuses.length<3||statuses.length>20||statuses.some((s:unknown)=>typeof s!=='string'||s.length>40)||new Set(statuses).size!==statuses.length||!['Pendiente','En curso','Completado'].every(s=>statuses.includes(s)))return respond({error:'Estados inválidos.'},400);
  if(!data||!Array.isArray(data.projects)||!Array.isArray(data.tasks)||!Number.isSafeInteger(revision)||revision<0||data.tasks.length>3000||data.projects.length>200||data.projects.some((p:unknown)=>typeof p!=='string')||data.tasks.some((t:{id?:unknown;name?:unknown;status?:unknown;comments?:unknown})=>!t||typeof t.id!=='string'||typeof t.name!=='string'||!statuses.includes(t.status)||!Array.isArray(t.comments)))return respond({error:'Formato del espacio inválido.'},400);
  const record={payload:data,revision:revision+1,updated_at:new Date().toISOString()};
  const result=revision===0?await supabase.from('crm_workspaces').insert({user_id:user.id,...record}).select('revision').maybeSingle():await supabase.from('crm_workspaces').update(record).eq('user_id',user.id).eq('revision',revision).select('revision').maybeSingle();
  if(result.error?.code==='23505'||(!result.error&&!result.data))return respond({error:'Este espacio cambió en otra pestaña o dispositivo. Descarga tus cambios y recarga.'},409);
  if(result.error){console.error('Workspace save failed',result.error.code);return respond({error:'No se pudieron guardar los cambios. Intenta de nuevo.'},503)}
  return respond({revision:result.data!.revision});
}
