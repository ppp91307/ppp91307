-- 亞丁血盟：放置傳說／線上血盟系統
-- 請在 Supabase SQL Editor 一次執行整份檔案。
create extension if not exists pgcrypto;

create table if not exists public.clans (
 id uuid primary key default gen_random_uuid(),
 name text not null unique check(char_length(name) between 2 and 12),
 invite_code text not null unique,
 owner_id uuid not null references auth.users(id) on delete cascade,
 level integer not null default 1 check(level between 1 and 10),
 xp bigint not null default 0 check(xp>=0),
 funds bigint not null default 0 check(funds>=0),
 created_at timestamptz not null default now()
);
create table if not exists public.clan_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 clan_id uuid not null references public.clans(id) on delete cascade,
 role text not null default 'member' check(role in ('owner','officer','member')),
 contribution bigint not null default 0 check(contribution>=0),
 joined_at timestamptz not null default now()
);
create table if not exists public.clan_applications (
 id uuid primary key default gen_random_uuid(), clan_id uuid not null references public.clans(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','accepted','rejected')),
 created_at timestamptz not null default now(), unique(clan_id,user_id)
);
create table if not exists public.clan_invites (
 id uuid primary key default gen_random_uuid(), clan_id uuid not null references public.clans(id) on delete cascade,
 target_user_id uuid not null references auth.users(id) on delete cascade,
 inviter_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','accepted','rejected')),
 created_at timestamptz not null default now(), unique(clan_id,target_user_id)
);
create table if not exists public.clan_donations (
 user_id uuid not null references auth.users(id) on delete cascade,
 donated_on date not null default current_date, amount bigint not null check(amount>0),
 primary key(user_id,donated_on)
);
create index if not exists clan_members_clan_idx on public.clan_members(clan_id);
create index if not exists clan_applications_clan_idx on public.clan_applications(clan_id,status);
create index if not exists clan_invites_target_idx on public.clan_invites(target_user_id,status);
alter table public.clans enable row level security;
alter table public.clan_members enable row level security;
alter table public.clan_applications enable row level security;
alter table public.clan_invites enable row level security;
alter table public.clan_donations enable row level security;

create or replace function public.clan_raise_level(p_clan uuid) returns void language plpgsql security definer set search_path=public as $$
declare l integer; x bigint;
begin
 loop select level,xp into l,x from clans where id=p_clan for update; exit when l>=10 or x<l*100;
  update clans set level=level+1,xp=xp-l*100 where id=p_clan;
 end loop;
end $$;

create or replace function public.clan_create(p_name text) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid; code text;
begin
 if auth.uid() is null then raise exception '尚未登入'; end if;
 if exists(select 1 from clan_members where user_id=auth.uid()) then raise exception '你已經有血盟'; end if;
 if char_length(trim(p_name)) not between 2 and 12 then raise exception '名稱長度需為 2～12 字'; end if;
 loop code:=upper(substr(encode(gen_random_bytes(6),'hex'),1,8));exit when not exists(select 1 from clans where invite_code=code);end loop;
 insert into clans(name,invite_code,owner_id) values(trim(p_name),code,auth.uid()) returning id into cid;
 insert into clan_members(user_id,clan_id,role) values(auth.uid(),cid,'owner');return cid;
exception when unique_violation then raise exception '血盟名稱已被使用';
end $$;

create or replace function public.clan_join_code(p_code text) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid; lim integer; cnt integer;
begin
 if exists(select 1 from clan_members where user_id=auth.uid()) then raise exception '你已經有血盟'; end if;
 select id,5+level*3 into cid,lim from clans where invite_code=upper(trim(p_code)) for update;
 if cid is null then raise exception '邀請碼不存在'; end if;select count(*) into cnt from clan_members where clan_id=cid;
 if cnt>=lim then raise exception '血盟人數已滿'; end if;
 insert into clan_members(user_id,clan_id) values(auth.uid(),cid);delete from clan_invites where target_user_id=auth.uid();delete from clan_applications where user_id=auth.uid();return cid;
end $$;

create or replace function public.clan_apply(p_clan uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare aid uuid;
begin
 if exists(select 1 from clan_members where user_id=auth.uid()) then raise exception '你已經有血盟'; end if;
 insert into clan_applications(clan_id,user_id,status,created_at) values(p_clan,auth.uid(),'pending',now())
 on conflict(clan_id,user_id) do update set status='pending',created_at=now() returning id into aid;return aid;
end $$;

create or replace function public.clan_invite(p_target uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid; iid uuid;
begin
 select clan_id into cid from clan_members where user_id=auth.uid() and role in('owner','officer');if cid is null then raise exception '只有盟主或副盟主可以邀請';end if;
 if not exists(select 1 from market_profiles where user_id=p_target) then raise exception '找不到玩家';end if;
 if exists(select 1 from clan_members where user_id=p_target) then raise exception '對方已經有血盟';end if;
 insert into clan_invites(clan_id,target_user_id,inviter_id,status,created_at) values(cid,p_target,auth.uid(),'pending',now())
 on conflict(clan_id,target_user_id) do update set inviter_id=auth.uid(),status='pending',created_at=now() returning id into iid;return iid;
end $$;

create or replace function public.clan_review_application(p_application uuid,p_accept boolean) returns void language plpgsql security definer set search_path=public as $$
declare a clan_applications; lim integer; cnt integer;
begin
 select * into a from clan_applications where id=p_application and status='pending' for update;if a.id is null then raise exception '申請不存在';end if;
 if not exists(select 1 from clan_members where user_id=auth.uid() and clan_id=a.clan_id and role in('owner','officer')) then raise exception '沒有審核權限';end if;
 if p_accept then
  if exists(select 1 from clan_members where user_id=a.user_id) then raise exception '玩家已加入其他血盟';end if;
  select 5+level*3 into lim from clans where id=a.clan_id;select count(*) into cnt from clan_members where clan_id=a.clan_id;if cnt>=lim then raise exception '血盟人數已滿';end if;
  insert into clan_members(user_id,clan_id) values(a.user_id,a.clan_id);update clan_applications set status='accepted' where id=a.id;delete from clan_invites where target_user_id=a.user_id;
 else update clan_applications set status='rejected' where id=a.id;end if;
end $$;

create or replace function public.clan_respond_invite(p_invite uuid,p_accept boolean) returns void language plpgsql security definer set search_path=public as $$
declare i clan_invites; lim integer; cnt integer;
begin
 select * into i from clan_invites where id=p_invite and target_user_id=auth.uid() and status='pending' for update;if i.id is null then raise exception '邀請不存在';end if;
 if p_accept then
  if exists(select 1 from clan_members where user_id=auth.uid()) then raise exception '你已經有血盟';end if;
  select 5+level*3 into lim from clans where id=i.clan_id;select count(*) into cnt from clan_members where clan_id=i.clan_id;if cnt>=lim then raise exception '血盟人數已滿';end if;
  insert into clan_members(user_id,clan_id) values(auth.uid(),i.clan_id);update clan_invites set status='accepted' where id=i.id;delete from clan_applications where user_id=auth.uid();
 else update clan_invites set status='rejected' where id=i.id;end if;
end $$;

create or replace function public.clan_donate(p_amount bigint) returns void language plpgsql security definer set search_path=public as $$
declare cid uuid; gain integer;
begin
 if p_amount not in(10000,100000) then raise exception '捐獻金額不正確';end if;select clan_id into cid from clan_members where user_id=auth.uid();if cid is null then raise exception '尚未加入血盟';end if;
 insert into clan_donations(user_id,amount) values(auth.uid(),p_amount);gain:=case when p_amount=100000 then 30 else 10 end;
 update clans set funds=funds+p_amount,xp=xp+gain where id=cid;update clan_members set contribution=contribution+p_amount/1000 where user_id=auth.uid();perform clan_raise_level(cid);
exception when unique_violation then raise exception '今天已經捐獻過了';
end $$;

create or replace function public.clan_search(p_query text) returns table(id uuid,name text,level integer,member_count bigint,member_limit integer) language sql security definer set search_path=public as $$
 select c.id,c.name,c.level,count(m.user_id),5+c.level*3 from clans c left join clan_members m on m.clan_id=c.id where c.name ilike '%'||trim(coalesce(p_query,''))||'%' group by c.id order by c.level desc,c.name limit 30;
$$;
create or replace function public.clan_search_players(p_query text) returns table(user_id uuid,display_name text) language sql security definer set search_path=public as $$
 select p.user_id,p.display_name from market_profiles p left join clan_members m on m.user_id=p.user_id where m.user_id is null and p.user_id<>auth.uid() and p.display_name ilike '%'||trim(coalesce(p_query,''))||'%' order by p.display_name limit 30;
$$;

create or replace function public.clan_my_state() returns jsonb language plpgsql security definer set search_path=public as $$
declare cid uuid; mine clan_members; c clans; result jsonb;
begin
 select * into mine from clan_members where user_id=auth.uid();cid:=mine.clan_id;if cid is not null then select * into c from clans where id=cid;end if;
 result:=jsonb_build_object(
  'clan',case when cid is null then null else jsonb_build_object('id',c.id,'name',c.name,'invite_code',c.invite_code,'level',c.level,'xp',c.xp,'funds',c.funds,'member_limit',5+c.level*3) end,
  'me',case when cid is null then null else jsonb_build_object('role',mine.role,'contribution',mine.contribution) end,
  'members',case when cid is null then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,'display_name',coalesce(p.display_name,'冒險者'),'role',m.role,'contribution',m.contribution,'joined_at',m.joined_at) order by case m.role when 'owner' then 1 when 'officer' then 2 else 3 end,m.joined_at) from clan_members m left join market_profiles p on p.user_id=m.user_id where m.clan_id=cid),'[]'::jsonb) end,
  'applications',case when mine.role in('owner','officer') then coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'user_id',a.user_id,'display_name',coalesce(p.display_name,'冒險者'),'created_at',a.created_at)) from clan_applications a left join market_profiles p on p.user_id=a.user_id where a.clan_id=cid and a.status='pending'),'[]'::jsonb) else '[]'::jsonb end,
  'invites',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'clan_name',cl.name,'inviter_name',coalesce(p.display_name,'冒險者'),'created_at',i.created_at)) from clan_invites i join clans cl on cl.id=i.clan_id left join market_profiles p on p.user_id=i.inviter_id where i.target_user_id=auth.uid() and i.status='pending'),'[]'::jsonb)
 );return result;
end $$;

revoke all on function public.clan_raise_level(uuid) from public;
revoke all on function public.clan_create(text),public.clan_join_code(text),public.clan_apply(uuid),public.clan_invite(uuid),public.clan_review_application(uuid,boolean),public.clan_respond_invite(uuid,boolean),public.clan_donate(bigint),public.clan_search(text),public.clan_search_players(text),public.clan_my_state() from public;
grant execute on function public.clan_create(text),public.clan_join_code(text),public.clan_apply(uuid),public.clan_invite(uuid),public.clan_review_application(uuid,boolean),public.clan_respond_invite(uuid,boolean),public.clan_donate(bigint),public.clan_search(text),public.clan_search_players(text),public.clan_my_state() to authenticated;
