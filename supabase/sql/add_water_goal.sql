-- ==========================================
-- هدف الماء اليومي (بالليتر)، يُحسب عند Onboarding بناءً على وزن الجسم
-- ==========================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS water_goal_liters NUMERIC(3, 1);
