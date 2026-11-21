BEGIN;
-- The super-admin issuer uses Firestore. Supabase tenant administration is
-- reserved for trusted server jobs. Preserve the existing SELECT policies.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.tenants FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "tenants_insert" ON public.tenants;
DROP POLICY IF EXISTS "tenants_update" ON public.tenants;
DROP POLICY IF EXISTS "tenants_delete" ON public.tenants;
DROP POLICY IF EXISTS "Allow modify tenants" ON public.tenants;
DROP POLICY IF EXISTS "Allow update tenants" ON public.tenants;
DROP POLICY IF EXISTS "Allow delete tenants" ON public.tenants;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tenants TO service_role;
COMMIT;
