import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/plan_day_calculator.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  HomeCubit() : super(HomeInitial());

  Future<void> fetchHomeData({bool silent = false}) async {
    try {
      // silent: نتجنب إظهار مؤشر التحميل الكامل عند إعادة الجلب بعد Check-in
      // أو Pull-to-refresh طالما هناك بيانات معروضة بالفعل.
      if (!(silent && state is HomeLoaded)) {
        emit(HomeLoading());
      }

      final userId = _supabase.auth.currentUser!.id;
      final todayDate = _formatDate(DateTime.now());

      // نُطلق الاستعلامات المستقلة معاً (concurrently) ثم ننتظرها
      final profileFuture =
          _supabase.from('profiles').select().eq('id', userId).single();
      final checkinFuture = _supabase
          .from('daily_checkins')
          .select()
          .eq('user_id', userId)
          .eq('checkin_date', todayDate)
          .maybeSingle();
      final gamificationFuture = _supabase
          .from('user_gamification')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final workoutPlanFuture = _supabase
          .from('workout_plans')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();
      final mealPlanFuture = _supabase
          .from('meal_plans')
          .select('id, created_at')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      final profile = await profileFuture;
      final checkin = await checkinFuture;
      final gamification = await gamificationFuture;
      final workoutPlan = await workoutPlanFuture;
      final mealPlan = await mealPlanFuture;

      bool isRestDay = true;
      String workoutDayName = '';
      int workoutExerciseCount = 0;

      if (workoutPlan != null) {
        // day_number لخطة التمارين يطابق يوم الأسبوع الحقيقي (ISO)، بعد
        // اختيار المستخدم أيام تمرينه الفعلية في Onboarding.
        final todayDayNumber = currentIsoWeekday();

        final workoutDay = await _supabase
            .from('workout_days')
            .select()
            .eq('workout_plan_id', workoutPlan['id'])
            .eq('day_number', todayDayNumber)
            .maybeSingle();

        if (workoutDay != null) {
          isRestDay = workoutDay['is_rest_day'] as bool? ?? false;
          workoutDayName = workoutDay['day_name'] as String? ?? '';

          if (!isRestDay) {
            final exercises = await _supabase
                .from('workout_exercises')
                .select('id')
                .eq('workout_day_id', workoutDay['id']);
            workoutExerciseCount = exercises.length;
          }
        }
      }

      int consumedCalories = 0;
      double consumedProteinG = 0;
      double consumedCarbsG = 0;
      double consumedFatsG = 0;

      if (mealPlan != null) {
        final mealPlanCreatedAt =
            DateTime.parse(mealPlan['created_at'] as String);
        final todayMealDayNumber = calculatePlanDayNumber(mealPlanCreatedAt);

        final meals = await _supabase
            .from('daily_meals')
            .select()
            .eq('meal_plan_id', mealPlan['id'])
            .eq('day_number', todayMealDayNumber);

        for (final meal in meals) {
          consumedCalories += (meal['calories'] as num?)?.toInt() ?? 0;
          consumedProteinG += (meal['protein_g'] as num?)?.toDouble() ?? 0;
          consumedCarbsG += (meal['carbs_g'] as num?)?.toDouble() ?? 0;
          consumedFatsG += (meal['fats_g'] as num?)?.toDouble() ?? 0;
        }
      }

      emit(HomeLoaded(HomeData(
        fullName: profile['full_name'] as String? ?? '',
        targetCalories: (profile['target_calories'] as num?)?.toInt() ?? 0,
        proteinG: (profile['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (profile['carbs_g'] as num?)?.toDouble() ?? 0,
        fatsG: (profile['fats_g'] as num?)?.toDouble() ?? 0,
        streakDays:
            (gamification?['current_streak_days'] as num?)?.toInt() ?? 0,
        totalPoints: (gamification?['total_points'] as num?)?.toInt() ?? 0,
        currentLevel: (gamification?['current_level'] as num?)?.toInt() ?? 1,
        followedDiet: checkin?['followed_diet'] as bool? ?? false,
        completedWorkout: checkin?['completed_workout'] as bool? ?? false,
        waterLiters: (checkin?['water_liters'] as num?)?.toDouble() ?? 0,
        waterGoalLiters:
            (profile['water_goal_liters'] as num?)?.toDouble() ?? 2.5,
        hasActiveWorkoutPlan: workoutPlan != null,
        isRestDay: isRestDay,
        workoutDayName: workoutDayName,
        workoutExerciseCount: workoutExerciseCount,
        hasActiveMealPlan: mealPlan != null,
        consumedCalories: consumedCalories,
        consumedProteinG: consumedProteinG,
        consumedCarbsG: consumedCarbsG,
        consumedFatsG: consumedFatsG,
      )));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> toggleDiet(bool value) async {
    await _upsertTodayCheckin({'followed_diet': value});
    await _refreshAfterCheckin(followedDiet: value);
  }

  Future<void> toggleWorkout(bool value) async {
    await _upsertTodayCheckin({'completed_workout': value});
    await _refreshAfterCheckin(completedWorkout: value);
  }

  Future<void> addWater(double deltaLiters) async {
    final current =
        state is HomeLoaded ? (state as HomeLoaded).data.waterLiters : 0.0;
    final newValue = (current + deltaLiters).clamp(0, 15).toDouble();
    await _upsertTodayCheckin({'water_liters': newValue});
    await _refreshAfterCheckin(waterLiters: newValue);
  }

  /// بعد تسجيل check-in لا نعيد جلب كل شيء (profile/plans/meals)، فقط نحدّث
  /// الحقول المتأثرة محلياً ونجلب user_gamification فقط (تحدّثه trigger في
  /// قاعدة البيانات) — يوفّر عدة طلبات شبكة غير ضرورية في كل ضغطة.
  Future<void> _refreshAfterCheckin({
    bool? followedDiet,
    bool? completedWorkout,
    double? waterLiters,
  }) async {
    final current = state;
    if (current is! HomeLoaded) return;

    final userId = _supabase.auth.currentUser!.id;
    final gamification = await _supabase
        .from('user_gamification')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    emit(HomeLoaded(current.data.copyWith(
      followedDiet: followedDiet,
      completedWorkout: completedWorkout,
      waterLiters: waterLiters,
      streakDays: (gamification?['current_streak_days'] as num?)?.toInt(),
      totalPoints: (gamification?['total_points'] as num?)?.toInt(),
      currentLevel: (gamification?['current_level'] as num?)?.toInt(),
    )));
  }

  /// يحدّث صف daily_checkins الخاص باليوم الحالي، أو يُنشئه إن لم يكن موجوداً
  /// (upsert يدوي لأن الحقول الأخرى غير المُمرَّرة يجب أن تبقى كما هي).
  Future<void> _upsertTodayCheckin(Map<String, dynamic> fields) async {
    final userId = _supabase.auth.currentUser!.id;
    final todayDate = _formatDate(DateTime.now());

    final updated = await _supabase
        .from('daily_checkins')
        .update(fields)
        .eq('user_id', userId)
        .eq('checkin_date', todayDate)
        .select();

    if (updated.isEmpty) {
      await _supabase.from('daily_checkins').insert({
        'user_id': userId,
        'checkin_date': todayDate,
        ...fields,
      });
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
