import {maintenance} from '@/lib/local/maintenance';
export const dynamic='force-dynamic';
export async function POST(request:Request){return maintenance(request)}
