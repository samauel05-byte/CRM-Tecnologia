const fs=require('node:fs'),path=require('node:path'),{DatabaseSync}=require('node:sqlite');
const [snapshotFile,directory]=process.argv.slice(2);
if(!snapshotFile||!directory)throw new Error('Indica el respaldo y la carpeta de datos.');
const snapshot=JSON.parse(fs.readFileSync(snapshotFile,'utf8').replace(/^\uFEFF/,''));
if(!Array.isArray(snapshot.users)||!snapshot.users.some(user=>user.role==='admin')||!Array.isArray(snapshot.workspaces)||!Array.isArray(snapshot.projects)||!Array.isArray(snapshot.credentials))throw new Error('Respaldo incompleto.');
for(const user of snapshot.users){const credential=snapshot.credentials.find(row=>row.user_id===user.user_id);if(!credential?.hash?.startsWith('$2'))throw new Error('Falta la credencial protegida de un usuario.');}
if(snapshot.attachments?.length)throw new Error('Este respaldo requiere trasladar los archivos adjuntos antes de continuar.');
fs.mkdirSync(directory,{recursive:true});const databasePath=path.join(directory,'crm.sqlite');
if(fs.existsSync(databasePath))throw new Error('Ya existe una base local. No se sobrescribira.');
const db=new DatabaseSync(databasePath);db.exec(`PRAGMA journal_mode=WAL;PRAGMA synchronous=FULL;
CREATE TABLE document(id INTEGER PRIMARY KEY CHECK(id=1),json TEXT NOT NULL);
CREATE TABLE credentials(user_id TEXT PRIMARY KEY,hash TEXT,activation TEXT UNIQUE);
CREATE TABLE sessions(token TEXT PRIMARY KEY,user_id TEXT NOT NULL,expires INTEGER NOT NULL);
CREATE TABLE attempts(key TEXT PRIMARY KEY,count INTEGER NOT NULL,expires INTEGER NOT NULL);
CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);`);
db.exec('BEGIN IMMEDIATE');try{
const state={users:snapshot.users,workspaces:snapshot.workspaces,projects:snapshot.projects,notifications:snapshot.notifications||[],attachments:snapshot.attachments||[],initialized:true};
db.prepare('INSERT INTO document(id,json) VALUES(1,?)').run(JSON.stringify(state));
for(const credential of snapshot.credentials)db.prepare('INSERT INTO credentials(user_id,hash) VALUES(?,?)').run(credential.user_id,credential.hash);
db.prepare('INSERT INTO metadata(key,value) VALUES(?,?)').run('importedAt',new Date().toISOString());db.exec('COMMIT');db.exec('PRAGMA wal_checkpoint(TRUNCATE)');
console.log(JSON.stringify({users:state.users.length,projects:state.projects.length,tasks:state.workspaces.reduce((count,space)=>count+space.payload.tasks.length,0),passwordsPreserved:true}));
}catch(error){db.exec('ROLLBACK');throw error}finally{db.close()}
