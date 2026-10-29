import { redirect } from 'next/navigation';
import { createSupabaseServer } from '@/lib/supabase/server';
import PasswordForm from './password-form';
import '../../login/style.css';
export const dynamic='force-dynamic';
export default async function Complete(){
  if(process.env.CRM_STORAGE==='local')redirect('/login');
  const supabase=await createSupabaseServer();const {data:{user}}=await supabase.auth.getUser();
  if(!user)redirect('/login');
  return <main className="login"><section className="intro"><span/><div><small>CRM TECNOLOGÍA</small><h1>Tu espacio<br/>está listo.</h1><p>Configura tu acceso para comenzar.</p></div><footer>Gestión de proyectos</footer></section><section className="access"><PasswordForm email={user.email||''}/></section></main>;
}
