import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  if(process.env.CRM_STORAGE==='local'){
    const publicUrl=process.env.CRM_PUBLIC_URL,host=request.headers.get('host')||'';
    const loopback=/^(127\.0\.0\.1|localhost)(:\d+)?$/.test(host);
    const trustedProxy=Boolean(process.env.CRM_PROXY_SECRET)&&request.headers.get('x-crm-proxy')===process.env.CRM_PROXY_SECRET&&request.headers.get('x-forwarded-proto')==='https';
    if(process.env.CRM_HTTPS_ENFORCE==='1'&&publicUrl?.startsWith('https:')&&!loopback&&!trustedProxy)return NextResponse.redirect(new URL(request.nextUrl.pathname+request.nextUrl.search,publicUrl),307);
    response.headers.set('Cache-Control','private, no-store');return response;
  }
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL, key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return response;
  const supabase=createServerClient(url,key,{cookies:{
    getAll:()=>request.cookies.getAll(),
    setAll(items, cacheHeaders){
      items.forEach(({name,value})=>request.cookies.set(name,value));
      response=NextResponse.next({request});
      items.forEach(({name,value,options})=>response.cookies.set(name,value,options));
      Object.entries(cacheHeaders||{}).forEach(([name,value])=>response.headers.set(name,value));
    },
  }});
  await supabase.auth.getClaims();
  response.headers.set('Cache-Control','private, no-store');
  return response;
}
export const config={matcher:['/((?!_next/static|_next/image).*)']};
