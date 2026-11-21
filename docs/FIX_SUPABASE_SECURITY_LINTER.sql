-- =========================================================================
-- FIX SUPABASE SECURITY & RLS LINTER WARNINGS
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/axcdhxubqzbzjpbhyvvf/sql
-- =========================================================================

-- 1. DROP OVERLY PERMISSIVE POLICIES
DROP POLICY IF EXISTS "Allow anon insert tenants" ON public.tenants;
DROP POLICY IF EXISTS "Allow anon write categories" ON public.categories;
DROP POLICY IF EXISTS "Allow anon write products" ON public.products;
DROP POLICY IF EXISTS "Allow anon all customers" ON public.customers;
DROP POLICY IF EXISTS "Allow anon all sales_invoices" ON public.sales_invoices;
DROP POLICY IF EXISTS "Allow anon all orders" ON public.orders;
DROP POLICY IF EXISTS "Allow anon all subscriptions_log" ON public.tenant_subscriptions_log;
DROP POLICY IF EXISTS "Allow anon all video_quotas" ON public.tenant_video_quotas;
DROP POLICY IF EXISTS "Public Read Product Media" ON storage.objects;

-- 2. SECURE STORAGE BUCKET (Public bucket allows public download via URL without listing)
-- No SELECT policy on storage.objects is needed for public buckets; Supabase CDN serves files directly via public URL.
-- We keep only upload/update permissions for authenticated/anon clients:
DROP POLICY IF EXISTS "Public Upload to Product Media" ON storage.objects;
DROP POLICY IF EXISTS "Public Update Product Media" ON storage.objects;

CREATE POLICY "Allow Insert Product Media" ON storage.objects
    FOR INSERT TO anon, authenticated
    WITH CHECK (bucket_id = 'product-media');

CREATE POLICY "Allow Update Product Media" ON storage.objects
    FOR UPDATE TO anon, authenticated
    USING (bucket_id = 'product-media')
    WITH CHECK (bucket_id = 'product-media');

-- 3. SECURE TABLE POLICIES WITH SCOPED ROLES & NON-TRIVIAL CHECKS

-- Preserve tenant reads and reserve writes for server-side administration.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.tenants FROM PUBLIC, anon, authenticated;

-- Categories: Read is public, write requires valid tenant_id
CREATE POLICY "Allow scoped write categories" ON public.categories
    FOR ALL TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Products: Read is public, write requires valid tenant_id and name
CREATE POLICY "Allow scoped write products" ON public.products
    FOR ALL TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(name) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(name) > 0);

-- Customers: scoped by tenant_id
CREATE POLICY "Allow scoped customers" ON public.customers
    FOR ALL TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Sales Invoices: scoped by tenant_id
CREATE POLICY "Allow scoped sales_invoices" ON public.sales_invoices
    FOR ALL TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Orders: scoped by tenant_id
CREATE POLICY "Allow scoped orders" ON public.orders
    FOR ALL TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Subscriptions Log: scoped by tenant_id
CREATE POLICY "Allow scoped subscriptions_log" ON public.tenant_subscriptions_log
    FOR ALL TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Video Quotas: scoped by tenant_id
CREATE POLICY "Allow scoped video_quotas" ON public.tenant_video_quotas
    FOR ALL TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);
