
-- Create permission enum
CREATE TYPE public.note_permission AS ENUM ('owner', 'editor', 'viewer');

-- Create note_collaborators table
CREATE TABLE public.note_collaborators (
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

-- Add share_token to notes for invite links
ALTER TABLE public.notes ADD COLUMN share_token TEXT UNIQUE;

-- Security definer function to check note access without recursion
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

-- Function to check edit permission
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

-- Function to check ownership
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

-- Update notes SELECT policy to include collaborators
DROP POLICY "Users can view their own notes" ON public.notes;
CREATE POLICY "Users can view accessible notes" ON public.notes
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.has_note_access(auth.uid(), id));

-- Update notes UPDATE policy to include editors
DROP POLICY "Users can update their own notes" ON public.notes;
CREATE POLICY "Users can update accessible notes" ON public.notes
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR public.can_edit_note(auth.uid(), id));

-- Collaborators RLS policies
-- Owners can manage collaborators on their notes
CREATE POLICY "Note owners can view collaborators" ON public.note_collaborators
  FOR SELECT TO authenticated
  USING (public.has_note_access(auth.uid(), note_id));

CREATE POLICY "Note owners can add collaborators" ON public.note_collaborators
  FOR INSERT TO authenticated
  WITH CHECK (public.is_note_owner(auth.uid(), note_id));

CREATE POLICY "Note owners can update collaborators" ON public.note_collaborators
  FOR UPDATE TO authenticated
  USING (public.is_note_owner(auth.uid(), note_id));

CREATE POLICY "Note owners can remove collaborators" ON public.note_collaborators
  FOR DELETE TO authenticated
  USING (public.is_note_owner(auth.uid(), note_id) OR auth.uid() = user_id);
