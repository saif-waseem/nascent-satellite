-- Contains no order, tenant or customer data.
CREATE OR REPLACE FUNCTION public.order_stock_sync_healthy()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT coalesce((SELECT r.status='succeeded' AND r.end_time>now()-interval '20 minutes'
    FROM cron.job_run_details r JOIN cron.job j USING(jobid)
    WHERE j.jobname='confirmed-order-stock' AND r.end_time IS NOT NULL
    ORDER BY r.runid DESC LIMIT 1),false)
$$;
REVOKE ALL ON FUNCTION public.order_stock_sync_healthy() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.order_stock_sync_healthy() TO anon,authenticated,service_role;
