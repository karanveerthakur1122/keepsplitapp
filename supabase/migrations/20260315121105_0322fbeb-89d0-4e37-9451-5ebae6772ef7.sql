
-- Expenses table (one per payment event, linked to a note)
CREATE TABLE public.expenses (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  note_id UUID NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Expense items
CREATE TABLE public.expense_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  expense_id UUID NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Expense item participants
CREATE TABLE public.expense_item_participants (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  item_id UUID NOT NULL REFERENCES public.expense_items(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  UNIQUE(item_id, user_id)
);

-- Enable RLS
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_item_participants ENABLE ROW LEVEL SECURITY;

-- RLS for expenses: users with note access can read, users who can edit can write
CREATE POLICY "Users with note access can view expenses"
  ON public.expenses FOR SELECT TO authenticated
  USING (has_note_access(auth.uid(), note_id));

CREATE POLICY "Users who can edit note can insert expenses"
  ON public.expenses FOR INSERT TO authenticated
  WITH CHECK (can_edit_note(auth.uid(), note_id) OR is_note_owner(auth.uid(), note_id));

CREATE POLICY "Users who can edit note can update expenses"
  ON public.expenses FOR UPDATE TO authenticated
  USING (can_edit_note(auth.uid(), note_id) OR is_note_owner(auth.uid(), note_id));

CREATE POLICY "Users who can edit note can delete expenses"
  ON public.expenses FOR DELETE TO authenticated
  USING (can_edit_note(auth.uid(), note_id) OR is_note_owner(auth.uid(), note_id));

-- RLS for expense_items: based on parent expense's note access
CREATE POLICY "Users with note access can view expense items"
  ON public.expense_items FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND has_note_access(auth.uid(), e.note_id)
  ));

CREATE POLICY "Users who can edit can insert expense items"
  ON public.expense_items FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
  ));

CREATE POLICY "Users who can edit can update expense items"
  ON public.expense_items FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
  ));

CREATE POLICY "Users who can edit can delete expense items"
  ON public.expense_items FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.expenses e WHERE e.id = expense_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
  ));

-- RLS for expense_item_participants: based on parent item's expense's note access
CREATE POLICY "Users with note access can view item participants"
  ON public.expense_item_participants FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.expense_items ei
    JOIN public.expenses e ON e.id = ei.expense_id
    WHERE ei.id = item_id AND has_note_access(auth.uid(), e.note_id)
  ));

CREATE POLICY "Users who can edit can insert item participants"
  ON public.expense_item_participants FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.expense_items ei
    JOIN public.expenses e ON e.id = ei.expense_id
    WHERE ei.id = item_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
  ));

CREATE POLICY "Users who can edit can delete item participants"
  ON public.expense_item_participants FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.expense_items ei
    JOIN public.expenses e ON e.id = ei.expense_id
    WHERE ei.id = item_id AND (can_edit_note(auth.uid(), e.note_id) OR is_note_owner(auth.uid(), e.note_id))
  ));

-- Enable realtime for expenses
ALTER PUBLICATION supabase_realtime ADD TABLE public.expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_item_participants;
