import type { SupabaseClient } from '@supabase/supabase-js';
export async function getCrmRole(supabase:SupabaseClient,userId:string){
  const {data,error}=await supabase.from('crm_user_roles').select('role,username').eq('user_id',userId).maybeSingle();
  if(error)throw new Error('No se pudieron verificar los permisos.');
  return {role:data?.role==='admin'?'admin':'user',username:data?.username||null};
}
