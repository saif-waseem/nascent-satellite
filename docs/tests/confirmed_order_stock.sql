BEGIN;
DO $test$
DECLARE
  tenant text := gen_random_uuid()::text;
  item text := gen_random_uuid()::text;
  order_id text := gen_random_uuid()::text;
  stamp timestamptz := clock_timestamp();
  lines jsonb;
  actual public.products%ROWTYPE;
BEGIN
  INSERT INTO public.tenants(id,name) VALUES (tenant,'Rollback fixture');
  INSERT INTO public.products(id,tenant_id,name,stock_quantity,variants)
    VALUES (item,tenant,'Rollback fixture',5,
    '[{"color":"red","size":"S","stock":5,"storageLocations":[{"warehouseName":"A","quantity":2},{"warehouseName":"B","quantity":3}]}]');
  lines := jsonb_build_array(jsonb_build_object('id',item,'color','red','size','S','qty',4));
  PERFORM public.sync_confirmed_order_stock(order_id,tenant,stamp,lines);
  PERFORM public.sync_confirmed_order_stock(order_id,tenant,stamp,lines);
  PERFORM public.sync_confirmed_order_stock(order_id,tenant,stamp-interval '1 second','[]');
  SELECT * INTO STRICT actual FROM public.products WHERE id=item;
  IF actual.stock_quantity<>1 OR actual.variants#>>'{0,storageLocations,1,quantity}' <> '1'
    THEN RAISE EXCEPTION 'Duplicate or stale revision changed stock'; END IF;
  BEGIN
    PERFORM public.sync_confirmed_order_stock(order_id,tenant,stamp+interval '1 second',jsonb_set(lines,'{0,qty}','9'));
    RAISE EXCEPTION 'Oversold';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE 'Insufficient%' THEN RAISE; END IF;
  END;
  PERFORM public.sync_confirmed_order_stock(order_id,tenant,stamp+interval '2 seconds','[]');
  SELECT * INTO STRICT actual FROM public.products WHERE id=item;
  IF actual.stock_quantity<>5 OR actual.variants#>>'{0,storageLocations,0,quantity}'<>'2'
    OR actual.variants#>>'{0,storageLocations,1,quantity}'<>'3'
    THEN RAISE EXCEPTION 'Cancellation did not restore allocated bins'; END IF;
END $test$;
ROLLBACK;
