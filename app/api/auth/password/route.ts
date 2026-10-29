import { isSameOrigin } from '@/lib/http';
import { createSupabaseServer } from '@/lib/supabase/server';
export async function POST(request:Request){
  const headers={'Cache-Control':'private, no-store'};
  if(!isSameOrigin(request))return Response.json({error:'Origen inválido.'},{status:403,headers});
  const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
  if(!user)return Response.json({error:'Abre el enlace de invitación para continuar.'},{status:401,headers});
  let body;try{body=await request.json()}catch{return Response.json({error:'Solicitud inválida.'},{status:400,headers})}
  if(typeof body.password!=='string'||body.password.length<8||body.password.length>128)return Response.json({error:'Usa una contraseña de entre 8 y 128 caracteres.'},{status:400,headers});
  const {error}=await supabase.auth.updateUser({password:body.password});
  if(error)return Response.json({error:'No se pudo guardar la contraseña. Prueba con otra o vuelve a abrir tu invitación.'},{status:400,headers});
  return Response.json({ok:true},{headers});
}
