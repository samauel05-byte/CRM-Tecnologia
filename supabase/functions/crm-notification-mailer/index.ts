import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
const encoder=new TextEncoder(),decoder=new TextDecoder();
function base64(value:string){return btoa(String.fromCharCode(...encoder.encode(value)))}
function escapeHtml(value:string){return value.replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]!))}
async function sendMail(email:string,title:string,message:string,id:string,password:string){
 if(!/^[^\s<>\r\n@]+@[^\s<>\r\n@]+\.[^\s<>\r\n@]+$/.test(email))throw new Error('Invalid recipient');
 const connection=await Deno.connectTls({hostname:'mail.gdlinea.com',port:465});
 let buffered='';
 async function reply(expected:number[]){let code=0;for(let lines=0;lines<100;lines++){while(!buffered.includes('\n')){const bytes=new Uint8Array(4096);const count=await connection.read(bytes);if(!count)throw new Error('SMTP disconnected');buffered+=decoder.decode(bytes.subarray(0,count));if(buffered.length>65536)throw new Error('SMTP reply too large')}const split=buffered.indexOf('\n'),line=buffered.slice(0,split).replace(/\r$/,'');buffered=buffered.slice(split+1);code=Number(line.slice(0,3));if(line[3]!=='-'){if(!expected.includes(code))throw new Error('SMTP rejected command');return}}throw new Error('Invalid SMTP reply')}
 async function command(value:string,codes:number[]){const bytes=encoder.encode(value+'\r\n');let offset=0;while(offset<bytes.length)offset+=await connection.write(bytes.subarray(offset));await reply(codes)}
 const timeout=setTimeout(()=>{try{connection.close()}catch{}},20000);
 try{
  await reply([220]);await command('EHLO crm.local',[250]);await command('AUTH LOGIN',[334]);await command(base64('sroa@grupodupla.com'),[334]);await command(base64(password),[235]);
  await command('MAIL FROM:<sroa@grupodupla.com>',[250]);await command('RCPT TO:<'+email+'>',[250,251]);await command('DATA',[354]);
  const html='<div style="font-family:Arial,sans-serif;color:#234b38;max-width:560px;margin:auto;padding:30px"><h2>'+escapeHtml(title)+'</h2><p style="line-height:1.8">'+escapeHtml(message)+'</p><p><a href="https://tecnologiacrm.vercel.app/" style="background:#157765;color:white;padding:12px 18px;text-decoration:none;border-radius:6px">Abrir CRM Tecnología</a></p><p style="font-size:11px;color:#8b9e91">Aviso automático de tu equipo de trabajo.</p></div>';
  const encoded=base64(html).match(/.{1,76}/g)!.join('\r\n');
  await command('From: CRM Tecnologia <sroa@grupodupla.com>\r\nTo: <'+email+'>\r\nSubject: =?UTF-8?B?'+base64(title)+'?=\r\nDate: '+new Date().toUTCString()+'\r\nMessage-ID: <'+id+'@crm.grupodupla.com>\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n'+encoded+'\r\n.',[250]);
  await command('QUIT',[221]);
 }finally{clearTimeout(timeout);try{connection.close()}catch{}}
}
Deno.serve(async request=>{
 if(request.method==='GET')return Response.json({configured:!!Deno.env.get('CRM_SMTP_PASSWORD')});
 if(request.method!=='POST')return new Response('Method not allowed',{status:405});
 const password=Deno.env.get('CRM_SMTP_PASSWORD');if(!password)return Response.json({error:'SMTP password has not been configured'},{status:503});
 // Recipients and content come only from the database outbox, never from HTTP input.
 const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
 const {data:jobs,error}=await supabase.rpc('crm_claim_notification_emails');if(error)return Response.json({error:'Outbox unavailable'},{status:503});
 let sent=0,failed=0;
 for(const job of jobs||[]){try{await sendMail(job.email,job.title,job.message,job.id,password);await supabase.from('crm_notifications').update({email_status:'sent',email_sent_at:new Date().toISOString(),email_locked_at:null}).eq('id',job.id);sent++}catch{const {data:record}=await supabase.from('crm_notifications').select('email_attempts').eq('id',job.id).single();await supabase.from('crm_notifications').update({email_status:(record?.email_attempts||0)>=5?'failed':'pending',email_locked_at:null}).eq('id',job.id);failed++}}
 return Response.json({sent,failed});
});
