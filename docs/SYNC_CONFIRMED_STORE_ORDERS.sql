BEGIN;
CREATE SCHEMA IF NOT EXISTS inventory_private;
REVOKE ALL ON SCHEMA inventory_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS inventory_private.store_order_stock (
  order_id text PRIMARY KEY, tenant text NOT NULL, version timestamptz NOT NULL,
  lines jsonb NOT NULL
);
REVOKE ALL ON inventory_private.store_order_stock FROM PUBLIC, anon, authenticated;

-- Only the backend that reads the confirmed Firestore order may call this.
CREATE OR REPLACE FUNCTION public.sync_confirmed_order_stock(
  p_order text, p_tenant text, p_version timestamptz, p_items jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  previous inventory_private.store_order_stock%ROWTYPE;
  product public.products%ROWTYPE;
  line record;
  v jsonb;
  places jsonb;
  place jsonb;
  variant_idx integer;
  i integer;
  need integer;
  take integer;
  next_qty integer;
  held jsonb;
  key text;
  available integer;
  allocations jsonb;
BEGIN
  IF nullif(p_order,'') IS NULL OR nullif(p_tenant,'') IS NULL OR p_version IS NULL
      OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items)>500 THEN
    RAISE EXCEPTION 'Invalid order';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_order,0));
  SELECT * INTO previous FROM inventory_private.store_order_stock WHERE order_id=p_order;
  IF FOUND AND previous.tenant <> p_tenant THEN RAISE EXCEPTION 'Order tenant changed'; END IF;
  IF previous.version >= p_version THEN RETURN; END IF;
  IF EXISTS (SELECT FROM jsonb_to_recordset(p_items) x(id text,color text,size text,qty int)
    WHERE nullif(id,'') IS NULL OR color IS NULL OR size IS NULL OR qty IS NULL OR qty NOT BETWEEN 1 AND 1000000)
    THEN RAISE EXCEPTION 'Invalid order quantity or product'; END IF;
  -- Retain bin allocations so cancellations put units back in their original bin.
  allocations := '[]';
  FOR line IN
    WITH desired AS (SELECT id,color,size,sum(qty)::int qty FROM jsonb_to_recordset(p_items)
      AS x(id text,color text,size text,qty int) GROUP BY id,color,size),
    old AS (SELECT * FROM jsonb_to_recordset(coalesce(previous.lines,'[]'))
      AS x(id text,color text,size text,qty int,bins jsonb))
    SELECT id,color,size,coalesce(desired.qty,0) qty,coalesce(desired.qty,0)-coalesce(old.qty,0) delta,
      coalesce(old.bins,'{}') bins FROM desired FULL JOIN old USING(id,color,size) ORDER BY id,color,size
  LOOP
    held := line.bins;
    IF line.delta <> 0 THEN
      SELECT * INTO STRICT product FROM public.products WHERE tenant_id=p_tenant AND id=line.id FOR UPDATE;
      next_qty := product.stock_quantity-line.delta;
      IF next_qty<0 THEN RAISE EXCEPTION 'Insufficient product stock'; END IF;
      variant_idx := NULL;
      IF jsonb_array_length(coalesce(product.variants,'[]'))>0 THEN
        SELECT (n-1)::int,value INTO STRICT variant_idx,v FROM jsonb_array_elements(product.variants)
          WITH ORDINALITY AS x(value,n) WHERE value->>'color'=line.color AND value->>'size'=line.size;
        IF (v->>'stock')::int < line.delta THEN RAISE EXCEPTION 'Insufficient variant stock'; END IF;
        v := jsonb_set(v,'{stock}',to_jsonb((v->>'stock')::int-line.delta));
        places := coalesce(v->'storageLocations','[]');
      ELSE
        places := coalesce(product.storage_locations,'[]');
      END IF;
      need := abs(line.delta);
      IF jsonb_array_length(places)>0 OR held<>'{}' THEN
        FOR i IN 0..jsonb_array_length(places)-1 LOOP
          place := places->i;
          key := jsonb_build_array(place->>'warehouseName',place->>'shelf',place->>'box')::text;
          available := (place->>'quantity')::int;
          IF available IS NULL OR available<0 THEN RAISE EXCEPTION 'Invalid location stock'; END IF;
          take := least(need, CASE WHEN line.delta>0 THEN available ELSE coalesce((held->>key)::int,0) END);
          IF take>0 THEN
            places := jsonb_set(places,ARRAY[i::text,'quantity'],to_jsonb(available-sign(line.delta)::int*take));
            held := jsonb_set(held,ARRAY[key],to_jsonb(coalesce((held->>key)::int,0)+sign(line.delta)::int*take));
            need := need-take;
          END IF;
          EXIT WHEN need=0;
        END LOOP;
        IF need<>0 THEN RAISE EXCEPTION 'Location allocation requires reconciliation'; END IF;
      END IF;
      IF variant_idx IS NOT NULL THEN
        product.variants := jsonb_set(product.variants,ARRAY[variant_idx::text],jsonb_set(v,'{storageLocations}',places));
      ELSE
        product.storage_locations := places;
      END IF;
      UPDATE public.products SET stock_quantity=next_qty,in_stock=next_qty>0,variants=product.variants,
        storage_locations=product.storage_locations,updated_at=now() WHERE id=line.id AND tenant_id=p_tenant;
    END IF;
    IF line.qty>0 THEN allocations := allocations || jsonb_build_array(jsonb_build_object(
      'id',line.id,'color',line.color,'size',line.size,'qty',line.qty,'bins',held)); END IF;
  END LOOP;
  INSERT INTO inventory_private.store_order_stock VALUES (p_order,p_tenant,p_version,allocations)
    ON CONFLICT(order_id) DO UPDATE SET version=excluded.version,lines=excluded.lines;
END $$;
REVOKE ALL ON FUNCTION public.sync_confirmed_order_stock(text,text,timestamptz,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_confirmed_order_stock(text,text,timestamptz,jsonb) TO service_role;
COMMIT;
