BEGIN;
CREATE TABLE IF NOT EXISTS cashier_private.stock_ledger(
 seq bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant text NOT NULL, product text NOT NULL, recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 opening integer NOT NULL,balance integer NOT NULL,note text NOT NULL,variants jsonb NOT NULL
);
CREATE INDEX IF NOT EXISTS stock_ledger_lookup ON cashier_private.stock_ledger(tenant,product,seq DESC);
REVOKE ALL ON cashier_private.stock_ledger FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION cashier_private.record_product_balance() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE prior integer:=coalesce(old.stock_quantity,0); lines jsonb; trace text; source text;
BEGIN
 WITH a AS (SELECT v->>'color' color,v->>'size' size,sum((v->>'stock')::int)::int qty
 FROM jsonb_array_elements(coalesce(old.variants,'[]')) v GROUP BY 1,2),
 b AS (SELECT v->>'color' color,v->>'size' size,sum((v->>'stock')::int)::int qty
 FROM jsonb_array_elements(coalesce(new.variants,'[]')) v GROUP BY 1,2)
 SELECT coalesce(jsonb_agg(jsonb_build_object('color',color,'size',size,'opening',coalesce(a.qty,0),'balance',coalesce(b.qty,0)) ORDER BY color,size),'[]')
 INTO lines FROM a FULL JOIN b USING(color,size) WHERE coalesce(a.qty,0)<>coalesce(b.qty,0);
 GET DIAGNOSTICS trace = PG_CONTEXT;
 source:=CASE WHEN trace LIKE '%sync_confirmed_order_stock(%' THEN 'طلب المتجر'
 WHEN trace LIKE '%count_cashier_product(%' THEN 'جرد وتسوية'
 WHEN trace LIKE '%write_cashier_catalog(%' THEN 'تحديث من الكاشير'
 WHEN trace LIKE '%submit_cashier_stock(%' THEN 'حركة الكاشير'
 WHEN trace LIKE '%undo_product_edit(%' THEN 'تراجع عن إدخال'
 ELSE 'إدخال أو تعديل مخزون' END;
 IF prior<>new.stock_quantity OR lines<>'[]' THEN
 INSERT INTO cashier_private.stock_ledger(tenant,product,opening,balance,note,variants)
 VALUES(new.tenant_id,new.id,prior,new.stock_quantity,source,lines);
 END IF;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS record_product_balance ON public.products;
CREATE TRIGGER record_product_balance AFTER INSERT OR UPDATE OF stock_quantity,variants ON public.products
FOR EACH ROW EXECUTE FUNCTION cashier_private.record_product_balance();
CREATE TABLE IF NOT EXISTS cashier_private.ledger_start(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), started timestamptz NOT NULL DEFAULT now());
INSERT INTO cashier_private.ledger_start(singleton) VALUES(true) ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION public.cashier_product_snapshot(p_tenant text,p_device_key text,p_product text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE snapshot jsonb;
BEGIN
 PERFORM public.submit_cashier_stock(p_tenant,p_device_key,'[]'::jsonb);
 SELECT jsonb_build_object('stock_quantity',p.stock_quantity,'history',coalesce((
 SELECT jsonb_agg(to_jsonb(h) ORDER BY h.recorded_at DESC,h.seq DESC) FROM (
 SELECT * FROM (
 SELECT l.recorded_at,l.balance-l.opening delta,l.balance,l.note,l.opening,l.variants,l.seq
 FROM cashier_private.stock_ledger l WHERE l.tenant=p_tenant AND l.product=p_product
 UNION ALL SELECT o.recorded_at,o.delta,o.balance,o.note,o.balance-o.delta,'[]',0
 FROM public.cashier_product_history(p_tenant,p_device_key,p_product) o
 WHERE o.recorded_at < (SELECT started FROM cashier_private.ledger_start)
 ) movements ORDER BY recorded_at DESC,seq DESC LIMIT 100) h),'[]'))
 INTO STRICT snapshot FROM public.products p WHERE p.tenant_id=p_tenant AND p.id=p_product;
 RETURN snapshot;
END $$;
COMMIT;
