-- يضيف تفضيلات جدولة التمارين: الأيام الفعلية المختارة (1=الاثنين ISO
-- ... 7=الأحد) والساعة المفضّلة، تُملأ من Onboarding وتُستخدم مباشرة عند
-- توليد خطة التمارين (day_number في workout_days يطابقها بالضبط الآن).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS preferred_workout_days SMALLINT[],
  ADD COLUMN IF NOT EXISTS preferred_workout_time TIME;
