-- 線上血盟管理更新：盟主解散血盟。
-- 原本的搜尋血盟、直接申請加入與盟主審核已包含在 supabase-clan.sql；
-- 已安裝舊版血盟系統者，只需在同一個 Supabase 專案執行本檔。
create or replace function public.clan_dissolve(p_confirm_name text) returns void
language plpgsql security definer set search_path=public as $$
declare cid uuid;cname text;
begin
 select c.id,c.name into cid,cname from clans c join clan_members m on m.clan_id=c.id
 where m.user_id=auth.uid() and m.role='owner' for update;
 if cid is null then raise exception '只有盟主可以解散血盟';end if;
 if trim(coalesce(p_confirm_name,''))<>cname then raise exception '血盟名稱確認不正確';end if;
 -- 所有成員、申請、邀請、倉庫、科技等資料皆由外鍵 on delete cascade 一併移除。
 delete from clans where id=cid and owner_id=auth.uid();
 if not found then raise exception '解散血盟失敗';end if;
end $$;

revoke all on function public.clan_dissolve(text) from public;
grant execute on function public.clan_dissolve(text) to authenticated;
notify pgrst,'reload schema';
