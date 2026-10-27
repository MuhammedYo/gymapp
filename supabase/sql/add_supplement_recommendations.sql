-- جدول جديد بالكامل (لا يوجد مسبقاً في المخطط الأصلي): توصيات مكملات غذائية
-- رياضية عامة (بروتين، كرياتين، فيتامينات...) تُولَّد مع كل خطة تغذية،
-- وترتبط بها مباشرة. لا تشمل أي أدوية أو مواد تستدعي وصفة طبية.
CREATE TABLE IF NOT EXISTS public.supplement_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  meal_plan_id UUID NOT NULL REFERENCES public.meal_plans (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  dosage TEXT,
  timing TEXT,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.supplement_recommendations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "supplement_recommendations_select_own" ON public.supplement_recommendations;
CREATE POLICY "supplement_recommendations_select_own" ON public.supplement_recommendations
  FOR SELECT USING (auth.uid() = user_id);
