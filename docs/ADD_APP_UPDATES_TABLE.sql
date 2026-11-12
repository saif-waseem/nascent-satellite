-- =========================================================================
-- APP UPDATES MANAGEMENT TABLE (Zero-Touch In-App Updates)
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.app_updates (
    id TEXT PRIMARY KEY, -- e.g. 'pos_windows', 'store_admin_android', 'user_app_ios'
    title TEXT NOT NULL,
    version_code INTEGER NOT NULL DEFAULT 1,
    version_name TEXT NOT NULL DEFAULT '1.0.0',
    download_url TEXT NOT NULL,
    release_notes TEXT DEFAULT '',
    is_mandatory BOOLEAN DEFAULT FALSE,
    is_app_disabled BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.app_updates ENABLE ROW LEVEL SECURITY;

-- Everyone can read updates info
CREATE POLICY "Allow public read app_updates" ON public.app_updates
    FOR SELECT USING (true);

-- Super admin can insert or modify
CREATE POLICY "Allow modify app_updates" ON public.app_updates
    FOR ALL TO anon, authenticated
    USING (id IS NOT NULL)
    WITH CHECK (id IS NOT NULL);

-- Seed initial versions
INSERT INTO public.app_updates (id, title, version_code, versionName, download_url, release_notes, is_mandatory)
VALUES 
    ('pos_windows', 'برنامج الكاشير (Windows)', 1, '1.0.0', 'https://example.com/pos_setup.exe', 'النسخة الأولى المستقرة', false),
    ('store_admin_android', 'أدمن المتجر (Android)', 1, '1.0.0', 'https://example.com/store_admin.apk', 'النسخة الأولى', false),
    ('user_app_android', 'تطبيق المتجر (Android)', 1, '1.0.0', 'https://example.com/store.apk', 'النسخة الأولى', false)
ON CONFLICT (id) DO NOTHING;
