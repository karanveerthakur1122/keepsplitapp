-- ============================================================
-- Fix RLS Policy Performance (Idempotent - safe to re-run)
--
-- Wraps auth.uid() / current_setting() in (select ...) so
-- PostgreSQL evaluates them once per query instead of per row.
--
-- Consolidates the two permissive SELECT policies on
-- public.notes into a single policy.
--
-- Wrapped in BEGIN/COMMIT so any failure rolls back everything.
-- ============================================================

BEGIN;

-- 1. public.profiles
ALTER POLICY "Users can insert their own profile" ON public.profiles
  WITH CHECK ((select auth.uid()) = user_id);

ALTER POLICY "Users can update their own profile" ON public.profiles
  USING ((select auth.uid()) = user_id);

-- 2. public.notes (consolidate two SELECT policies + fix others)
DROP POLICY IF EXISTS "Users can view accessible notes" ON public.notes;
DROP POLICY IF EXISTS "Users can view notes by share token" ON public.notes;

CREATE POLICY "Users can view accessible notes" ON public.notes
  FOR SELECT TO authenticated
  USING (
    (select auth.uid()) = user_id
    OR public.has_note_access((select auth.uid()), id)
    OR (
      share_token IS NOT NULL
      AND share_token = (select current_setting('request.query.share_token', true))
    )
  );

ALTER POLICY "Users can create their own notes" ON public.notes
  WITH CHECK ((select auth.uid()) = user_id);

ALTER POLICY "Users can delete their own notes" ON public.notes
  USING ((select auth.uid()) = user_id);

ALTER POLICY "Users can update accessible notes" ON public.notes
  USING ((select auth.uid()) = user_id OR public.can_edit_note((select auth.uid()), id));

-- 3. public.note_collaborators
ALTER POLICY "Note owners can view collaborators" ON public.note_collaborators
  USING (public.has_note_access((select auth.uid()), note_id));

ALTER POLICY "Note owners can add collaborators" ON public.note_collaborators
  WITH CHECK (public.is_note_owner((select auth.uid()), note_id));

ALTER POLICY "Note owners can update collaborators" ON public.note_collaborators
  USING (public.is_note_owner((select auth.uid()), note_id));

ALTER POLICY "Note owners can remove collaborators" ON public.note_collaborators
  USING (public.is_note_owner((select auth.uid()), note_id) OR (select auth.uid()) = user_id);

-- 4. public.ai_user_keys
ALTER POLICY "Users manage own keys" ON public.ai_user_keys
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- 5. public.ai_user_models
ALTER POLICY "Users manage own models" ON public.ai_user_models
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- 6. public.ai_usage_logs
ALTER POLICY "Users read own logs" ON public.ai_usage_logs
  USING ((select auth.uid()) = user_id);

ALTER POLICY "System inserts logs" ON public.ai_usage_logs
  WITH CHECK ((select auth.uid()) = user_id);

-- 7. public.expenses
ALTER POLICY "Users with note access can view expenses" ON public.expenses
  USING (has_note_access((select auth.uid()), note_id));

ALTER POLICY "Users who can edit note can insert expenses" ON public.expenses
  WITH CHECK (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

ALTER POLICY "Users who can edit note can update expenses" ON public.expenses
  USING (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

ALTER POLICY "Users who can edit note can delete expenses" ON public.expenses
  USING (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

-- 8. public.expense_items
ALTER POLICY "Users with note access can view expense items" ON public.expense_items
  USING (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND has_note_access((select auth.uid()), e.note_id)
  ));

ALTER POLICY "Users who can edit can insert expense items" ON public.expense_items
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note((select auth.uid()), e.note_id) OR is_note_owner((select auth.uid()), e.note_id))
  ));

ALTER POLICY "Users who can edit can update expense items" ON public.expense_items
  USING (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note((select auth.uid()), e.note_id) OR is_note_owner((select auth.uid()), e.note_id))
  ));

ALTER POLICY "Users who can edit can delete expense items" ON public.expense_items
  USING (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note((select auth.uid()), e.note_id) OR is_note_owner((select auth.uid()), e.note_id))
  ));

-- 9. public.expense_item_participants
ALTER POLICY "Users with note access can view item participants" ON public.expense_item_participants
  USING (EXISTS (
    SELECT 1 FROM public.expense_items ei
    JOIN public.expenses e ON e.id = ei.expense_id
    WHERE ei.id = item_id AND has_note_access((select auth.uid()), e.note_id)
  ));

ALTER POLICY "Users who can edit can insert item participants" ON public.expense_item_participants
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.expense_items ei
    JOIN public.expenses e ON e.id = ei.expense_id
    WHERE ei.id = item_id AND (can_edit_note((select auth.uid()), e.note_id) OR is_note_owner((select auth.uid()), e.note_id))
  ));

ALTER POLICY "Users who can edit can delete item participants" ON public.expense_item_participants
  USING (EXISTS (
    SELECT 1 FROM public.expense_items ei
    JOIN public.expenses e ON e.id = ei.expense_id
    WHERE ei.id = item_id AND (can_edit_note((select auth.uid()), e.note_id) OR is_note_owner((select auth.uid()), e.note_id))
  ));

-- 10. public.expense_audits
ALTER POLICY "Users with note access can view expense audits" ON public.expense_audits
  USING (has_note_access((select auth.uid()), note_id));

-- 11. public.note_expense_settings
ALTER POLICY "Users with note access can view expense settings" ON public.note_expense_settings
  USING (has_note_access((select auth.uid()), note_id));

ALTER POLICY "Users who can edit can upsert expense settings" ON public.note_expense_settings
  WITH CHECK (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

ALTER POLICY "Users who can edit can update expense settings" ON public.note_expense_settings
  USING (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

-- 12. public.note_manual_users
ALTER POLICY "Users with note access can view manual users" ON public.note_manual_users
  USING (has_note_access((select auth.uid()), note_id));

ALTER POLICY "Users who can edit can add manual users" ON public.note_manual_users
  WITH CHECK (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

ALTER POLICY "Users who can edit can update manual users" ON public.note_manual_users
  USING (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

ALTER POLICY "Users who can edit can delete manual users" ON public.note_manual_users
  USING (can_edit_note((select auth.uid()), note_id) OR is_note_owner((select auth.uid()), note_id));

-- ============================================================
-- Verify: the old split policy must be gone, the consolidated
-- one must exist.  If not, raise and roll back.
-- ============================================================
DO $$ BEGIN
  -- Old split policy should no longer exist
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'notes'
      AND policyname = 'Users can view notes by share token'
  ) THEN
    RAISE EXCEPTION '007 verification failed: old split policy "Users can view notes by share token" still exists';
  END IF;

  -- Consolidated policy must exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'notes'
      AND policyname = 'Users can view accessible notes'
  ) THEN
    RAISE EXCEPTION '007 verification failed: consolidated policy "Users can view accessible notes" not found';
  END IF;
END $$;

COMMIT;
