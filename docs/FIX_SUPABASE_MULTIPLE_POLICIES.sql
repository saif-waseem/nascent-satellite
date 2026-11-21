-- =========================================================================
-- SUPABASE OPTIMAL PERFORMANCE FIX: Zero Overlapping Policies
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/axcdhxubqzbzjpbhyvvf/sql
-- =========================================================================

-- 1. Remove overlapping policies
DROP POLICY IF EXISTS "Allow modify tenants" ON public.tenants;
DROP POLICY IF EXISTS "Allow modify categories" ON public.categories;
DROP POLICY IF EXISTS "Allow modify products" ON public.products;

-- 2. Re-create write policies restricted strictly to INSERT, UPDATE, DELETE (Excluding SELECT)

-- Tenant writes are reserved for server-side administration.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.tenants FROM PUBLIC, anon, authenticated;

-- Categories:
CREATE POLICY "Allow modify categories" ON public.categories
    FOR INSERT TO anon, authenticated
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

CREATE POLICY "Allow update categories" ON public.categories
    FOR UPDATE TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

CREATE POLICY "Allow delete categories" ON public.categories
    FOR DELETE TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- Products:
CREATE POLICY "Allow modify products" ON public.products
    FOR INSERT TO anon, authenticated
    WITH CHECK (tenant_id IS NOT NULL AND length(name) > 0);

CREATE POLICY "Allow update products" ON public.products
    FOR UPDATE TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(name) > 0)
    WITH CHECK (tenant_id IS NOT NULL AND length(name) > 0);

CREATE POLICY "Allow delete products" ON public.products
    FOR DELETE TO anon, authenticated
    USING (tenant_id IS NOT NULL AND length(name) > 0);
