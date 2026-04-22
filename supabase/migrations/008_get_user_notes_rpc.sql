-- ============================================================
-- Consolidate the 2-3 sequential queries in getNotes() into a
-- single RPC.  Returns owned notes UNION collaborated notes,
-- ordered by updated_at DESC, with no duplicates.
--
-- Idempotent: CREATE OR REPLACE.
-- Wrapped in BEGIN/COMMIT for safety.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_user_notes()
RETURNS SETOF public.notes
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT n.*
  FROM public.notes n
  WHERE n.user_id = (select auth.uid())

  UNION

  SELECT n.*
  FROM public.notes n
  INNER JOIN public.note_collaborators nc ON nc.note_id = n.id
  WHERE nc.user_id = (select auth.uid())

  ORDER BY updated_at DESC
$$;

-- Verify the function was created
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'get_user_notes'
  ) THEN
    RAISE EXCEPTION '008 verification failed: get_user_notes function not found';
  END IF;
END $$;

COMMIT;
