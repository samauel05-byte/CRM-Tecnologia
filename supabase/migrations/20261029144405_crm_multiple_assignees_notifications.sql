create or replace function crm_private.task_assignees(task jsonb) returns text[] language sql immutable set search_path='' as $$
select coalesce(array_agg(distinct trim(name)) filter(where trim(name)<>''),'{}'::text[]) from jsonb_array_elements_text(case when jsonb_typeof(task->'owners')='array' then task->'owners' else to_jsonb(string_to_array(coalesce(task->>'owner',''),', ')) end) name $$;
revoke all on function crm_private.task_assignees(jsonb) from public,anon,authenticated;
create function crm_private.normalize_tasks() returns trigger language plpgsql set search_path='' as $$
declare task jsonb; tasks jsonb='[]'; names text[];
begin
 for task in select value from jsonb_array_elements(new.payload->'tasks') loop
 names=crm_private.task_assignees(task);
 task=task||jsonb_build_object('name',upper(trim(task->>'name')),'owners',to_jsonb(names),'owner',array_to_string(names,', '));
 tasks=tasks||jsonb_build_array(task);
 end loop;
 new.payload=jsonb_set(new.payload,'{tasks}',tasks);return new;
end $$;
revoke all on function crm_private.normalize_tasks() from public,anon,authenticated;
create trigger crm_normalize_tasks before insert or update of payload on public.crm_workspaces for each row execute function crm_private.normalize_tasks();
create table public.crm_notifications(
 id uuid primary key default gen_random_uuid(),recipient_id uuid not null references auth.users(id) on delete cascade,
 workspace_id uuid not null references auth.users(id) on delete cascade,task_id text not null,kind text not null check(kind in ('assigned','due')),
 title text not null,message text not null,dedupe_key text not null unique,created_at timestamptz not null default now(),read_at timestamptz,
 email_status text not null default 'pending' check(email_status in ('pending','sending','sent','failed')),email_attempts int not null default 0,email_locked_at timestamptz,email_sent_at timestamptz
);
alter table public.crm_notifications enable row level security;
revoke all on public.crm_notifications from anon,authenticated;
grant select on public.crm_notifications to authenticated;
grant update(read_at) on public.crm_notifications to authenticated;
create policy crm_notifications_own_read on public.crm_notifications for select to authenticated using(recipient_id=(select auth.uid()));
create policy crm_notifications_own_seen on public.crm_notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
create index crm_notifications_recipient_created on public.crm_notifications(recipient_id,created_at desc);
create index crm_notifications_outbox on public.crm_notifications(email_status,created_at) where email_status in ('pending','sending');
create function crm_private.notify_assignments() returns trigger language plpgsql security definer set search_path='' as $$
declare task jsonb; previous_task jsonb; person record;
begin
 for task in select value from jsonb_array_elements(new.payload->'tasks') where not value ? 'deletedAt' loop
 previous_task=null;
 if tg_op='UPDATE' then select value into previous_task from jsonb_array_elements(old.payload->'tasks') where value->>'id'=task->>'id';end if;
 for person in select user_id,username from public.crm_user_roles where username=any(crm_private.task_assignees(task)) and not username=any(crm_private.task_assignees(coalesce(previous_task,'{}'::jsonb))) loop
 insert into public.crm_notifications(recipient_id,workspace_id,task_id,kind,title,message,dedupe_key)
 values(person.user_id,new.user_id,task->>'id','assigned','Nueva tarea asignada',task->>'name',new.user_id||'/'||(task->>'id')||'/'||person.user_id||'/assigned/'||new.revision)
 on conflict(dedupe_key) do nothing;
 end loop;end loop;return new;
end $$;
revoke all on function crm_private.notify_assignments() from public,anon,authenticated;
create trigger crm_notify_assignments after insert or update of payload on public.crm_workspaces for each row execute function crm_private.notify_assignments();
create function crm_private.queue_deadlines() returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.crm_notifications(recipient_id,workspace_id,task_id,kind,title,message,dedupe_key)
 select person.user_id,w.user_id,task->>'id','due','Tu tarea está por vencer',(task->>'name')||' · Fecha de terminación: '||(task->>'date'),
 w.user_id||'/'||(task->>'id')||'/'||person.user_id||'/due/'||(task->>'date')
 from public.crm_workspaces w cross join lateral jsonb_array_elements(w.payload->'tasks') task
 join public.crm_user_roles person on person.username=any(crm_private.task_assignees(task))
 where not task ? 'deletedAt' and task->>'status'<>'Completado' and task->>'date'~'^\d{4}-\d{2}-\d{2}$'
 and ((task->>'date')::date+time '23:59:59') at time zone 'America/Santo_Domingo' between now() and now()+interval '24 hours'
 on conflict(dedupe_key) do nothing;
end $$;
revoke all on function crm_private.queue_deadlines() from public,anon,authenticated;
grant select,update on public.crm_notifications to service_role;
create function public.crm_claim_notification_emails() returns table(id uuid,email text,title text,message text)
language sql security invoker set search_path='' as $$
with claimed as (
 update public.crm_notifications n set email_status='sending',email_locked_at=now(),email_attempts=email_attempts+1
 where n.id in(select q.id from public.crm_notifications q where (q.email_status='pending' or (q.email_status='sending' and q.email_locked_at<now()-interval '10 minutes')) and q.email_attempts<5 order by q.created_at for update skip locked limit 10)
 returning n.id,n.recipient_id,n.title,n.message
) select c.id,r.email,c.title,c.message from claimed c join public.crm_user_roles r on r.user_id=c.recipient_id $$;
revoke all on function public.crm_claim_notification_emails() from public,anon,authenticated;
grant execute on function public.crm_claim_notification_emails() to service_role;
create extension if not exists pg_cron;
select cron.schedule('crm-deadline-notifications','*/15 * * * *','select crm_private.queue_deadlines()');
update public.crm_workspaces set payload=payload,revision=revision+1;

