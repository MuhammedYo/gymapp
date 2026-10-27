-- ==========================================
-- شغّل هذا الملف كاملاً مرة واحدة في Supabase SQL Editor.
-- يجمع كل الإضافات التي بنيناها حتى الآن، بالترتيب الصحيح.
-- ==========================================

-- 1) إنشاء profile + user_gamification تلقائياً لأي مستخدم جديد
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_gamification (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 2) علم إكمال Onboarding
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- 3) هدف الماء اليومي
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS water_goal_liters NUMERIC(3, 1);

-- 4) حساب الستريك/النقاط/المستوى تلقائياً عند كل check-in
ALTER TABLE public.user_gamification
  ADD COLUMN IF NOT EXISTS last_checkin_date DATE;

CREATE OR REPLACE FUNCTION public.handle_checkin_gamification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_last_date DATE;
  v_streak INT;
  v_points INT;
  v_earned INT := 0;
  v_day_success BOOLEAN;
  v_water_goal NUMERIC;
BEGIN
  v_day_success := COALESCE(NEW.followed_diet, FALSE) OR COALESCE(NEW.completed_workout, FALSE);

  SELECT COALESCE(water_goal_liters, 2.5) INTO v_water_goal
    FROM public.profiles WHERE id = NEW.user_id;

  SELECT last_checkin_date, current_streak_days, total_points
    INTO v_last_date, v_streak, v_points
    FROM public.user_gamification
    WHERE user_id = NEW.user_id
    FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.user_gamification (user_id) VALUES (NEW.user_id);
    v_last_date := NULL;
    v_streak := 0;
    v_points := 0;
  END IF;

  IF v_last_date IS DISTINCT FROM NEW.checkin_date THEN
    IF v_day_success THEN
      IF v_last_date IS NOT NULL AND NEW.checkin_date = v_last_date + INTERVAL '1 day' THEN
        v_streak := v_streak + 1;
      ELSE
        v_streak := 1;
      END IF;
    ELSE
      v_streak := 0;
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.followed_diet, FALSE) THEN v_earned := v_earned + 10; END IF;
    IF COALESCE(NEW.completed_workout, FALSE) THEN v_earned := v_earned + 10; END IF;
    IF COALESCE(NEW.water_liters, 0) >= v_water_goal THEN v_earned := v_earned + 5; END IF;
  ELSE
    IF COALESCE(NEW.followed_diet, FALSE) AND NOT COALESCE(OLD.followed_diet, FALSE) THEN
      v_earned := v_earned + 10;
    END IF;
    IF COALESCE(NEW.completed_workout, FALSE) AND NOT COALESCE(OLD.completed_workout, FALSE) THEN
      v_earned := v_earned + 10;
    END IF;
    IF COALESCE(NEW.water_liters, 0) >= v_water_goal AND COALESCE(OLD.water_liters, 0) < v_water_goal THEN
      v_earned := v_earned + 5;
    END IF;
  END IF;

  v_points := v_points + v_earned;

  UPDATE public.user_gamification
  SET
    current_streak_days = v_streak,
    total_points = v_points,
    current_level = 1 + (v_points / 200),
    last_checkin_date = NEW.checkin_date
  WHERE user_id = NEW.user_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_checkin_upsert ON public.daily_checkins;

CREATE TRIGGER on_checkin_upsert
  AFTER INSERT OR UPDATE ON public.daily_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_checkin_gamification();

-- 5) إغلاق ثغرة تبديل الحالة للحصول على نقاط بلا حدود، وتقييد كمية الماء بالهدف
CREATE OR REPLACE FUNCTION public.enforce_checkin_limits()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_water_goal NUMERIC;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.followed_diet = TRUE AND NEW.followed_diet = FALSE THEN
      NEW.followed_diet := TRUE;
    END IF;
    IF OLD.completed_workout = TRUE AND NEW.completed_workout = FALSE THEN
      NEW.completed_workout := TRUE;
    END IF;
  END IF;

  SELECT COALESCE(water_goal_liters, 2.5) INTO v_water_goal
    FROM public.profiles WHERE id = NEW.user_id;

  IF NEW.water_liters IS NOT NULL THEN
    NEW.water_liters := LEAST(NEW.water_liters, v_water_goal);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS before_checkin_enforce ON public.daily_checkins;

CREATE TRIGGER before_checkin_enforce
  BEFORE INSERT OR UPDATE ON public.daily_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_checkin_limits();

-- 6) تعويض (backfill) أي حسابات أُنشئت قبل هذا الإعداد ولا تملك
--    صفوف profiles / user_gamification بعد (آمن التكرار: ON CONFLICT DO NOTHING)
INSERT INTO public.profiles (id, full_name)
SELECT u.id, u.raw_user_meta_data->>'full_name'
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;

INSERT INTO public.user_gamification (user_id)
SELECT u.id
FROM auth.users u
LEFT JOIN public.user_gamification g ON g.user_id = u.id
WHERE g.user_id IS NULL;

-- 7) ترقيم الأيام لخطة التغذية (day_number=1 هو يوم إنشاء الخطة، يتكرر كل
--    7 أيام) للسماح بتنويع الوجبات أسبوعياً بدل تكرار نفس اليوم دائماً.
ALTER TABLE public.daily_meals
  ADD COLUMN IF NOT EXISTS day_number SMALLINT NOT NULL DEFAULT 1
  CHECK (day_number BETWEEN 1 AND 7);

-- 8) أعمدة جدول الأوسمة badges (إضافة فقط)
ALTER TABLE public.badges
  ADD COLUMN IF NOT EXISTS code TEXT,
  ADD COLUMN IF NOT EXISTS name_ar TEXT,
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS description_ar TEXT,
  ADD COLUMN IF NOT EXISTS description_en TEXT,
  ADD COLUMN IF NOT EXISTS icon TEXT,
  ADD COLUMN IF NOT EXISTS requirement_type TEXT,
  ADD COLUMN IF NOT EXISTS requirement_value INT;

CREATE UNIQUE INDEX IF NOT EXISTS badges_code_uidx ON public.badges (code);

ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "badges_select_all" ON public.badges;
CREATE POLICY "badges_select_all" ON public.badges FOR SELECT USING (true);

ALTER TABLE public.user_badges
  ADD COLUMN IF NOT EXISTS earned_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS user_badges_user_badge_uidx
  ON public.user_badges (user_id, badge_id);

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_badges_select_own" ON public.user_badges;
CREATE POLICY "user_badges_select_own" ON public.user_badges
  FOR SELECT USING (auth.uid() = user_id);

-- 9) الأوسمة الافتراضية (آمنة التكرار)
-- ملاحظة: جدول badges يحتوي عمود "name" قديماً (NOT NULL) من المخطط الأصلي،
-- نملؤه بنفس قيمة name_en لضمان توافقه دون التأثير على أي استخدام سابق له.
INSERT INTO public.badges
  (name, code, name_ar, name_en, description_ar, description_en, icon, requirement_type, requirement_value)
VALUES
  ('3-Day Streak', 'streak_3', 'ملتزم 3 أيام', '3-Day Streak', 'حافظت على التزامك 3 أيام متتالية', 'Kept your streak for 3 consecutive days', '🔥', 'streak_days', 3),
  ('7-Day Streak', 'streak_7', 'ملتزم أسبوع', '7-Day Streak', 'حافظت على التزامك 7 أيام متتالية', 'Kept your streak for 7 consecutive days', '🔥', 'streak_days', 7),
  ('30-Day Streak', 'streak_30', 'بطل الشهر', '30-Day Streak', 'حافظت على التزامك 30 يوماً متتالياً', 'Kept your streak for 30 consecutive days', '🏆', 'streak_days', 30),
  ('100 Points', 'points_100', '100 نقطة', '100 Points', 'جمعت 100 نقطة', 'Earned 100 points', '⭐', 'total_points', 100),
  ('500 Points', 'points_500', '500 نقطة', '500 Points', 'جمعت 500 نقطة', 'Earned 500 points', '⭐', 'total_points', 500),
  ('1000 Points', 'points_1000', 'نخبة اللياقة', '1000 Points', 'جمعت 1000 نقطة', 'Earned 1000 points', '💎', 'total_points', 1000)
ON CONFLICT (code) DO NOTHING;

-- 10) توسيع دالة الـ trigger الحالية لمنح الأوسمة تلقائياً عند بلوغ الشرط
CREATE OR REPLACE FUNCTION public.handle_checkin_gamification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_last_date DATE;
  v_streak INT;
  v_points INT;
  v_earned INT := 0;
  v_day_success BOOLEAN;
  v_water_goal NUMERIC;
BEGIN
  v_day_success := COALESCE(NEW.followed_diet, FALSE) OR COALESCE(NEW.completed_workout, FALSE);

  SELECT COALESCE(water_goal_liters, 2.5) INTO v_water_goal
    FROM public.profiles WHERE id = NEW.user_id;

  SELECT last_checkin_date, current_streak_days, total_points
    INTO v_last_date, v_streak, v_points
    FROM public.user_gamification
    WHERE user_id = NEW.user_id
    FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.user_gamification (user_id) VALUES (NEW.user_id);
    v_last_date := NULL;
    v_streak := 0;
    v_points := 0;
  END IF;

  IF v_last_date IS DISTINCT FROM NEW.checkin_date THEN
    IF v_day_success THEN
      IF v_last_date IS NOT NULL AND NEW.checkin_date = v_last_date + INTERVAL '1 day' THEN
        v_streak := v_streak + 1;
      ELSE
        v_streak := 1;
      END IF;
    ELSE
      v_streak := 0;
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.followed_diet, FALSE) THEN v_earned := v_earned + 10; END IF;
    IF COALESCE(NEW.completed_workout, FALSE) THEN v_earned := v_earned + 10; END IF;
    IF COALESCE(NEW.water_liters, 0) >= v_water_goal THEN v_earned := v_earned + 5; END IF;
  ELSE
    IF COALESCE(NEW.followed_diet, FALSE) AND NOT COALESCE(OLD.followed_diet, FALSE) THEN
      v_earned := v_earned + 10;
    END IF;
    IF COALESCE(NEW.completed_workout, FALSE) AND NOT COALESCE(OLD.completed_workout, FALSE) THEN
      v_earned := v_earned + 10;
    END IF;
    IF COALESCE(NEW.water_liters, 0) >= v_water_goal AND COALESCE(OLD.water_liters, 0) < v_water_goal THEN
      v_earned := v_earned + 5;
    END IF;
  END IF;

  v_points := v_points + v_earned;

  UPDATE public.user_gamification
  SET
    current_streak_days = v_streak,
    total_points = v_points,
    current_level = 1 + (v_points / 200),
    last_checkin_date = NEW.checkin_date
  WHERE user_id = NEW.user_id;

  INSERT INTO public.user_badges (user_id, badge_id)
  SELECT NEW.user_id, b.id
  FROM public.badges b
  WHERE
    (b.requirement_type = 'streak_days' AND v_streak >= b.requirement_value) OR
    (b.requirement_type = 'total_points' AND v_points >= b.requirement_value)
  ON CONFLICT (user_id, badge_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- 11) أعمدة جدول body_scans (صور تحليل الجسم بالذكاء الاصطناعي)
ALTER TABLE public.body_scans
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS image_path TEXT,
  ADD COLUMN IF NOT EXISTS ai_summary TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.body_scans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "body_scans_select_own" ON public.body_scans;
CREATE POLICY "body_scans_select_own" ON public.body_scans
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "body_scans_insert_own" ON public.body_scans;
CREATE POLICY "body_scans_insert_own" ON public.body_scans
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "body_scans_update_own" ON public.body_scans;
CREATE POLICY "body_scans_update_own" ON public.body_scans
  FOR UPDATE USING (auth.uid() = user_id);

-- 12) Storage bucket خاص لصور تحليل الجسم + سياسات وصول لكل مستخدم لمجلده
--     الخاص فقط (المسار: <user_id>/<اسم الملف>)
INSERT INTO storage.buckets (id, name, public)
VALUES ('body-scans', 'body-scans', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "body_scans_storage_insert_own" ON storage.objects;
CREATE POLICY "body_scans_storage_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'body-scans' AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "body_scans_storage_select_own" ON storage.objects;
CREATE POLICY "body_scans_storage_select_own" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'body-scans' AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 13) توصيات مكملات غذائية رياضية عامة (جدول جديد بالكامل)، تُولَّد مع كل
--     خطة تغذية وترتبط بها. لا تشمل أي أدوية أو مواد تستدعي وصفة طبية.
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

-- 14) تسجيل إنهاء التمارين فعلياً (جدول جديد بالكامل)، ليبقى محفوظاً بعد
--     إغلاق التطبيق بدل الاعتماد على ذاكرة الجلسة فقط. مقيَّد بتاريخ اليوم
--     لأن نفس workout_exercises.id يتكرر أسبوعياً (دورة الخطة 7 أيام).
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

-- 15) تفضيلات جدولة التمارين: الأيام الفعلية المختارة (1=الاثنين ISO ...
--     7=الأحد) والساعة المفضّلة، من Onboarding. day_number في workout_days
--     يطابق هذه الأيام بالضبط الآن (وليس نسبياً لتاريخ إنشاء الخطة).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS preferred_workout_days SMALLINT[],
  ADD COLUMN IF NOT EXISTS preferred_workout_time TIME;

-- 16) تسجيل إنهاء الوجبات فعلياً (جدول جديد بالكامل)، مطابق تماماً لنمط
--     exercise_completions — يحدّد حالة اليوم (✓/✗) في شريط التغذية بدقة
--     حقيقية بدل الاعتماد فقط على daily_checkins.followed_diet اليدوي.
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
