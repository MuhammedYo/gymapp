-- يضيف ترقيم الأيام لجدول daily_meals (نفس فكرة day_number في workout_days):
-- day_number=1 هو يوم إنشاء خطة التغذية، ويتكرر كل 7 أيام. يسمح هذا بتنويع
-- الوجبات فعلياً على مدار الأسبوع بدل تكرار نفس اليوم كل يوم.
ALTER TABLE public.daily_meals
  ADD COLUMN IF NOT EXISTS day_number SMALLINT NOT NULL DEFAULT 1
  CHECK (day_number BETWEEN 1 AND 7);
