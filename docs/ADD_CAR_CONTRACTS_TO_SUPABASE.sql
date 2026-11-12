-- =========================================================================
-- جدول عقود السيارات (Car Contracts) في Supabase SQL
-- متوافق بالكامل مع نظام الـ Tiers والقواعد الجديدة
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.car_contracts (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    seller_name TEXT NOT NULL,
    seller_id TEXT,
    seller_address TEXT,
    seller_phone TEXT,
    seller_mukhtar TEXT,
    seller_photo_url TEXT,
    buyer_name TEXT NOT NULL,
    buyer_id TEXT,
    buyer_address TEXT,
    buyer_phone TEXT,
    buyer_mukhtar TEXT,
    buyer_photo_url TEXT,
    car_type TEXT DEFAULT 'خصوصي',
    car_model_name TEXT NOT NULL,
    car_year TEXT,
    car_plate TEXT,
    car_color TEXT,
    car_annual_id TEXT,
    car_chassis TEXT,
    price_total NUMERIC DEFAULT 0.0,
    price_paid NUMERIC DEFAULT 0.0,
    price_remaining NUMERIC DEFAULT 0.0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- فهرس المستأجر لسرعة الاستعلام
CREATE INDEX IF NOT EXISTS idx_car_contracts_tenant_id ON public.car_contracts(tenant_id);

-- تفعيل أمان مستوى الصفوف (Row Level Security - RLS)
ALTER TABLE public.car_contracts ENABLE ROW LEVEL SECURITY;

-- سياسات الوصول (Zero Overlaps)
CREATE POLICY "car_contracts_select" ON public.car_contracts 
    FOR SELECT USING (true);

CREATE POLICY "car_contracts_insert" ON public.car_contracts 
    FOR INSERT TO anon, authenticated 
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

CREATE POLICY "car_contracts_update" ON public.car_contracts 
    FOR UPDATE TO anon, authenticated 
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0) 
    WITH CHECK (tenant_id IS NOT NULL AND length(tenant_id) > 0);

CREATE POLICY "car_contracts_delete" ON public.car_contracts 
    FOR DELETE TO anon, authenticated 
    USING (tenant_id IS NOT NULL AND length(tenant_id) > 0);

-- إضافة حقول عقود السيارات إلى جدول tenants في حال لم تكن موجودة
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tenants' AND column_name = 'is_cars_enabled') THEN
        ALTER TABLE public.tenants ADD COLUMN is_cars_enabled BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tenants' AND column_name = 'cars_expiry_date') THEN
        ALTER TABLE public.tenants ADD COLUMN cars_expiry_date TIMESTAMP WITH TIME ZONE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tenants' AND column_name = 'cars_activation_code') THEN
        ALTER TABLE public.tenants ADD COLUMN cars_activation_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tenants' AND column_name = 'cars_tier') THEN
        ALTER TABLE public.tenants ADD COLUMN cars_tier TEXT DEFAULT 'A';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tenants' AND column_name = 'cars_excel_enabled') THEN
        ALTER TABLE public.tenants ADD COLUMN cars_excel_enabled BOOLEAN DEFAULT TRUE;
    END IF;
END $$;
