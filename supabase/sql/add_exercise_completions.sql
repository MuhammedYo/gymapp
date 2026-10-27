-- جدول جديد بالكامل: يسجّل فعلياً أي تمرين أنهاه المستخدم في أي تاريخ،
-- ليبقى محفوظاً بعد إغلاق التطبيق وإعادة فتحه (بدل الاعتماد على ذاكرة
-- الجلسة فقط). مقيَّد بتاريخ اليوم (completion_date) عمداً — لأن نفس
-- workout_exercises.id يتكرر أسبوعياً (الخطة دورة 7 أيام)، فيجب أن يبدأ
-- التمرين "فارغاً" من جديد في الأسبوع التالي لنفس اليوم.
CREATE TABLE IF NOT EXISTS public.exercise_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  workout_exercise_id UUID NOT NULL REFERENCES public.workout_exercises (id) ON DELETE CASCADE,
  completion_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS exercise_completions_unique_idx
  ON public.exercise_completions (user_id, workout_exercise_id, completion_date);

ALTER TABLE public.exercise_completions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "exercise_completions_select_own" ON public.exercise_completions;
CREATE POLICY "exercise_completions_select_own" ON public.exercise_completions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "exercise_completions_insert_own" ON public.exercise_completions;
CREATE POLICY "exercise_completions_insert_own" ON public.exercise_completions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
