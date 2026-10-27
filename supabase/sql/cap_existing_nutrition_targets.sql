-- يطبّق الحدود الجديدة (ماء بحد أقصى 3 لتر، سعرات بين 1200 و4000) على
-- الحسابات الموجودة مسبقاً فوراً، دون الحاجة لإعادة Onboarding. آمن التكرار.
UPDATE public.profiles
SET water_goal_liters = 3.0
WHERE water_goal_liters > 3.0;

UPDATE public.profiles
SET target_calories = 4000
WHERE target_calories > 4000;

UPDATE public.profiles
SET target_calories = 1200
WHERE target_calories IS NOT NULL AND target_calories < 1200;
