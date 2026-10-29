import {localMode,localApi} from '@/lib/local/api';
import { createSupabaseServer } from '@/lib/supabase/server';
export const dynamic='force-dynamic';
export async function GET(request:Request){if(localMode())return localApi('members',request);
 const headers={'Cache-Control':'private, no-store'};
 const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
 if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 const {data,error}=await supabase.rpc('crm_list_members');
 if(error)return Response.json({error:'No se pudieron cargar los responsables.'},{status:503,headers});
 return Response.json({members:data},{headers});
}
