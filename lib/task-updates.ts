type Task=Record<string,unknown>&{id:string;updatedAt?:string};
function stable(value:unknown):unknown{
 if(Array.isArray(value))return value.map(stable);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).sort(([a],[b])=>a.localeCompare(b)).map(([key,item])=>[key,stable(item)]));
 return value;
}
function content(task:Task){const {updatedAt,...fields}=task;return JSON.stringify(stable(fields))}
export function stampTaskUpdates(tasks:Task[],previous:Task[],now:string){
 const old=new Map(previous.map(task=>[task.id,task]));
 return tasks.map(task=>{const before=old.get(task.id);const timestamp=!before||content(task)!==content(before)?now:before.updatedAt;const next={...task};delete next.updatedAt;if(timestamp)next.updatedAt=timestamp;return next});
}
