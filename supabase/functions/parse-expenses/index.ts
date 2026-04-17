import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

const PROMPT_TEMPLATE = `You extract financial transactions from text.
Return JSON only.
Format:
{"transactions":[{"payer":"name","receiver":"Group","items":[{"name":"item","amount":number}],"total":number}]}

User Text:
`;

const DEFAULT_MODEL = "gemini-2.0-flash-lite";
const MAX_INPUT_CHARS = 2000;
const MAX_OUTPUT_TOKENS = 200;

// Simple in-memory rate guard (per isolate)
const lastRequestByUser = new Map<string, number>();

async function resolveAPIKey(userId: string, supabaseAdmin: any): Promise<{ apiKey: string; providerId: string; model: string; source: "user" | "system" }> {
  // Try user key
  const { data: userKeys } = await supabaseAdmin
    .from("ai_user_keys")
    .select("provider_id, api_key_encrypted")
    .eq("user_id", userId)
    .eq("is_active", true)
    .limit(1);

  if (userKeys && userKeys.length > 0) {
    const key = userKeys[0];
    // Get user model preference
    const { data: userModel } = await supabaseAdmin
      .from("ai_user_models")
      .select("model_name")
      .eq("user_id", userId)
      .eq("provider_id", key.provider_id)
      .maybeSingle();

    // Force gemini-1.5-flash if no model selected
    const model = userModel?.model_name || DEFAULT_MODEL;

    return { apiKey: key.api_key_encrypted, providerId: key.provider_id, model, source: "user" };
  }

  // System fallback
  const systemKey = Deno.env.get("GEMINI_API_KEY");
  if (systemKey) {
    const { data: provider } = await supabaseAdmin
      .from("ai_providers")
      .select("id")
      .eq("provider_key", "gemini")
      .single();
    return { apiKey: systemKey, providerId: provider?.id || "", model: DEFAULT_MODEL, source: "system" };
  }

  throw new Error("NO_KEY");
}

function parseGeminiError(responseBody: string, status: number): string {
  const lower = responseBody.toLowerCase();
  if (lower.includes("api_key_invalid") || lower.includes("api key expired") || lower.includes("api key not valid")) {
    return "AI_INVALID_KEY";
  }
  if (lower.includes("resource_exhausted") || lower.includes("quota") || lower.includes("exceeded your current quota")) {
    return "AI_QUOTA_EXCEEDED";
  }
  if (lower.includes("ratelimitexceeded") || lower.includes("rate_limit_exceeded") || status === 429) {
    return "AI_RATE_LIMIT";
  }
  if (status === 400 || status === 401) return "AI_INVALID_KEY";
  if (status === 403) return "AI_QUOTA_EXCEEDED";
  return "AI_PROVIDER_DOWN";
}

const ERROR_MESSAGES: Record<string, string> = {
  AI_INVALID_KEY: "Invalid API key. Update it in Settings → AI Settings.",
  AI_QUOTA_EXCEEDED: "AI quota exhausted. Add a new key in Settings → AI Settings.",
  AI_RATE_LIMIT: "Rate limit exceeded. Please wait a moment and try again.",
  AI_PROVIDER_DOWN: "AI provider is currently unavailable.",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const { noteContent } = await req.json();

    if (!noteContent || typeof noteContent !== "string" || noteContent.trim().length === 0) {
      return new Response(JSON.stringify({ error: "No content to analyze", transactions: [] }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Auth
    const authHeader = req.headers.get("Authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    let userId: string | null = null;
    if (authHeader) {
      const userClient = createClient(supabaseUrl, supabaseAnon, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data } = await userClient.auth.getUser();
      userId = data.user?.id || null;
    }

    if (!userId) {
      return new Response(JSON.stringify({ error: "Unauthorized", errorCode: "AI_INVALID_KEY" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Rate guard: 3 second cooldown per user
    const now = Date.now();
    const lastReq = lastRequestByUser.get(userId);
    if (lastReq && now - lastReq < 3000) {
      return new Response(JSON.stringify({ error: "Please wait a few seconds before trying again.", errorCode: "AI_RATE_LIMIT" }), {
        status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    lastRequestByUser.set(userId, now);

    // Resolve key
    let config: Awaited<ReturnType<typeof resolveAPIKey>>;
    try {
      config = await resolveAPIKey(userId, supabaseAdmin);
    } catch {
      return new Response(JSON.stringify({
        error: "No AI API key configured. Please add one in Settings → AI Settings.",
        errorCode: "AI_INVALID_KEY",
      }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Truncate input
    const truncated = noteContent.slice(0, MAX_INPUT_CHARS);
    const inputTokenEstimate = Math.ceil(truncated.length / 4);

    console.log(`Request: user=${userId.slice(0, 8)}, model=${config.model}, source=${config.source}, est_tokens=${inputTokenEstimate}`);

    // Single request - NO retries
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${config.model}:generateContent?key=${config.apiKey}`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: PROMPT_TEMPLATE + truncated }] }],
        generationConfig: {
          maxOutputTokens: MAX_OUTPUT_TOKENS,
          temperature: 0.1,
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Gemini error ${response.status}:`, errorText);

      const errorCode = parseGeminiError(errorText, response.status);

      // If user key failed, try system fallback ONCE with different key
      if (config.source === "user") {
        const systemKey = Deno.env.get("GEMINI_API_KEY");
        if (systemKey && systemKey !== config.apiKey) {
          console.log("Trying system fallback key");
          const fallbackResp = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${DEFAULT_MODEL}:generateContent?key=${systemKey}`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                contents: [{ parts: [{ text: PROMPT_TEMPLATE + truncated }] }],
                generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS, temperature: 0.1 },
              }),
            }
          );

          if (fallbackResp.ok) {
            const fallbackData = await fallbackResp.json();
            const text = fallbackData.candidates?.[0]?.content?.parts?.[0]?.text;
            if (text) {
              const parsed = JSON.parse(text);
              const tokensUsed = fallbackData.usageMetadata?.totalTokenCount || 0;
              // Log usage
              if (config.providerId) {
                await supabaseAdmin.from("ai_usage_logs").insert({
                  user_id: userId, provider_id: config.providerId,
                  model: DEFAULT_MODEL, tokens_used: tokensUsed, request_type: "expense_parse",
                });
              }
              return new Response(JSON.stringify(parsed), {
                status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
              });
            }
          }
        }
      }

      return new Response(JSON.stringify({
        error: ERROR_MESSAGES[errorCode] || ERROR_MESSAGES.AI_PROVIDER_DOWN,
        errorCode,
      }), { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Parse success
    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      return new Response(JSON.stringify({ error: "No transactions found", transactions: [] }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const parsed = JSON.parse(text);
    const tokensUsed = data.usageMetadata?.totalTokenCount || 0;

    console.log(`Success: tokens_used=${tokensUsed}`);

    // Log usage
    if (config.providerId) {
      await supabaseAdmin.from("ai_usage_logs").insert({
        user_id: userId, provider_id: config.providerId,
        model: config.model, tokens_used: tokensUsed, request_type: "expense_parse",
      });
    }

    return new Response(JSON.stringify(parsed), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("parse-expenses error:", e);
    return new Response(JSON.stringify({
      error: e instanceof Error ? e.message : "Unknown error",
      errorCode: "AI_PROVIDER_DOWN",
    }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
