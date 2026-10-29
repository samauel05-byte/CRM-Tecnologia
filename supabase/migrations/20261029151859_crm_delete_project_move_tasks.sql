create function crm_private.delete_project_move_tasks(source_project text,target_project text) returns integer
language plpgsql security definer set search_path='' as $$
declare stamp text; moved integer; actor text;
begin
 if not crm_private.is_member() then raise exception 'No tienes acceso al equipo.' using errcode='42501'; end if;
 lock table public.crm_projects in share row exclusive mode;
 if not exists(select 1 from public.crm_projects where name=source_project) then raise exception 'Proyecto no encontrado. Actualiza el panel.' using errcode='P0002'; end if;
 if source_project=target_project then raise exception 'Selecciona otro proyecto de destino.' using errcode='22023'; end if;
 -- Lock workspaces before counting and moving tasks, including tasks in the trash.
 perform 1 from public.crm_workspaces order by user_id for update;
 select count(*) into moved from public.crm_workspaces w,jsonb_array_elements(w.payload->'tasks') t where t->>'project'=source_project;
 if moved>0 and (target_project is null or not exists(select 1 from public.crm_projects where name=target_project)) then raise exception 'Selecciona un proyecto para conservar las tareas.' using errcode='22023'; end if;
 if target_project is not null and not exists(select 1 from public.crm_projects where name=target_project) then raise exception 'Proyecto de destino no encontrado.' using errcode='22023'; end if;
 stamp=to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
 select username into actor from public.crm_user_roles where user_id=(select auth.uid());
 update public.crm_workspaces w set payload=jsonb_set(jsonb_set(w.payload,'{projects}',coalesce((select jsonb_agg(value order by n) from jsonb_array_elements_text(w.payload->'projects') with ordinality a(value,n) where value<>source_project),'[]'::jsonb)),'{tasks}',coalesce((select jsonb_agg(case when value->>'project'=source_project then value||jsonb_build_object('project',target_project,'updatedAt',stamp,'comments',coalesce(value->'comments','[]'::jsonb)||jsonb_build_array(jsonb_build_object('text','Proyecto eliminado por '||actor||'. Tarea movida de '||source_project||' a '||target_project,'at',stamp))) else value end order by n) from jsonb_array_elements(w.payload->'tasks') with ordinality a(value,n)),'[]'::jsonb)),revision=revision+1,updated_at=now()
 where w.payload->'projects' ? source_project or exists(select 1 from jsonb_array_elements(w.payload->'tasks') t where t->>'project'=source_project);
 delete from public.crm_projects where name=source_project;
 return moved;
end $$;
revoke all on function crm_private.delete_project_move_tasks(text,text) from public,anon;
grant execute on function crm_private.delete_project_move_tasks(text,text) to authenticated;
create function public.crm_delete_project_move_tasks(source_project text,target_project text) returns integer
language sql security invoker set search_path='' as $$ select crm_private.delete_project_move_tasks(source_project,target_project) $$;
revoke all on function public.crm_delete_project_move_tasks(text,text) from public,anon;
grant execute on function public.crm_delete_project_move_tasks(text,text) to authenticated;
