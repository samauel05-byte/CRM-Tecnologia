'use client';
import { useState } from 'react';
export default function PasswordForm({email}:{email:string}){
  const [busy,setBusy]=useState(false),[message,setMessage]=useState('');
  async function submit(event:React.FormEvent<HTMLFormElement>){
    event.preventDefault();const fields=new FormData(event.currentTarget);setMessage('');
    if(fields.get('password')!==fields.get('confirm')){setMessage('Las contraseñas no coinciden.');return}
    setBusy(true);
    try{const response=await fetch('/api/auth/password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:fields.get('password')})});const body=await response.json();if(!response.ok)throw new Error(body.error);location.replace('/')}
    catch(error){setMessage(error instanceof Error?error.message:'No se pudo guardar. Intenta de nuevo.')}
    finally{setBusy(false)}
  }
  return <form onSubmit={submit}><small>COMPLETA TU ACCESO</small><h2>Crea tu contraseña</h2><p>{email}</p><label>Contraseña<input name="password" type="password" minLength={8} maxLength={128} autoComplete="new-password" required/></label><label>Confirmar contraseña<input name="confirm" type="password" minLength={8} maxLength={128} autoComplete="new-password" required/></label><button className="submit" disabled={busy}>{busy?'Guardando…':'Guardar y entrar'}</button>{message?<p className="message" role="alert">{message}</p>:null}</form>;
}
