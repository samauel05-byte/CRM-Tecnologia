-- Retain the cloud copy as a read-only migration backup. Only CRM tables are affected.
create function crm_private.cloud_cutover_readonly() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if (select auth.uid()) is not null then
  raise exception 'CRM en migración a la PC local. Completa MIGRAR-A-LOCAL.cmd antes de guardar cambios.' using errcode='42501';
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
revoke all on function crm_private.cloud_cutover_readonly() from public,anon;
grant execute on function crm_private.cloud_cutover_readonly() to authenticated;
create trigger crm_local_cutover_readonly before insert or update or delete on public.crm_workspaces for each row execute function crm_private.cloud_cutover_readonly();
create trigger crm_local_cutover_readonly before insert or update or delete on public.crm_projects for each row execute function crm_private.cloud_cutover_readonly();
create trigger crm_local_cutover_readonly before insert or update or delete on public.crm_user_roles for each row execute function crm_private.cloud_cutover_readonly();
create trigger crm_local_cutover_readonly before insert or update or delete on public.crm_attachments for each row execute function crm_private.cloud_cutover_readonly();
select cron.unschedule(jobid) from cron.job where jobname in ('crm-deadline-notifications','crm-notification-email-delivery');
