-- Execute após 001_initial.sql e 002_monthly_limits.sql no mesmo Supabase.
-- O histórico existente continua em Pessoal, sem alterar nenhum valor.
begin;

create table if not exists public.financial_profiles (
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  id text not null check (id ~ '^[a-z][a-z0-9_-]{0,63}$'),
  kind text not null check (kind in ('personal', 'business')),
  name text not null check (
    name = btrim(name) and char_length(name) between 1 and 60
  ),
  primary key (user_id, id),
  constraint financial_profiles_valid_identity check (
    (kind = 'personal' and id = 'personal')
    or (kind = 'business' and id <> 'personal')
  )
);

create table if not exists public.financial_profile_preferences (
  user_id uuid primary key default auth.uid()
    references auth.users(id) on delete cascade,
  active_profile_id text not null default 'personal',
  constraint financial_profile_preferences_owned_profile_fkey
    foreign key (user_id, active_profile_id)
    references public.financial_profiles(user_id, id)
);

alter table public.financial_profiles enable row level security;
alter table public.financial_profiles force row level security;
alter table public.financial_profile_preferences enable row level security;
alter table public.financial_profile_preferences force row level security;

drop policy if exists financial_profiles_select_own on public.financial_profiles;
create policy financial_profiles_select_own on public.financial_profiles
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists financial_profiles_insert_own on public.financial_profiles;
create policy financial_profiles_insert_own on public.financial_profiles
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists financial_profiles_update_own on public.financial_profiles;
create policy financial_profiles_update_own on public.financial_profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists financial_profile_preferences_select_own
  on public.financial_profile_preferences;
create policy financial_profile_preferences_select_own
  on public.financial_profile_preferences
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists financial_profile_preferences_insert_own
  on public.financial_profile_preferences;
create policy financial_profile_preferences_insert_own
  on public.financial_profile_preferences
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists financial_profile_preferences_update_own
  on public.financial_profile_preferences;
create policy financial_profile_preferences_update_own
  on public.financial_profile_preferences
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Revoga também eventuais permissões recebidas por privilégios padrão.
revoke all on public.financial_profiles
  from public, anon, authenticated;
revoke all on public.financial_profile_preferences
  from public, anon, authenticated;
grant usage on schema public to authenticated;
grant select, insert on public.financial_profiles to authenticated;
grant update (name) on public.financial_profiles to authenticated;
grant select, insert on public.financial_profile_preferences to authenticated;
grant update (active_profile_id) on public.financial_profile_preferences
  to authenticated;

-- Cria apenas os espaços financeiros; não cria dinheiro ou lançamentos.
insert into public.financial_profiles (user_id, id, kind, name)
select users.id, defaults.id, defaults.kind, defaults.name
from auth.users as users
cross join (values
  ('personal', 'personal', 'Pessoal'),
  ('business', 'business', 'Empresa')
) as defaults(id, kind, name)
on conflict (user_id, id) do nothing;

insert into public.financial_profile_preferences (user_id, active_profile_id)
select id, 'personal' from auth.users
on conflict (user_id) do nothing;

alter table public.transactions
  add column if not exists profile_id text not null default 'personal';
alter table public.monthly_limits
  add column if not exists profile_id text not null default 'personal';

do $migration$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.transactions'::regclass
      and conname = 'transactions_owned_profile_fkey'
  ) then
    alter table public.transactions
      add constraint transactions_owned_profile_fkey
      foreign key (user_id, profile_id)
      references public.financial_profiles(user_id, id);
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.monthly_limits'::regclass
      and conname = 'monthly_limits_owned_profile_fkey'
  ) then
    alter table public.monthly_limits
      add constraint monthly_limits_owned_profile_fkey
      foreign key (user_id, profile_id)
      references public.financial_profiles(user_id, id);
  end if;
end;
$migration$;

-- O mesmo mês pode ter um limite em Pessoal e outro em Empresa.
alter table public.monthly_limits
  drop constraint if exists monthly_limits_pkey;
alter table public.monthly_limits
  add constraint monthly_limits_pkey primary key (user_id, profile_id, month);

create index if not exists transactions_user_profile_date_idx
  on public.transactions
  (user_id, profile_id, occurred_on desc, created_at desc, id);

-- Cadastros novos já recebem os espaços, mesmo antes de abrir o app.
create or replace function public.initialize_financial_profiles_for_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.financial_profiles (user_id, id, kind, name)
  values
    (new.id, 'personal', 'personal', 'Pessoal'),
    (new.id, 'business', 'business', 'Empresa')
  on conflict (user_id, id) do nothing;

  insert into public.financial_profile_preferences (user_id, active_profile_id)
  values (new.id, 'personal')
  on conflict (user_id) do nothing;
  return new;
end;
$function$;

revoke all on function public.initialize_financial_profiles_for_user()
  from public, anon, authenticated;

drop trigger if exists initialize_financial_profiles_after_signup on auth.users;
create trigger initialize_financial_profiles_after_signup
  after insert on auth.users
  for each row execute function public.initialize_financial_profiles_for_user();

-- A RPC roda com as permissões e a sessão do próprio usuário (RLS ativa).
create or replace function public.ensure_financial_profiles()
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  current_user_id uuid := auth.uid();
  result jsonb;
begin
  if current_user_id is null then
    raise exception 'Entre na sua conta para continuar.' using errcode = '42501';
  end if;

  insert into public.financial_profiles (user_id, id, kind, name)
  values
    (current_user_id, 'personal', 'personal', 'Pessoal'),
    (current_user_id, 'business', 'business', 'Empresa')
  on conflict (user_id, id) do nothing;

  insert into public.financial_profile_preferences (user_id, active_profile_id)
  values (current_user_id, 'personal')
  on conflict (user_id) do nothing;

  select pg_catalog.jsonb_build_object(
    'profiles', (
      select pg_catalog.jsonb_agg(
        pg_catalog.to_jsonb(profile)
        order by case when profile.kind = 'personal' then 0 else 1 end,
          profile.id
      )
      from public.financial_profiles as profile
      where profile.user_id = current_user_id
    ),
    'active_profile_id', (
      select active_profile_id from public.financial_profile_preferences
      where user_id = current_user_id
    )
  ) into result;
  return result;
end;
$function$;

revoke all on function public.ensure_financial_profiles()
  from public, anon, authenticated;
grant execute on function public.ensure_financial_profiles() to authenticated;

commit;

notify pgrst, 'reload schema';
