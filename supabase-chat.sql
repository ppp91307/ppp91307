-- 全服／血盟聊天室：在 idle-lineage-market 專案的 SQL Editor 執行。
create table if not exists public.chat_messages(
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 clan_id uuid references public.clans(id) on delete cascade,
 channel text not null check(channel in('global','clan')),
 content text not null check(char_length(content) between 1 and 120),
 created_at timestamptz not null default now()
);
create index if not exists chat_messages_global_idx on public.chat_messages(channel,created_at desc);
create index if not exists chat_messages_clan_idx on public.chat_messages(clan_id,created_at desc);
alter table public.chat_messages enable row level security;

create table if not exists public.online_presence(
 user_id uuid primary key references auth.users(id) on delete cascade,
 last_seen timestamptz not null default now()
);
alter table public.online_presence enable row level security;

create or replace function public.chat_presence() returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin if auth.uid() is null then raise exception '尚未登入';end if;
 insert into online_presence(user_id,last_seen)values(auth.uid(),now())on conflict(user_id)do update set last_seen=now();
 delete from online_presence where last_seen<now()-interval '2 minutes';
 select count(*) into n from online_presence where last_seen>=now()-interval '1 minute';return n;
end $$;

create or replace function public.chat_send(p_channel text,p_content text) returns bigint language plpgsql security definer set search_path=public as $$
declare cid uuid;mid bigint;clean text;
begin
 if auth.uid() is null then raise exception '尚未登入';end if;if p_channel not in('global','clan') then raise exception '頻道不正確';end if;
 clean:=trim(regexp_replace(coalesce(p_content,''),'[\n\r\t]+',' ','g'));if char_length(clean) not between 1 and 120 then raise exception '訊息長度需為 1～120 字';end if;
 if exists(select 1 from chat_messages where user_id=auth.uid() and created_at>now()-interval '2 seconds') then raise exception '發言速度太快，請稍候';end if;
 if p_channel='clan' then select clan_id into cid from clan_members where user_id=auth.uid();if cid is null then raise exception '尚未加入血盟';end if;end if;
 insert into chat_messages(user_id,clan_id,channel,content) values(auth.uid(),cid,p_channel,clean) returning id into mid;return mid;
end $$;

create or replace function public.chat_read(p_channel text) returns table(id bigint,author text,content text,created_at timestamptz) language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 if auth.uid() is null then raise exception '尚未登入';end if;if p_channel not in('global','clan') then raise exception '頻道不正確';end if;
 if p_channel='clan' then select clan_id into cid from clan_members where user_id=auth.uid();if cid is null then raise exception '尚未加入血盟';end if;end if;
 return query select x.id,case when nullif(trim(p.player_tag),'') is not null then '@'||p.player_tag else coalesce(p.display_name,'冒險者')end,x.content,x.created_at from(select m.* from chat_messages m where(p_channel='global' and m.channel='global')or(p_channel='clan' and m.channel='clan' and m.clan_id=cid)order by m.created_at desc limit 60)x left join market_profiles p on p.user_id=x.user_id order by x.created_at;
end $$;

revoke all on function public.chat_send(text,text),public.chat_read(text),public.chat_presence() from public;
grant execute on function public.chat_send(text,text),public.chat_read(text),public.chat_presence() to authenticated;
notify pgrst,'reload schema';
