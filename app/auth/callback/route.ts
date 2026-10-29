import { createSupabaseServer } from '@/lib/supabase/server';
export async function GET(request:Request){
  if(process.env.CRM_STORAGE==='local')return new Response(null,{status:303,headers:{Location:'/login','Cache-Control':'no-store'}});
  const url=new URL(request.url),code=url.searchParams.get('code'),tokenHash=url.searchParams.get('token_hash');
  const headers={'Cache-Control':'private, no-store','Referrer-Policy':'no-referrer'};
  const supabase=await createSupabaseServer();
  const type=url.searchParams.get('type');
  if(tokenHash&&(type==='invite'||type==='recovery')){
    const {error}=await supabase.auth.verifyOtp({token_hash:tokenHash,type});
    return new Response(null,{status:303,headers:{...headers,Location:error?'/login?invite=expired':'/auth/complete'}});
  }
  if(code){const {error}=await supabase.auth.exchangeCodeForSession(code);if(!error)return new Response(null,{status:303,headers:{...headers,Location:'/'}})}
  return new Response(null,{status:303,headers:{...headers,Location:'/login?confirmed=1'}});
}
