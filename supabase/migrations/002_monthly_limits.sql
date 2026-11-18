-- Execute após 001_initial.sql no SQL Editor do mesmo projeto Supabase.
begin;

create table if not exists public.monthly_limits (
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  limit_cents bigint not null check (limit_cents between 1 and 9999999999),
  primary key (user_id, month)
);

alter table public.monthly_limits enable row level security;
alter table public.monthly_limits force row level security;

drop policy if exists monthly_limits_select_own on public.monthly_limits;
create policy monthly_limits_select_own on public.monthly_limits
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists monthly_limits_insert_own on public.monthly_limits;
create policy monthly_limits_insert_own on public.monthly_limits
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists monthly_limits_update_own on public.monthly_limits;
create policy monthly_limits_update_own on public.monthly_limits
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists monthly_limits_delete_own on public.monthly_limits;
create policy monthly_limits_delete_own on public.monthly_limits
  for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.monthly_limits from public, anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.monthly_limits to authenticated;

-- Limites são definidos pelo usuário; nenhum valor é preenchido aqui.
commit;

-- Atualiza a API para que a nova tabela fique disponível no aplicativo.
notify pgrst, 'reload schema';
