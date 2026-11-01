-- Template: new table migration
-- Supabase removes legacy auto-grants on Oct 30, 2026. New tables in public
-- without explicit GRANTs are invisible to the Data API (PostgREST 42501).
-- Copy this file when adding a CREATE TABLE migration.

CREATE TABLE public.your_table (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id      uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  -- ... your columns ...
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Grants (required after Oct 30, 2026)
-- No `anon` grant on purpose: app requests run as `authenticated` (custom JWT).
-- Add `GRANT SELECT ... TO anon;` only if table needs public read.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.your_table TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.your_table TO service_role;

-- If table uses a sequence (serial / bigserial), also:
-- GRANT USAGE, SELECT ON SEQUENCE public.your_table_id_seq TO authenticated, service_role;

-- RLS
ALTER TABLE public.your_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_isolation"
  ON public.your_table FOR ALL
  TO authenticated
  USING (team_id = public.current_team_id())
  WITH CHECK (team_id = public.current_team_id());

-- Indexes
CREATE INDEX idx_your_table_team_id ON public.your_table(team_id);
