import {readFileSync} from 'node:fs';
import {join} from 'node:path';
export const dynamic='force-dynamic';
export async function GET(){let version='development';try{version=readFileSync(join(process.cwd(),'.next','BUILD_ID'),'utf8').trim()}catch{}return Response.json({version},{headers:{'Cache-Control':'no-store'}})}
