import {localMode,localApi} from '@/lib/local/api';
import { createSupabaseServer } from '@/lib/supabase/server';
import { isSameOrigin } from '@/lib/http';
export const dynamic='force-dynamic';
export async function POST(request:Request){if(localMode())return localApi('projects',request);return mutate(request,false)}
export async function PATCH(request:Request){if(localMode())return localApi('projects',request);return mutate(request,true)}
export async function DELETE(request:Request){if(localMode())return localApi('projects',request);
 const headers={'Cache-Control':'private, no-store'};
 if(!isSameOrigin(request))return Response.json({error:'Origen inválido.'},{status:403,headers});
 const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
 if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 let body;try{body=await request.json()}catch{return Response.json({error:'Solicitud inválida.'},{status:400,headers})}
 if(typeof body.name!=='string'||!body.name.trim()||body.name.length>80||(body.target!==null&&(typeof body.target!=='string'||!body.target.trim()||body.target.length>80)))return Response.json({error:'Selecciona el proyecto y su destino.'},{status:400,headers});
 const {data,error}=await supabase.rpc('crm_delete_project_move_tasks',{source_project:body.name,target_project:body.target});
 if(error)return Response.json({error:['22023','P0002','42501'].includes(error.code)?error.message:'No se pudo eliminar el proyecto.'},{status:error.code==='42501'?403:400,headers});
 return Response.json({ok:true,moved:data},{headers});
}
async function mutate(request:Request,rename:boolean){
 const headers={'Cache-Control':'private, no-store'};
 if(!isSameOrigin(request))return Response.json({error:'Origen inválido.'},{status:403,headers});
 const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
 if(!user)return Response.json({error:'Inicia sesión.'},{status:401,headers});
 let body;try{body=await request.json()}catch{return Response.json({error:'Solicitud inválida.'},{status:400,headers})}
 if(typeof body.name!=='string'||!body.name.trim()||body.name.trim().length>80||(rename&&typeof body.oldName!=='string'))return Response.json({error:'Escribe un nombre de hasta 80 caracteres.'},{status:400,headers});
 const result=rename?await supabase.rpc('crm_rename_project',{old_name:body.oldName,new_name:body.name.trim()}):await supabase.from('crm_projects').insert({name:body.name.trim(),created_by:user.id});
 if(result.error)return Response.json({error:result.error.code==='23505'?'Ya existe un proyecto con ese nombre.':result.error.code==='42501'?'Solo el creador o el administrador puede cambiar este proyecto.':'No se pudo guardar el proyecto.'},{status:result.error.code==='42501'?403:400,headers});
 return Response.json({ok:true},{headers});
}
