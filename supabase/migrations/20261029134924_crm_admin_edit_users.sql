create function crm_private.edit_user(target_id uuid, new_username text, new_role text) returns void
language plpgsql security definer set search_path='' as $$
begin
  lock table public.crm_user_roles in share row exclusive mode;
  if not crm_private.is_admin() then raise exception 'Solo el administrador puede editar usuarios.' using errcode='42501'; end if;
  if new_role not in ('admin','user') or new_role is null or new_username is null or length(trim(new_username)) not between 1 and 80 then raise exception 'Nombre o rol inválido.' using errcode='22023'; end if;
  if not exists(select 1 from public.crm_user_roles where user_id=target_id) then raise exception 'Usuario no encontrado.' using errcode='P0002'; end if;
  if new_role='user' and exists(select 1 from public.crm_user_roles where user_id=target_id and role='admin') and (select count(*) from public.crm_user_roles where role='admin')<=1 then raise exception 'Debe quedar al menos un administrador.' using errcode='22023'; end if;
  update public.crm_user_roles set username=trim(new_username),role=new_role where user_id=target_id;
end $$;
revoke all on function crm_private.edit_user(uuid,text,text) from public,anon;
grant execute on function crm_private.edit_user(uuid,text,text) to authenticated;
create function public.crm_edit_user(target_id uuid,new_username text,new_role text) returns void
language sql security invoker set search_path='' as $$ select crm_private.edit_user(target_id,new_username,new_role) $$;
revoke all on function public.crm_edit_user(uuid,text,text) from public,anon;
grant execute on function public.crm_edit_user(uuid,text,text) to authenticated;
