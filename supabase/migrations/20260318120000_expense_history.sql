-- Drop the table and triggers if they exist so this script can be run multiple times safely
DROP TRIGGER IF EXISTS expense_audit_trigger ON public.expenses;
DROP TRIGGER IF EXISTS expense_item_audit_trigger ON public.expense_items;
DROP TABLE IF EXISTS public.expense_audits CASCADE;

-- Create expense_audits table
CREATE TABLE public.expense_audits (
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

CREATE POLICY "Users with note access can view expense audits"
  ON public.expense_audits FOR SELECT TO authenticated
  USING (has_note_access(auth.uid(), note_id));

ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_audits;

-- Trigger Function for Expenses
CREATE OR REPLACE FUNCTION log_expense_audit()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (NEW.note_id, auth.uid(), 'ADD', 'EXPENSE', NEW.id, jsonb_build_object('payer_id', NEW.payer_id));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (OLD.note_id, auth.uid(), 'DELETE', 'EXPENSE', OLD.id, jsonb_build_object('payer_id', OLD.payer_id));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER expense_audit_trigger
AFTER INSERT OR DELETE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION log_expense_audit();

-- Trigger for Items
CREATE OR REPLACE FUNCTION log_expense_item_audit()
RETURNS TRIGGER AS $$
DECLARE
  v_note_id UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT note_id INTO v_note_id FROM public.expenses WHERE id = NEW.expense_id;
    IF v_note_id IS NULL THEN RETURN NEW; END IF;
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (v_note_id, auth.uid(), 'ADD', 'ITEM', NEW.id, jsonb_build_object('name', NEW.name, 'price', NEW.price));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT note_id INTO v_note_id FROM public.expenses WHERE id = OLD.expense_id;
    IF v_note_id IS NULL THEN RETURN OLD; END IF;
    INSERT INTO public.expense_audits (note_id, user_id, action, entity_type, entity_id, details)
    VALUES (v_note_id, auth.uid(), 'DELETE', 'ITEM', OLD.id, jsonb_build_object('name', OLD.name, 'price', OLD.price));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER expense_item_audit_trigger
AFTER INSERT OR DELETE ON public.expense_items
FOR EACH ROW EXECUTE FUNCTION log_expense_item_audit();
