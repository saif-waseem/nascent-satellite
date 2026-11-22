-- Runs with the caller's regular product permissions. Compare and restore only
-- fields touched by the original edit in the same row lock.
CREATE OR REPLACE FUNCTION public.undo_product_edit(p_tenant text,p_id text,p_expected jsonb,p_restore jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE item public.products%ROWTYPE; assignments text; k text;
BEGIN
  SELECT * INTO STRICT item FROM public.products WHERE tenant_id=p_tenant AND id=p_id FOR UPDATE;
  IF jsonb_typeof(p_expected) IS DISTINCT FROM 'object' OR p_expected='{}' OR
      jsonb_typeof(p_restore) IS DISTINCT FROM 'object' OR p_restore='{}' THEN RAISE EXCEPTION 'Invalid edit'; END IF;
  IF EXISTS(SELECT FROM jsonb_each(p_expected) e WHERE to_jsonb(item)->e.key IS DISTINCT FROM to_jsonb(jsonb_populate_record(null::public.products,p_expected))->e.key)
    THEN RAISE EXCEPTION 'تغير السجل بعد الحفظ'; END IF;
  FOR k IN SELECT jsonb_object_keys(p_restore) LOOP
    IF NOT (p_expected ? k) OR NOT k=ANY(ARRAY['name','price','category','description','old_price','purchase_price','wholesale_price','stock_quantity','in_stock','min_stock_level','unit','barcode','images','video_url','is_offer','is_featured_deal','is_daily_starred','colors','sizes','variants','is_archived','last_supplier_id','expiry_date','discount_percentage'])
      THEN RAISE EXCEPTION 'Unsupported field'; END IF;
    assignments:=concat_ws(', ',assignments,format('%I=v.%I',k,k));
  END LOOP;
  EXECUTE format('update public.products set %s,updated_at=now() from jsonb_populate_record(null::public.products,$1) v where products.id=$2 and products.tenant_id=$3',assignments)
    USING p_restore,p_id,p_tenant;
END $$;
REVOKE ALL ON FUNCTION public.undo_product_edit(text,text,jsonb,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.undo_product_edit(text,text,jsonb,jsonb) TO anon,authenticated;
