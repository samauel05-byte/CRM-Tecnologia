create policy crm_mail_config_deny_clients on crm_private.mail_delivery_config for all to authenticated using(false) with check(false);
