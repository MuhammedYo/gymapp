// Supabase Edge Function: generate-plan
//
// يُستدعى من التطبيق (زر "توليد خطة التمارين" أو "توليد خطة التغذية"،
// كل واحدة مستقلة تماماً عن الأخرى عبر body.type = 'workout' | 'meal').
// يقرأ ملف المستخدم + حالاته الطبية، يطلب من Gemini الخطة المطلوبة فقط
// بصيغة JSON منظّمة (عبر responseSchema)، ثم يكتبها في قاعدة البيانات:
// - workout: workout_plans/workout_days/workout_exercises (مع مطابقة/إضافة
//   إلى مكتبة exercises المشتركة).
// - meal: meal_plans/daily_meals.
//
// أسماء التمارين تُولَّد بالإنجليزية دائماً (لأن exercises مكتبة مشتركة بين
// كل المستخدمين، ومزج اللغات فيها يفتّتها لمدخلات مكررة). أما الوجبات
// (daily_meals خاصة بكل مستخدم) فتُولَّد بلغة المستخدم (locale).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const GEMINI_MODEL = "gemini-3.6-flash";
// نموذج احتياطي مستقر يُستخدم فقط إذا استمر ازدحام (503) النموذج الأساسي
// بعد استنفاذ كل محاولاته — نموذج مختلف عادة له سعة/طابور منفصل عن النموذج
// الأساسي، فيرفع فرصة نجاح الطلب دون انتظار أطول على نفس النموذج المزدحم.
// ملاحظة: gemini-2.5-flash جُرِّب أولاً هنا لكنه أصبح مرفوضاً بالكامل لمشاريع
// جديدة ("no longer available to new users")، فاستُبدل بـgemini-3.8-flash
// (أحدث نموذج GA متاح لكل المستخدمين وقت هذا التعديل).
const GEMINI_FALLBACK_MODEL = "gemini-3.8-flash";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// اختياري: بدون هذا المفتاح تُنشأ التمارين بدون فيديو تعليمي فقط (best-effort)
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY") ?? "";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ==================== المخطط (Schema) ====================

const WORKOUT_SCHEMA = {
  type: "object",
  required: ["workout_plan_title", "workout_days"],
  properties: {
    workout_plan_title: { type: "string" },
    workout_days: {
      type: "array",
      minItems: 7,
      maxItems: 7,
      items: {
        type: "object",
        required: ["day_number", "day_name", "is_rest_day", "exercises"],
        properties: {
          day_number: { type: "integer", minimum: 1, maximum: 7 },
          day_name: { type: "string" },
          is_rest_day: { type: "boolean" },
          exercises: {
            type: "array",
            items: {
              type: "object",
              required: [
                "name",
                "target_muscle",
                "sets",
                "reps_range",
                "rest_seconds",
                "order_index",
              ],
              properties: {
                name: {
                  type: "string",
                  description: "English canonical exercise name",
                },
                description: { type: "string" },
                target_muscle: { type: "string" },
                secondary_muscles: { type: "array", items: { type: "string" } },
                equipment_needed: { type: "string" },
                common_mistakes: { type: "string" },
                is_home_friendly: { type: "boolean" },
                sets: { type: "integer" },
                reps_range: { type: "string" },
                rest_seconds: { type: "integer" },
                order_index: { type: "integer" },
              },
            },
          },
        },
      },
    },
  },
};

const MEAL_SCHEMA = {
  type: "object",
  required: ["meal_days", "supplements"],
  properties: {
    supplements: {
      type: "array",
      items: {
        type: "object",
        required: ["name", "category", "dosage", "reason"],
        properties: {
          name: { type: "string" },
          category: {
            type: "string",
            enum: ["protein", "creatine", "vitamin", "omega3", "other"],
          },
          dosage: { type: "string" },
          timing: { type: "string" },
          reason: { type: "string" },
        },
      },
    },
    meal_days: {
      type: "array",
      minItems: 7,
      maxItems: 7,
      items: {
        type: "object",
        required: ["day_number", "total_daily_calories", "meals"],
        properties: {
          day_number: { type: "integer", minimum: 1, maximum: 7 },
          total_daily_calories: { type: "integer" },
          meals: {
            type: "array",
            items: {
              type: "object",
              required: [
                "meal_type",
                "food_name",
                "calories",
                "protein_g",
                "carbs_g",
                "fats_g",
              ],
              properties: {
                meal_type: {
                  type: "string",
                  enum: ["breakfast", "lunch", "dinner", "snack"],
                },
                food_name: { type: "string" },
                portion_description: { type: "string" },
                calories: { type: "integer" },
                protein_g: { type: "number" },
                carbs_g: { type: "number" },
                fats_g: { type: "number" },
                alternatives: { type: "string" },
              },
            },
          },
        },
      },
    },
  },
};

// ==================== بناء الـ Prompt ====================

const ISO_WEEKDAY_NAMES_AR = [
  "الاثنين",
  "الثلاثاء",
  "الأربعاء",
  "الخميس",
  "الجمعة",
  "السبت",
  "الأحد",
];
const ISO_WEEKDAY_NAMES_EN = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
];

function weekdayNames(days: number[], locale: string): string {
  const names = locale === "ar" ? ISO_WEEKDAY_NAMES_AR : ISO_WEEKDAY_NAMES_EN;
  return days.map((d) => names[d - 1]).join("، ");
}

function profileSummary(profile: any) {
  return `- العمر: ${profile.age}
- الجنس: ${profile.gender}
- الطول: ${profile.height_cm} سم
- الوزن: ${profile.weight_kg} كجم
- الهدف: ${profile.target_goal}
- مستوى اللياقة: ${profile.fitness_level}
- مكان التمرين: ${profile.workout_location}
- الأيام المتاحة أسبوعياً: ${profile.available_days_per_week}
- مستوى النشاط اليومي: ${profile.activity_level}
- ساعات النوم: ${profile.sleep_hours}
- نوع الطعام المفضل: ${profile.dietary_preference}
- السعرات المستهدفة يومياً: ${profile.target_calories} kcal
- البروتين المستهدف: ${profile.protein_g} g
- الكاربوهيدرات المستهدفة: ${profile.carbs_g} g
- الدهون المستهدفة: ${profile.fats_g} g`;
}

function buildWorkoutPrompt(profile: any, conditions: any[], locale: string) {
  const conditionsText = conditions.length
    ? conditions
        .map(
          (c) =>
            `- ${c.condition_type}: ${c.name} (${c.affected_body_part ?? "غير محدد"}, severity: ${c.severity})`,
        )
        .join("\n")
    : "لا توجد حالات طبية أو إصابات مسجّلة.";

  const preferredDays: number[] = Array.isArray(profile.preferred_workout_days)
    ? profile.preferred_workout_days
    : [];
  const trainingDaysText =
    preferredDays.length > 0
      ? `${preferredDays.join(", ")} (${weekdayNames(preferredDays, locale)})`
      : "غير محدد من المستخدم — وزّع الأيام بحرية";
  const restDays = [1, 2, 3, 4, 5, 6, 7].filter((d) => !preferredDays.includes(d));

  return `أنت مدرب لياقة بدنية محترف. أنشئ خطة تمارين أسبوعية (7 أيام) لمستخدم بالبيانات التالية:

${profileSummary(profile)}

الحالات الطبية والإصابات:
${conditionsText}

تعليمات مهمة:
1. day_number يمثّل رقم يوم الأسبوع التقويمي الحقيقي بمعيار ISO: 1=الاثنين، 2=الثلاثاء، 3=الأربعاء، 4=الخميس، 5=الجمعة، 6=السبت، 7=الأحد. المستخدم اختار بنفسه أيام تمرينه الفعلية وهي بالضبط: ${trainingDaysText}. اجعل is_rest_day = false لهذه الأيام فقط بالضبط، وis_rest_day = true لكل الأيام الأخرى (${restDays.join(", ")}) دون استثناء — هذا إلزامي وليس اقتراحاً.
2. إن كان مكان التمرين "home"، استخدم تمارين وزن الجسم أو أدوات بسيطة فقط. إن كان "gym"، استخدم تمارين حديد/أجهزة احترافية تناسب المستوى.
3. راعِ الحالات الطبية والإصابات: تجنّب أو عدّل أي تمرين يُجهد الجزء المصاب. إن وُجدت حالة severity="severe"، أضف ملاحظة صريحة في common_mistakes تنصح باستشارة الطبيب قبل أداء التمرين.
4. اسم كل تمرين (name) يجب أن يكون بالإنجليزية دائماً وبصيغة قياسية معروفة (مثل "Barbell Bench Press")، بغض النظر عن لغة المستخدم، لأنها تُخزَّن في مكتبة تمارين مشتركة.
5. باقي الحقول (day_name, description, common_mistakes) يجب أن تكون بلغة: ${locale === "ar" ? "العربية" : "الإنجليزية"}.
6. day_name وصف مختصر لتركيز التمرين ذلك اليوم (مثل "صدر وترايسبس" أو "Push Day")، أو "يوم راحة" / "Rest Day" لأيام الراحة — لا داعي لتكرار اسم اليوم نفسه فيه لأنه معروف من day_number.
7. أجب حصراً بكائن JSON مطابق تماماً للحقول المطلوبة، بدون أي نص أو شرح خارج الـ JSON.`;
}

// تُستخدم بدل buildWorkoutPrompt حصراً عندما يملك المستخدم إصابة مسجّلة
// (condition_type = "injury") — وليس أي مرض عام — بناءً على طلب صريح: خطة
// تمرين بدني عادية غير مناسبة لإصابة، فتتحول الخطة بالكامل لخطة تأهيلية
// هدفها التعافي الآمن، لا بناء العضلات. تحافظ على نفس بنية الـJSON/الجدول
// تماماً (WORKOUT_SCHEMA نفسه) حتى لا يتطلب الأمر أي تغيير في قاعدة البيانات
// أو شاشة العرض — فقط محتوى الخطة وعنوانها يتغيران.
function buildRehabPrompt(profile: any, conditions: any[], locale: string) {
  const injuries = conditions.filter((c) => c.condition_type === "injury");
  const conditionsText = conditions.length
    ? conditions
        .map(
          (c) =>
            `- ${c.condition_type}: ${c.name} (${c.affected_body_part ?? "غير محدد"}, severity: ${c.severity})`,
        )
        .join("\n")
    : "لا توجد حالات طبية أو إصابات مسجّلة.";

  const injuredPartsText = injuries
    .map((c) => c.affected_body_part || c.name)
    .filter(Boolean)
    .join("، ");

  const preferredDays: number[] = Array.isArray(profile.preferred_workout_days)
    ? profile.preferred_workout_days
    : [];
  const trainingDaysText =
    preferredDays.length > 0
      ? `${preferredDays.join(", ")} (${weekdayNames(preferredDays, locale)})`
      : "غير محدد من المستخدم — وزّع الأيام بحرية";
  const restDays = [1, 2, 3, 4, 5, 6, 7].filter((d) => !preferredDays.includes(d));

  return `أنت أخصائي علاج طبيعي وتأهيل إصابات رياضية محترف، ولست مدرب لياقة بدنية عاماً في هذه الحالة. المستخدم لديه إصابة مسجّلة تستدعي **خطة تأهيلية** بدل خطة تمرين بدني عادية، ببيانات:

${profileSummary(profile)}

الحالات الطبية والإصابات المسجّلة:
${conditionsText}

هدف هذه الخطة هو مساعدة المستخدم على التعافي الآمن والتدريجي من إصابته (${
    injuredPartsText || "المذكورة أعلاه"
  })، وليس بناء العضلات أو زيادة القوة كهدف أساسي.

تعليمات مهمة:
1. ركّز التمارين على: تمارين مدى حركة آمن (mobility)، تمارين تقوية تدريجية ولطيفة خاصة بالجزء المصاب ضمن حدود آمنة، وتمارين إطالة خفيفة. تجنّب تماماً أي تمرين قد يُجهد أو يُفاقم الإصابة المذكورة.
2. يمكن تضمين تمارين خفيفة الشدة لباقي الجسم (غير المصاب) للحفاظ على لياقة عامة بسيطة، لكن بلا أي حمل ثقيل أو تمرين عالي الصدمة (كالقفز) طالما الإصابة قائمة.
3. day_number يمثّل رقم يوم الأسبوع التقويمي الحقيقي بمعيار ISO: 1=الاثنين، 2=الثلاثاء، 3=الأربعاء، 4=الخميس، 5=الجمعة، 6=السبت، 7=الأحد. أيام تمرين المستخدم المختارة هي بالضبط: ${trainingDaysText}. اجعل is_rest_day=false لهذه الأيام فقط بالضبط، وis_rest_day=true لكل الأيام الأخرى (${restDays.join(", ")}) دون استثناء — هذا إلزامي.
4. لكل تمرين متعلق مباشرة بالجزء المصاب، أضف في common_mistakes ملاحظة صريحة تنصح بالتوقف فوراً عند الشعور بألم حاد واستشارة أخصائي علاج طبيعي أو طبيب مختص قبل المتابعة.
5. اجعل workout_plan_title يوضح صراحة أنها خطة تأهيلية (مثل "برنامج تأهيلي لإصابة الركبة" أو "Knee Injury Rehabilitation Program")، وليس عنوان خطة تمرين عادي.
6. اسم كل تمرين (name) يجب أن يكون بالإنجليزية دائماً وبصيغة قياسية معروفة، بغض النظر عن لغة المستخدم.
7. باقي الحقول (day_name, description, common_mistakes) يجب أن تكون بلغة: ${locale === "ar" ? "العربية" : "الإنجليزية"}.
8. أجب حصراً بكائن JSON مطابق تماماً للحقول المطلوبة، بدون أي نص أو شرح خارج الـ JSON.`;
}

function buildMealPrompt(profile: any, locale: string) {
  return `أنت أخصائي تغذية محترف. أنشئ خطة تغذية أسبوعية (7 أيام) لمستخدم بالبيانات التالية:

${profileSummary(profile)}

تعليمات مهمة:
1. day_number يمثّل رقم يوم البرنامج بدءاً من يوم إنشاء الخطة (day_number=1 هو اليوم الذي يبدأ فيه المستخدم، وليس مرتبطاً بيوم أسبوع تقويمي محدد)، ويتكرر كل 7 أيام (7 أيام دائماً، مرقّمة 1 إلى 7 بالترتيب).
2. نوّع الوجبات فعلياً بين الأيام السبعة (لا تكرر نفس الأطعمة كل يوم) مع الحفاظ على سعرات وماكروز كل يوم قريبة من الهدف نفسه.
3. مجموع سعرات meals في كل يوم يجب أن يقارب ${profile.target_calories} kcal بأقرب ما يمكن، موزّعة على breakfast/lunch/dinner ووجبة خفيفة واحدة أو اثنتين snack.
4. احترم نوع الطعام المفضل "${profile.dietary_preference}" في كل الوجبات والبدائل المقترحة (alternatives).
5. اجعل مجموع البروتين/الكارب/الدهون في كل يوم قريباً من: بروتين ${profile.protein_g}g، كارب ${profile.carbs_g}g، دهون ${profile.fats_g}g.
6. كل الحقول النصية (food_name, portion_description, alternatives) يجب أن تكون بلغة: ${locale === "ar" ? "العربية" : "الإنجليزية"}.
7. supplements: اقترح 2 إلى 4 مكملات غذائية رياضية شائعة وآمنة تناسب هدف المستخدم "${profile.target_goal}" ومستوى نشاطه (مثل: Whey Protein، Creatine Monohydrate، Multivitamin، Omega-3، Fiber، Electrolytes). لكل مكمل: category من القائمة المحددة فقط، dosage عام تقريبي (وليس وصفة دقيقة)، timing (متى يُؤخذ)، وreason (لماذا يناسب هدفه).
8. قيود صارمة على supplements: اقترح فقط مكملات غذائية رياضية شائعة تُباع بدون وصفة طبية (OTC). ممنوع منعاً باتاً اقتراح أي دواء، هرمون، منشط، أو أي مادة تستدعي وصفة طبية أو إشرافاً طبياً متخصصاً (مثل الستيرويدات، SARMs، أو أي عقاقير). لا تذكر جرعات دقيقة كوصفة طبية، واجعل dosage إرشادياً عاماً فقط. لا تذكر أسماء علامات تجارية محددة، استخدم الاسم العام للمكمل فقط.
9. أجب حصراً بكائن JSON مطابق تماماً للحقول المطلوبة، بدون أي نص أو شرح خارج الـ JSON.`;
}

// ==================== استدعاء Gemini ====================

// عدد مرات إعادة المحاولة عند خطأ مؤقت من Gemini (503 ازدحام، 429 تجاوز
// الحصة) فقط — لا نعيد المحاولة عند أخطاء الطلب الحقيقية (400/401/404) لأن
// إعادتها لن تُصلح شيئاً وتُبطئ فشل الاستجابة للمستخدم بلا فائدة.
// رُفع العدد من 3 إلى 5 (مع سقف 8 ثوانٍ لكل انتظار) بعد أن استمر ظهور رسالة
// "الخدمة مزدحمة" لبعض المستخدمين مع 3 محاولات فقط — ازدحام Gemini قد يستمر
// لأكثر من ~7 ثوانٍ (إجمالي المحاولات القديمة)، فمنحه نافذة زمنية أطول
// (إجمالي ~23 ثانية) يرفع فرصة النجاح دون الاصطدام بحد زمن تنفيذ الدالة.
const GEMINI_MAX_RETRIES = 5;
const GEMINI_RETRYABLE_STATUS = [429, 503];
const GEMINI_MAX_BACKOFF_MS = 8000;

// يُنشئ خطأً يحمل رمز حالة HTTP الأصلي (إن وُجد) حتى تستطيع الدالة المستدعية
// (callGemini) معرفة هل يستحق تجربة النموذج الاحتياطي أم لا.
class GeminiHttpError extends Error {
  status?: number;
  constructor(message: string, status?: number) {
    super(message);
    this.status = status;
  }
}

async function callGeminiModel(
  model: string,
  prompt: string,
  schema: unknown,
) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

  let lastError = "";
  let lastStatus: number | undefined;
  for (let attempt = 0; attempt <= GEMINI_MAX_RETRIES; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: schema,
          // كان 8000 يقطع (truncate) استجابات الخطط الكبيرة (7 أيام + مكملات)
          // في منتصف نص JSON فيسبب "unterminated string" عند JSON.parse. كل
          // من gemini-3.6-flash وgemini-3.8-flash يدعمان حتى 65536، فرُفع
          // الحد إلى 32768 لهامش أمان واسع دون تكلفة/تأخير أقصى الحد.
          maxOutputTokens: 32768,
        },
      }),
    });

    if (res.ok) {
      const json = await res.json();
      const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) throw new Error("لم يُرجع النموذج نتيجة منظّمة.");
      try {
        return JSON.parse(text);
      } catch (parseError) {
        // نص مقطوع/JSON غير صالح رغم res.ok — نعامله كخطأ قابل لإعادة
        // المحاولة (بل وتجربة النموذج الاحتياطي) بدل تحطّم الطلب فوراً.
        lastStatus = 503;
        lastError =
          `Gemini returned malformed JSON (${model}): ${
            (parseError as Error).message
          }`;
        const canRetryParse = attempt < GEMINI_MAX_RETRIES;
        if (!canRetryParse) throw new GeminiHttpError(lastError, lastStatus);
        const waitMs = Math.min(
          1000 * Math.pow(2, attempt),
          GEMINI_MAX_BACKOFF_MS,
        );
        console.warn(`${lastError} — retrying in ${waitMs}ms (attempt ${
          attempt + 1
        }/${GEMINI_MAX_RETRIES})`);
        await new Promise((resolve) => setTimeout(resolve, waitMs));
        continue;
      }
    }

    const text = await res.text();
    lastStatus = res.status;
    lastError = `Gemini API error (${model}, ${res.status}): ${text}`;

    const canRetry =
      GEMINI_RETRYABLE_STATUS.includes(res.status) &&
      attempt < GEMINI_MAX_RETRIES;
    if (!canRetry) throw new GeminiHttpError(lastError, lastStatus);

    // تراجع تصاعدي (exponential backoff) بسقف أقصى، لتجنب انتظار طويل جداً
    // إن استمر الازدحام: 1s، 2s، 4s، 8s، 8s.
    const waitMs = Math.min(1000 * Math.pow(2, attempt), GEMINI_MAX_BACKOFF_MS);
    console.warn(`${lastError} — retrying in ${waitMs}ms (attempt ${attempt + 1}/${GEMINI_MAX_RETRIES})`);
    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }

  throw new GeminiHttpError(lastError, lastStatus);
}

// يجرّب النموذج الأساسي أولاً بكل محاولاته، وإن استمر ازدحامه (503/429) حتى
// بعد استنفاذ كل تلك المحاولات، يجرّب نموذجاً احتياطياً مستقراً مختلفاً قبل
// الفشل النهائي — لأن الازدحام غالباً يخص طابور نموذج واحد بعينه فقط.
async function callGemini(prompt: string, schema: unknown) {
  try {
    return await callGeminiModel(GEMINI_MODEL, prompt, schema);
  } catch (e) {
    const status = e instanceof GeminiHttpError ? e.status : undefined;
    if (!status || !GEMINI_RETRYABLE_STATUS.includes(status)) throw e;

    console.warn(
      `Primary model ${GEMINI_MODEL} exhausted retries (${status}) — falling back to ${GEMINI_FALLBACK_MODEL}`,
    );
    return await callGeminiModel(GEMINI_FALLBACK_MODEL, prompt, schema);
  }
}

// يبحث في YouTube عن فيديو تعليمي لاسم التمرين الإنجليزي القياسي. best-effort:
// أي فشل (مفتاح غير موجود/حصة منتهية/لا نتائج) يُرجع null بدلاً من رمي خطأ،
// لأن غياب الفيديو لا يجب أن يوقف توليد خطة التمارين بالكامل.
async function findYouTubeVideoUrl(exerciseName: string): Promise<string | null> {
  if (!YOUTUBE_API_KEY) return null;

  try {
    const query = `${exerciseName} exercise proper form tutorial`;
    const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&maxResults=1&q=${
      encodeURIComponent(query)
    }&key=${YOUTUBE_API_KEY}`;

    const res = await fetch(url);
    if (!res.ok) {
      console.error(`YouTube API error (${res.status}): ${await res.text()}`);
      return null;
    }

    const json = await res.json();
    const videoId = json.items?.[0]?.id?.videoId;
    return videoId ? `https://www.youtube.com/watch?v=${videoId}` : null;
  } catch (e) {
    console.error(`YouTube lookup failed for "${exerciseName}":`, e);
    return null;
  }
}

// يربط فيديو تعليمي بتمرين لا يملك واحداً بعد (مرة واحدة لكل تمرين فريد في
// المكتبة المشتركة، وليس لكل مستخدم/خطة) — لا يرمي خطأ عند الفشل.
async function attachVideoIfMissing(admin: any, exerciseId: string, exerciseName: string) {
  const videoUrl = await findYouTubeVideoUrl(exerciseName);
  if (!videoUrl) return;
  await admin.from("exercises").update({ video_url: videoUrl }).eq("id", exerciseId);
}

async function resolveExerciseId(admin: any, ex: any): Promise<string> {
  const { data: existing } = await admin
    .from("exercises")
    .select("id, video_url")
    .ilike("name", ex.name)
    .maybeSingle();

  if (existing) {
    if (!existing.video_url) {
      await attachVideoIfMissing(admin, existing.id, ex.name);
    }
    return existing.id;
  }

  const { data: inserted, error } = await admin
    .from("exercises")
    .insert({
      name: ex.name,
      description: ex.description ?? null,
      target_muscle: ex.target_muscle,
      secondary_muscles: ex.secondary_muscles ?? [],
      equipment_needed: ex.equipment_needed ?? "none",
      common_mistakes: ex.common_mistakes ?? null,
      is_home_friendly: ex.is_home_friendly ?? true,
    })
    .select("id")
    .single();

  if (error) throw error;

  await attachVideoIfMissing(admin, inserted.id, ex.name);

  return inserted.id;
}

// ==================== توليد وكتابة خطة التمارين ====================

async function generateWorkoutPlan(
  admin: any,
  userId: string,
  profile: any,
  locale: string,
) {
  const { data: conditions } = await admin
    .from("user_medical_conditions")
    .select("*")
    .eq("user_id", userId);

  // إصابة مسجّلة (injury) تحديداً — وليس مرض عام (disease) — تحوّل الخطة
  // بالكامل إلى خطة تأهيلية بدل خطة تمرين عادية، بناءً على طلب صريح.
  const hasInjury = (conditions ?? []).some(
    (c: any) => c.condition_type === "injury",
  );
  const prompt = hasInjury
    ? buildRehabPrompt(profile, conditions ?? [], locale)
    : buildWorkoutPrompt(profile, conditions ?? [], locale);
  const plan = await callGemini(prompt, WORKOUT_SCHEMA);

  await admin
    .from("workout_plans")
    .update({ is_active: false })
    .eq("user_id", userId)
    .eq("is_active", true);

  const { data: workoutPlan, error: wpError } = await admin
    .from("workout_plans")
    .insert({ user_id: userId, title: plan.workout_plan_title, is_active: true })
    .select("id")
    .single();
  if (wpError) throw wpError;

  for (const day of plan.workout_days) {
    const { data: workoutDay, error: wdError } = await admin
      .from("workout_days")
      .insert({
        workout_plan_id: workoutPlan.id,
        day_number: day.day_number,
        day_name: day.day_name,
        is_rest_day: day.is_rest_day,
      })
      .select("id")
      .single();
    if (wdError) throw wdError;

    if (day.is_rest_day) continue;

    for (const ex of day.exercises ?? []) {
      const exerciseId = await resolveExerciseId(admin, ex);
      const { error: weError } = await admin.from("workout_exercises").insert({
        workout_day_id: workoutDay.id,
        exercise_id: exerciseId,
        sets: ex.sets,
        reps_range: ex.reps_range,
        rest_seconds: ex.rest_seconds,
        order_index: ex.order_index,
      });
      if (weError) throw weError;
    }
  }

  return { workout_plan_id: workoutPlan.id };
}

// ==================== توليد وكتابة خطة التغذية ====================

async function generateMealPlan(admin: any, userId: string, profile: any, locale: string) {
  const prompt = buildMealPrompt(profile, locale);
  const plan = await callGemini(prompt, MEAL_SCHEMA);

  await admin
    .from("meal_plans")
    .update({ is_active: false })
    .eq("user_id", userId)
    .eq("is_active", true);

  // total_daily_calories على مستوى الخطة أصبح متوسطاً تقريبياً فقط (كل يوم
  // له سعراته الفعلية الخاصة في daily_meals عبر day_number)، محفوظ للتوافق
  // مع العمود الحالي في الجدول.
  const avgCalories = Math.round(
    plan.meal_days.reduce(
      (sum: number, d: any) => sum + d.total_daily_calories,
      0,
    ) / plan.meal_days.length,
  );

  const { data: mealPlan, error: mpError } = await admin
    .from("meal_plans")
    .insert({
      user_id: userId,
      is_active: true,
      total_daily_calories: avgCalories,
    })
    .select("id")
    .single();
  if (mpError) throw mpError;

  for (const day of plan.meal_days) {
    for (const meal of day.meals ?? []) {
      const { error: dmError } = await admin.from("daily_meals").insert({
        meal_plan_id: mealPlan.id,
        day_number: day.day_number,
        meal_type: meal.meal_type,
        food_name: meal.food_name,
        portion_description: meal.portion_description ?? null,
        calories: meal.calories,
        protein_g: meal.protein_g,
        carbs_g: meal.carbs_g,
        fats_g: meal.fats_g,
        alternatives: meal.alternatives ?? null,
      });
      if (dmError) throw dmError;
    }
  }

  for (const supplement of plan.supplements ?? []) {
    const { error: srError } = await admin
      .from("supplement_recommendations")
      .insert({
        user_id: userId,
        meal_plan_id: mealPlan.id,
        name: supplement.name,
        category: supplement.category,
        dosage: supplement.dosage ?? null,
        timing: supplement.timing ?? null,
        reason: supplement.reason ?? null,
      });
    if (srError) throw srError;
  }

  return { meal_plan_id: mealPlan.id };
}

// ==================== المعالج الرئيسي ====================

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
    const locale = body.locale === "en" ? "en" : "ar";
    const type = body.type === "meal" ? "meal" : "workout";

    // عميل بصلاحية service_role للكتابة في جدول exercises المشترك ولضمان
    // اكتمال إنشاء الخطة كاملة (كل جداولها) دون التعثر بسياسات RLS الجزئية.
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("*")
      .eq("id", user.id)
      .single();
    if (profileError) throw profileError;

    const result =
      type === "meal"
        ? await generateMealPlan(admin, user.id, profile, locale)
        : await generateWorkoutPlan(admin, user.id, profile, locale);

    return new Response(JSON.stringify({ success: true, ...result }), {
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
