-- جدول جديد بالكامل: يسجّل فعلياً أي وجبة مخطَّطة أكلها المستخدم في أي
-- تاريخ، مطابق تماماً لنمط exercise_completions — ليبقى محفوظاً بعد إغلاق
-- التطبيق، ومقيَّد بتاريخ اليوم (completion_date) لأن نفس daily_meals.id
-- يتكرر أسبوعياً (خطة التغذية دورة 7 أيام). يُستخدم فقط لتحديد حالة اليوم
-- (✓/✗) في شريط اختيار الأيام بتبويب التغذية — لا علاقة له بـ
-- daily_checkins.followed_diet (المستخدَم في نظام النقاط/الستريك ويبقى يدوياً).
CREATE TABLE IF NOT EXISTS public.meal_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  daily_meal_id UUID NOT NULL REFERENCES public.daily_meals (id) ON DELETE CASCADE,
  completion_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS meal_completions_unique_idx
  ON public.meal_completions (user_id, daily_meal_id, completion_date);

ALTER TABLE public.meal_completions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "meal_completions_select_own" ON public.meal_completions;
CREATE POLICY "meal_completions_select_own" ON public.meal_completions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "meal_completions_insert_own" ON public.meal_completions;
CREATE POLICY "meal_completions_insert_own" ON public.meal_completions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
