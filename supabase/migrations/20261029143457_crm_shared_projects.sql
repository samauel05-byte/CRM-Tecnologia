create table public.crm_projects(
 name text primary key check(length(trim(name)) between 1 and 80 and name=trim(name)),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.crm_projects enable row level security;
revoke all on public.crm_projects from anon,authenticated;
grant select,insert on public.crm_projects to authenticated;
create policy crm_projects_read on public.crm_projects for select to authenticated using((select crm_private.is_member()));
create policy crm_projects_create on public.crm_projects for insert to authenticated with check(created_by=(select auth.uid()) and (select crm_private.is_member()));
insert into public.crm_projects(name,created_by)
select distinct on (trim(project)) trim(project),w.user_id
from public.crm_workspaces w cross join lateral jsonb_array_elements_text(w.payload->'projects') project
where length(trim(project)) between 1 and 80 order by trim(project),w.user_id;
create function crm_private.rename_project(old_name text,new_name text) returns void
language plpgsql security definer set search_path='' as $$
declare creator uuid; stamp text;
begin
 lock table public.crm_projects in share row exclusive mode;
 select created_by into creator from public.crm_projects where name=old_name;
 if not found then raise exception 'Proyecto no encontrado.' using errcode='P0002'; end if;
 if not crm_private.is_member() or (creator<>(select auth.uid()) and not crm_private.is_admin()) then raise exception 'Solo el creador o el administrador puede renombrar este proyecto.' using errcode='42501'; end if;
 if new_name is null or length(trim(new_name)) not between 1 and 80 then raise exception 'Nombre inválido.' using errcode='22023'; end if;
 new_name=trim(new_name);if new_name=old_name then return; end if;
 update public.crm_projects set name=new_name where name=old_name;
 stamp=to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
 update public.crm_workspaces w set payload=jsonb_set(jsonb_set(payload,'{projects}',coalesce((select jsonb_agg(case when value=old_name then new_name else value end order by n) from jsonb_array_elements_text(w.payload->'projects') with ordinality a(value,n)),'[]'::jsonb)),'{tasks}',coalesce((select jsonb_agg(case when value->>'project'=old_name then value||jsonb_build_object('project',new_name,'updatedAt',stamp) else value end order by n) from jsonb_array_elements(w.payload->'tasks') with ordinality a(value,n)),'[]'::jsonb)),revision=revision+1,updated_at=now()
 where w.payload->'projects' ? old_name or exists(select 1 from jsonb_array_elements(w.payload->'tasks') t where t->>'project'=old_name);
end $$;
revoke all on function crm_private.rename_project(text,text) from public,anon;
grant execute on function crm_private.rename_project(text,text) to authenticated;
create function public.crm_rename_project(old_name text,new_name text) returns void
language sql security invoker set search_path='' as $$ select crm_private.rename_project(old_name,new_name) $$;
revoke all on function public.crm_rename_project(text,text) from public,anon;
grant execute on function public.crm_rename_project(text,text) to authenticated;
