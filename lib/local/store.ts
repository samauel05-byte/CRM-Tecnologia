import {DatabaseSync,backup} from 'node:sqlite';
import {mkdirSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash,randomBytes,scryptSync,timingSafeEqual} from 'node:crypto';

export type Task=Record<string,unknown>&{id:string;name:string;project:string;status:string;owner?:string;owners?:string[];date?:string;start?:string;comments:{text:string;at:string}[];deletedAt?:string;updatedAt?:string};
export type Member={user_id:string;username:string;email:string;role:'admin'|'user'};
export type Space={user_id:string;payload:{tasks:Task[];projects:string[];statuses:string[]};revision:number;updated_at:string};
export type Notice={id:string;recipient_id:string;workspace_id:string;task_id:string;kind:string;title:string;message:string;dedupe_key:string;created_at:string;read_at:string|null;email_status:string;email_attempts:number};
export type Attachment={id:string;user_id:string;name:string;size:number;uploaded?:boolean;upload_token?:string};
export type State={users:Member[];workspaces:Space[];projects:{name:string;created_by:string;created_at:string}[];notifications:Notice[];attachments:Attachment[];initialized:boolean};
export const localMode=()=>process.env.CRM_STORAGE==='local';
export const dataRoot=()=>{if(!process.env.CRM_DATA_DIR)throw new Error('Falta la carpeta de datos local.');return resolve(/*turbopackIgnore: true*/process.env.CRM_DATA_DIR)};
let connection:DatabaseSync|undefined;
export function database(){if(!connection){mkdirSync(dataRoot(),{recursive:true});connection=new DatabaseSync(join(dataRoot(),'crm.sqlite'));connection.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=10000;
CREATE TABLE IF NOT EXISTS document(id INTEGER PRIMARY KEY CHECK(id=1),json TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS credentials(user_id TEXT PRIMARY KEY,hash TEXT,activation TEXT UNIQUE);
CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user_id TEXT NOT NULL,expires INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS attempts(key TEXT PRIMARY KEY,count INTEGER NOT NULL,expires INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);`);connection.prepare('INSERT OR IGNORE INTO document(id,json) VALUES(1,?)').run(JSON.stringify({users:[],workspaces:[],projects:[],notifications:[],attachments:[],initialized:false}));}return connection}
export function readState():State{return JSON.parse((database().prepare('SELECT json FROM document WHERE id=1').get() as {json:string}).json)}
export function transaction<T>(operation:(state:State)=>T):T{const db=database();db.exec('BEGIN IMMEDIATE');try{const state=readState(),result=operation(state);db.prepare('UPDATE document SET json=? WHERE id=1').run(JSON.stringify(state));db.exec('COMMIT');return result}catch(error){db.exec('ROLLBACK');throw error}}
export const digest=(value:string)=>createHash('sha256').update(value).digest('hex');
export const secret=()=>randomBytes(32).toString('base64url');
export function passwordHash(value:string){const salt=randomBytes(16).toString('hex');return salt+':'+scryptSync(value,salt,64).toString('hex')}
export function verifyPassword(value:string,hash:string){try{const [salt,hex]=hash.split(':'),expected=Buffer.from(hex,'hex'),actual=scryptSync(value,salt,64);return expected.length===actual.length&&timingSafeEqual(expected,actual)}catch{return false}}
export function sessionUser(token:string|undefined){if(!token)return null;const session=database().prepare('SELECT user_id FROM sessions WHERE token=? AND expires>?').get(digest(token),Date.now()) as {user_id:string}|undefined;return session?readState().users.find(user=>user.user_id===session.user_id)||null:null}
export function assignees(task:Task){return [...new Set(Array.isArray(task.owners)?task.owners:String(task.owner||'').split(', ').filter(Boolean))]}
export function notifyAssignments(state:State,space:Space,previous:Task[]){for(const task of space.payload.tasks){if(task.deletedAt)continue;const before=previous.find(item=>item.id===task.id),old=before?assignees(before):[];for(const name of assignees(task).filter(name=>!old.includes(name))){const member=state.users.find(user=>user.username===name);if(member)addNotice(state,member.user_id,space.user_id,task,'assigned',`${space.user_id}/${task.id}/${member.user_id}/assigned/${space.revision}`)}}}
export function addNotice(state:State,recipient:string,workspace:string,task:Task,kind:string,key:string){if(state.notifications.some(item=>item.dedupe_key===key))return;state.notifications.push({id:crypto.randomUUID(),recipient_id:recipient,workspace_id:workspace,task_id:task.id,kind,title:kind==='assigned'?'Nueva tarea asignada':'Tu tarea está por vencer',message:task.name,dedupe_key:key,created_at:new Date().toISOString(),read_at:null,email_status:'pending',email_attempts:0})}
export function checkTasks(tasks:Task[],state:State,statuses:string[]){if(!Array.isArray(tasks)||tasks.length>3000)throw new Error('Formato de tareas inválido.');const ids=new Set<string>();for(const task of tasks){if(!task||typeof task.id!=='string'||task.id.length>100||ids.has(task.id)||typeof task.name!=='string'||!task.name.trim()||task.name.trim().length>160||!Array.isArray(task.comments)||!statuses.includes(task.status)||!state.projects.some(project=>project.name===task.project))throw new Error('Revisa el nombre, estado y proyecto de las tareas.');ids.add(task.id);task.name=task.name.trim().toUpperCase();task.owners=assignees(task);if(task.owners.length>20||task.owners.some(name=>!state.users.some(user=>user.username===name)))throw new Error('Selecciona responsables registrados.');task.owner=task.owners.join(', ');for(const value of [task.start,task.date])if(value&&(!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(Date.parse(value))))throw new Error('Fechas inválidas.');if(task.start&&task.date&&task.start>task.date)throw new Error('La terminación debe ser posterior al inicio.')}}
export async function dailyBackup(){const key=new Date().toISOString().slice(0,10),db=database();if(db.prepare('SELECT value FROM metadata WHERE key=?').get('backup-'+key))return;const folder=join(dataRoot(),'copias');mkdirSync(folder,{recursive:true});await backup(db,join(folder,'crm-'+key+'-'+Date.now()+'.sqlite'));db.prepare('INSERT OR REPLACE INTO metadata(key,value) VALUES(?,?)').run('backup-'+key,key)}
