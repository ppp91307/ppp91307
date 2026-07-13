-- 連線競技場小數能力值修正。
-- 已經執行過 supabase-pvp.sql 的專案，只需執行本檔一次。
create or replace function public.pvp_safe_snapshot(p jsonb) returns jsonb
language sql immutable set search_path=public as $$
 select jsonb_build_object(
  'lv',greatest(1,least(100,round(coalesce((p->>'lv')::numeric,1))::integer)),
  'class',left(coalesce(nullif(p->>'class',''),'冒險者'),20),
  'max_hp',greatest(100,least(1000000,round(coalesce((p->>'max_hp')::numeric,100))::integer)),
  'atk',greatest(10,least(100000,round(coalesce((p->>'atk')::numeric,10))::integer)),
  'def',greatest(0,least(100000,round(coalesce((p->>'def')::numeric,0))::integer)),
  'crit',greatest(0,least(50,coalesce((p->>'crit')::numeric,0))),
  'speed',greatest(0.6,least(2.5,coalesce((p->>'speed')::numeric,1)))
 );
$$;
revoke all on function public.pvp_safe_snapshot(jsonb) from public;
notify pgrst,'reload schema';
