-- CRM Tecnología: objects are isolated from other applications in this project.
create table public.crm_workspaces (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now()
);
alter table public.crm_workspaces enable row level security;
revoke all on public.crm_workspaces from anon;
grant select, insert, update on public.crm_workspaces to authenticated;
create policy crm_workspace_select on public.crm_workspaces for select to authenticated
  using ((select auth.uid()) = user_id);
create policy crm_workspace_insert on public.crm_workspaces for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy crm_workspace_update on public.crm_workspaces for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create table public.crm_attachments (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(name) between 1 and 200),
  size bigint not null check (size between 0 and 10000000),
  created_at timestamptz not null default now()
);
create index crm_attachments_user_id_idx on public.crm_attachments(user_id);
alter table public.crm_attachments enable row level security;
revoke all on public.crm_attachments from anon;
grant select, insert on public.crm_attachments to authenticated;
grant usage on schema public to authenticated;
create policy crm_attachment_select on public.crm_attachments for select to authenticated
  using ((select auth.uid()) = user_id);
create policy crm_attachment_insert on public.crm_attachments for insert to authenticated
  with check ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit)
  values ('crm-attachments', 'crm-attachments', false, 10000000);
create policy crm_storage_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'crm-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy crm_storage_select on storage.objects for select to authenticated
  using (bucket_id = 'crm-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
