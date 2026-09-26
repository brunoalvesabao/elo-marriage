-- =========================================================================
-- ELO — schema do Supabase
-- Cole este arquivo inteiro no Supabase: SQL Editor → New query → Run.
-- Pode rodar de novo sem problemas (é idempotente).
-- =========================================================================

-- ---------- Tabelas ----------

-- Um casal. Os nomes ficam aqui; o código de convite serve para o(a)
-- parceiro(a) entrar no mesmo casal.
create table if not exists public.couples (
  id          uuid primary key default gen_random_uuid(),
  p0_name     text not null default '',
  p1_name     text not null default '',
  invite_code text not null unique
              default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)),
  created_at  timestamptz not null default now()
);

-- Quem é quem: cada usuário pertence a um único casal, na posição p0 ou p1.
create table if not exists public.members (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id   uuid not null unique references auth.users(id) on delete cascade,
  slot      text not null check (slot in ('p0','p1')),
  joined_at timestamptz not null default now(),
  primary key (couple_id, slot)
);

-- Dados compartilhados do casal.
--   entry       → check-in semanal (id = 'AAAA-Wss:p0' ou 'AAAA-Wss:p1')
--   action      → ações combinadas
--   recognition → mural de reconhecimentos
--   conflict    → registro de conflitos e reparação
create table if not exists public.items (
  couple_id  uuid not null references public.couples(id) on delete cascade,
  kind       text not null check (kind in ('entry','action','recognition','conflict')),
  id         text not null,
  data       jsonb not null,
  author     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (couple_id, kind, id)
);

-- Dados que só o próprio usuário vê.
--   note   → "Meu espaço" (diário privado)
--   safety → respostas de segurança do check-in (id = semana)
create table if not exists public.private_items (
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind       text not null check (kind in ('note','safety')),
  id         text not null,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, id)
);

-- ---------- updated_at automático ----------

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists items_touch on public.items;
create trigger items_touch before update on public.items
  for each row execute function public.touch_updated_at();

drop trigger if exists private_items_touch on public.private_items;
create trigger private_items_touch before update on public.private_items
  for each row execute function public.touch_updated_at();

-- ---------- Funções auxiliares (security definer evita recursão no RLS) ----------

create or replace function public.my_couple() returns uuid
language sql stable security definer set search_path = public as $$
  select couple_id from members where user_id = auth.uid()
$$;

create or replace function public.my_slot() returns text
language sql stable security definer set search_path = public as $$
  select slot from members where user_id = auth.uid()
$$;

-- Eu já enviei meu check-in desta semana? (regra: as notas do outro só
-- aparecem depois que eu respondi também)
create or replace function public.has_my_entry(c uuid, wk text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from items
    where couple_id = c and kind = 'entry'
      and author = auth.uid() and split_part(id, ':', 1) = wk
  )
$$;

-- Quem já respondeu cada semana (sem revelar as respostas).
create or replace function public.week_status()
returns table(week text, slot text, at timestamptz)
language sql stable security definer set search_path = public as $$
  select split_part(id, ':', 1), split_part(id, ':', 2), updated_at
  from items
  where couple_id = my_couple() and kind = 'entry'
$$;

-- Cria o casal e coloca quem chamou na posição p0.
create or replace function public.create_couple(my_name text, partner_name text)
returns public.couples
language plpgsql security definer set search_path = public as $$
declare c public.couples;
begin
  if auth.uid() is null then raise exception 'Faça login primeiro'; end if;
  if exists(select 1 from members where user_id = auth.uid()) then
    raise exception 'Você já faz parte de um casal';
  end if;
  insert into couples(p0_name, p1_name)
    values (trim(my_name), trim(partner_name)) returning * into c;
  insert into members(couple_id, user_id, slot) values (c.id, auth.uid(), 'p0');
  return c;
end $$;

-- Entra no casal pelo código de convite, na posição p1.
create or replace function public.join_couple(code text)
returns public.couples
language plpgsql security definer set search_path = public as $$
declare c public.couples;
begin
  if auth.uid() is null then raise exception 'Faça login primeiro'; end if;
  if exists(select 1 from members where user_id = auth.uid()) then
    raise exception 'Você já faz parte de um casal';
  end if;
  select * into c from couples where invite_code = upper(trim(code));
  if not found then raise exception 'Código não encontrado'; end if;
  if exists(select 1 from members where couple_id = c.id and slot = 'p1') then
    raise exception 'Este casal já está completo';
  end if;
  insert into members(couple_id, user_id, slot) values (c.id, auth.uid(), 'p1');
  return c;
end $$;

revoke execute on function public.create_couple(text, text) from anon;
revoke execute on function public.join_couple(text) from anon;
revoke execute on function public.week_status() from anon;

-- ---------- Row Level Security ----------

alter table public.couples       enable row level security;
alter table public.members       enable row level security;
alter table public.items         enable row level security;
alter table public.private_items enable row level security;

drop policy if exists couples_select on public.couples;
create policy couples_select on public.couples for select
  using (id = public.my_couple());
drop policy if exists couples_update on public.couples;
create policy couples_update on public.couples for update
  using (id = public.my_couple()) with check (id = public.my_couple());

drop policy if exists members_select on public.members;
create policy members_select on public.members for select
  using (couple_id = public.my_couple());

-- Check-ins: o meu sempre; o do outro só depois que eu respondi a mesma semana.
drop policy if exists items_select on public.items;
create policy items_select on public.items for select
  using (
    couple_id = public.my_couple()
    and (kind <> 'entry'
         or author = auth.uid()
         or public.has_my_entry(couple_id, split_part(id, ':', 1)))
  );

-- Só dá para criar/editar/apagar o próprio check-in; o resto é do casal.
drop policy if exists items_insert on public.items;
create policy items_insert on public.items for insert
  with check (
    couple_id = public.my_couple()
    and author = auth.uid()
    and (kind <> 'entry' or split_part(id, ':', 2) = public.my_slot())
  );
drop policy if exists items_update on public.items;
create policy items_update on public.items for update
  using (couple_id = public.my_couple() and (kind <> 'entry' or author = auth.uid()))
  with check (
    couple_id = public.my_couple()
    and (kind <> 'entry' or (author = auth.uid() and split_part(id, ':', 2) = public.my_slot()))
  );
drop policy if exists items_delete on public.items;
create policy items_delete on public.items for delete
  using (couple_id = public.my_couple() and (kind <> 'entry' or author = auth.uid()));

drop policy if exists private_items_all on public.private_items;
create policy private_items_all on public.private_items for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
