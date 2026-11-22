BEGIN;
DO $t$
DECLARE tenant text:=gen_random_uuid()::text; product text:=gen_random_uuid()::text; p public.products%ROWTYPE; l cashier_private.stock_ledger%ROWTYPE;
BEGIN
INSERT INTO public.tenants(id,name) VALUES(tenant,'undo test');
INSERT INTO public.products(id,tenant_id,name,price,stock_quantity,variants) VALUES(product,tenant,'original',9,3,'[{"color":"Red","size":"S","stock":3}]');
UPDATE public.products SET price=15 WHERE id=product;
UPDATE public.products SET stock_quantity=2,variants='[{"color":"Red","size":"S","stock":2}]' WHERE id=product;
PERFORM public.undo_product_edit(tenant,product,'{"price":15}','{"price":9}');
SELECT * INTO STRICT p FROM public.products WHERE id=product;
IF p.price<>9 OR p.stock_quantity<>2 THEN RAISE EXCEPTION 'Lost sale or failed undo'; END IF;
SELECT * INTO STRICT l FROM cashier_private.stock_ledger WHERE stock_ledger.product=p.id ORDER BY seq DESC LIMIT 1;
IF l.balance<>2 OR l.opening<>3 OR l.variants#>>'{0,size}'<>'S' THEN RAISE EXCEPTION 'Incorrect movement'; END IF;
BEGIN
 PERFORM public.undo_product_edit(tenant,product,'{"stock_quantity":3,"is_archived":false}','{"is_archived":true}');
 RAISE EXCEPTION 'Unexpected reversal';
EXCEPTION WHEN raise_exception THEN IF SQLERRM='Unexpected reversal' THEN RAISE; END IF; END;
END $t$;
ROLLBACK;
