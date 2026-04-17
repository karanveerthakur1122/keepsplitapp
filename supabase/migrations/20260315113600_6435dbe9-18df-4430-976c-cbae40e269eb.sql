-- AI Providers table (system-level)
CREATE TABLE public.ai_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  provider_key text NOT NULL UNIQUE,
  base_url text NOT NULL,
  is_default boolean NOT NULL DEFAULT false
);

-- Seed default providers
INSERT INTO public.ai_providers (name, provider_key, base_url, is_default) VALUES
  ('Gemini', 'gemini', 'https://generativelanguage.googleapis.com/v1beta', true),
  ('OpenAI Compatible', 'openai', 'https://api.openai.com/v1', false);

-- Make providers readable by all authenticated users
ALTER TABLE public.ai_providers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read providers" ON public.ai_providers FOR SELECT TO authenticated USING (true);

-- AI User Keys table
CREATE TABLE public.ai_user_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_id uuid NOT NULL REFERENCES public.ai_providers(id) ON DELETE CASCADE,
  api_key_encrypted text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, provider_id)
);

ALTER TABLE public.ai_user_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own keys" ON public.ai_user_keys FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- AI User Models table
CREATE TABLE public.ai_user_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_id uuid NOT NULL REFERENCES public.ai_providers(id) ON DELETE CASCADE,
  model_name text NOT NULL,
  is_default boolean NOT NULL DEFAULT true,
  UNIQUE(user_id, provider_id)
);

ALTER TABLE public.ai_user_models ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own models" ON public.ai_user_models FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- AI Usage Logs table
CREATE TABLE public.ai_usage_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider_id uuid NOT NULL REFERENCES public.ai_providers(id) ON DELETE CASCADE,
  model text NOT NULL,
  tokens_used integer NOT NULL DEFAULT 0,
  request_type text NOT NULL DEFAULT 'expense_parse',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_usage_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own logs" ON public.ai_usage_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "System inserts logs" ON public.ai_usage_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);