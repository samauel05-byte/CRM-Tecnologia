create function crm_private.list_members() returns table(user_id uuid,username text)
language sql stable security definer set search_path='' as $$
select r.user_id,r.username from public.crm_user_roles r
where (select auth.uid()) is not null and exists(select 1 from public.crm_user_roles me where me.user_id=(select auth.uid()))
order by r.username $$;
revoke all on function crm_private.list_members() from public,anon;
grant execute on function crm_private.list_members() to authenticated;
create function public.crm_list_members() returns table(user_id uuid,username text)
language sql stable security invoker set search_path='' as $$ select * from crm_private.list_members() $$;
revoke all on function public.crm_list_members() from public,anon;
grant execute on function public.crm_list_members() to authenticated;
