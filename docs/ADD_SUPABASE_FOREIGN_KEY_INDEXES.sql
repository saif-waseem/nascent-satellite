-- =========================================================================
-- INDEXING FOREIGN KEYS (Solves all unindexed_foreign_keys INFO notices)
-- Run this once in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/axcdhxubqzbzjpbhyvvf/sql
-- =========================================================================

-- 1. Index on categories(tenant_id)
CREATE INDEX IF NOT EXISTS idx_categories_tenant_id ON public.categories(tenant_id);

-- 2. Index on products(tenant_id)
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON public.products(tenant_id);

-- 3. Index on customers(tenant_id)
CREATE INDEX IF NOT EXISTS idx_customers_tenant_id ON public.customers(tenant_id);

-- 4. Index on sales_invoices(tenant_id)
CREATE INDEX IF NOT EXISTS idx_sales_invoices_tenant_id ON public.sales_invoices(tenant_id);

-- 5. Index on orders(tenant_id)
CREATE INDEX IF NOT EXISTS idx_orders_tenant_id ON public.orders(tenant_id);

-- 6. Index on tenant_subscriptions_log(tenant_id)
CREATE INDEX IF NOT EXISTS idx_tenant_subscriptions_log_tenant_id ON public.tenant_subscriptions_log(tenant_id);
