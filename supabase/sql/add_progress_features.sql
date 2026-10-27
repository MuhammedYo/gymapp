-- ==========================================
-- يضيف كل ما يلزم لتبويب "التقدم": الأوسمة (badges) التلقائية + تخزين
-- صور تحليل الجسم بالذكاء الاصطناعي (body_scans). شغّل هذا الملف مرة واحدة
-- في Supabase SQL Editor (أو استخدم run_all.sql المحدَّث الذي يتضمنه).
-- ==========================================

-- 1) أعمدة جدول الأوسمة badges (إضافة فقط، لا تُلمس أي أعمدة موجودة مسبقاً)
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

-- 2) جدول user_badges (ربط مستخدم ↔ وسام)
ALTER TABLE public.user_badges
  ADD COLUMN IF NOT EXISTS earned_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS user_badges_user_badge_uidx
  ON public.user_badges (user_id, badge_id);

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_badges_select_own" ON public.user_badges;
CREATE POLICY "user_badges_select_own" ON public.user_badges
  FOR SELECT USING (auth.uid() = user_id);

-- 3) الأوسمة الافتراضية (آمنة التكرار)
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

-- 4) توسيع دالة الـ trigger الحالية (handle_checkin_gamification) لمنح
--    الأوسمة تلقائياً عند بلوغ الشرط، دون تكرار المنح (ON CONFLICT DO NOTHING)
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

-- 5) أعمدة جدول body_scans (صور تحليل الجسم بالذكاء الاصطناعي)
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

-- 6) Storage bucket خاص (private) لصور تحليل الجسم + سياسات وصول لكل مستخدم
--    لمجلده الخاص فقط (المسار: <user_id>/<اسم الملف>)
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
