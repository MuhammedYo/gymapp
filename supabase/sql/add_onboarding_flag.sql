-- ==========================================
-- علم بسيط لمعرفة هل أكمل المستخدم استمارة البيانات الأولية (Onboarding)
-- تُستخدم لتوجيه AuthGate: onboarding_completed = false -> OnboardingScreen
--                            onboarding_completed = true  -> HomeScreen
-- ==========================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;
