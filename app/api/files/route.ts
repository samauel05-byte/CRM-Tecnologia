import { createSupabaseServer } from '@/lib/supabase/server';
export const dynamic='force-dynamic';
const bucket='crm-attachments';
export async function POST(request:Request){
  if(request.headers.get('origin')!==new URL(request.url).origin)return Response.json({error:'Origen inválido.'},{status:403});
  const supabase=await createSupabaseServer(),{data:{user}}=await supabase.auth.getUser();if(!user)return Response.json({error:'Inicia sesión.'},{status:401});
  let body;try{body=await request.json()}catch{return Response.json({error:'Solicitud inválida.'},{status:400})}
  if(typeof body.name!=='string'||!body.name.trim()||body.name.length>200||!Number.isInteger(body.size)||body.size<0||body.size>10000000)return Response.json({error:'Archivo inválido o mayor a 10 MB.'},{status:400});
  const id=crypto.randomUUID(),path=`${user.id}/${id}`;
  const {data:signed,error}=await supabase.storage.from(bucket).createSignedUploadUrl(path,{upsert:false});
  if(error)return Response.json({error:'No se pudo preparar el archivo. Intenta de nuevo.'},{status:503});
  const {error:rowError}=await supabase.from('crm_attachments').insert({id,user_id:user.id,name:body.name,size:body.size});
  if(rowError)return Response.json({error:'No se pudo registrar el archivo.'},{status:503});
  return Response.json({id,name:body.name,size:body.size,uploadUrl:signed.signedUrl},{headers:{'Cache-Control':'private, no-store'}});
}
export async function GET(request:Request){
  const supabase=await createSupabaseServer(),{data:{user}}=await supabase.auth.getUser();if(!user)return new Response(null,{status:401});
  const id=new URL(request.url).searchParams.get('id');if(!id||!/^[a-f0-9-]{36}$/.test(id))return new Response(null,{status:400});
  const {data:file,error}=await supabase.from('crm_attachments').select('name').eq('id',id).eq('user_id',user.id).maybeSingle();
  if(error||!file)return new Response(null,{status:404});
  const {data:signed,error:storageError}=await supabase.storage.from(bucket).createSignedUrl(`${user.id}/${id}`,60,{download:file.name});
  if(storageError)return new Response(null,{status:404});
  return new Response(null,{status:302,headers:{Location:signed.signedUrl,'Cache-Control':'private, no-store'}});
}
