import { createSupabaseServer } from '@/lib/supabase/server';
import { NextResponse } from 'next/server';
export async function GET(request:Request){const url=new URL(request.url),code=url.searchParams.get('code');if(code){const supabase=await createSupabaseServer();const {error}=await supabase.auth.exchangeCodeForSession(code);if(!error)return NextResponse.redirect(new URL('/',url.origin))}return NextResponse.redirect(new URL('/login?confirmed=1',url.origin))}
