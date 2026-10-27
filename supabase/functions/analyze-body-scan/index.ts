// Supabase Edge Function: analyze-body-scan
//
// يُستدعى بعد أن يرفع التطبيق صورة الجسم إلى Storage bucket "body-scans"
// وينشئ صف body_scans (status='pending'). يقرأ الصورة، يرسلها إلى Gemini
// (نموذج يدعم الرؤية) مع Prompt تحفيزي غير تشخيصي، ثم يحفظ النتيجة في نفس
// الصف (ai_summary + status='done').

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const GEMINI_MODEL = "gemini-3.6-flash";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const BODY_SCAN_SCHEMA = {
  type: "object",
  required: ["summary", "observations", "suggestions"],
  properties: {
    summary: { type: "string" },
    observations: { type: "array", items: { type: "string" } },
    suggestions: { type: "array", items: { type: "string" } },
  },
};

function buildBodyScanPrompt(locale: string) {
  const lang = locale === "en" ? "الإنجليزية" : "العربية";
  return `أنت مدرب لياقة بدنية إيجابي وودود. انظر إلى صورة الجسم هذه لغرض متابعة تقدم اللياقة البدنية فقط (وليس تشخيصاً طبياً أو تقييماً دقيقاً للوزن أو الشكل). قدّم:
- summary: ملخص عام قصير ومحفّز عن المظهر البدني العام الظاهر في الصورة.
- observations: 2 إلى 4 ملاحظات إيجابية أو محايدة حول الوضعية أو البنية العامة الظاهرة.
- suggestions: 2 إلى 3 اقتراحات عامة قابلة للتطبيق (تمارين أو تغذية) لدعم استمرار التقدم.

تعليمات مهمة:
1. حافظ على نبرة إيجابية ومحترمة دائماً، ولا تصدر أي حكم قد يسبب إحراجاً أو ضيقاً.
2. لا تقدّم أي تشخيص طبي أو تقييماً دقيقاً للوزن؛ إن لاحظت أي شيء يستدعي القلق الصحي وضّح أنه يجب استشارة مختص.
3. أجب حصراً بكائن JSON مطابق تماماً للحقول المطلوبة، بلغة ${lang}، بدون أي نص خارج الـ JSON.`;
}

async function callGeminiVision(prompt: string, base64Image: string) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [
            { text: prompt },
            { inline_data: { mime_type: "image/jpeg", data: base64Image } },
          ],
        },
      ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: BODY_SCAN_SCHEMA,
        maxOutputTokens: 2000,
      },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Gemini API error (${res.status}): ${text}`);
  }

  const json = await res.json();
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("لم يُرجع النموذج نتيجة منظّمة.");
  return JSON.parse(text);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      });
    }

    const authedClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
    } = await authedClient.auth.getUser();

    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const scanId = body.scan_id;
    const locale = body.locale === "en" ? "en" : "ar";
    if (!scanId) throw new Error("scan_id is required");

    // service_role: لتحميل الصورة من bucket خاص وتحديث الصف بصلاحية كاملة
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: scan, error: scanError } = await admin
      .from("body_scans")
      .select("*")
      .eq("id", scanId)
      .eq("user_id", user.id)
      .single();
    if (scanError) throw scanError;

    const { data: fileBlob, error: dlError } = await admin.storage
      .from("body-scans")
      .download(scan.image_path);
    if (dlError) throw dlError;

    const bytes = new Uint8Array(await fileBlob.arrayBuffer());
    const base64Image = encodeBase64(bytes);

    const prompt = buildBodyScanPrompt(locale);
    const analysis = await callGeminiVision(prompt, base64Image);

    const { error: updateError } = await admin
      .from("body_scans")
      .update({ ai_summary: JSON.stringify(analysis), status: "done" })
      .eq("id", scanId);
    if (updateError) throw updateError;

    return new Response(JSON.stringify({ success: true, analysis }), {
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: `${e}` }), {
      status: 500,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  }
});
