alter table public.products
  add column if not exists is_archived boolean not null default false,
  add column if not exists last_supplier_id text,
  add column if not exists expiry_date timestamptz,
  add column if not exists discount_percentage integer;

create table if not exists cashier_private.catalog_receipts(
  tenant_id text not null, operation uuid not null, product_id text not null,
  primary key(tenant_id,operation)
);
revoke all on cashier_private.catalog_receipts from public, anon, authenticated;

create or replace function public.write_cashier_catalog(
  p_tenant text,p_device_key text,p_operation uuid,p_id text,p_action text,
  p_patch jsonb,p_before jsonb
) returns void language plpgsql security definer set search_path='' as $$
declare
  old_row public.products%rowtype;
  k text;
  assignments text;
  allowed constant text[] := array['name','category','description','price','old_price','purchase_price','wholesale_price','min_stock_level','unit','barcode','images','video_url','stock_quantity','in_stock','is_offer','is_featured_deal','is_daily_starred','colors','sizes','variants','is_archived','expiry_date','last_supplier_id','discount_percentage'];
begin
  perform public.submit_cashier_stock(p_tenant,p_device_key,'[]'::jsonb);
  if p_action not in ('create','patch','delete') or p_action is null or nullif(p_id,'') is null or p_operation is null or jsonb_typeof(p_patch) is distinct from 'object' or jsonb_typeof(p_before) is distinct from 'object' then
    raise exception 'Invalid catalog operation';
  end if;
  insert into cashier_private.catalog_receipts values(p_tenant,p_operation,p_id)
    on conflict do nothing;
  if not found then return; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id,0));
  select * into old_row from public.products where id=p_id for update;
  if found and old_row.tenant_id <> p_tenant then raise exception 'Product does not belong to this store'; end if;
  if p_action='delete' then
    delete from public.products where id=p_id and tenant_id=p_tenant;
    return;
  elsif p_action='create' then
    if old_row.id is not null then raise exception 'Product ID already exists'; end if;
    insert into public.products(id,tenant_id,name) values(p_id,p_tenant,p_patch->>'name');
  elsif old_row.id is null then raise exception 'Product no longer exists'; end if;
  for k in select jsonb_object_keys(p_patch) loop
    if not(k=any(allowed)) then raise exception 'Unsupported catalog field'; end if;
    if p_action='patch' and p_before ? k and to_jsonb(old_row)->k is distinct from p_before->k and to_jsonb(old_row)->k is distinct from p_patch->k then
      raise exception 'Concurrent catalog edit: %',k using errcode='40001';
    end if;
    assignments:=concat_ws(', ',assignments,format('%I=v.%I',k,k));
  end loop;
  if assignments is not null then
    execute format('update public.products p set %s, updated_at=now() from jsonb_populate_record(null::public.products,$1) v where p.tenant_id=$2 and p.id=$3',assignments)
      using p_patch,p_tenant,p_id;
  end if;
end $$;
revoke all on function public.write_cashier_catalog(text,text,uuid,text,text,jsonb,jsonb) from public;
grant execute on function public.write_cashier_catalog(text,text,uuid,text,text,jsonb,jsonb) to anon,authenticated;
