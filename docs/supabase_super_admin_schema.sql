-- =========================================================================
-- Supabase Schema: Super Admin Multi-Tenant & POS Tiers Management
-- =========================================================================

-- 1. Create or Update Tenants Table
CREATE TABLE IF NOT EXISTS public.tenants (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    admin_ids TEXT[] DEFAULT '{}',
    logo_url TEXT,
    description TEXT DEFAULT '',
    whatsapp_number TEXT DEFAULT '',
    primary_color TEXT DEFAULT '#000000',
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expiry_date TIMESTAMP WITH TIME ZONE,
    activation_code TEXT,
    subscriber_count INTEGER DEFAULT 0,
    manager_name TEXT,
    manager_phone TEXT,
    
    -- Subscribed Apps
    is_store_enabled BOOLEAN DEFAULT FALSE,
    is_pos_enabled BOOLEAN DEFAULT FALSE,
    pos_expiry_date TIMESTAMP WITH TIME ZONE,
    pos_activation_code TEXT,
    is_cars_enabled BOOLEAN DEFAULT FALSE,
    cars_expiry_date TIMESTAMP WITH TIME ZONE,
    cars_activation_code TEXT,
    
    -- POS Tiers & Limits (A = Free/Offline, B = LAN, C = Cloud Backup, D = Enterprise)
    pos_tier TEXT DEFAULT 'A' CHECK (pos_tier IN ('A', 'B', 'C', 'D')),
    pos_device_limit INTEGER DEFAULT 1,
    
    -- Free Trial & Grace Period
    is_trial_active BOOLEAN DEFAULT FALSE,
    trial_start_date TIMESTAMP WITH TIME ZONE,
    trial_end_date TIMESTAMP WITH TIME ZONE,
    pos_grace_days INTEGER DEFAULT 14,
    
    -- Modular Feature Flags
    pos_lan_sync_enabled BOOLEAN DEFAULT FALSE,
    pos_cloud_backup_enabled BOOLEAN DEFAULT FALSE,
    pos_remote_dash_enabled BOOLEAN DEFAULT FALSE,
    pos_excel_enabled BOOLEAN DEFAULT FALSE,
    pos_multi_branch_enabled BOOLEAN DEFAULT FALSE,
    pos_video_gen_enabled BOOLEAN DEFAULT FALSE,
    pos_daily_video_quota INTEGER DEFAULT 0,
    
    -- Financial Settings
    currency_unit TEXT DEFAULT 'IQD',
    shipping_cost NUMERIC(12, 2) DEFAULT 5000.00
);

-- Index for speedy lookups
CREATE INDEX IF NOT EXISTS idx_tenants_active ON public.tenants(is_active);
CREATE INDEX IF NOT EXISTS idx_tenants_pos_tier ON public.tenants(pos_tier);

-- 2. Subscriptions & Tier History Log
CREATE TABLE IF NOT EXISTS public.tenant_subscriptions_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    app_type TEXT NOT NULL, -- 'pos', 'store', 'cars'
    action_type TEXT NOT NULL, -- 'activate', 'renew', 'tier_upgrade', 'trial_grant'
    tier TEXT,
    months INTEGER,
    days INTEGER,
    activation_code TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. AI Video Generation Quota Table
CREATE TABLE IF NOT EXISTS public.tenant_video_quotas (
    tenant_id TEXT PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
    quota_limit INTEGER DEFAULT 0,
    used_today INTEGER DEFAULT 0,
    last_reset_date DATE DEFAULT CURRENT_DATE
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_subscriptions_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_video_quotas ENABLE ROW LEVEL SECURITY;

-- Allow Super Admin service role full access
CREATE POLICY "Super Admin Service Full Access" ON public.tenants
    FOR ALL USING (true) WITH CHECK (true);
    
CREATE POLICY "Super Admin Subscriptions Log Access" ON public.tenant_subscriptions_log
    FOR ALL USING (true) WITH CHECK (true);
    
CREATE POLICY "Super Admin Video Quotas Access" ON public.tenant_video_quotas
    FOR ALL USING (true) WITH CHECK (true);
