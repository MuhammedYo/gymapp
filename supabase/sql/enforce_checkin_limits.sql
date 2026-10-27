-- ==========================================
-- إغلاق ثغرة تبديل الحالة (toggle) للحصول على نقاط بلا حدود:
--   - بعد تفعيل "النظام الغذائي" أو "التمرين" لليوم، لا يمكن إلغاؤه لنفس اليوم
--     (يعود تلقائياً false في اليوم التالي لأن كل يوم صف مستقل في daily_checkins).
--   - كمية الماء لا يمكن أن تتجاوز هدف اليوم (profiles.water_goal_liters).
-- تعمل BEFORE INSERT/UPDATE فتُصحح القيمة قبل أن تصل لجدول gamification_trigger.
-- ==========================================

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
