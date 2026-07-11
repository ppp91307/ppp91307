-- 老楷研究-放置天堂：玩家交易所
-- 在 Supabase SQL Editor 一次執行整份檔案。
create extension if not exists pgcrypto;

create table if not exists public.market_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '冒險者',
  wallet bigint not null default 0 check (wallet >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.market_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  seller_name text not null,
  item_id text not null,
  item_name text not null,
  item_data jsonb not null,
  qty integer not null check (qty > 0),
  unit_price bigint not null check (unit_price between 1 and 999999999999),
  status text not null default 'active' check (status in ('active','sold','cancelled')),
  buyer_id uuid references auth.users(id),
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.market_deliveries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  source text not null check (source in ('purchase','cancel')),
  item_data jsonb not null,
  qty integer not null check (qty > 0),
  claimed boolean not null default false,
  created_at timestamptz not null default now(),
  claimed_at timestamptz
);

create index if not exists market_listings_active_idx on public.market_listings(status, created_at desc);
create index if not exists market_deliveries_owner_idx on public.market_deliveries(owner_id, claimed, created_at);

alter table public.market_profiles enable row level security;
alter table public.market_listings enable row level security;
alter table public.market_deliveries enable row level security;

drop policy if exists market_profile_own on public.market_profiles;
create policy market_profile_own on public.market_profiles for select using (auth.uid() = user_id);
drop policy if exists market_listing_read on public.market_listings;
create policy market_listing_read on public.market_listings for select using (status = 'active' or auth.uid() = seller_id or auth.uid() = buyer_id);
drop policy if exists market_delivery_own on public.market_deliveries;
create policy market_delivery_own on public.market_deliveries for select using (auth.uid() = owner_id);

create or replace function public.market_ensure_profile(p_name text)
returns public.market_profiles language plpgsql security definer set search_path=public as $$
declare r public.market_profiles;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into market_profiles(user_id,display_name) values(auth.uid(),left(coalesce(nullif(trim(p_name),''),'冒險者'),30))
  on conflict(user_id) do update set display_name=excluded.display_name,updated_at=now();
  select * into r from market_profiles where user_id=auth.uid(); return r;
end $$;

create or replace function public.market_deposit(p_amount bigint)
returns bigint language plpgsql security definer set search_path=public as $$
declare w bigint;
begin
  if p_amount <= 0 then raise exception 'invalid amount'; end if;
  insert into market_profiles(user_id) values(auth.uid()) on conflict do nothing;
  update market_profiles set wallet=wallet+p_amount,updated_at=now() where user_id=auth.uid() returning wallet into w;
  return w;
end $$;

create or replace function public.market_withdraw(p_amount bigint)
returns bigint language plpgsql security definer set search_path=public as $$
declare w bigint;
begin
  if p_amount <= 0 then raise exception 'invalid amount'; end if;
  update market_profiles set wallet=wallet-p_amount,updated_at=now() where user_id=auth.uid() and wallet>=p_amount returning wallet into w;
  if w is null then raise exception 'insufficient wallet'; end if; return w;
end $$;

create or replace function public.market_create_listing(p_item_id text,p_item_name text,p_item_data jsonb,p_qty integer,p_unit_price bigint)
returns uuid language plpgsql security definer set search_path=public as $$
declare lid uuid; n text;
begin
  if auth.uid() is null or p_qty<1 or p_unit_price<1 then raise exception 'invalid listing'; end if;
  select display_name into n from market_profiles where user_id=auth.uid();
  if n is null then raise exception 'profile missing'; end if;
  insert into market_listings(seller_id,seller_name,item_id,item_name,item_data,qty,unit_price)
  values(auth.uid(),n,left(p_item_id,100),left(p_item_name,100),p_item_data,p_qty,p_unit_price) returning id into lid;
  return lid;
end $$;

create or replace function public.market_buy(p_listing uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare l market_listings; total bigint; did uuid;
begin
  select * into l from market_listings where id=p_listing for update;
  if l.id is null or l.status<>'active' then raise exception 'listing unavailable'; end if;
  if l.seller_id=auth.uid() then raise exception 'cannot buy your listing'; end if;
  total:=l.qty::bigint*l.unit_price;
  update market_profiles set wallet=wallet-total,updated_at=now() where user_id=auth.uid() and wallet>=total;
  if not found then raise exception 'insufficient wallet'; end if;
  update market_profiles set wallet=wallet+floor(total*.95)::bigint,updated_at=now() where user_id=l.seller_id;
  update market_listings set status='sold',buyer_id=auth.uid(),finished_at=now() where id=l.id;
  insert into market_deliveries(owner_id,source,item_data,qty) values(auth.uid(),'purchase',l.item_data,l.qty) returning id into did;
  return did;
end $$;

create or replace function public.market_cancel(p_listing uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare l market_listings; did uuid;
begin
  select * into l from market_listings where id=p_listing and seller_id=auth.uid() for update;
  if l.id is null or l.status<>'active' then raise exception 'listing unavailable'; end if;
  update market_listings set status='cancelled',finished_at=now() where id=l.id;
  insert into market_deliveries(owner_id,source,item_data,qty) values(auth.uid(),'cancel',l.item_data,l.qty) returning id into did;
  return did;
end $$;

create or replace function public.market_claim(p_delivery uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare d market_deliveries;
begin
  update market_deliveries set claimed=true,claimed_at=now()
  where id=p_delivery and owner_id=auth.uid() and claimed=false returning * into d;
  if d.id is null then raise exception 'delivery unavailable'; end if;
  return jsonb_build_object('item',d.item_data,'qty',d.qty);
end $$;

revoke all on function public.market_ensure_profile(text) from public;
revoke all on function public.market_deposit(bigint) from public;
revoke all on function public.market_withdraw(bigint) from public;
revoke all on function public.market_create_listing(text,text,jsonb,integer,bigint) from public;
revoke all on function public.market_buy(uuid) from public;
revoke all on function public.market_cancel(uuid) from public;
revoke all on function public.market_claim(uuid) from public;
grant execute on function public.market_ensure_profile(text) to authenticated;
grant execute on function public.market_deposit(bigint) to authenticated;
grant execute on function public.market_withdraw(bigint) to authenticated;
grant execute on function public.market_create_listing(text,text,jsonb,integer,bigint) to authenticated;
grant execute on function public.market_buy(uuid) to authenticated;
grant execute on function public.market_cancel(uuid) to authenticated;
grant execute on function public.market_claim(uuid) to authenticated;
grant select on public.market_profiles,public.market_listings,public.market_deliveries to authenticated;
