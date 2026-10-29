import {localApi,localMode} from '@/lib/local/api';
export const dynamic='force-dynamic';
export async function GET(request:Request){if(!localMode())return Response.json({local:false},{headers:{'Cache-Control':'no-store'}});if(new URL(request.url).searchParams.has('details'))return localApi('status',request);return Response.json({local:true},{headers:{'Cache-Control':'no-store'}})}
