BEGIN;

CREATE TABLE IF NOT EXISTS public.simple_stock_movements (
    tenant_id text NOT NULL,
    operation_id uuid NOT NULL,
    product_id text NOT NULL,
    quantity_delta integer NOT NULL CHECK (quantity_delta <> 0),
    resulting_quantity integer NOT NULL CHECK (resulting_quantity >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, operation_id)
);

ALTER TABLE public.simple_stock_movements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.simple_stock_movements FROM PUBLIC, anon, authenticated;

-- Called by a trusted backend after authorizing the cashier for this tenant.
CREATE OR REPLACE FUNCTION public.apply_simple_stock_movement(
    p_tenant text, p_operation uuid, p_product text, p_delta integer
) RETURNS integer
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
    previous public.simple_stock_movements%ROWTYPE;
    item public.products%ROWTYPE;
    balance integer;
BEGIN
    IF p_operation IS NULL OR p_delta IS NULL OR p_delta = 0 THEN
        RAISE EXCEPTION 'Missing movement ID or quantity';
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant || p_operation::text, 0));
    SELECT * INTO previous FROM public.simple_stock_movements
        WHERE tenant_id = p_tenant AND operation_id = p_operation;
    IF FOUND THEN
        IF previous.product_id IS DISTINCT FROM p_product OR previous.quantity_delta <> p_delta THEN
            RAISE EXCEPTION 'Movement ID reused with different data';
        END IF;
        RETURN previous.resulting_quantity;
    END IF;

    SELECT * INTO STRICT item FROM public.products
        WHERE tenant_id = p_tenant AND id = p_product FOR UPDATE;
    IF jsonb_array_length(coalesce(item.variants, '[]'::jsonb)) > 0
       OR jsonb_array_length(coalesce(item.storage_locations, '[]'::jsonb)) > 0 THEN
        RAISE EXCEPTION 'A location-specific movement is required';
    END IF;
    balance := item.stock_quantity + p_delta;
    IF balance < 0 THEN RAISE EXCEPTION 'Insufficient stock'; END IF;
    UPDATE public.products SET stock_quantity = balance, in_stock = balance > 0, updated_at = now()
        WHERE tenant_id = p_tenant AND id = p_product;
    INSERT INTO public.simple_stock_movements
        (tenant_id, operation_id, product_id, quantity_delta, resulting_quantity)
        VALUES (p_tenant, p_operation, p_product, p_delta, balance);
    RETURN balance;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_simple_stock_movement(text, uuid, text, integer)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_simple_stock_movement(text, uuid, text, integer) TO service_role;
GRANT SELECT, INSERT ON public.simple_stock_movements TO service_role;

COMMIT;
