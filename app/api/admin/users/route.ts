import { createSupabaseServer } from '@/lib/supabase/server';
import { getCrmRole } from '@/lib/supabase/role';
import { isSameOrigin } from '@/lib/http';
export const dynamic='force-dynamic';
export async function GET(){
  const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
  if(!user)return Response.json({error:'Inicia sesión.'},{status:401});
  try{const permissions=await getCrmRole(supabase,user.id);
    if(permissions.role!=='admin')return Response.json({error:'Solo el administrador puede consultar los usuarios.'},{status:403});
    const {data,error}=await supabase.from('crm_user_roles').select('user_id,username,email,role').order('username');
    if(error)throw error;
    return Response.json({users:data},{headers:{'Cache-Control':'private, no-store'}});
  }catch{return Response.json({error:'No se pudieron consultar los usuarios.'},{status:503})}
}
export async function PATCH(request:Request){
  const headers={'Cache-Control':'private, no-store'};
  if(!isSameOrigin(request))return Response.json({error:'Origen inválido.'},{status:403,headers});
  const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
  if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
  try{
    if((await getCrmRole(supabase,user.id)).role!=='admin')return Response.json({error:'Solo el administrador puede editar usuarios.'},{status:403,headers});
    let body;try{body=await request.json()}catch{return Response.json({error:'Solicitud inválida.'},{status:400,headers})}
    if(typeof body.user_id!=='string'||! /^[0-9a-f-]{36}$/i.test(body.user_id)||typeof body.username!=='string'||!body.username.trim()||body.username.trim().length>80||!['admin','user'].includes(body.role))return Response.json({error:'Revisa el nombre y el rol.'},{status:400,headers});
    const {error}=await supabase.rpc('crm_edit_user',{target_id:body.user_id,new_username:body.username.trim(),new_role:body.role});
    if(error){const message=error.code==='23505'?'Ese nombre ya está en uso.':error.code==='22023'?error.message:'No se pudo editar el usuario.';return Response.json({error:message},{status:400,headers})}
    return Response.json({ok:true},{headers});
  }catch{return Response.json({error:'No se pudo editar el usuario.'},{status:503,headers})}
}
