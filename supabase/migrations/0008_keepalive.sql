-- Keepalive project Free Supabase: pause setelah 7 hari tanpa aktivitas.
-- Job harian menyentuh DB (pg_cron) dan mengirim satu request HTTP ke endpoint
-- project (pg_net) supaya jam pause terus bergeser selama masa demo.
-- Request tanpa apikey menjawab 401 — itu tidak masalah, tujuannya traffic.
-- Job berhenti sendiri tanggal 21 Des 2026, sehari setelah masa demo berakhir.

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'sibal-keepalive',
  '0 3 * * *',
  $$select net.http_get('https://mlqbmhbklbopagfqkdiy.supabase.co/rest/v1/labs?select=id&limit=1')$$
);

select cron.schedule(
  'sibal-keepalive-stop',
  '0 0 21 12 *',
  $$select cron.unschedule('sibal-keepalive'); select cron.unschedule('sibal-keepalive-stop');$$
);
