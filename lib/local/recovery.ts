import {database,readState,digest,secret,passwordHash,audit,setMeta} from './store';
import {mailTransport,privateConfig,publicUrl} from './mail';
const headers={'Cache-Control':'private, no-store','Referrer-Policy':'no-referrer'};
const reply=(body:unknown,status=200)=>Response.json(body,{status,headers});
export async function recovery(request:Request){
 if(request.method!=='POST')return reply({error:'Método no permitido.'},405);
 const text=await request.text();if(text.length>4096)return reply({error:'Solicitud demasiado grande.'},413);
 let body;try{body=JSON.parse(text)}catch{return reply({error:'Solicitud inválida.'},400)}
 const db=database(),time=Date.now();db.prepare('DELETE FROM recovery WHERE expires<?').run(time);db.prepare('DELETE FROM attempts WHERE expires<?').run(time);
 if(body.action==='request'){
  const message='Si el correo está registrado, recibirás un enlace para recuperar tu acceso. Revisa también la carpeta de correo no deseado.';
  if(typeof body.email!=='string'||body.email.length>254)return reply({message});
  const email=body.email.trim().toLowerCase(),key=digest('recovery:'+email);const old=db.prepare('SELECT count FROM attempts WHERE key=?').get(key) as {count:number}|undefined;
  if(old&&old.count>=3)return reply({message});
  db.prepare('INSERT INTO attempts(key,count,expires) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1').run(key,time+15*60000);
  const user=readState().users.find(user=>user.email.toLowerCase()===email);if(!user)return reply({message});
  const token=secret();db.prepare('DELETE FROM recovery WHERE user_id=?').run(user.user_id);db.prepare('INSERT INTO recovery(token,user_id,expires) VALUES(?,?,?)').run(digest(token),user.user_id,time+20*60000);
  try{const config=privateConfig(),transport=mailTransport(config);try{await transport.sendMail({from:{name:'Tecnología',address:config.smtp.user},to:user.email,subject:'Recupera tu acceso · Tecnología',text:'Hola '+user.username+'.\n\nPara configurar una contraseña nueva, abre este enlace desde la red de la oficina:\n'+publicUrl()+'/auth/recover#token='+token+'\n\nEl enlace vence en 20 minutos y funciona una sola vez. Si no lo solicitaste, ignora este mensaje. Tu contraseña actual sigue funcionando.'})}finally{transport.close()}setMeta('recovery-mail',{at:new Date().toISOString(),ok:true})}catch{db.prepare('DELETE FROM recovery WHERE token=?').run(digest(token));setMeta('recovery-mail',{at:new Date().toISOString(),ok:false})}
  return reply({message});
 }
 if(body.action==='reset'){
  if(typeof body.token!=='string'||body.token.length>100||typeof body.password!=='string'||body.password.length<10||body.password.length>128)return reply({error:'Usa una contraseña de entre 10 y 128 caracteres.'},400);
  const hash=passwordHash(body.password);db.exec('BEGIN IMMEDIATE');try{const row=db.prepare('SELECT user_id FROM recovery WHERE token=? AND expires>?').get(digest(body.token),time) as {user_id:string}|undefined;if(!row){db.exec('ROLLBACK');return reply({error:'Este enlace venció o ya fue utilizado. Solicita uno nuevo.'},400)}
   const user=readState().users.find(user=>user.user_id===row.user_id);if(!user)throw new Error('Cuenta no disponible');db.prepare('UPDATE credentials SET hash=? WHERE user_id=?').run(hash,row.user_id);db.prepare('DELETE FROM sessions WHERE user_id=?').run(row.user_id);db.prepare('DELETE FROM recovery WHERE user_id=?').run(row.user_id);audit(user,'contraseña restablecida','usuario','',row.user_id,{});db.exec('COMMIT');return reply({ok:true});
  }catch{db.exec('ROLLBACK');return reply({error:'No se pudo recuperar el acceso.'},400)}
 }
 return reply({error:'Solicitud no permitida.'},400);
}
