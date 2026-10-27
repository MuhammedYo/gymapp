import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/plan_day_calculator.dart';
import 'workout_state.dart';

class WorkoutCubit extends Cubit<WorkoutState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  WorkoutCubit() : super(WorkoutLoading());

  Future<void> fetchWorkoutPlan() async {
    try {
      emit(WorkoutLoading());

      final userId = _supabase.auth.currentUser!.id;

      final plan = await _supabase
          .from('workout_plans')
          .select('id, title, created_at')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (plan == null) {
        emit(WorkoutNoActivePlan());
        return;
      }

      // جلب كل أيام الخطة مع تماريها وبيانات التمرين المرجعية في طلب واحد
      // (embedded select) بدل استعلام منفصل لكل يوم/تمرين.
      final days = await _supabase
          .from('workout_days')
          .select('*, workout_exercises(*, exercises(*))')
          .eq('workout_plan_id', plan['id'])
          .order('day_number');

      final dayList = days
          .cast<Map<String, dynamic>>()
          .map(WorkoutDayData.fromMap)
          .toList();

      final createdAt = DateTime.parse(plan['created_at'] as String);

      // نجلب التمارين المُنهاة عبر أسبوع التقويم الحالي كاملاً (الاثنين إلى
      // الأحد، بما أن day_number يطابق يوم الأسبوع الحقيقي الآن)، لنعرف حالة
      // كل يوم في شريط الاختيار (اكتمل/فائت/لم يأتِ).
      final cycleStart = dateForIsoWeekday(1);
      final cycleEnd = dateForIsoWeekday(7);
      final completions = await _supabase
          .from('exercise_completions')
          .select('workout_exercise_id, completion_date')
          .eq('user_id', userId)
          .gte('completion_date', _formatDate(cycleStart))
          .lte('completion_date', _formatDate(cycleEnd));

      final completionsByDate = <String, Set<String>>{};
      for (final row in completions.cast<Map<String, dynamic>>()) {
        final date = row['completion_date'] as String;
        completionsByDate
            .putIfAbsent(date, () => {})
            .add(row['workout_exercise_id'] as String);
      }

      emit(WorkoutLoaded(
        WorkoutPlanData(
          title: plan['title'] as String? ?? '',
          createdAt: createdAt,
          days: dayList,
        ),
        completionsByDate: completionsByDate,
      ));
    } catch (e) {
      emit(WorkoutError(e.toString()));
    }
  }

  /// يُستدعى عند إنهاء المستخدم فعلياً لكل مجموعات تمرين واحد (من شاشة
  /// الجلسة). يُحدَّث محلياً فوراً ثم يُحفَظ في قاعدة البيانات (best-effort:
  /// فشل الحفظ لا يُلغي العلامة المحلية الفورية التي يراها المستخدم).
  Future<void> markExerciseCompleted(String workoutExerciseId) async {
    final current = state;
    if (current is! WorkoutLoaded) return;
    final todayStr = _formatDate(DateTime.now());
    if ((current.completionsByDate[todayStr] ?? const {})
        .contains(workoutExerciseId)) {
      return;
    }

    final updated = Map<String, Set<String>>.from(current.completionsByDate);
    updated[todayStr] = {...(updated[todayStr] ?? const {}), workoutExerciseId};
    emit(WorkoutLoaded(current.plan, completionsByDate: updated));

    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('exercise_completions').insert({
        'user_id': userId,
        'workout_exercise_id': workoutExerciseId,
        'completion_date': todayStr,
      });
    } catch (_) {
      // best-effort — العلامة المحلية تبقى كما هي حتى لو فشل الحفظ.
    }
  }

  /// هل أنهى المستخدم كل تمارين هذا اليوم فعلياً (بعد آخر تحديث حالة)؟
  bool isDayFullyCompleted(WorkoutDayData day) {
    final current = state;
    if (current is! WorkoutLoaded) return false;
    if (day.exercises.isEmpty) return false;
    return day.exercises
        .every((ex) => current.completedExerciseIds.contains(ex.id));
  }

  /// حالة يوم معيّن (اكتمل/فائت/اليوم/لم يأتِ) لعرضها كعلامة صح/خطأ في
  /// شريط اختيار الأيام. أيام الراحة تبقى محايدة دائماً (لا شيء "يُفوَّت").
  PlanDayStatus dayStatus(WorkoutDayData day) {
    final current = state;
    if (current is! WorkoutLoaded) return PlanDayStatus.future;
    if (day.isRestDay || day.exercises.isEmpty) return PlanDayStatus.future;

    final targetDate = dateForIsoWeekday(day.dayNumber);

    // إن كان تاريخ هذا اليوم (ضمن أسبوع التقويم الحالي) قبل تاريخ إنشاء
    // الخطة نفسه، فهذا يعني أن الخطة لم تكن موجودة بعد في ذلك اليوم — مثلاً
    // خطة أُنشئت يوم الجمعة، فأيام الاثنين/الأربعاء/الخميس من نفس الأسبوع
    // التقويمي سابقة لبدء الخطة، ولا يصح اعتبارها "فائتة".
    final createdAt = current.plan.createdAt;
    final planStartDate =
        DateTime(createdAt.year, createdAt.month, createdAt.day);
    if (targetDate.isBefore(planStartDate)) return PlanDayStatus.future;

    final completedForDate =
        current.completionsByDate[_formatDate(targetDate)] ?? const {};
    final allDone =
        day.exercises.every((ex) => completedForDate.contains(ex.id));

    return planDayStatus(targetDate: targetDate, isCompleted: allDone);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
