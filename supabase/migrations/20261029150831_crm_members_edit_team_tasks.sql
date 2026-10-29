grant execute on function crm_private.task_assignees(jsonb) to authenticated,service_role;
create or replace function crm_private.edit_team_task(workspace_id uuid,task_id text,expected_revision bigint,patch jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare space public.crm_workspaces%rowtype; current_task jsonb; changed_task jsonb; next_tasks jsonb; stamp text;
begin
 if not crm_private.is_member() then raise exception 'No tienes acceso al equipo.' using errcode='42501'; end if;
 select * into space from public.crm_workspaces where user_id=workspace_id for update;
 if not found then raise exception 'Espacio no encontrado.' using errcode='P0002'; end if;
 if space.revision<>expected_revision then raise exception 'La tarea cambió en otro dispositivo. Actualiza el panel y vuelve a intentarlo.' using errcode='40001'; end if;
 if jsonb_typeof(patch)<>'object' or patch-array['name','project','status','owner','start','date','priority','description','owners']<>'{}'::jsonb or (select count(*) from jsonb_object_keys(patch))<>9 then raise exception 'Campos inválidos.' using errcode='22023'; end if;
 if exists(select 1 from jsonb_each(patch) f where f.key<>'owners' and jsonb_typeof(f.value)<>'string') then raise exception 'Formato inválido.' using errcode='22023'; end if;
 if length(trim(patch->>'name')) not between 1 and 160 or length(patch->>'description')>10000 or length(patch->>'owner')>1600 then raise exception 'Revisa el nombre y la descripción.' using errcode='22023'; end if;
 if not exists(select 1 from public.crm_projects where name=patch->>'project') or not (coalesce(space.payload->'statuses','["Pendiente","En curso","Completado","Sin asignar"]'::jsonb)||'["Sin asignar"]'::jsonb) ? (patch->>'status') or (patch->>'priority') not in ('Urgente','Alta','Normal','Baja') then raise exception 'Proyecto, estado o prioridad inválido.' using errcode='22023'; end if;
 if jsonb_typeof(patch->'owners')<>'array' or jsonb_array_length(patch->'owners')>20 or exists(select 1 from jsonb_array_elements(patch->'owners') value where jsonb_typeof(value)<>'string') then raise exception 'Selecciona responsables válidos.' using errcode='22023'; end if;
 if exists(select 1 from jsonb_array_elements_text(patch->'owners') value where not exists(select 1 from public.crm_user_roles where username=value)) then raise exception 'Selecciona responsables registrados.' using errcode='22023'; end if;
 patch=jsonb_set(patch,'{owner}',to_jsonb(array_to_string(crm_private.task_assignees(patch),', ')));
 if (patch->>'start'<>'' and (patch->>'start'!~'^\d{4}-\d{2}-\d{2}$')) or (patch->>'date'<>'' and (patch->>'date'!~'^\d{4}-\d{2}-\d{2}$')) then raise exception 'Fechas inválidas.' using errcode='22023'; end if;
 if patch->>'start'<>'' then perform (patch->>'start')::date; end if;
 if patch->>'date'<>'' then perform (patch->>'date')::date; end if;
 if patch->>'start'<>'' and patch->>'date'<>'' and patch->>'start'>patch->>'date' then raise exception 'La terminación debe ser posterior al inicio.' using errcode='22023'; end if;
 select value into current_task from jsonb_array_elements(space.payload->'tasks') where value->>'id'=task_id and not value ? 'deletedAt';
 if not found then raise exception 'Tarea no encontrada.' using errcode='P0002'; end if;
 changed_task=current_task||patch;
 if changed_task=current_task then return space.revision; end if;
 stamp=to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
 changed_task=jsonb_set(changed_task,'{updatedAt}',to_jsonb(stamp));
 changed_task=jsonb_set(changed_task,'{comments}',coalesce(current_task->'comments','[]'::jsonb)||jsonb_build_array(jsonb_build_object('text','Tarea actualizada por '||(select username from public.crm_user_roles where user_id=(select auth.uid())),'at',stamp)));
 select jsonb_agg(case when value->>'id'=task_id then changed_task else value end order by n) into next_tasks from jsonb_array_elements(space.payload->'tasks') with ordinality a(value,n);
 update public.crm_workspaces set payload=jsonb_set(space.payload,'{tasks}',next_tasks),revision=space.revision+1,updated_at=now() where user_id=workspace_id;
 return space.revision+1;
end $$;
