create extension if not exists pg_net;
create table crm_private.mail_delivery_config(id boolean primary key default true check(id),anon_key text not null);
alter table crm_private.mail_delivery_config enable row level security;
revoke all on crm_private.mail_delivery_config from public,anon,authenticated;
create function crm_private.deliver_notification_mail() returns void language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.crm_notifications where email_status in ('pending','sending') and email_attempts<5) then
 perform net.http_post(url:='https://uvaotfqutfojokbnzgcs.supabase.co/functions/v1/crm-notification-mailer',headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||(select anon_key from crm_private.mail_delivery_config where id=true)),body:='{}'::jsonb,timeout_milliseconds:=10000);
 end if;
end $$;
revoke all on function crm_private.deliver_notification_mail() from public,anon,authenticated;
select cron.schedule('crm-notification-email-delivery','*/2 * * * *','select crm_private.deliver_notification_mail()');
