BEGIN;
CREATE SCHEMA IF NOT EXISTS buyer_private;
REVOKE ALL ON SCHEMA buyer_private FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS buyer_private.reviewers (
 tenant text NOT NULL REFERENCES public.tenants(id),email text NOT NULL CHECK(email=lower(email)),
 PRIMARY KEY(tenant,email));
CREATE OR REPLACE FUNCTION public.is_buyer_reviewer(p_tenant text,p_email text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT FROM buyer_private.reviewers WHERE tenant=p_tenant AND email=lower(p_email));
$$;
CREATE OR REPLACE FUNCTION public.buyer_worker_authorized(p_key text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(p_key=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='buyer_purge_worker'),false);
$$;
CREATE OR REPLACE FUNCTION public.buyer_service_configuration() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='buyer_firebase_service_account';
$$;
REVOKE ALL ON FUNCTION public.is_buyer_reviewer(text,text),public.buyer_worker_authorized(text),public.buyer_service_configuration() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.is_buyer_reviewer(text,text),public.buyer_worker_authorized(text),public.buyer_service_configuration() TO service_role;
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM vault.secrets WHERE name='buyer_purge_worker') THEN
   PERFORM vault.create_secret(gen_random_uuid()::text||gen_random_uuid()::text,'buyer_purge_worker');
 END IF;
END $$;
CREATE OR REPLACE FUNCTION buyer_private.purge() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE code int;
BEGIN
 IF public.buyer_service_configuration() IS NULL THEN RETURN; END IF;
 PERFORM set_config('http.curlopt_timeout_ms','50000',true);
 SELECT status INTO code FROM extensions.http(('POST','https://axcdhxubqzbzjpbhyvvf.supabase.co/functions/v1/buyer-account',
 ARRAY[extensions.http_header('x-buyer-worker',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='buyer_purge_worker'))],
 'application/json','{"action":"purge"}')::extensions.http_request);
 IF code IS DISTINCT FROM 200 THEN RAISE EXCEPTION 'Account cleanup failed: %',code; END IF;
END $$;
REVOKE ALL ON FUNCTION buyer_private.purge() FROM PUBLIC,anon,authenticated;
SELECT cron.schedule('buyer-account-purge','*/5 * * * *','select buyer_private.purge()');
COMMIT;
