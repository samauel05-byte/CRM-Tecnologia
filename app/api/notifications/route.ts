import { createSupabaseServer } from '@/lib/supabase/server';
import { isSameOrigin } from '@/lib/http';
export const dynamic='force-dynamic';
export async function GET(){
 const headers={'Cache-Control':'private, no-store'},supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
 if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 const {data,error}=await supabase.from('crm_notifications').select('id,title,message,task_id,workspace_id,created_at,read_at').eq('recipient_id',user.id).order('created_at',{ascending:false}).limit(50);
 return error?Response.json({error:'No se pudieron cargar los avisos.'},{status:503,headers}):Response.json({notifications:data},{headers});
}
export async function PATCH(request:Request){
 const headers={'Cache-Control':'private, no-store'};
 if(!isSameOrigin(request))return Response.json({error:'Origen inválido.'},{status:403,headers});
 const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 const {error}=await supabase.from('crm_notifications').update({read_at:new Date().toISOString()}).eq('recipient_id',user.id).is('read_at',null);
 return error?Response.json({error:'No se pudieron actualizar los avisos.'},{status:503,headers}):Response.json({ok:true},{headers});
}
