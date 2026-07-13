-- 亞丁血盟：放置傳說／連線玩家競技場
-- 請在既有 idle-lineage-market 專案的 Supabase SQL Editor 執行整份檔案。
create extension if not exists pgcrypto;

create table if not exists public.pvp_profiles(
 user_id uuid primary key references auth.users(id) on delete cascade,
 rating integer not null default 1000 check(rating between 0 and 999999),
 wins integer not null default 0,
 losses integer not null default 0,
 draws integer not null default 0,
 updated_at timestamptz not null default now()
);

create table if not exists public.pvp_queue(
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null,
 player_tag text,
 snapshot jsonb not null,
 joined_at timestamptz not null default now()
);

create table if not exists public.pvp_matches(
 id uuid primary key default gen_random_uuid(),
 player1_id uuid not null references auth.users(id) on delete cascade,
 player2_id uuid not null references auth.users(id) on delete cascade,
 player1_name text not null,
 player2_name text not null,
 player1_tag text,
 player2_tag text,
 player1_stats jsonb not null,
 player2_stats jsonb not null,
 hp1 integer not null,
 hp2 integer not null,
 round integer not null default 0,
 status text not null default 'active' check(status in('active','finished')),
 winner_id uuid references auth.users(id) on delete set null,
 result_text text,
 battle_log jsonb not null default '[]'::jsonb,
 last_tick timestamptz not null default now()-interval '2 seconds',
 settled boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists pvp_matches_p1_idx on public.pvp_matches(player1_id,created_at desc);
create index if not exists pvp_matches_p2_idx on public.pvp_matches(player2_id,created_at desc);
create index if not exists pvp_queue_joined_idx on public.pvp_queue(joined_at);
alter table public.pvp_profiles enable row level security;
alter table public.pvp_queue enable row level security;
alter table public.pvp_matches enable row level security;

-- 對玩家傳來的戰鬥快照做伺服器端限幅，避免異常值破壞戰局。
create or replace function public.pvp_safe_snapshot(p jsonb) returns jsonb
language sql immutable set search_path=public as $$
 select jsonb_build_object(
  'lv',greatest(1,least(100,coalesce((p->>'lv')::integer,1))),
  'class',left(coalesce(nullif(p->>'class',''),'冒險者'),20),
  'max_hp',greatest(100,least(1000000,coalesce((p->>'max_hp')::integer,100))),
  'atk',greatest(10,least(100000,coalesce((p->>'atk')::integer,10))),
  'def',greatest(0,least(100000,coalesce((p->>'def')::integer,0))),
  'crit',greatest(0,least(50,coalesce((p->>'crit')::numeric,0))),
  'speed',greatest(0.6,least(2.5,coalesce((p->>'speed')::numeric,1)))
 );
$$;

create or replace function public.pvp_state(p_match uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare m public.pvp_matches; mine public.pvp_profiles;
begin
 select * into m from pvp_matches where id=p_match and auth.uid() in(player1_id,player2_id);
 if m.id is null then raise exception '找不到這場競技';end if;
 insert into pvp_profiles(user_id) values(auth.uid()) on conflict do nothing;
 select * into mine from pvp_profiles where user_id=auth.uid();
 return jsonb_build_object(
  'kind','match','id',m.id,'my_side',case when auth.uid()=m.player1_id then 1 else 2 end,
  'status',m.status,'round',m.round,'winner_id',m.winner_id,'result_text',m.result_text,
  'player1',jsonb_build_object('id',m.player1_id,'name',m.player1_name,'tag',m.player1_tag,'stats',m.player1_stats,'hp',m.hp1),
  'player2',jsonb_build_object('id',m.player2_id,'name',m.player2_name,'tag',m.player2_tag,'stats',m.player2_stats,'hp',m.hp2),
  'log',m.battle_log,'record',jsonb_build_object('rating',mine.rating,'wins',mine.wins,'losses',mine.losses,'draws',mine.draws)
 );
end $$;

create or replace function public.pvp_join_queue(p_snapshot jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare me public.market_profiles; mine public.pvp_profiles; foe public.pvp_queue; mid uuid; s jsonb; active_id uuid;
begin
 if auth.uid() is null then raise exception '尚未登入';end if;
 select * into me from market_profiles where user_id=auth.uid();
 if me.user_id is null then raise exception '找不到玩家資料，請先設定玩家 ID';end if;
 insert into pvp_profiles(user_id) values(auth.uid()) on conflict do nothing;
 select * into mine from pvp_profiles where user_id=auth.uid();
 select id into active_id from pvp_matches where auth.uid() in(player1_id,player2_id) and status='active' order by created_at desc limit 1;
 if active_id is not null then return pvp_state(active_id);end if;
 delete from pvp_queue where joined_at<now()-interval '2 minutes';
 delete from pvp_queue where user_id=auth.uid();
 select * into foe from pvp_queue where user_id<>auth.uid() order by abs(extract(epoch from(now()-joined_at))) for update skip locked limit 1;
 s:=pvp_safe_snapshot(p_snapshot);
 if foe.user_id is null then
  insert into pvp_queue(user_id,display_name,player_tag,snapshot) values(auth.uid(),me.display_name,me.player_tag,s);
  return jsonb_build_object('kind','queued','rating',mine.rating,'message','等待其他玩家進入競技場…');
 end if;
 insert into pvp_matches(player1_id,player2_id,player1_name,player2_name,player1_tag,player2_tag,player1_stats,player2_stats,hp1,hp2)
 values(foe.user_id,auth.uid(),foe.display_name,me.display_name,foe.player_tag,me.player_tag,pvp_safe_snapshot(foe.snapshot),s,
        (pvp_safe_snapshot(foe.snapshot)->>'max_hp')::integer,(s->>'max_hp')::integer) returning id into mid;
 delete from pvp_queue where user_id in(foe.user_id,auth.uid());
 return pvp_state(mid);
end $$;

create or replace function public.pvp_poll() returns jsonb
language plpgsql security definer set search_path=public as $$
declare mid uuid; mine public.pvp_profiles;
begin
 insert into pvp_profiles(user_id) values(auth.uid()) on conflict do nothing;
 select id into mid from pvp_matches where auth.uid() in(player1_id,player2_id) and status='active' order by created_at desc limit 1;
 if mid is not null then return pvp_state(mid);end if;
 select * into mine from pvp_profiles where user_id=auth.uid();
 if exists(select 1 from pvp_queue where user_id=auth.uid()) then
  return jsonb_build_object('kind','queued','rating',mine.rating,'message','等待其他玩家進入競技場…');
 end if;
 return jsonb_build_object('kind','idle','rating',mine.rating,'wins',mine.wins,'losses',mine.losses,'draws',mine.draws);
end $$;

create or replace function public.pvp_tick(p_match uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare m public.pvp_matches;a1 numeric;a2 numeric;df1 numeric;df2 numeric;sp1 numeric;sp2 numeric;cr1 numeric;cr2 numeric;
 d1 integer;d2 integer;c1 boolean;c2 boolean;nh1 integer;nh2 integer;win uuid;txt text;entry jsonb;
begin
 select * into m from pvp_matches where id=p_match and auth.uid() in(player1_id,player2_id) for update;
 if m.id is null then raise exception '找不到這場競技';end if;
 if m.status<>'active' or now()-m.last_tick<interval '800 milliseconds' then return pvp_state(m.id);end if;
 a1:=(m.player1_stats->>'atk')::numeric; a2:=(m.player2_stats->>'atk')::numeric;
 df1:=(m.player1_stats->>'def')::numeric; df2:=(m.player2_stats->>'def')::numeric;
 sp1:=(m.player1_stats->>'speed')::numeric; sp2:=(m.player2_stats->>'speed')::numeric;
 cr1:=(m.player1_stats->>'crit')::numeric; cr2:=(m.player2_stats->>'crit')::numeric;
 c1:=random()*100<cr1;c2:=random()*100<cr2;
 d1:=greatest(1,floor(a1*(0.85+random()*0.30)*(0.75+sp1*0.25)-df2*0.28)::integer);if c1 then d1:=d1*2;end if;
 d2:=greatest(1,floor(a2*(0.85+random()*0.30)*(0.75+sp2*0.25)-df1*0.28)::integer);if c2 then d2:=d2*2;end if;
 nh1:=greatest(0,m.hp1-d2);nh2:=greatest(0,m.hp2-d1);
 if nh1=0 or nh2=0 then
  if nh1=0 and nh2=0 then win:=null;txt:='雙方同時倒下，戰成平手';
  elsif nh2=0 then win:=m.player1_id;txt:=m.player1_name||' 獲得勝利';
  else win:=m.player2_id;txt:=m.player2_name||' 獲得勝利';end if;
 end if;
 entry:=jsonb_build_object('round',m.round+1,'d1',d1,'d2',d2,'c1',c1,'c2',c2,'hp1',nh1,'hp2',nh2);
 update pvp_matches set hp1=nh1,hp2=nh2,round=round+1,battle_log=battle_log||jsonb_build_array(entry),last_tick=now(),updated_at=now(),
  status=case when nh1=0 or nh2=0 then 'finished' else 'active' end,winner_id=win,result_text=txt where id=m.id;
 if (nh1=0 or nh2=0) and not m.settled then
  if win is null then
   update pvp_profiles set draws=draws+1,rating=rating+2,updated_at=now() where user_id in(m.player1_id,m.player2_id);
  else
   update pvp_profiles set wins=wins+1,rating=rating+15,updated_at=now() where user_id=win;
   update pvp_profiles set losses=losses+1,rating=greatest(0,rating-10),updated_at=now() where user_id in(m.player1_id,m.player2_id) and user_id<>win;
  end if;
  update pvp_matches set settled=true where id=m.id;
 end if;
 return pvp_state(m.id);
end $$;

create or replace function public.pvp_cancel_queue() returns void
language sql security definer set search_path=public as $$delete from pvp_queue where user_id=auth.uid()$$;

create or replace function public.pvp_forfeit(p_match uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare m public.pvp_matches;win uuid;txt text;
begin
 select * into m from pvp_matches where id=p_match and auth.uid() in(player1_id,player2_id) for update;
 if m.id is null then raise exception '找不到這場競技';end if;if m.status<>'active' then return pvp_state(m.id);end if;
 win:=case when auth.uid()=m.player1_id then m.player2_id else m.player1_id end;
 txt:=case when win=m.player1_id then m.player1_name else m.player2_name end||' 因對手投降而獲勝';
 update pvp_matches set status='finished',winner_id=win,result_text=txt,settled=true,updated_at=now() where id=m.id;
 update pvp_profiles set wins=wins+1,rating=rating+15,updated_at=now() where user_id=win;
 update pvp_profiles set losses=losses+1,rating=greatest(0,rating-10),updated_at=now() where user_id=auth.uid();
 return pvp_state(m.id);
end $$;

revoke all on function public.pvp_safe_snapshot(jsonb),public.pvp_state(uuid),public.pvp_join_queue(jsonb),public.pvp_poll(),public.pvp_tick(uuid),public.pvp_cancel_queue(),public.pvp_forfeit(uuid) from public;
grant execute on function public.pvp_state(uuid),public.pvp_join_queue(jsonb),public.pvp_poll(),public.pvp_tick(uuid),public.pvp_cancel_queue(),public.pvp_forfeit(uuid) to authenticated;
notify pgrst,'reload schema';
