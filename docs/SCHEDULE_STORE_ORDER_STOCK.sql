BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS supabase_vault CASCADE;
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM vault.secrets WHERE name='order_stock_worker') THEN
    PERFORM vault.create_secret(gen_random_uuid()::text || gen_random_uuid()::text,'order_stock_worker');
  END IF;
END $$;

-- Secrets are accessible only to the server-side worker. The scheduled command
-- contains a secret name, never a token. A dedicated Firebase sync session is
-- reused and its refresh token is encrypted in Vault.
CREATE OR REPLACE FUNCTION public.order_stock_worker_session(worker text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF worker IS NULL OR worker IS DISTINCT FROM (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='order_stock_worker') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN coalesce((SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='order_stock_firebase_session'),'');
END $$;
CREATE OR REPLACE FUNCTION public.save_order_stock_session(worker text, refresh_token text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE secret_id uuid;
BEGIN
  PERFORM public.order_stock_worker_session(worker);
  IF nullif(refresh_token,'') IS NULL THEN RAISE EXCEPTION 'Empty session'; END IF;
  SELECT id INTO secret_id FROM vault.secrets WHERE name='order_stock_firebase_session';
  IF secret_id IS NULL THEN
    PERFORM vault.create_secret(refresh_token,'order_stock_firebase_session');
  ELSE
    PERFORM vault.update_secret(secret_id,refresh_token);
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.order_stock_worker_session(text), public.save_order_stock_session(text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.order_stock_worker_session(text), public.save_order_stock_session(text,text) TO service_role;
SELECT cron.schedule('confirmed-order-stock', '*/5 * * * *', $job$
  SELECT net.http_post(
    url:='https://axcdhxubqzbzjpbhyvvf.supabase.co/functions/v1/confirm-order-stock',
    headers:=jsonb_build_object('Content-Type','application/json','x-stock-worker',
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='order_stock_worker')),
    body:='{"sweep":true}'::jsonb, timeout_milliseconds:=55000)
$job$);
COMMIT;
