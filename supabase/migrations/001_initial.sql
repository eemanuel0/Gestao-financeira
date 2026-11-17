-- Execute no SQL Editor de um projeto Supabase novo.
begin;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  type text not null check (type in ('income', 'expense')),
  amount_cents bigint not null check (amount_cents between 1 and 9999999999),
  category text not null,
  description text not null check (char_length(btrim(description)) between 1 and 120),
  occurred_on date not null,
  created_at timestamptz not null default now(),
  constraint transactions_valid_category check (
    (type = 'income' and category in ('salary', 'services', 'other'))
    or
    (type = 'expense' and category in (
      'food', 'housing', 'transport', 'health', 'leisure', 'other'
    ))
  )
);

create index if not exists transactions_user_date_idx
  on public.transactions (user_id, occurred_on desc, created_at desc, id);

-- A proteção também é aplicada pelo servidor, independentemente da tela.
alter table public.transactions enable row level security;
alter table public.transactions force row level security;

drop policy if exists transactions_select_own on public.transactions;
create policy transactions_select_own on public.transactions
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists transactions_insert_own on public.transactions;
create policy transactions_insert_own on public.transactions
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists transactions_update_own on public.transactions;
create policy transactions_update_own on public.transactions
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists transactions_delete_own on public.transactions;
create policy transactions_delete_own on public.transactions
  for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.transactions from public, anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;

-- Nenhum usuário ou lançamento de exemplo é criado.
commit;
