-- 唯一玩家 ID：支援 2～16 位中文、英文、數字及底線。
alter table public.market_profiles add column if not exists player_tag text;
create unique index if not exists market_profiles_player_tag_unique on public.market_profiles(lower(player_tag)) where player_tag is not null;

create or replace function public.player_set_tag(p_tag text) returns text language plpgsql security definer set search_path=public as $$
declare clean text;
begin clean:=trim(p_tag);if auth.uid() is null then raise exception '尚未登入';end if;if char_length(clean) not between 2 and 16 or clean!~'^[A-Za-z0-9_一-龥]{2,16}$' then raise exception 'ID只能使用2～16位中文、英文字母、數字或底線';end if;
 update market_profiles set player_tag=clean,updated_at=now() where user_id=auth.uid();if not found then raise exception '玩家資料不存在';end if;return clean;
exception when unique_violation then raise exception '這個玩家ID已經有人使用';end $$;

create or replace function public.player_my_identity() returns jsonb language sql security definer set search_path=public as $$select jsonb_build_object('user_id',user_id,'display_name',display_name,'player_tag',player_tag)from market_profiles where user_id=auth.uid()$$;

drop function if exists public.clan_search_players(text);
create function public.clan_search_players(p_query text) returns table(user_id uuid,display_name text,player_tag text) language sql security definer set search_path=public as $$
 select p.user_id,p.display_name,p.player_tag from market_profiles p left join clan_members m on m.user_id=p.user_id where m.user_id is null and p.user_id<>auth.uid() and(p.display_name ilike '%'||trim(coalesce(p_query,''))||'%' or p.player_tag ilike '%'||trim(coalesce(p_query,''))||'%')order by p.display_name limit 30;
$$;

create or replace function public.chat_read(p_channel text) returns table(id bigint,author text,content text,created_at timestamptz) language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin if auth.uid() is null then raise exception '尚未登入';end if;if p_channel not in('global','clan')then raise exception '頻道不正確';end if;if p_channel='clan'then select clan_id into cid from clan_members where user_id=auth.uid();if cid is null then raise exception '尚未加入血盟';end if;end if;
 return query select x.id,case when p.player_tag is not null then '@'||p.player_tag else coalesce(p.display_name,'冒險者')end,x.content,x.created_at from(select m.* from chat_messages m where(p_channel='global'and m.channel='global')or(p_channel='clan'and m.channel='clan'and m.clan_id=cid)order by m.created_at desc limit 60)x left join market_profiles p on p.user_id=x.user_id order by x.created_at;
end $$;

revoke all on function player_set_tag(text),player_my_identity(),clan_search_players(text) from public;
grant execute on function player_set_tag(text),player_my_identity(),clan_search_players(text) to authenticated;
notify pgrst,'reload schema';
