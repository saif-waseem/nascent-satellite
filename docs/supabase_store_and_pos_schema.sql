-- =========================================================================
-- Supabase SQL Schema: Store Admin & POS Core Tables (Relational & Fast)
-- =========================================================================

-- 1. Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon_code TEXT,
    image_url TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_categories_tenant ON public.categories(tenant_id);

-- 2. Products Table (Primary catalog for Store & Cashier POS)
CREATE TABLE IF NOT EXISTS public.products (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT DEFAULT 'عام',
    description TEXT DEFAULT '',
    price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
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
    variants JSONB DEFAULT '[]',
    storage_locations JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_products_tenant ON public.products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON public.products(tenant_id, barcode);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(tenant_id, category);

-- 3. Customers Table
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
CREATE INDEX IF NOT EXISTS idx_customers_tenant ON public.customers(tenant_id);

-- 4. Sales Invoices (Synchronized with Cashier POS)
CREATE TABLE IF NOT EXISTS public.sales_invoices (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_number TEXT NOT NULL,
    cashier_id TEXT,
    cashier_name TEXT,
    customer_id TEXT REFERENCES public.customers(id) ON DELETE SET NULL,
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
CREATE INDEX IF NOT EXISTS idx_sales_invoices_tenant ON public.sales_invoices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_date ON public.sales_invoices(tenant_id, created_at DESC);

-- 5. Online Store Orders Table
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
CREATE INDEX IF NOT EXISTS idx_orders_tenant ON public.orders(tenant_id);

-- 6. Storage Bucket for Products Media (Images & Videos)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('product-media', 'product-media', true)
ON CONFLICT (id) DO NOTHING;

-- Policies for public reading and authenticated write
CREATE POLICY "Public Read Product Media" ON storage.objects
    FOR SELECT USING (bucket_id = 'product-media');

CREATE POLICY "Allow Upload to Product Media" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'product-media');
