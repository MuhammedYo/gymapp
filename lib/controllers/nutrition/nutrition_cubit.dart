import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/plan_day_calculator.dart';
import 'nutrition_state.dart';

class NutritionCubit extends Cubit<NutritionState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  NutritionCubit() : super(NutritionLoading());

  Future<void> fetchMealPlan() async {
    try {
      emit(NutritionLoading());

      final userId = _supabase.auth.currentUser!.id;

      final plan = await _supabase
          .from('meal_plans')
          .select('id, created_at')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (plan == null) {
        emit(NutritionNoActivePlan());
        return;
      }

      final mealsFuture = _supabase
          .from('daily_meals')
          .select()
          .eq('meal_plan_id', plan['id'])
          .order('day_number');
      final supplementsFuture = _supabase
          .from('supplement_recommendations')
          .select()
          .eq('meal_plan_id', plan['id']);

      final meals = await mealsFuture;
      final supplementRows = await supplementsFuture;

      final byDay = <int, List<MealItemData>>{};
      for (final row in meals.cast<Map<String, dynamic>>()) {
        final dayNumber = (row['day_number'] as num?)?.toInt() ?? 1;
        byDay.putIfAbsent(dayNumber, () => []).add(MealItemData.fromMap(row));
      }

      final days = byDay.entries
          .map((e) => MealDayData(dayNumber: e.key, meals: e.value))
          .toList()
        ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

      final supplements = supplementRows
          .cast<Map<String, dynamic>>()
          .map(SupplementData.fromMap)
          .toList();

      final createdAt = DateTime.parse(plan['created_at'] as String);

      // نجلب الوجبات المُنهاة فعلياً عبر الدورة الأسبوعية الحالية كاملة،
      // لتحديد حالة كل يوم في شريط الاختيار (اكتمل/فائت/لم يأتِ) بدقة.
      final cycleStart = dateForPlanDayNumber(createdAt, 1);
      final cycleEnd = dateForPlanDayNumber(createdAt, 7);
      final completions = await _supabase
          .from('meal_completions')
          .select('daily_meal_id, completion_date')
          .eq('user_id', userId)
          .gte('completion_date', _formatDate(cycleStart))
          .lte('completion_date', _formatDate(cycleEnd));

      final completionsByDate = <String, Set<String>>{};
      for (final row in completions.cast<Map<String, dynamic>>()) {
        final date = row['completion_date'] as String;
        completionsByDate
            .putIfAbsent(date, () => {})
            .add(row['daily_meal_id'] as String);
      }

      emit(NutritionLoaded(
        MealPlanData(
          createdAt: createdAt,
          days: days,
          supplements: supplements,
        ),
        completionsByDate: completionsByDate,
      ));
    } catch (e) {
      emit(NutritionError(e.toString()));
    }
  }

  /// يُستدعى عند تأشير المستخدم فعلياً على وجبة بأنها أُكلت (من شاشة
  /// التغذية). يُحدَّث محلياً فوراً ثم يُحفَظ في قاعدة البيانات (best-effort:
  /// فشل الحفظ لا يُلغي العلامة المحلية الفورية التي يراها المستخدم).
  Future<void> markMealCompleted(String dailyMealId) async {
    final current = state;
    if (current is! NutritionLoaded) return;
    final todayStr = _formatDate(DateTime.now());
    if ((current.completionsByDate[todayStr] ?? const {})
        .contains(dailyMealId)) {
      return;
    }

    final updated = Map<String, Set<String>>.from(current.completionsByDate);
    updated[todayStr] = {...(updated[todayStr] ?? const {}), dailyMealId};
    emit(NutritionLoaded(current.plan, completionsByDate: updated));

    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('meal_completions').insert({
        'user_id': userId,
        'daily_meal_id': dailyMealId,
        'completion_date': todayStr,
      });
    } catch (_) {
      // best-effort — العلامة المحلية تبقى كما هي حتى لو فشل الحفظ.
    }
  }

  /// هل أنهى المستخدم كل وجبات هذا اليوم فعلياً (بعد آخر تحديث حالة)؟
  /// يُستخدم لتفعيل بطاقة "النظام الغذائي" في الرئيسية تلقائياً — نفس نمط
  /// isDayFullyCompleted في WorkoutCubit.
  bool isDayFullyCompleted(MealDayData day) {
    final current = state;
    if (current is! NutritionLoaded) return false;
    if (day.meals.isEmpty) return false;
    final todayStr = _formatDate(DateTime.now());
    final completedToday = current.completionsByDate[todayStr] ?? const {};
    return day.meals.every((m) => completedToday.contains(m.id));
  }

  /// حالة يوم معيّن (اكتمل/فائت/اليوم/لم يأتِ) لعرضها كعلامة صح/خطأ في
  /// شريط اختيار الأيام، بناءً على عدد الوجبات المخطَّطة فعلياً المؤكَّدة في
  /// تاريخه الحقيقي هذا الأسبوع.
  PlanDayStatus dayStatus(MealDayData day) {
    final current = state;
    if (current is! NutritionLoaded) return PlanDayStatus.future;
    if (day.meals.isEmpty) return PlanDayStatus.future;

    final targetDate =
        dateForPlanDayNumber(current.plan.createdAt, day.dayNumber);
    final completedForDate =
        current.completionsByDate[_formatDate(targetDate)] ?? const {};
    final allDone = day.meals.every((m) => completedForDate.contains(m.id));

    return planDayStatus(targetDate: targetDate, isCompleted: allDone);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
