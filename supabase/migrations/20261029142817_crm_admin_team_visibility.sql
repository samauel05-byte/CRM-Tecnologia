create policy crm_admin_read_team on public.crm_workspaces for select to authenticated using ((select crm_private.is_admin()));
