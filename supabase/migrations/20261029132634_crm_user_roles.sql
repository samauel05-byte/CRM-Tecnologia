create table public.crm_user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (length(username) between 1 and 80),
  email text not null,
  role text not null default 'user' check (role in ('admin','user')),
  created_at timestamptz not null default now()
);
alter table public.crm_user_roles enable row level security;
revoke all on public.crm_user_roles from anon, authenticated;
grant select on public.crm_user_roles to authenticated;

-- A private, parameter-free helper avoids recursive RLS checks. Membership is
-- read from the database, never from user-editable profile metadata.
create schema if not exists crm_private;
revoke all on schema crm_private from public;
grant usage on schema crm_private to authenticated;
create function crm_private.is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (
  select 1 from public.crm_user_roles
  where user_id = (select auth.uid()) and role = 'admin'
) $$;
revoke all on function crm_private.is_admin() from public, anon;
grant execute on function crm_private.is_admin() to authenticated;
create policy crm_role_read on public.crm_user_roles for select to authenticated
  using (user_id = (select auth.uid()) or (select crm_private.is_admin()));
