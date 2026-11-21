BEGIN;
CREATE SCHEMA IF NOT EXISTS cashier_private;
REVOKE ALL ON SCHEMA cashier_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS cashier_private.stock_device (
  token_hash bytea PRIMARY KEY,
  tenant_id text NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON cashier_private.stock_device FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION cashier_private.issue_stock_key(p_tenant text)
RETURNS text LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE secret text := replace(gen_random_uuid()::text || gen_random_uuid()::text,'-','');
BEGIN
  INSERT INTO cashier_private.stock_device(token_hash, tenant_id)
  VALUES (sha256(convert_to(secret,'UTF8')), p_tenant);
  RETURN secret;
END;
$$;
REVOKE ALL ON FUNCTION cashier_private.issue_stock_key(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_cashier_stock(
  p_tenant text, p_device_key text, p_movements jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE movement jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cashier_private.stock_device d
    JOIN public.tenants t ON t.id = d.tenant_id
    WHERE d.tenant_id = p_tenant AND t.is_active AND t.is_pos_enabled
      AND d.token_hash = sha256(convert_to(p_device_key,'UTF8'))
  ) THEN RAISE EXCEPTION 'Device not authorized' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_movements) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Expected an array of stock movements';
  END IF;
  FOR movement IN SELECT value FROM jsonb_array_elements(p_movements)
                  ORDER BY value->>'product', value->>'operation' LOOP
    PERFORM public.apply_simple_stock_movement(p_tenant, (movement->>'operation')::uuid,
      movement->>'product', (movement->>'delta')::integer);
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.submit_cashier_stock(text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_cashier_stock(text,text,jsonb) TO anon, authenticated;
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_publication WHERE pubname = 'supabase_realtime' AND NOT puballtables)
    AND NOT EXISTS (SELECT FROM pg_catalog.pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'products')
  THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
  END IF;
END;
$$;
COMMIT;