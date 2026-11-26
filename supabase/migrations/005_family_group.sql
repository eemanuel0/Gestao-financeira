-- Execute após as migrações 001–004.
begin;

create schema if not exists finance_private;
revoke all on schema finance_private from public, anon, authenticated;

create table if not exists finance_private.family_groups (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  invite_hash bytea unique,
  invite_expires_at timestamptz
);

create table if not exists finance_private.family_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  owner_id uuid not null references finance_private.family_groups(owner_id)
    on delete cascade
);

create index if not exists family_members_owner_idx
  on finance_private.family_members (owner_id);

alter table public.financial_profiles
  drop constraint if exists financial_profiles_id_check,
  drop constraint if exists financial_profiles_kind_check,
  drop constraint if exists financial_profiles_valid_identity;
alter table public.financial_profiles
  add constraint financial_profiles_valid_identity check (
    (kind = 'personal' and id = 'personal')
    or (kind = 'business' and id <> 'personal' and id ~ '^[a-z][a-z0-9_-]{0,63}$')
    or (kind = 'family' and id = 'family.shared')
  );

create or replace function public.current_family_owner_id()
returns uuid
language sql stable security definer set search_path = ''
as $function$
  select owner_id from finance_private.family_members where user_id = auth.uid();
$function$;

create or replace function public.ensure_financial_profiles(include_family boolean)
returns jsonb
language plpgsql security invoker set search_path = ''
as $function$
declare
  current_user_id uuid := auth.uid();
  family_owner_id uuid;
  active_id text;
begin
  if current_user_id is null then
    raise exception 'Entre na sua conta para continuar.' using errcode = '42501';
  end if;

  insert into public.financial_profiles (user_id, id, kind, name)
  values
    (current_user_id, 'personal', 'personal', 'Pessoal'),
    (current_user_id, 'business', 'business', 'Empresa')
  on conflict (user_id, id) do nothing;

  if include_family then
    insert into public.financial_profiles (user_id, id, kind, name)
    values (current_user_id, 'family.shared', 'family', 'Familiar')
    on conflict (user_id, id) do nothing;
    family_owner_id := public.current_family_owner_id();
  end if;

  insert into public.financial_profile_preferences (user_id, active_profile_id)
  values (current_user_id, 'personal')
  on conflict (user_id) do nothing;

  select active_profile_id into active_id
  from public.financial_profile_preferences where user_id = current_user_id;
  if active_id = 'family.shared' and include_family is not true then
    active_id := 'personal';
  end if;

  return pg_catalog.jsonb_build_object(
    'profiles', (
      select pg_catalog.jsonb_agg(
        case when profile.kind = 'family' then
          pg_catalog.to_jsonb(profile) ||
            pg_catalog.jsonb_build_object('family_owner_id', family_owner_id)
        else pg_catalog.to_jsonb(profile) end
        order by case profile.kind
          when 'personal' then 0 when 'business' then 1 else 2 end, profile.id
      )
      from public.financial_profiles as profile
      where profile.user_id = current_user_id
        and (profile.kind <> 'family' or include_family)
    ),
    'active_profile_id', active_id
  );
end;
$function$;

-- Os clientes antigos continuam a usar a assinatura sem argumentos.
create or replace function public.ensure_financial_profiles()
returns jsonb
language sql security invoker set search_path = ''
as $function$
  select public.ensure_financial_profiles(false);
$function$;

create or replace function public.create_family_group()
returns void
language plpgsql security definer set search_path = ''
as $function$
declare
  caller uuid := auth.uid();
  current_owner uuid;
begin
  if caller is null then
    raise exception 'Entre na sua conta para continuar.' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text, 0));
  current_owner := public.current_family_owner_id();
  if current_owner = caller then
    return;
  elsif current_owner is not null then
    raise exception 'Saia do grupo atual antes de criar outro.' using errcode = 'P0001';
  end if;

  insert into public.financial_profiles (user_id, id, kind, name)
  values (caller, 'family.shared', 'family', 'Familiar')
  on conflict (user_id, id) do nothing;
  insert into finance_private.family_groups (owner_id) values (caller);
  insert into finance_private.family_members (user_id, owner_id) values (caller, caller);
end;
$function$;

create or replace function public.create_family_invite()
returns text
language plpgsql security definer set search_path = ''
as $function$
declare
  caller uuid := auth.uid();
  invite_code text := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
begin
  update finance_private.family_groups
  set invite_hash = pg_catalog.sha256(pg_catalog.convert_to(invite_code, 'UTF8')),
      invite_expires_at = pg_catalog.now() + interval '7 days'
  where owner_id = caller;
  if not found then
    raise exception 'Somente o responsável pode gerar convites.' using errcode = '42501';
  end if;

  return invite_code;
end;
$function$;

create or replace function public.join_family_group(invite_code text)
returns void
language plpgsql security definer set search_path = ''
as $function$
declare
  caller uuid := auth.uid();
  normalized_code text := pg_catalog.lower(pg_catalog.btrim(invite_code));
  invited_owner uuid;
begin
  if caller is null then
    raise exception 'Entre na sua conta para continuar.' using errcode = '42501';
  end if;
  if normalized_code is null or normalized_code !~ '^[0-9a-f]{32}$' then
    raise exception 'Informe um código de convite válido.' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text, 0));
  if public.current_family_owner_id() is not null then
    raise exception 'Você já participa de um grupo familiar.' using errcode = 'P0001';
  end if;

  update finance_private.family_groups
  set invite_hash = null, invite_expires_at = null
  where invite_hash = pg_catalog.sha256(pg_catalog.convert_to(normalized_code, 'UTF8'))
    and invite_expires_at > pg_catalog.clock_timestamp()
  returning owner_id into invited_owner;
  if not found then
    raise exception 'Este convite venceu ou já foi utilizado.' using errcode = 'P0002';
  end if;

  insert into finance_private.family_members (user_id, owner_id)
  values (caller, invited_owner);
end;
$function$;

create or replace function public.list_family_members()
returns table (user_id uuid, name text)
language sql stable security definer set search_path = ''
as $function$
  select member.user_id,
    coalesce(
      nullif(pg_catalog.left(pg_catalog.btrim(account.raw_user_meta_data->>'name'), 60), ''),
      'Membro'
    )
  from finance_private.family_members as member
  join auth.users as account on account.id = member.user_id
  where member.owner_id = public.current_family_owner_id()
  order by (member.user_id = member.owner_id) desc, member.user_id;
$function$;

create or replace function public.remove_family_member(member_id uuid)
returns void
language sql security definer set search_path = ''
as $function$
  delete from finance_private.family_members
  where user_id = member_id and owner_id = auth.uid() and user_id <> owner_id;
$function$;

create or replace function public.leave_family_group()
returns void
language sql security definer set search_path = ''
as $function$
  delete from finance_private.family_members
  where user_id = auth.uid() and user_id <> owner_id;
$function$;

revoke all on function public.current_family_owner_id(),
  public.ensure_financial_profiles(boolean), public.ensure_financial_profiles(),
  public.create_family_group(), public.create_family_invite(),
  public.join_family_group(text), public.list_family_members(),
  public.remove_family_member(uuid), public.leave_family_group()
  from public, anon, authenticated;
grant execute on function public.current_family_owner_id(),
  public.ensure_financial_profiles(boolean), public.ensure_financial_profiles(),
  public.create_family_group(), public.create_family_invite(),
  public.join_family_group(text), public.list_family_members(),
  public.remove_family_member(uuid), public.leave_family_group() to authenticated;

-- As linhas conjuntas usam a chave do responsável e exigem vínculo com o grupo.
-- A política restritiva complementa as permissões já existentes nos perfis privados.
drop policy if exists transactions_family_scope on public.transactions;
create policy transactions_family_scope on public.transactions
  as restrictive for all to authenticated
  using (profile_id <> 'family.shared' or user_id = (select public.current_family_owner_id()))
  with check (profile_id <> 'family.shared' or user_id = (select public.current_family_owner_id()));

drop policy if exists transactions_shared_family on public.transactions;
create policy transactions_shared_family on public.transactions
  for all to authenticated
  using (profile_id = 'family.shared' and user_id = (select public.current_family_owner_id()))
  with check (profile_id = 'family.shared' and user_id = (select public.current_family_owner_id()));

drop policy if exists monthly_limits_family_scope on public.monthly_limits;
create policy monthly_limits_family_scope on public.monthly_limits
  as restrictive for all to authenticated
  using (profile_id <> 'family.shared' or user_id = (select public.current_family_owner_id()))
  with check (profile_id <> 'family.shared' or user_id = (select public.current_family_owner_id()));

drop policy if exists monthly_limits_shared_family on public.monthly_limits;
create policy monthly_limits_shared_family on public.monthly_limits
  for all to authenticated
  using (profile_id = 'family.shared' and user_id = (select public.current_family_owner_id()))
  with check (profile_id = 'family.shared' and user_id = (select public.current_family_owner_id()));

create or replace function finance_private.keep_family_record_scope()
returns trigger
language plpgsql set search_path = ''
as $function$
begin
  if (old.profile_id = 'family.shared' or new.profile_id = 'family.shared')
    and (new.user_id <> old.user_id or new.profile_id <> old.profile_id) then
    raise exception 'O espaço de um registro familiar é fixo.' using errcode = '23514';
  end if;
  return new;
end;
$function$;

drop trigger if exists keep_family_transaction_scope on public.transactions;
create trigger keep_family_transaction_scope before update on public.transactions
  for each row execute function finance_private.keep_family_record_scope();

drop trigger if exists keep_family_limit_scope on public.monthly_limits;
create trigger keep_family_limit_scope before update on public.monthly_limits
  for each row execute function finance_private.keep_family_record_scope();

alter table public.transactions
  drop constraint if exists transactions_valid_category;
alter table public.transactions
  add constraint transactions_valid_category check (
    case
      when profile_id = 'personal' then
        (type = 'income' and category in ('salary', 'services', 'other'))
        or (type = 'expense' and category in (
          'food', 'housing', 'transport', 'health', 'leisure', 'other'
        ))
      when profile_id = 'family.shared' then
        (type = 'income' and category in ('contribution', 'salary', 'services', 'other'))
        or (type = 'expense' and category in (
          'food', 'housing', 'householdBills', 'transport', 'health', 'education', 'leisure', 'other'
        ))
      else
        (type = 'income' and category in ('sales', 'services', 'other', 'salary'))
        or (type = 'expense' and category in (
          'suppliers', 'payroll', 'businessRent', 'utilities', 'taxes',
          'transport', 'other', 'food', 'housing', 'health', 'leisure'
        ))
    end
  );

commit;
notify pgrst, 'reload schema';
