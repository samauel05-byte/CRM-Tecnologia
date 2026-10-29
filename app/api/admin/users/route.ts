import { createSupabaseServer } from '@/lib/supabase/server';
import { getCrmRole } from '@/lib/supabase/role';
export const dynamic='force-dynamic';
export async function GET(){
  const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
  if(!user)return Response.json({error:'Inicia sesión.'},{status:401});
  try{const permissions=await getCrmRole(supabase,user.id);
    if(permissions.role!=='admin')return Response.json({error:'Solo el administrador puede consultar los usuarios.'},{status:403});
    const {data,error}=await supabase.from('crm_user_roles').select('username,email,role').order('username');
    if(error)throw error;
    return Response.json({users:data},{headers:{'Cache-Control':'private, no-store'}});
  }catch{return Response.json({error:'No se pudieron consultar los usuarios.'},{status:503})}
}
