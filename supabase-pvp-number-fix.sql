-- 連線競技場小數能力值修正。
-- 已經執行過 supabase-pvp.sql 的專案，只需執行本檔一次。
create or replace function public.pvp_safe_snapshot(p jsonb) returns jsonb
language sql immutable set search_path=public as $$
 select jsonb_build_object(
  'lv',greatest(1,least(100,round(coalesce((p->>'lv')::numeric,1))::integer)),
  'class',left(coalesce(nullif(p->>'class',''),'冒險者'),20),
  'avatar',left(coalesce(p->>'avatar',''),20),
  'morph',left(coalesce(p->>'morph',''),30),
  'weapon',left(coalesce(p->>'weapon','sword1'),20),
  'buffs',case when jsonb_typeof(p->'buffs')='array' then jsonb_path_query_array(p->'buffs','$[0 to 23]') else '[]'::jsonb end,
  'statuses',case when jsonb_typeof(p->'statuses')='array' then jsonb_path_query_array(p->'statuses','$[0 to 15]') else '[]'::jsonb end,
  'max_hp',greatest(100,least(1000000,round(coalesce((p->>'max_hp')::numeric,100))::integer)),
  'atk',greatest(10,least(100000,round(coalesce((p->>'atk')::numeric,10))::integer)),
  'def',greatest(0,least(100000,round(coalesce((p->>'def')::numeric,0))::integer)),
  'crit',greatest(0,least(50,coalesce((p->>'crit')::numeric,0))),
  'speed',greatest(0.6,least(2.5,coalesce((p->>'speed')::numeric,1)))
 );
$$;
revoke all on function public.pvp_safe_snapshot(jsonb) from public;
notify pgrst,'reload schema';
