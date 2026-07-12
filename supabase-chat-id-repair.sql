-- 修復聊天室作者顯示：優先使用唯一玩家 ID，同時保留線上人數功能。
create or replace function public.chat_read(p_channel text)
returns table(id bigint,author text,content text,created_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 if auth.uid() is null then raise exception '尚未登入';end if;
 if p_channel not in('global','clan') then raise exception '頻道不正確';end if;
 if p_channel='clan' then
  select clan_id into cid from clan_members where user_id=auth.uid();
  if cid is null then raise exception '尚未加入血盟';end if;
 end if;
 return query
 select x.id,
        case when nullif(trim(p.player_tag),'') is not null
             then '@'||p.player_tag
             else coalesce(p.display_name,'冒險者') end,
        x.content,x.created_at
 from (
  select m.* from chat_messages m
  where (p_channel='global' and m.channel='global')
     or (p_channel='clan' and m.channel='clan' and m.clan_id=cid)
  order by m.created_at desc limit 60
 ) x
 left join market_profiles p on p.user_id=x.user_id
 order by x.created_at;
end $$;

revoke all on function public.chat_read(text) from public;
grant execute on function public.chat_read(text) to authenticated;
notify pgrst,'reload schema';
