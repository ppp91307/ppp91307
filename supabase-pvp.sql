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
alter table public.pvp_matches add column if not exists starts_at timestamptz;
update public.pvp_matches set starts_at=coalesce(starts_at,created_at+interval '5 seconds') where starts_at is null;
alter table public.pvp_matches alter column starts_at set default (now()+interval '5 seconds');
create index if not exists pvp_matches_p1_idx on public.pvp_matches(player1_id,created_at desc);
create index if not exists pvp_matches_p2_idx on public.pvp_matches(player2_id,created_at desc);
create index if not exists pvp_queue_joined_idx on public.pvp_queue(joined_at);
alter table public.pvp_profiles enable row level security;
alter table public.pvp_queue enable row level security;
alter table public.pvp_matches enable row level security;

-- 對玩家傳來的戰鬥快照做伺服器端限幅，避免異常值破壞戰局。
create or replace function public.pvp_safe_snapshot(p jsonb) returns jsonb
language plpgsql immutable set search_path=public as $$
declare x jsonb; safe_buffs jsonb='[]'::jsonb;safe_statuses jsonb='[]'::jsonb;n integer:=0;t integer;d integer;
begin
 if jsonb_typeof(p->'buffs')='array' then
  for x in select value from jsonb_array_elements(p->'buffs') limit 24 loop
   n:=n+1;t:=case when coalesce(x->>'t','')~'^[0-9]+$' then least(86400,(x->>'t')::integer) else 0 end;
   if t>0 then safe_buffs:=safe_buffs||jsonb_build_array(jsonb_build_object('id',left(coalesce(x->>'id','buff'),40),'n',left(coalesce(x->>'n','增益'),30),'t',t));end if;
  end loop;
 end if;
 if jsonb_typeof(p->'statuses')='array' then
  for x in select value from jsonb_array_elements(p->'statuses') limit 16 loop
   t:=case when coalesce(x->>'t','')~'^[0-9]+$' then least(3600,(x->>'t')::integer) else 0 end;
   d:=case when coalesce(x->>'dmg','')~'^[0-9]+$' then least(100000,(x->>'dmg')::integer) else 0 end;
   if t>0 then safe_statuses:=safe_statuses||jsonb_build_array(jsonb_build_object('id',left(coalesce(x->>'id','status'),30),'n',left(coalesce(x->>'n','異常狀態'),30),'t',t,'dmg',d));end if;
  end loop;
 end if;
 return jsonb_build_object(
  'lv',greatest(1,least(100,round(coalesce((p->>'lv')::numeric,1))::integer)),
  'class',left(coalesce(nullif(p->>'class',''),'冒險者'),20),
  'avatar',left(coalesce(p->>'avatar',''),20),'morph',left(coalesce(p->>'morph',''),30),'weapon',left(coalesce(p->>'weapon','sword1'),20),
  'buffs',safe_buffs,'statuses',safe_statuses,
  'max_hp',greatest(100,least(1000000,round(coalesce((p->>'max_hp')::numeric,100))::integer)),
  'atk',greatest(10,least(100000,round(coalesce((p->>'atk')::numeric,10))::integer)),
  'def',greatest(0,least(100000,round(coalesce((p->>'def')::numeric,0))::integer)),
  'crit',greatest(0,least(50,coalesce((p->>'crit')::numeric,0))),
  'speed',greatest(0.6,least(2.5,coalesce((p->>'speed')::numeric,1)))
 );
end $$;

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
  'status',m.status,'round',m.round,'winner_id',m.winner_id,'result_text',m.result_text,'starts_at',m.starts_at,
  'countdown',greatest(0,ceil(extract(epoch from(coalesce(m.starts_at,m.created_at)-now())))::integer),
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
 insert into pvp_matches(player1_id,player2_id,player1_name,player2_name,player1_tag,player2_tag,player1_stats,player2_stats,hp1,hp2,starts_at)
 values(foe.user_id,auth.uid(),foe.display_name,me.display_name,foe.player_tag,me.player_tag,pvp_safe_snapshot(foe.snapshot),s,
        (pvp_safe_snapshot(foe.snapshot)->>'max_hp')::integer,(s->>'max_hp')::integer,now()+interval '5 seconds') returning id into mid;
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
 d1 integer;d2 integer;c1 boolean;c2 boolean;nh1 integer;nh2 integer;dot1 integer:=0;dot2 integer:=0;hard1 boolean:=false;hard2 boolean:=false;win uuid;txt text;entry jsonb;note text:='';
begin
 select * into m from pvp_matches where id=p_match and auth.uid() in(player1_id,player2_id) for update;
 if m.id is null then raise exception '找不到這場競技';end if;
 if m.status<>'active' or now()<coalesce(m.starts_at,m.created_at) or now()-m.last_tick<interval '800 milliseconds' then return pvp_state(m.id);end if;
 a1:=(m.player1_stats->>'atk')::numeric; a2:=(m.player2_stats->>'atk')::numeric;
 df1:=(m.player1_stats->>'def')::numeric; df2:=(m.player2_stats->>'def')::numeric;
 sp1:=(m.player1_stats->>'speed')::numeric; sp2:=(m.player2_stats->>'speed')::numeric;
 cr1:=(m.player1_stats->>'crit')::numeric; cr2:=(m.player2_stats->>'crit')::numeric;
 select coalesce(bool_or((x->>'id') in('stun','freeze','stone','sleep','paralyze') and coalesce((x->>'t')::integer,0)>m.round),false),
        coalesce(sum(case when (x->>'id') in('poison','burn','bleed','scald') and coalesce((x->>'t')::integer,0)>m.round then coalesce((x->>'dmg')::integer,0) else 0 end),0)
 into hard1,dot1 from jsonb_array_elements(coalesce(m.player1_stats->'statuses','[]'::jsonb)) x;
 select coalesce(bool_or((x->>'id') in('stun','freeze','stone','sleep','paralyze') and coalesce((x->>'t')::integer,0)>m.round),false),
        coalesce(sum(case when (x->>'id') in('poison','burn','bleed','scald') and coalesce((x->>'t')::integer,0)>m.round then coalesce((x->>'dmg')::integer,0) else 0 end),0)
 into hard2,dot2 from jsonb_array_elements(coalesce(m.player2_stats->'statuses','[]'::jsonb)) x;
 c1:=not hard1 and random()*100<cr1;c2:=not hard2 and random()*100<cr2;
 d1:=case when hard1 then 0 else greatest(1,floor(a1*(0.85+random()*0.30)*(0.75+sp1*0.25)-df2*0.28)::integer) end;if c1 then d1:=d1*2;end if;
 d2:=case when hard2 then 0 else greatest(1,floor(a2*(0.85+random()*0.30)*(0.75+sp2*0.25)-df1*0.28)::integer) end;if c2 then d2:=d2*2;end if;
 nh1:=greatest(0,m.hp1-d2-dot1);nh2:=greatest(0,m.hp2-d1-dot2);
 if hard1 then note:=m.player1_name||' 無法行動';end if;if hard2 then note:=concat_ws('、',nullif(note,''),m.player2_name||' 無法行動');end if;
 if dot1+dot2>0 then note:=concat_ws('、',nullif(note,''),'持續傷害 '||(dot1+dot2));end if;
 if nh1=0 or nh2=0 then
  if nh1=0 and nh2=0 then win:=null;txt:='雙方同時倒下，戰成平手';
  elsif nh2=0 then win:=m.player1_id;txt:=m.player1_name||' 獲得勝利';
  else win:=m.player2_id;txt:=m.player2_name||' 獲得勝利';end if;
 end if;
 entry:=jsonb_build_object('round',m.round+1,'d1',d1,'d2',d2,'c1',c1,'c2',c2,'hp1',nh1,'hp2',nh2,'dot1',dot1,'dot2',dot2,'hard1',hard1,'hard2',hard2,'note',note);
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

-- ============================================================================
-- PVP v2：完整角色戰鬥狀態同步（2026-07-13）
-- 可直接重複執行；既有配對紀錄與積分不會被刪除。
-- ============================================================================
alter table public.pvp_matches add column if not exists mp1 integer not null default 0;
alter table public.pvp_matches add column if not exists mp2 integer not null default 0;
alter table public.pvp_matches add column if not exists state1 jsonb not null default '{}'::jsonb;
alter table public.pvp_matches add column if not exists state2 jsonb not null default '{}'::jsonb;
alter table public.pvp_matches add column if not exists next_action1 timestamptz;
alter table public.pvp_matches add column if not exists next_action2 timestamptz;
update public.pvp_matches set status='finished',result_text='競技場戰鬥核心已升級，請重新配對',settled=true,updated_at=now()
 where status='active' and (coalesce((player1_stats->>'version')::integer,1)<2 or coalesce((player2_stats->>'version')::integer,1)<2);
delete from public.pvp_queue where coalesce((snapshot->>'version')::integer,1)<2;

create or replace function public.pvp_has(p jsonb,p_id text) returns boolean
language sql immutable set search_path=public as $$
 select exists(select 1 from jsonb_array_elements_text(coalesce(p->'passives','[]'::jsonb)) as x(v) where v=p_id)
$$;

create or replace function public.pvp_safe_snapshot(p jsonb) returns jsonb
language plpgsql immutable set search_path=public as $$
declare x jsonb; b jsonb='[]'::jsonb; z jsonb='[]'::jsonb; ps jsonb='[]'::jsonb;
 t integer; d integer; sk jsonb:=null; hl jsonb:=null; st jsonb:=null; sid text;
begin
 if jsonb_typeof(p->'buffs')='array' then for x in select value from jsonb_array_elements(p->'buffs') limit 24 loop
  t:=greatest(0,least(86400,coalesce((x->>'t')::integer,0)));
  if t>0 then b:=b||jsonb_build_array(jsonb_build_object('id',left(coalesce(x->>'id','buff'),40),'n',left(coalesce(x->>'n','增益'),30),'t',t));end if;
 end loop;end if;
 if jsonb_typeof(p->'statuses')='array' then for x in select value from jsonb_array_elements(p->'statuses') limit 16 loop
  t:=greatest(0,least(3600,coalesce((x->>'t')::integer,0)));d:=greatest(0,least(100000,coalesce((x->>'dmg')::integer,0)));
  if t>0 then z:=z||jsonb_build_array(jsonb_build_object('id',left(coalesce(x->>'id','status'),30),'n',left(coalesce(x->>'n','異常狀態'),30),'t',t,'dmg',d));end if;
 end loop;end if;
 if jsonb_typeof(p->'passives')='array' then for x in select value from jsonb_array_elements(p->'passives') limit 24 loop
  sid:=trim(both '"' from x::text);
  if sid in('sk_resurrection','sk_warrior_berserk','sk_warrior_titan_rock','sk_warrior_titan_bullet','sk_warrior_titan_magic','sk_royal_kingguard','sk_dragon_deadlybody','sk_dark_double','sk_dark_burn','sk_counter_barrier','sk_holy_barrier','sk_elf_mirror','sk_elf_preciseshot','sk_elf_attrfire','sk_abs_barrier') then ps:=ps||to_jsonb(sid);end if;
 end loop;end if;
 if jsonb_typeof(p->'skill')='object' then
  x:=p->'skill';st:=case when jsonb_typeof(x->'status')='object' then jsonb_build_object('kind',left(coalesce(x->'status'->>'kind',''),20),'chance',greatest(0,least(80,coalesce((x->'status'->>'chance')::numeric,0))),'dur',greatest(1,least(30,coalesce((x->'status'->>'dur')::integer,2)))) else null end;
  sk:=jsonb_build_object('id',left(coalesce(x->>'id',''),50),'n',left(coalesce(x->>'n','職業技能'),30),'type',case when x->>'type' in('magic','ranged','physical') then x->>'type' else 'physical' end,'mp',greatest(0,least(9999,coalesce((x->>'mp')::integer,0))),'hp',greatest(0,least(9999,coalesce((x->>'hp')::integer,0))),'power',greatest(0,least(99999,coalesce((x->>'power')::integer,0))),'hits',greatest(1,least(8,coalesce((x->>'hits')::integer,1))),'lifesteal',coalesce((x->>'lifesteal')::boolean,false),'status',st);
 end if;
 if jsonb_typeof(p->'heal')='object' then x:=p->'heal';hl:=jsonb_build_object('id',left(coalesce(x->>'id',''),50),'n',left(coalesce(x->>'n','治癒術'),30),'mp',greatest(0,least(9999,coalesce((x->>'mp')::integer,0))),'heal',greatest(1,least(999999,coalesce((x->>'heal')::integer,1))),'hot',coalesce((x->>'hot')::boolean,false));end if;
 return jsonb_build_object(
  'version',2,'lv',greatest(1,least(100,round(coalesce((p->>'lv')::numeric,1))::integer)),'class',left(coalesce(nullif(p->>'class',''),'冒險者'),20),
  'avatar',left(coalesce(p->>'avatar',''),20),'morph',left(coalesce(p->>'morph',''),30),'weapon',left(coalesce(p->>'weapon','sword1'),20),
  'attack_type',case when p->>'attack_type' in('melee','ranged','magic') then p->>'attack_type' else 'melee' end,'buffs',b,'statuses',z,'passives',ps,'skill',sk,'heal',hl,
  'max_hp',greatest(100,least(1000000,round(coalesce((p->>'max_hp')::numeric,100))::integer)),'max_mp',greatest(0,least(1000000,round(coalesce((p->>'max_mp')::numeric,0))::integer)),
  'atk',greatest(1,least(100000,round(coalesce((p->>'atk')::numeric,10))::integer)),'weapon_roll',greatest(1,least(10000,round(coalesce((p->>'weapon_roll')::numeric,1))::integer)),'hit',greatest(-1000,least(10000,round(coalesce((p->>'hit')::numeric,0))::integer)),
  'crit',greatest(0,least(75,coalesce((p->>'crit')::numeric,0))),'crit_dmg',greatest(25,least(300,coalesce((p->>'crit_dmg')::numeric,50))),'interval',greatest(.10,least(5,coalesce((p->>'interval')::numeric,1))),
  'ac',greatest(-1000,least(1000,round(coalesce((p->>'ac')::numeric,-coalesce((p->>'def')::numeric,0)/2))::integer)),'mr',greatest(0,least(2000,round(coalesce((p->>'mr')::numeric,0))::integer)),'dr',greatest(0,least(10000,round(coalesce((p->>'dr')::numeric,0))::integer)),'er',greatest(0,least(95,round(coalesce((p->>'er')::numeric,0))::integer)),
  'hp_regen',greatest(-1000,least(10000,round(coalesce((p->>'hp_regen')::numeric,0))::integer)),'mp_regen',greatest(-1000,least(10000,round(coalesce((p->>'mp_regen')::numeric,0))::integer)),'mp_reduce',greatest(0,least(80,round(coalesce((p->>'mp_reduce')::numeric,0))::integer)),
  'res_fire',greatest(-100,least(100,round(coalesce((p->>'res_fire')::numeric,0))::integer)),'res_water',greatest(-100,least(100,round(coalesce((p->>'res_water')::numeric,0))::integer)),'res_wind',greatest(-100,least(100,round(coalesce((p->>'res_wind')::numeric,0))::integer)),'res_earth',greatest(-100,least(100,round(coalesce((p->>'res_earth')::numeric,0))::integer)),
  'imm_poison',coalesce((p->>'imm_poison')::boolean,false),'imm_stone',coalesce((p->>'imm_stone')::boolean,false)
 );
end $$;

create or replace function public.pvp_runtime_status(p_state jsonb) returns jsonb
language sql stable set search_path=public as $$
 select case when coalesce((p_state->>'status_until')::numeric,0)>extract(epoch from now()) then jsonb_build_array(jsonb_build_object('id',coalesce(p_state->>'status_id','status'),'n',coalesce(p_state->>'status_name','異常狀態'),'t',ceil((p_state->>'status_until')::numeric-extract(epoch from now()))::integer,'dmg',coalesce((p_state->>'status_dmg')::integer,0))) else '[]'::jsonb end
$$;

create or replace function public.pvp_initial_state(p_stats jsonb) returns jsonb
language plpgsql volatile set search_path=public as $$
declare x jsonb;
begin
 select value into x from jsonb_array_elements(coalesce(p_stats->'statuses','[]'::jsonb)) order by coalesce((value->>'t')::integer,0) desc limit 1;
 if x is null then return '{}'::jsonb;end if;
 return jsonb_build_object('status_id',coalesce(x->>'id','status'),'status_name',coalesce(x->>'n','異常狀態'),'status_until',extract(epoch from now())+coalesce((x->>'t')::integer,0),'status_dmg',coalesce((x->>'dmg')::integer,0));
end $$;

create or replace function public.pvp_state(p_match uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare m public.pvp_matches; mine public.pvp_profiles;s1 jsonb;s2 jsonb;
begin
 select * into m from pvp_matches where id=p_match and auth.uid() in(player1_id,player2_id);if m.id is null then raise exception '找不到競技場戰鬥';end if;
 insert into pvp_profiles(user_id) values(auth.uid()) on conflict do nothing;select * into mine from pvp_profiles where user_id=auth.uid();
 s1:=m.player1_stats||jsonb_build_object('statuses',pvp_runtime_status(m.state1));s2:=m.player2_stats||jsonb_build_object('statuses',pvp_runtime_status(m.state2));
 return jsonb_build_object('kind','match','id',m.id,'my_side',case when auth.uid()=m.player1_id then 1 else 2 end,'status',m.status,'round',m.round,'elapsed_seconds',greatest(0,floor(extract(epoch from(now()-coalesce(m.starts_at,m.created_at))))::integer),'winner_id',m.winner_id,'result_text',m.result_text,'starts_at',m.starts_at,'countdown',greatest(0,ceil(extract(epoch from(coalesce(m.starts_at,m.created_at)-now())))::integer),
 'player1',jsonb_build_object('id',m.player1_id,'name',m.player1_name,'tag',m.player1_tag,'stats',s1,'hp',m.hp1,'mp',m.mp1),'player2',jsonb_build_object('id',m.player2_id,'name',m.player2_name,'tag',m.player2_tag,'stats',s2,'hp',m.hp2,'mp',m.mp2),'log',m.battle_log,'record',jsonb_build_object('rating',mine.rating,'wins',mine.wins,'losses',mine.losses,'draws',mine.draws));
end $$;

create or replace function public.pvp_join_queue(p_snapshot jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare me public.market_profiles;mine public.pvp_profiles;foe public.pvp_queue;mid uuid;s jsonb;fs jsonb;active_id uuid;
begin
 if auth.uid() is null then raise exception '尚未登入';end if;select * into me from market_profiles where user_id=auth.uid();if me.user_id is null then raise exception '找不到玩家資料，請先設定玩家 ID';end if;
 insert into pvp_profiles(user_id) values(auth.uid()) on conflict do nothing;select * into mine from pvp_profiles where user_id=auth.uid();select id into active_id from pvp_matches where auth.uid() in(player1_id,player2_id) and status='active' order by created_at desc limit 1;if active_id is not null then return pvp_state(active_id);end if;
 delete from pvp_queue where joined_at<now()-interval '2 minutes';delete from pvp_queue where user_id=auth.uid();select * into foe from pvp_queue where user_id<>auth.uid() order by joined_at for update skip locked limit 1;s:=pvp_safe_snapshot(p_snapshot);
 if foe.user_id is null then insert into pvp_queue(user_id,display_name,player_tag,snapshot) values(auth.uid(),me.display_name,me.player_tag,s);return jsonb_build_object('kind','queued','rating',mine.rating,'message','等待其他玩家加入競技場…');end if;
 fs:=pvp_safe_snapshot(foe.snapshot);insert into pvp_matches(player1_id,player2_id,player1_name,player2_name,player1_tag,player2_tag,player1_stats,player2_stats,hp1,hp2,mp1,mp2,state1,state2,starts_at,next_action1,next_action2)
 values(foe.user_id,auth.uid(),foe.display_name,me.display_name,foe.player_tag,me.player_tag,fs,s,(fs->>'max_hp')::integer,(s->>'max_hp')::integer,(fs->>'max_mp')::integer,(s->>'max_mp')::integer,pvp_initial_state(fs),pvp_initial_state(s),now()+interval '5 seconds',now()+interval '5 seconds',now()+interval '5 seconds') returning id into mid;delete from pvp_queue where user_id in(foe.user_id,auth.uid());return pvp_state(mid);
end $$;

create or replace function public.pvp_attack(p_atk jsonb,p_def jsonb,p_use_skill boolean) returns jsonb
language plpgsql volatile set search_path=public as $$
declare ty text:=coalesce(p_atk->>'attack_type','melee');sk jsonb:=p_atk->'skill';raw numeric;chance numeric;dmg integer;crit boolean:=false;land boolean;mult numeric:=1;res numeric:=0;name text:='一般攻擊';status jsonb:=null;
begin
 if p_use_skill and sk is not null then ty:=case when sk->>'type'='physical' then coalesce(p_atk->>'attack_type','melee') else sk->>'type' end;name:=coalesce(sk->>'n','職業技能');end if;
 if ty='magic' then chance:=greatest(15,least(95,70+(p_atk->>'hit')::numeric*.5-(p_def->>'mr')::numeric*.12));else chance:=greatest(15,least(95,78+(p_atk->>'hit')::numeric*.35-case when ty='ranged' then (p_def->>'er')::numeric else greatest(0,-(p_def->>'ac')::numeric)*.12 end));end if;
 if pvp_has(p_atk,'sk_elf_preciseshot') and ty='ranged' then chance:=100;end if;land:=random()*100<chance;
 if not land then return jsonb_build_object('damage',0,'hit',false,'crit',false,'name',name,'type',ty,'status',null,'lifesteal',false);end if;
 if ty='magic' and p_use_skill and sk is not null then raw:=greatest(1,(sk->>'power')::numeric)*(1+greatest(0,(p_atk->>'atk')::numeric)*3/16)*(1+least(10,greatest(1,(p_atk->>'lv')::numeric))/30);else raw:=(p_atk->>'atk')::numeric+(p_atk->>'weapon_roll')::numeric;if p_use_skill and sk is not null then raw:=raw*greatest(1,(sk->>'hits')::numeric)+greatest(0,(sk->>'power')::numeric);end if;end if;
 raw:=raw*(.88+random()*.24);if pvp_has(p_atk,'sk_warrior_berserk') and random()<.05 then raw:=raw*2;end if;if (pvp_has(p_atk,'sk_elf_attrfire') or pvp_has(p_atk,'sk_dark_burn')) and random()<.30 then raw:=raw*1.5;end if;
 crit:=random()*100<(p_atk->>'crit')::numeric;if crit then raw:=raw*(1+(p_atk->>'crit_dmg')::numeric/100);end if;
 if ty='magic' then res:=least(75,(p_def->>'mr')::numeric*.12);dmg:=greatest(1,floor(raw*(1-res/100))::integer);else res:=least(65,greatest(0,-(p_def->>'ac')::numeric)*.18);dmg:=greatest(1,floor(raw*(1-res/100)-(p_def->>'dr')::numeric)::integer);end if;
 if pvp_has(p_def,'sk_holy_barrier') then dmg:=greatest(1,floor(dmg*.7)::integer);end if;
 if p_use_skill and sk is not null then status:=sk->'status';end if;
 return jsonb_build_object('damage',dmg,'hit',true,'crit',crit,'name',name,'type',ty,'status',status,'lifesteal',p_use_skill and coalesce((sk->>'lifesteal')::boolean,false));
end $$;

create or replace function public.pvp_tick(p_match uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare m public.pvp_matches;s1 jsonb;s2 jsonb;r1 jsonb;r2 jsonb;nowe numeric:=extract(epoch from now());elapsed numeric;due1 boolean;due2 boolean;hard1 boolean;hard2 boolean;use1 boolean:=false;use2 boolean:=false;heal1 boolean:=false;heal2 boolean:=false;
 d1 integer:=0;d2 integer:=0;ref1 integer:=0;ref2 integer:=0;h1 integer:=0;h2 integer:=0;nh1 integer;nh2 integer;nmp1 integer;nmp2 integer;c1 boolean:=false;c2 boolean:=false;win uuid;txt text;note text:='';entry jsonb;cost integer;st jsonb;
begin
 select * into m from pvp_matches where id=p_match and auth.uid() in(player1_id,player2_id) for update;if m.id is null then raise exception '找不到競技場戰鬥';end if;if m.status<>'active' or now()<coalesce(m.starts_at,m.created_at) or now()-m.last_tick<interval '300 milliseconds' then return pvp_state(m.id);end if;
 s1:=m.state1;s2:=m.state2;elapsed:=greatest(.1,extract(epoch from(now()-m.last_tick)));nh1:=least((m.player1_stats->>'max_hp')::integer,m.hp1+greatest(0,round((m.player1_stats->>'hp_regen')::numeric*elapsed/3))::integer);nh2:=least((m.player2_stats->>'max_hp')::integer,m.hp2+greatest(0,round((m.player2_stats->>'hp_regen')::numeric*elapsed/3))::integer);nmp1:=least((m.player1_stats->>'max_mp')::integer,m.mp1+greatest(0,round((m.player1_stats->>'mp_regen')::numeric*elapsed/3))::integer);nmp2:=least((m.player2_stats->>'max_mp')::integer,m.mp2+greatest(0,round((m.player2_stats->>'mp_regen')::numeric*elapsed/3))::integer);
 if coalesce((s1->>'status_until')::numeric,0)>nowe and coalesce(s1->>'status_id','') in('poison','burn','bleed','scald') then nh1:=greatest(0,nh1-greatest(1,round(coalesce((s1->>'status_dmg')::numeric,1)*elapsed))::integer);end if;if coalesce((s2->>'status_until')::numeric,0)>nowe and coalesce(s2->>'status_id','') in('poison','burn','bleed','scald') then nh2:=greatest(0,nh2-greatest(1,round(coalesce((s2->>'status_dmg')::numeric,1)*elapsed))::integer);end if;
 hard1:=coalesce((s1->>'status_until')::numeric,0)>nowe and coalesce(s1->>'status_id','') in('stun','freeze','stone','sleep','paralyze');hard2:=coalesce((s2->>'status_until')::numeric,0)>nowe and coalesce(s2->>'status_id','') in('stun','freeze','stone','sleep','paralyze');due1:=now()>=coalesce(m.next_action1,m.starts_at,m.created_at) and not hard1;due2:=now()>=coalesce(m.next_action2,m.starts_at,m.created_at) and not hard2;
 if due1 and m.player1_stats->'heal' is not null and nh1<(m.player1_stats->>'max_hp')::integer*.45 then cost:=ceil((m.player1_stats->'heal'->>'mp')::numeric*(1-(m.player1_stats->>'mp_reduce')::numeric/100))::integer;if nmp1>=cost then heal1:=true;nmp1:=nmp1-cost;h1:=round((m.player1_stats->'heal'->>'heal')::numeric*(1+(m.player1_stats->>'atk')::numeric/50))::integer;nh1:=least((m.player1_stats->>'max_hp')::integer,nh1+h1);end if;end if;
 if due2 and m.player2_stats->'heal' is not null and nh2<(m.player2_stats->>'max_hp')::integer*.45 then cost:=ceil((m.player2_stats->'heal'->>'mp')::numeric*(1-(m.player2_stats->>'mp_reduce')::numeric/100))::integer;if nmp2>=cost then heal2:=true;nmp2:=nmp2-cost;h2:=round((m.player2_stats->'heal'->>'heal')::numeric*(1+(m.player2_stats->>'atk')::numeric/50))::integer;nh2:=least((m.player2_stats->>'max_hp')::integer,nh2+h2);end if;end if;
 if due1 and not heal1 and m.player1_stats->'skill' is not null and nowe>=coalesce((s1->>'skill_ready')::numeric,0) then cost:=ceil((m.player1_stats->'skill'->>'mp')::numeric*(1-(m.player1_stats->>'mp_reduce')::numeric/100))::integer;if nmp1>=cost and nh1>(m.player1_stats->'skill'->>'hp')::integer then use1:=true;nmp1:=nmp1-cost;nh1:=nh1-(m.player1_stats->'skill'->>'hp')::integer;s1:=jsonb_set(s1,'{skill_ready}',to_jsonb(nowe+3));end if;end if;
 if due2 and not heal2 and m.player2_stats->'skill' is not null and nowe>=coalesce((s2->>'skill_ready')::numeric,0) then cost:=ceil((m.player2_stats->'skill'->>'mp')::numeric*(1-(m.player2_stats->>'mp_reduce')::numeric/100))::integer;if nmp2>=cost and nh2>(m.player2_stats->'skill'->>'hp')::integer then use2:=true;nmp2:=nmp2-cost;nh2:=nh2-(m.player2_stats->'skill'->>'hp')::integer;s2:=jsonb_set(s2,'{skill_ready}',to_jsonb(nowe+3));end if;end if;
 if due1 and not heal1 then r1:=pvp_attack(m.player1_stats,m.player2_stats,use1);d1:=(r1->>'damage')::integer;c1:=(r1->>'crit')::boolean;if coalesce((r1->>'lifesteal')::boolean,false) then nh1:=least((m.player1_stats->>'max_hp')::integer,nh1+floor(d1*.5)::integer);end if;st:=r1->'status';if d1>0 and st is not null and random()*100<(st->>'chance')::numeric and not((st->>'kind'='poison' and coalesce((m.player2_stats->>'imm_poison')::boolean,false)) or (st->>'kind'='stone' and coalesce((m.player2_stats->>'imm_stone')::boolean,false))) then s2:=s2||jsonb_build_object('status_id',st->>'kind','status_name',st->>'kind','status_until',nowe+(st->>'dur')::numeric,'status_dmg',greatest(1,floor(d1*.08)::integer));end if;end if;
 if due2 and not heal2 then r2:=pvp_attack(m.player2_stats,m.player1_stats,use2);d2:=(r2->>'damage')::integer;c2:=(r2->>'crit')::boolean;if coalesce((r2->>'lifesteal')::boolean,false) then nh2:=least((m.player2_stats->>'max_hp')::integer,nh2+floor(d2*.5)::integer);end if;st:=r2->'status';if d2>0 and st is not null and random()*100<(st->>'chance')::numeric and not((st->>'kind'='poison' and coalesce((m.player1_stats->>'imm_poison')::boolean,false)) or (st->>'kind'='stone' and coalesce((m.player1_stats->>'imm_stone')::boolean,false))) then s1:=s1||jsonb_build_object('status_id',st->>'kind','status_name',st->>'kind','status_until',nowe+(st->>'dur')::numeric,'status_dmg',greatest(1,floor(d2*.08)::integer));end if;end if;
 if d2>0 and ((pvp_has(m.player1_stats,'sk_counter_barrier') and (r2->>'type')<>'magic' and random()<.5) or (pvp_has(m.player1_stats,'sk_dragon_deadlybody') and random()<.23) or (pvp_has(m.player1_stats,'sk_warrior_titan_rock') and nh1<(m.player1_stats->>'max_hp')::integer*.4)) then ref1:=case when pvp_has(m.player1_stats,'sk_counter_barrier') then d2*2 else d2 end;end if;
 if d1>0 and ((pvp_has(m.player2_stats,'sk_counter_barrier') and (r1->>'type')<>'magic' and random()<.5) or (pvp_has(m.player2_stats,'sk_dragon_deadlybody') and random()<.23) or (pvp_has(m.player2_stats,'sk_warrior_titan_rock') and nh2<(m.player2_stats->>'max_hp')::integer*.4)) then ref2:=case when pvp_has(m.player2_stats,'sk_counter_barrier') then d1*2 else d1 end;end if;
 nh1:=greatest(0,nh1-d2-ref2);nh2:=greatest(0,nh2-d1-ref1);
 if due1 then m.next_action1:=now()+make_interval(secs=>greatest(.10,(m.player1_stats->>'interval')::numeric));end if;if due2 then m.next_action2:=now()+make_interval(secs=>greatest(.10,(m.player2_stats->>'interval')::numeric));end if;
 if nh1=0 and pvp_has(m.player1_stats,'sk_resurrection') and not coalesce((s1->>'revived')::boolean,false) then nh1:=greatest(1,floor((m.player1_stats->>'max_hp')::numeric*.3)::integer);s1:=jsonb_set(s1,'{revived}','true'::jsonb);note:=m.player1_name||' 發動返生術';end if;if nh2=0 and pvp_has(m.player2_stats,'sk_resurrection') and not coalesce((s2->>'revived')::boolean,false) then nh2:=greatest(1,floor((m.player2_stats->>'max_hp')::numeric*.3)::integer);s2:=jsonb_set(s2,'{revived}','true'::jsonb);note:=concat_ws('；',nullif(note,''),m.player2_name||' 發動返生術');end if;
 if nh1=0 or nh2=0 then if nh1=0 and nh2=0 then win:=null;txt:='雙方同時倒下，平手';elsif nh2=0 then win:=m.player1_id;txt:=m.player1_name||' 獲得勝利';else win:=m.player2_id;txt:=m.player2_name||' 獲得勝利';end if;end if;
 entry:=jsonb_build_object('round',m.round+1,'d1',d1+ref1,'d2',d2+ref2,'c1',c1,'c2',c2,'hp1',nh1,'hp2',nh2,'skill1',case when use1 then r1->>'name' when heal1 then m.player1_stats->'heal'->>'n' else null end,'skill2',case when use2 then r2->>'name' when heal2 then m.player2_stats->'heal'->>'n' else null end,'heal1',h1,'heal2',h2,'reflect1',ref1,'reflect2',ref2,'note',note);
 update pvp_matches set hp1=nh1,hp2=nh2,mp1=nmp1,mp2=nmp2,state1=s1,state2=s2,next_action1=m.next_action1,next_action2=m.next_action2,round=round+1,battle_log=battle_log||jsonb_build_array(entry),last_tick=now(),updated_at=now(),status=case when nh1=0 or nh2=0 then 'finished' else 'active' end,winner_id=win,result_text=txt where id=m.id;
 if (nh1=0 or nh2=0) and not m.settled then if win is null then update pvp_profiles set draws=draws+1,rating=rating+2,updated_at=now() where user_id in(m.player1_id,m.player2_id);else update pvp_profiles set wins=wins+1,rating=rating+15,updated_at=now() where user_id=win;update pvp_profiles set losses=losses+1,rating=greatest(0,rating-10),updated_at=now() where user_id in(m.player1_id,m.player2_id) and user_id<>win;end if;update pvp_matches set settled=true where id=m.id;end if;return pvp_state(m.id);
end $$;

revoke all on function public.pvp_has(jsonb,text),public.pvp_runtime_status(jsonb),public.pvp_initial_state(jsonb),public.pvp_attack(jsonb,jsonb,boolean) from public;
grant execute on function public.pvp_state(uuid),public.pvp_join_queue(jsonb),public.pvp_poll(),public.pvp_tick(uuid),public.pvp_cancel_queue(),public.pvp_forfeit(uuid) to authenticated;
notify pgrst,'reload schema';
