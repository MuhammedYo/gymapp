-- ==========================================
-- منطق حساب الأيام المتتالية (streak) والنقاط والمستوى تلقائياً
-- في كل مرة يُدرج/يُعدَّل فيها صف في daily_checkins.
--
-- الافتراضات (قابلة للتعديل لاحقاً):
--   - يوم "ناجح" لغرض الستريك = التزام بالنظام الغذائي أو إتمام التمرين.
--   - النقاط: +10 نظام غذائي، +10 تمرين، +5 عند بلوغ هدف الماء
--     (profiles.water_goal_liters، أو 2.5L افتراضياً إن لم يُحسب بعد)،
--     تُمنح مرة واحدة فقط لكل يوم (لا تتكرر عند التعديل المتكرر لنفس القيمة).
--   - المستوى = 1 + (إجمالي النقاط ÷ 200).
-- ==========================================

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

  -- لا نعيد حساب الستريك إن كان هذا مجرد تعديل لنفس يوم آخر تسجيل محفوظ
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

  -- النقاط تُمنح فقط عن الانتقال إلى true لتفادي منحها مرات متكررة
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
