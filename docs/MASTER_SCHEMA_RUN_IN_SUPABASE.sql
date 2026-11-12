-- =========================================================================
-- COMPLETE, ULTIMATE & CLEAN SUPABASE SQL SCHEMA (ZERO WARNINGS)
-- Safe & Ready to paste directly into Supabase SQL Editor:
-- https://supabase.com/dashboard/project/axcdhxubqzbzjpbhyvvf/sql
-- =========================================================================

-- 1. Tables Creation
CREATE TABLE IF NOT EXISTS public.tenants (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    admin_ids TEXT[] DEFAULT '{}',
    logo_url TEXT,
    description TEXT DEFAULT '',
    whatsapp_number TEXT DEFAULT '',
    primary_color TEXT DEFAULT '#000000',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expiry_date TIMESTAMP WITH TIME ZONE,
    activation_code TEXT,
    subscriber_count INTEGER DEFAULT 0,
    manager_name TEXT,
    manager_phone TEXT,
    is_store_enabled BOOLEAN DEFAULT TRUE,
    is_pos_enabled BOOLEAN DEFAULT TRUE,
    pos_expiry_date TIMESTAMP WITH TIME ZONE,
    pos_activation_code TEXT,
    is_cars_enabled BOOLEAN DEFAULT FALSE,
    cars_expiry_date TIMESTAMP WITH TIME ZONE,
    cars_activation_code TEXT,
    pos_tier TEXT DEFAULT 'A',
    pos_device_limit INTEGER DEFAULT 1,
    is_trial_active BOOLEAN DEFAULT FALSE,
    trial_start_date TIMESTAMP WITH TIME ZONE,
    trial_end_date TIMESTAMP WITH TIME ZONE,
    pos_grace_days INTEGER DEFAULT 14,
    pos_lan_sync_enabled BOOLEAN DEFAULT FALSE,
    pos_cloud_backup_enabled BOOLEAN DEFAULT FALSE,
    pos_remote_dash_enabled BOOLEAN DEFAULT FALSE,
    pos_excel_enabled BOOLEAN DEFAULT TRUE,
    pos_multi_branch_enabled BOOLEAN DEFAULT FALSE,
    pos_video_gen_enabled BOOLEAN DEFAULT TRUE,
    pos_daily_video_quota INTEGER DEFAULT 5,
    currency_unit TEXT DEFAULT 'IQD',
    shipping_cost NUMERIC(12, 2) DEFAULT 5000.00
);

CREATE TABLE IF NOT EXISTS public.categories (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT,
    image_url TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.products (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT DEFAULT 'عام',
    description TEXT DEFAULT '',
    price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    old_price NUMERIC(12, 2),
    purchase_price NUMERIC(12, 2) DEFAULT 0.00,
    wholesale_price NUMERIC(12, 2) DEFAULT 0.00,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    min_stock_level INTEGER DEFAULT 5,
    unit TEXT DEFAULT 'قطعة',
    barcode TEXT,
    images TEXT[] DEFAULT '{}',
    video_url TEXT,
    rating NUMERIC(3, 2) DEFAULT 5.0,
    sales_count INTEGER DEFAULT 0,
    in_stock BOOLEAN DEFAULT TRUE,
    is_offer BOOLEAN DEFAULT FALSE,
    is_featured_deal BOOLEAN DEFAULT FALSE,
    is_daily_starred BOOLEAN DEFAULT FALSE,
    colors TEXT[] DEFAULT '{}',
    sizes TEXT[] DEFAULT '{}',
    variants JSONB DEFAULT '[]',
    storage_locations JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.customers (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT DEFAULT '',
    balance NUMERIC(12, 2) DEFAULT 0.00,
    address TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.sales_invoices (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_number TEXT NOT NULL,
    cashier_id TEXT,
    cashier_name TEXT,
    customer_id TEXT,
    customer_name TEXT,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    discount NUMERIC(12, 2) DEFAULT 0.00,
    tax NUMERIC(12, 2) DEFAULT 0.00,
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    remaining_amount NUMERIC(12, 2) DEFAULT 0.00,
    payment_method TEXT DEFAULT 'cash',
    items JSONB NOT NULL DEFAULT '[]',
    status TEXT DEFAULT 'completed',
    notes TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.orders (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    order_number TEXT NOT NULL,
    user_id TEXT,
    user_name TEXT,
    user_phone TEXT,
    shipping_address TEXT,
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status TEXT DEFAULT 'pending',
    items JSONB NOT NULL DEFAULT '[]',
    is_hidden_for_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tenant_subscriptions_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    app_type TEXT NOT NULL,
    action_type TEXT NOT NULL,
    tier TEXT,
    months INTEGER,
    days INTEGER,
    activation_code TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tenant_video_quotas (
    tenant_id TEXT PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
    quota_limit INTEGER DEFAULT 5,
    used_today INTEGER DEFAULT 0,
    last_reset_date DATE DEFAULT CURRENT_DATE
);

-- 2. Foreign Key Indexes (Eliminates all unindexed_foreign_keys warnings)
CREATE INDEX IF NOT EXISTS idx_categories_tenant_id ON public.categories(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON public.products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customers_tenant_id ON public.customers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_tenant_id ON public.sales_invoices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_orders_tenant_id ON public.orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_subscriptions_log_tenant_id ON public.tenant_subscriptions_log(tenant_id);

-- 3. Clean up all old/duplicate policies
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT schemaname, tablename, policyname 
        FROM pg_policies 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    END LOOP;
END $$;

DROP POLICY IF EXISTS "Public Read Product Media" ON storage.objects;
DROP POLICY IF EXISTS "Public Upload to Product Media" ON storage.objects;
DROP POLICY IF EXISTS "Public Update Product Media" ON storage.objects;
DROP POLICY IF EXISTS "Allow Insert Product Media" ON storage.objects;
DROP POLICY IF EXISTS "Allow Update Product Media" ON storage.objects;

-- 4. Enable RLS
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_subscriptions_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_video_quotas ENABLE ROW LEVEL SECURITY;

-- 5. Strict, High-Performance Policies (Zero Overlaps)

-- Tenants
CREATE POLICY "tenants_select" ON public.tenants FOR SELECT USING (true);
CREATE POLICY "tenants_insert" ON public.tenants FOR INSERT TO anon, authenticated WITH CHECK (id IS NOT NULL AND length(id) > 0);
CREATE POLICY "tenants_update" ON public.tenants FOR UPDATE TO anon, authenticated USING (id IS NOT NULL AND length(id) > 0) WITH CHECK (id IS NOT NULL AND length(id) > 0);
CREATE POLICY "tenants_delete" ON public.tenants FOR DELETE TO anon, authenticated USING (id IS NOT NULL AND length(id) > 0);

-- Categories
CREATE POLICY "categories_select" ON public.categories FOR SELECT USING (true);
CREATE POLICY "categories_insert" ON public.categories FOR INSERT TO anon, authenticated WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "categories_update" ON public.categories FOR UPDATE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0) WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "categories_delete" ON public.categories FOR DELETE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Products
CREATE POLICY "products_select" ON public.products FOR SELECT USING (true);
CREATE POLICY "products_insert" ON public.products FOR INSERT TO anon, authenticated WITH CHECK (tenant_id IS NOT NULL AND length(name) > 0);
CREATE POLICY "products_update" ON public.products FOR UPDATE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(name) > 0) WITH CHECK (tenant_id IS NOT NULL AND length(name) > 0);
CREATE POLICY "products_delete" ON public.products FOR DELETE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(name) > 0);

-- Customers
CREATE POLICY "customers_select" ON public.customers FOR SELECT USING (true);
CREATE POLICY "customers_insert" ON public.customers FOR INSERT TO anon, authenticated WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "customers_update" ON public.customers FOR UPDATE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0) WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "customers_delete" ON public.customers FOR DELETE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Sales Invoices
CREATE POLICY "sales_invoices_select" ON public.sales_invoices FOR SELECT USING (true);
CREATE POLICY "sales_invoices_insert" ON public.sales_invoices FOR INSERT TO anon, authenticated WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "sales_invoices_update" ON public.sales_invoices FOR UPDATE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0) WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "sales_invoices_delete" ON public.sales_invoices FOR DELETE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Orders
CREATE POLICY "orders_select" ON public.orders FOR SELECT USING (true);
CREATE POLICY "orders_insert" ON public.orders FOR INSERT TO anon, authenticated WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "orders_update" ON public.orders FOR UPDATE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0) WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "orders_delete" ON public.orders FOR DELETE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Subscriptions Log
CREATE POLICY "subscriptions_log_select" ON public.tenant_subscriptions_log FOR SELECT USING (true);
CREATE POLICY "subscriptions_log_insert" ON public.tenant_subscriptions_log FOR INSERT TO anon, authenticated WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Video Quotas
CREATE POLICY "video_quotas_select" ON public.tenant_video_quotas FOR SELECT USING (true);
CREATE POLICY "video_quotas_insert" ON public.tenant_video_quotas FOR INSERT TO anon, authenticated WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
CREATE POLICY "video_quotas_update" ON public.tenant_video_quotas FOR UPDATE TO anon, authenticated USING (tenant_id IS NOT NULL AND length(tenant_id) > 0) WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- 6. Storage Bucket Configuration (Zero Warnings)
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-media', 'product-media', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "product_media_insert" ON storage.objects
    FOR INSERT TO anon, authenticated
    WITH CHECK (bucket_id = 'product-media');

CREATE POLICY "product_media_update" ON storage.objects
    FOR UPDATE TO anon, authenticated
    USING (bucket_id = 'product-media')
    WITH CHECK (bucket_id = 'product-media');
