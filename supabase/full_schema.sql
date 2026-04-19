-- ============================================================
-- KeepBillNotes - Full Database Schema (Idempotent)
-- Safe to run multiple times - uses IF NOT EXISTS / OR REPLACE /
-- DROP IF EXISTS / ON CONFLICT DO NOTHING everywhere.
-- Run this in Supabase SQL Editor (https://supabase.com/dashboard)
-- Go to: SQL Editor > New Query > Paste this > Click "Run"
-- ============================================================

-- ============================================================
-- MIGRATION 1: Core tables (profiles, notes, triggers)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Profiles are viewable by authenticated users') THEN
    CREATE POLICY "Profiles are viewable by authenticated users" ON public.profiles FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can insert their own profile') THEN
    CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can update their own profile') THEN
    CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.notes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  color TEXT NOT NULL DEFAULT 'default',
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  is_checklist BOOLEAN NOT NULL DEFAULT false,
  labels TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notes' AND policyname = 'Users can view their own notes') THEN
    CREATE POLICY "Users can view their own notes" ON public.notes FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notes' AND policyname = 'Users can create their own notes') THEN
    CREATE POLICY "Users can create their own notes" ON public.notes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notes' AND policyname = 'Users can update their own notes') THEN
    CREATE POLICY "Users can update their own notes" ON public.notes FOR UPDATE TO authenticated USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notes' AND policyname = 'Users can delete their own notes') THEN
    CREATE POLICY "Users can delete their own notes" ON public.notes FOR DELETE TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS update_notes_updated_at ON public.notes;
CREATE TRIGGER update_notes_updated_at BEFORE UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name, email, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'display_name',
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      split_part(NEW.email, '@', 1)
    ),
    LOWER(NEW.email),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Backfill: ensure all existing profiles have a lowercase email from auth.users.
-- Safe to re-run.
UPDATE public.profiles p
SET email = LOWER(u.email)
FROM auth.users u
WHERE p.user_id = u.id
  AND (p.email IS NULL OR p.email IS DISTINCT FROM LOWER(u.email));

-- Index for fast case-insensitive email lookup (idempotent).
CREATE INDEX IF NOT EXISTS idx_profiles_email_lower
  ON public.profiles ((LOWER(email)));

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- MIGRATION 2: Collaboration (collaborators, permissions, share tokens)
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_permission') THEN
    CREATE TYPE public.note_permission AS ENUM ('owner', 'editor', 'viewer');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.note_collaborators (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  note_id UUID NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  permission note_permission NOT NULL DEFAULT 'viewer',
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  invited_email TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(note_id, user_id)
);

ALTER TABLE public.note_collaborators ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notes' AND column_name = 'share_token') THEN
    ALTER TABLE public.notes ADD COLUMN share_token TEXT UNIQUE;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.has_note_access(_user_id UUID, _note_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.notes WHERE id = _note_id AND user_id = _user_id
  ) OR EXISTS (
    SELECT 1 FROM public.note_collaborators WHERE note_id = _note_id AND user_id = _user_id
  )
$$;

CREATE OR REPLACE FUNCTION public.can_edit_note(_user_id UUID, _note_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.notes WHERE id = _note_id AND user_id = _user_id
  ) OR EXISTS (
    SELECT 1 FROM public.note_collaborators WHERE note_id = _note_id AND user_id = _user_id AND permission = 'editor'
  )
$$;

CREATE OR REPLACE FUNCTION public.is_note_owner(_user_id UUID, _note_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.notes WHERE id = _note_id AND user_id = _user_id
  )
$$;

-- Replace initial notes policies with collaboration-aware ones (safe: drop first)
DROP POLICY IF EXISTS "Users can view their own notes" ON public.notes;
DROP POLICY IF EXISTS "Users can view accessible notes" ON public.notes;
CREATE POLICY "Users can view accessible notes" ON public.notes
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.has_note_access(auth.uid(), id));

DROP POLICY IF EXISTS "Users can update their own notes" ON public.notes;
DROP POLICY IF EXISTS "Users can update accessible notes" ON public.notes;
CREATE POLICY "Users can update accessible notes" ON public.notes
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR public.can_edit_note(auth.uid(), id));

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'note_collaborators' AND policyname = 'Note owners can view collaborators') THEN
    CREATE POLICY "Note owners can view collaborators" ON public.note_collaborators
      FOR SELECT TO authenticated
      USING (public.has_note_access(auth.uid(), note_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'note_collaborators' AND policyname = 'Note owners can add collaborators') THEN
    CREATE POLICY "Note owners can add collaborators" ON public.note_collaborators
      FOR INSERT TO authenticated
      WITH CHECK (public.is_note_owner(auth.uid(), note_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'note_collaborators' AND policyname = 'Note owners can update collaborators') THEN
    CREATE POLICY "Note owners can update collaborators" ON public.note_collaborators
      FOR UPDATE TO authenticated
      USING (public.is_note_owner(auth.uid(), note_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'note_collaborators' AND policyname = 'Note owners can remove collaborators') THEN
    CREATE POLICY "Note owners can remove collaborators" ON public.note_collaborators
      FOR DELETE TO authenticated
      USING (public.is_note_owner(auth.uid(), note_id) OR auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================
-- MIGRATION 3: Enable Realtime for notes + collaborators
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notes;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'note_collaborators'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.note_collaborators;
  END IF;
END $$;

-- ============================================================
-- MIGRATION 4: AI Provider tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.ai_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  provider_key text NOT NULL UNIQUE,
  base_url text NOT NULL,
  is_default boolean NOT NULL DEFAULT false
);

INSERT INTO public.ai_providers (name, provider_key, base_url, is_default)
VALUES
  ('Gemini', 'gemini', 'https://generativelanguage.googleapis.com/v1beta', true),
  ('OpenAI Compatible', 'openai', 'https://api.openai.com/v1', false)
ON CONFLICT (provider_key) DO NOTHING;

ALTER TABLE public.ai_providers ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ai_providers' AND policyname = 'Anyone can read providers') THEN
    CREATE POLICY "Anyone can read providers" ON public.ai_providers FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.ai_user_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_id uuid NOT NULL REFERENCES public.ai_providers(id) ON DELETE CASCADE,
  api_key_encrypted text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, provider_id)
);

ALTER TABLE public.ai_user_keys ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ai_user_keys' AND policyname = 'Users manage own keys') THEN
    CREATE POLICY "Users manage own keys" ON public.ai_user_keys FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.ai_user_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_id uuid NOT NULL REFERENCES public.ai_providers(id) ON DELETE CASCADE,
  model_name text NOT NULL,
  is_default boolean NOT NULL DEFAULT true,
  UNIQUE(user_id, provider_id)
);

ALTER TABLE public.ai_user_models ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ai_user_models' AND policyname = 'Users manage own models') THEN
    CREATE POLICY "Users manage own models" ON public.ai_user_models FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.ai_usage_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_id uuid NOT NULL REFERENCES public.ai_providers(id) ON DELETE CASCADE,
  model text NOT NULL,
  tokens_used integer NOT NULL DEFAULT 0,
  request_type text NOT NULL DEFAULT 'expense_parse',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_usage_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ai_usage_logs' AND policyname = 'Users read own logs') THEN
    CREATE POLICY "Users read own logs" ON public.ai_usage_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ai_usage_logs' AND policyname = 'System inserts logs') THEN
    CREATE POLICY "System inserts logs" ON public.ai_usage_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================
-- MIGRATION 5: Expenses tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  note_id UUID NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expense_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  expense_id UUID NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expense_item_participants (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  item_id UUID NOT NULL REFERENCES public.expense_items(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  UNIQUE(item_id, user_id)
);

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_item_participants ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  -- Expenses policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expenses' AND policyname = 'Users with note access can view expenses') THEN
    CREATE POLICY "Users with note access can view expenses"
      ON public.expenses FOR SELECT TO authenticated
      USING (has_note_access(auth.uid(), note_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expenses' AND policyname = 'Users who can edit note can insert expenses') THEN
    CREATE POLICY "Users who can edit note can insert expenses"
      ON public.expenses FOR INSERT TO authenticated
      WITH CHECK (can_edit_note(auth.uid(), note_id) OR is_note_owner(auth.uid(), note_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expenses' AND policyname = 'Users who can edit note can update expenses') THEN
    CREATE POLICY "Users who can edit note can update expenses"
      ON public.expenses FOR UPDATE TO authenticated
      USING (can_edit_note(auth.uid(), note_id) OR is_note_owner(auth.uid(), note_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expenses' AND policyname = 'Users who can edit note can delete expenses') THEN
    CREATE POLICY "Users who can edit note can delete expenses"
      ON public.expenses FOR DELETE TO authenticated
      USING (can_edit_note(auth.uid(), note_id) OR is_note_owner(auth.uid(), note_id));
  END IF;

  -- Expense items policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_items' AND policyname = 'Users with note access can view expense items') THEN
    CREATE POLICY "Users with note access can view expense items"
      ON public.expense_items FOR SELECT TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND has_note_access(auth.uid(), e.note_id)
      ));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_items' AND policyname = 'Users who can edit can insert expense items') THEN
    CREATE POLICY "Users who can edit can insert expense items"
      ON public.expense_items FOR INSERT TO authenticated
      WITH CHECK (EXISTS (
        SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
      ));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_items' AND policyname = 'Users who can edit can update expense items') THEN
    CREATE POLICY "Users who can edit can update expense items"
      ON public.expense_items FOR UPDATE TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
      ));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_items' AND policyname = 'Users who can edit can delete expense items') THEN
    CREATE POLICY "Users who can edit can delete expense items"
      ON public.expense_items FOR DELETE TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
      ));
  END IF;

  -- Expense item participants policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_item_participants' AND policyname = 'Users with note access can view item participants') THEN
    CREATE POLICY "Users with note access can view item participants"
      ON public.expense_item_participants FOR SELECT TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.expense_items ei
        JOIN public.expenses e ON e.id = ei.expense_id
        WHERE ei.id = item_id AND has_note_access(auth.uid(), e.note_id)
      ));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_item_participants' AND policyname = 'Users who can edit can insert item participants') THEN
    CREATE POLICY "Users who can edit can insert item participants"
      ON public.expense_item_participants FOR INSERT TO authenticated
      WITH CHECK (EXISTS (
        SELECT 1 FROM public.expense_items ei
        JOIN public.expenses e ON e.id = ei.expense_id
        WHERE ei.id = item_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
      ));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_item_participants' AND policyname = 'Users who can edit can delete item participants') THEN
    CREATE POLICY "Users who can edit can delete item participants"
      ON public.expense_item_participants FOR DELETE TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.expense_items ei
        JOIN public.expenses e ON e.id = ei.expense_id
        WHERE ei.id = item_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
      ));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'expenses'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.expenses;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'expense_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_items;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'expense_item_participants'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_item_participants;
  END IF;
END $$;

-- ============================================================
-- MIGRATION 6: Expense audit logs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.expense_audits (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  note_id UUID NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.expense_audits ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expense_audits' AND policyname = 'Users with note access can view expense audits') THEN
    CREATE POLICY "Users with note access can view expense audits"
      ON public.expense_audits FOR SELECT TO authenticated
      USING (has_note_access(auth.uid(), note_id));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'expense_audits'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_audits;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION log_expense_audit()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (NEW.note_id, COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), 'ADD', 'EXPENSE', NEW.id, jsonb_build_object('payer_id', NEW.payer_id));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (OLD.note_id, COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), 'DELETE', 'EXPENSE', OLD.id, jsonb_build_object('payer_id', OLD.payer_id));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS expense_audit_trigger ON public.expenses;
CREATE TRIGGER expense_audit_trigger
AFTER INSERT OR DELETE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION log_expense_audit();

CREATE OR REPLACE FUNCTION log_expense_item_audit()
RETURNS TRIGGER AS $$
DECLARE
  v_note_id UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT note_id INTO v_note_id FROM public.expenses WHERE id = NEW.expense_id;
    IF v_note_id IS NULL THEN RETURN NEW; END IF;
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (v_note_id, COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), 'ADD', 'ITEM', NEW.id, jsonb_build_object('name', NEW.name, 'price', NEW.price));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT note_id INTO v_note_id FROM public.expenses WHERE id = OLD.expense_id;
    IF v_note_id IS NULL THEN RETURN OLD; END IF;
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (v_note_id, COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), 'DELETE', 'ITEM', OLD.id, jsonb_build_object('name', OLD.name, 'price', OLD.price));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS expense_item_audit_trigger ON public.expense_items;
CREATE TRIGGER expense_item_audit_trigger
AFTER INSERT OR DELETE ON public.expense_items
FOR EACH ROW EXECUTE FUNCTION log_expense_item_audit();

-- ============================================================
-- MIGRATION 7: Indexes for performance
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_notes_user_id ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON public.notes(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_share_token ON public.notes(share_token) WHERE share_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_note_collaborators_note_id ON public.note_collaborators(note_id);
CREATE INDEX IF NOT EXISTS idx_note_collaborators_user_id ON public.note_collaborators(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_note_id ON public.expenses(note_id);
CREATE INDEX IF NOT EXISTS idx_expense_items_expense_id ON public.expense_items(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_item_participants_item_id ON public.expense_item_participants(item_id);
CREATE INDEX IF NOT EXISTS idx_expense_audits_note_id ON public.expense_audits(note_id);

-- ============================================================
-- MIGRATION 8: Share-link join RPC (SECURITY DEFINER)
-- ============================================================

CREATE OR REPLACE FUNCTION public.join_note_via_token(p_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_note_id UUID;
  v_owner_id UUID;
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Guarantee the joining user has a profiles row. Skip entirely if one
  -- already exists so we never touch the row or trigger a conflict path.
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE user_id = v_user_id
  ) THEN
    INSERT INTO public.profiles (user_id, display_name, email)
    SELECT v_user_id,
           COALESCE(
             u.raw_user_meta_data->>'display_name',
             u.raw_user_meta_data->>'full_name',
             u.raw_user_meta_data->>'name',
             split_part(u.email, '@', 1)
           ),
           LOWER(u.email)
    FROM auth.users u
    WHERE u.id = v_user_id
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  SELECT id, user_id INTO v_note_id, v_owner_id
  FROM public.notes
  WHERE share_token = p_token
  LIMIT 1;

  IF v_note_id IS NULL THEN
    RAISE EXCEPTION 'Invalid share token';
  END IF;

  IF v_owner_id = v_user_id THEN
    RETURN;
  END IF;

  INSERT INTO public.note_collaborators (note_id, user_id, permission, invited_by)
  VALUES (v_note_id, v_user_id, 'editor', v_owner_id)
  ON CONFLICT (note_id, user_id) DO NOTHING;
END;
$$;

-- Allow reading notes by share_token (for the join screen)
DROP POLICY IF EXISTS "Users can view notes by share token" ON public.notes;
CREATE POLICY "Users can view notes by share token" ON public.notes
  FOR SELECT TO authenticated
  USING (share_token IS NOT NULL);

-- ============================================================
-- MIGRATION 9: Add FK from note_collaborators to profiles
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'note_collaborators_user_id_profiles_fkey'
      AND table_name = 'note_collaborators'
  ) THEN
    ALTER TABLE public.note_collaborators
      ADD CONSTRAINT note_collaborators_user_id_profiles_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;
  END IF;
END $$;

-- ============================================================
-- MIGRATION 10: Per-item payer_id on expense_items
-- ============================================================
-- Each item remembers who paid for it at creation time, so changing
-- the expense-level payer afterwards doesn't silently rewrite existing
-- items' payers.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'expense_items'
      AND column_name = 'payer_id'
  ) THEN
    ALTER TABLE public.expense_items ADD COLUMN payer_id UUID;
  END IF;
END $$;

-- Backfill existing items with the payer from their parent expense so
-- older data still displays a payer. Idempotent: only touches rows that
-- are still NULL.
UPDATE public.expense_items ei
SET payer_id = e.payer_id
FROM public.expenses e
WHERE ei.expense_id = e.id
  AND ei.payer_id IS NULL;

-- ============================================================
-- Done! All tables, policies, functions, and triggers are set up.
-- Every statement is idempotent - safe to run unlimited times.
-- ============================================================
