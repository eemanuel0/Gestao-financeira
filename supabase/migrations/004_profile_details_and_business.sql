-- Execute após 001_initial.sql, 002_monthly_limits.sql e 003_financial_profiles.sql.
-- Mantém o histórico e acrescenta dados opcionais e fotos privadas dos perfis.
begin;

alter table public.financial_profiles
  add column if not exists legal_name text,
  add column if not exists cnpj text,
  add column if not exists contact_email text,
  add column if not exists contact_phone text,
  add column if not exists avatar_path text;

-- Recebe o CNPJ canônico: 14 caracteres, maiúsculas e sem pontuação.
-- Suporta os formatos numérico e alfanumérico oficiais (ASCII - 48).
create or replace function public.is_valid_cnpj(value text)
returns boolean
language plpgsql
immutable
strict
parallel safe
set search_path = ''
as $function$
declare
  first_weights constant integer[] := array[5,4,3,2,9,8,7,6,5,4,3,2];
  second_weights constant integer[] := array[6,5,4,3,2,9,8,7,6,5,4,3,2];
  first_sum integer := 0;
  second_sum integer := 0;
  character_value integer;
  remainder integer;
  first_digit integer;
  second_digit integer;
  position integer;
begin
  if (value collate "C") !~ '^[A-Z0-9]{12}[0-9]{2}$'
      or value = pg_catalog.repeat(pg_catalog.substr(value, 1, 1), 14) then
    return false;
  end if;

  for position in 1..12 loop
    character_value := pg_catalog.ascii(pg_catalog.substr(value, position, 1)) - 48;
    first_sum := first_sum + character_value * first_weights[position];
    second_sum := second_sum + character_value * second_weights[position];
  end loop;

  remainder := first_sum % 11;
  first_digit := case when remainder < 2 then 0 else 11 - remainder end;
  if first_digit <> pg_catalog.ascii(pg_catalog.substr(value, 13, 1)) - 48 then
    return false;
  end if;

  second_sum := second_sum + first_digit * second_weights[13];
  remainder := second_sum % 11;
  second_digit := case when remainder < 2 then 0 else 11 - remainder end;
  return second_digit = pg_catalog.ascii(pg_catalog.substr(value, 14, 1)) - 48;
end;
$function$;

revoke all on function public.is_valid_cnpj(text)
  from public, anon, authenticated;
grant execute on function public.is_valid_cnpj(text) to authenticated;

alter table public.financial_profiles
  drop constraint if exists financial_profiles_business_details_only;
alter table public.financial_profiles
  add constraint financial_profiles_business_details_only check (
    kind = 'business'
    or (
      legal_name is null and cnpj is null
      and contact_email is null and contact_phone is null
    )
  );

alter table public.financial_profiles
  drop constraint if exists financial_profiles_legal_name_valid;
alter table public.financial_profiles
  add constraint financial_profiles_legal_name_valid check (
    legal_name is null or (
      legal_name = btrim(legal_name)
      and char_length(legal_name) between 1 and 120
    )
  );

alter table public.financial_profiles
  drop constraint if exists financial_profiles_cnpj_valid;
alter table public.financial_profiles
  add constraint financial_profiles_cnpj_valid check (
    cnpj is null or public.is_valid_cnpj(cnpj)
  );

alter table public.financial_profiles
  drop constraint if exists financial_profiles_contact_email_valid;
alter table public.financial_profiles
  add constraint financial_profiles_contact_email_valid check (
    contact_email is null or (
      contact_email = btrim(contact_email)
      and char_length(contact_email) between 1 and 254
      and (contact_email collate "C") ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    )
  );

alter table public.financial_profiles
  drop constraint if exists financial_profiles_contact_phone_valid;
alter table public.financial_profiles
  add constraint financial_profiles_contact_phone_valid check (
    contact_phone is null or (
      contact_phone = btrim(contact_phone)
      and char_length(contact_phone) between 1 and 32
      and (contact_phone collate "C") ~ '^[+0-9() .[:space:]-]+$'
      and char_length(regexp_replace(contact_phone, '[^0-9]', '', 'g')) between 8 and 15
    )
  );

alter table public.financial_profiles
  drop constraint if exists financial_profiles_avatar_path_valid;
alter table public.financial_profiles
  add constraint financial_profiles_avatar_path_valid check (
    avatar_path is null or (avatar_path collate "C") ~ (
      '^' || user_id::text || '/' || id
      || '/[A-Za-z0-9_-]{1,128}\.(jpg|jpeg|png|webp)$'
    )
  );

-- Atualização limitada aos dados editáveis; a identidade e o tipo não mudam.
grant update (name, legal_name, cnpj, contact_email, contact_phone, avatar_path)
  on public.financial_profiles to authenticated;

-- Novas categorias empresariais, preservando também as categorias antigas.
-- O perfil Pessoal continua aceitando somente as categorias pessoais.
alter table public.transactions
  drop constraint if exists transactions_valid_category;
alter table public.transactions
  add constraint transactions_valid_category check (
    (
      profile_id = 'personal'
      and (
        (type = 'income' and category in ('salary', 'services', 'other'))
        or (type = 'expense' and category in (
          'food', 'housing', 'transport', 'health', 'leisure', 'other'
        ))
      )
    )
    or (
      profile_id <> 'personal'
      and (
        (type = 'income' and category in ('sales', 'services', 'other', 'salary'))
        or (type = 'expense' and category in (
          'suppliers', 'payroll', 'businessRent', 'utilities', 'taxes',
          'transport', 'other', 'food', 'housing', 'health', 'leisure'
        ))
      )
    )
  );

-- O Supabase Storage aplica estes limites ao receber os arquivos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos', 'profile-photos', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- O Storage já mantém RLS ativa em storage.objects.
-- Não alteramos os privilégios ou as políticas dos outros buckets.
drop policy if exists profile_photos_select_own on storage.objects;
create policy profile_photos_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and split_part(name, '/', 1) = (select auth.uid())::text
    and (name collate "C") ~ '^[0-9a-f-]{36}/[a-z][a-z0-9_-]{0,63}/[A-Za-z0-9_-]{1,128}\.(jpg|jpeg|png|webp)$'
    and exists (
      select 1 from public.financial_profiles as profile
      where profile.user_id = (select auth.uid())
        and profile.id = split_part(storage.objects.name, '/', 2)
    )
  );

drop policy if exists profile_photos_insert_own on storage.objects;
create policy profile_photos_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and split_part(name, '/', 1) = (select auth.uid())::text
    and (name collate "C") ~ '^[0-9a-f-]{36}/[a-z][a-z0-9_-]{0,63}/[A-Za-z0-9_-]{1,128}\.(jpg|jpeg|png|webp)$'
    and exists (
      select 1 from public.financial_profiles as profile
      where profile.user_id = (select auth.uid())
        and profile.id = split_part(storage.objects.name, '/', 2)
    )
  );

drop policy if exists profile_photos_delete_own on storage.objects;
create policy profile_photos_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and split_part(name, '/', 1) = (select auth.uid())::text
    and (name collate "C") ~ '^[0-9a-f-]{36}/[a-z][a-z0-9_-]{0,63}/[A-Za-z0-9_-]{1,128}\.(jpg|jpeg|png|webp)$'
    and exists (
      select 1 from public.financial_profiles as profile
      where profile.user_id = (select auth.uid())
        and profile.id = split_part(storage.objects.name, '/', 2)
    )
  );

commit;

notify pgrst, 'reload schema';
