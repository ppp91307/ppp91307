-- 玩家 ID 私聊系統：請在 idle-lineage-market 專案的 SQL Editor 執行一次。
alter table public.chat_messages
  add column if not exists recipient_id uuid references auth.users(id) on delete cascade;

alter table public.chat_messages drop constraint if exists chat_messages_channel_check;
alter table public.chat_messages
  add constraint chat_messages_channel_check check(channel in('global','clan','private'));

create index if not exists chat_messages_private_sender_idx
  on public.chat_messages(user_id,recipient_id,created_at desc) where channel='private';
create index if not exists chat_messages_private_recipient_idx
  on public.chat_messages(recipient_id,user_id,created_at desc) where channel='private';

create or replace function public.chat_private_send(p_target_tag text,p_content text)
returns bigint language plpgsql security definer set search_path=public as $$
declare target_id uuid; mid bigint; clean text; target text;
begin
  if auth.uid() is null then raise exception '尚未登入'; end if;
  target:=trim(regexp_replace(coalesce(p_target_tag,''),'^@','','g'));
  select user_id into target_id from market_profiles where lower(player_tag)=lower(target) limit 1;
  if target_id is null then raise exception '找不到玩家 ID：%',target; end if;
  if target_id=auth.uid() then raise exception '不能私聊自己'; end if;
  clean:=trim(regexp_replace(coalesce(p_content,''),'[\n\r\t]+',' ','g'));
  if char_length(clean) not between 1 and 120 then raise exception '訊息長度必須為 1～120 字'; end if;
  if exists(select 1 from chat_messages where user_id=auth.uid() and created_at>now()-interval '2 seconds') then
    raise exception '發送太快，請稍候';
  end if;
  insert into chat_messages(user_id,recipient_id,channel,content)
  values(auth.uid(),target_id,'private',clean) returning id into mid;
  return mid;
end $$;

create or replace function public.chat_private_read(p_target_tag text default '')
returns table(id bigint,author text,recipient text,content text,created_at timestamptz,mine boolean)
language plpgsql security definer set search_path=public as $$
declare target_id uuid; target text;
begin
  if auth.uid() is null then raise exception '尚未登入'; end if;
  target:=trim(regexp_replace(coalesce(p_target_tag,''),'^@','','g'));
  if target<>'' then
    select user_id into target_id from market_profiles where lower(player_tag)=lower(target) limit 1;
    if target_id is null then raise exception '找不到玩家 ID：%',target; end if;
  end if;
  return query
  select m.id,
         coalesce('@'||nullif(sp.player_tag,''),sp.display_name,'冒險者'),
         coalesce('@'||nullif(rp.player_tag,''),rp.display_name,'冒險者'),
         m.content,m.created_at,(m.user_id=auth.uid())
  from chat_messages m
  left join market_profiles sp on sp.user_id=m.user_id
  left join market_profiles rp on rp.user_id=m.recipient_id
  where m.channel='private'
    and (m.user_id=auth.uid() or m.recipient_id=auth.uid())
    and (target_id is null or
         (m.user_id=auth.uid() and m.recipient_id=target_id) or
         (m.user_id=target_id and m.recipient_id=auth.uid()))
  order by m.created_at desc limit 80;
end $$;

revoke all on function public.chat_private_send(text,text),public.chat_private_read(text) from public;
grant execute on function public.chat_private_send(text,text),public.chat_private_read(text) to authenticated;
notify pgrst,'reload schema';
