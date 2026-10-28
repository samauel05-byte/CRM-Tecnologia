import { isSameOrigin } from '@/lib/http';
import { createSupabaseServer } from '@/lib/supabase/server';
export const dynamic='force-dynamic';
export async function POST(request:Request){
  if(!isSameOrigin(request))return Response.json({error:'Origen inválido.'},{status:403});
  let body;try{body=await request.json()}catch{return Response.json({error:'Solicitud inválida.'},{status:400})}
  const supabase=await createSupabaseServer();
  if(body.action==='signout'){await supabase.auth.signOut();return Response.json({ok:true},{headers:{'Cache-Control':'no-store'}})}
  const {email,password}=body;
  if(typeof email!=='string'||typeof password!=='string'||email.length>254||password.length<(body.action==='signup'?8:1)||password.length>128)return Response.json({error:'Escribe un correo válido y una contraseña de al menos 8 caracteres.'},{status:400});
  if(!['signin','signup'].includes(body.action))return Response.json({error:'Acción inválida.'},{status:400});
  const result=body.action==='signup'?await supabase.auth.signUp({email,password,options:{emailRedirectTo:request.headers.get('origin')+'/auth/callback'}}):await supabase.auth.signInWithPassword({email,password});
  if(result.error)return Response.json({error:result.error.status===429?'Demasiados intentos. Espera unos minutos.':body.action==='signup'?'No se pudo crear la cuenta. Revisa los datos o intenta iniciar sesión.':'No se pudo iniciar sesión. Revisa tus datos y confirma tu correo.'},{status:400,headers:{'Cache-Control':'no-store'}});
  return Response.json({ok:true,confirmation:!result.data.session},{headers:{'Cache-Control':'no-store'}});
}
