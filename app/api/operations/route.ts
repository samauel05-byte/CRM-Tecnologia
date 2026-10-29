import {localApi,localMode} from '@/lib/local/api';
export const dynamic='force-dynamic';
export async function GET(request:Request){if(!localMode())return new Response(null,{status:404});return localApi('operations',request)}
export async function POST(request:Request){if(!localMode())return new Response(null,{status:404});return localApi('operations',request)}
