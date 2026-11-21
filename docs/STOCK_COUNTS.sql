BEGIN;
CREATE TABLE IF NOT EXISTS cashier_private.stock_counts (
 tenant_id text NOT NULL, operation_id uuid NOT NULL, product_id text NOT NULL,
 expected_quantity integer NOT NULL, counted_quantity integer NOT NULL,
 reason text NOT NULL, created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY (tenant_id, operation_id)
);
REVOKE ALL ON cashier_private.stock_counts FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.count_cashier_product(p_tenant text,p_device_key text,
 p_product text,p_operation uuid,p_expected integer,p_counted integer,p_reason text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old cashier_private.stock_counts%ROWTYPE; item public.products%ROWTYPE;
BEGIN
 PERFORM public.submit_cashier_stock(p_tenant,p_device_key,'[]'::jsonb);
 IF p_expected IS NULL OR p_counted IS NULL OR least(p_expected,p_counted)<0 OR
    nullif(trim(p_reason),'') IS NULL OR length(p_reason)>250 OR p_operation IS NULL THEN
   RAISE EXCEPTION 'Invalid inventory count';
 END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant || p_operation::text,0));
 SELECT * INTO old FROM cashier_private.stock_counts WHERE tenant_id=p_tenant AND operation_id=p_operation;
 IF FOUND THEN
   IF (old.product_id,old.expected_quantity,old.counted_quantity,old.reason) IS DISTINCT FROM
      (p_product,p_expected,p_counted,trim(p_reason)) THEN RAISE EXCEPTION 'Count reference already used'; END IF;
   RETURN old.counted_quantity;
 END IF;
 SELECT * INTO STRICT item FROM public.products WHERE id=p_product AND tenant_id=p_tenant FOR UPDATE;
 IF item.stock_quantity <> p_expected THEN RAISE EXCEPTION 'Stock changed; refresh and count again'; END IF;
 IF jsonb_array_length(coalesce(item.variants,'[]'))>0 OR jsonb_array_length(coalesce(item.storage_locations,'[]'))>0 THEN
   RAISE EXCEPTION 'Location-specific count required';
 END IF;
 IF EXISTS(SELECT FROM public.simple_stock_movements WHERE tenant_id=p_tenant AND operation_id=p_operation) THEN
   RAISE EXCEPTION 'Movement reference already used';
 END IF;
 IF p_expected<>p_counted THEN
   PERFORM public.apply_simple_stock_movement(p_tenant,p_operation,p_product,p_counted-p_expected);
 END IF;
 INSERT INTO cashier_private.stock_counts(tenant_id,operation_id,product_id,expected_quantity,counted_quantity,reason)
 VALUES(p_tenant,p_operation,p_product,p_expected,p_counted,trim(p_reason));
 RETURN p_counted;
END;
$$;

CREATE INDEX IF NOT EXISTS simple_stock_history_idx ON public.simple_stock_movements(tenant_id,product_id,created_at DESC);
CREATE INDEX IF NOT EXISTS stock_counts_history_idx ON cashier_private.stock_counts(tenant_id,product_id,created_at DESC);
CREATE OR REPLACE FUNCTION public.cashier_product_history(p_tenant text,p_device_key text,p_product text)
RETURNS TABLE(recorded_at timestamptz,delta integer,balance integer,note text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.submit_cashier_stock(p_tenant,p_device_key,'[]'::jsonb);
 RETURN QUERY SELECT h.ts,h.d,h.b,h.n FROM (
   SELECT m.created_at ts,m.quantity_delta d,m.resulting_quantity b,'حركة مخزون'::text n,m.operation_id op
   FROM public.simple_stock_movements m WHERE m.tenant_id=p_tenant AND m.product_id=p_product
   AND NOT EXISTS (SELECT FROM cashier_private.stock_counts c WHERE c.tenant_id=m.tenant_id AND c.operation_id=m.operation_id)
   UNION ALL
   SELECT c.created_at,c.counted_quantity-c.expected_quantity,c.counted_quantity,c.reason,c.operation_id
   FROM cashier_private.stock_counts c WHERE c.tenant_id=p_tenant AND c.product_id=p_product
 ) h ORDER BY h.ts DESC,h.op LIMIT 100;
END;
$$;
REVOKE ALL ON FUNCTION public.cashier_product_history(text,text,text),public.count_cashier_product(text,text,text,uuid,integer,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cashier_product_history(text,text,text),public.count_cashier_product(text,text,text,uuid,integer,integer,text) TO anon,authenticated;
CREATE OR REPLACE FUNCTION public.cashier_product_snapshot(p_tenant text,p_device_key text,p_product text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE snapshot jsonb;
BEGIN
 PERFORM public.submit_cashier_stock(p_tenant,p_device_key,'[]'::jsonb);
 SELECT jsonb_build_object('stock_quantity',p.stock_quantity,'history',
   coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.recorded_at DESC) FROM public.cashier_product_history(p_tenant,p_device_key,p_product) h),'[]'::jsonb))
 INTO STRICT snapshot FROM public.products p WHERE p.tenant_id=p_tenant AND p.id=p_product;
 RETURN snapshot;
END;
$$;
REVOKE ALL ON FUNCTION public.cashier_product_snapshot(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cashier_product_snapshot(text,text,text) TO anon,authenticated;
COMMIT;