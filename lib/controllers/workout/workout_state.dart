import '../../core/utils/plan_day_calculator.dart';

class ExerciseData {
  final String id;
  final String name;
  final String? description;
  final String targetMuscle;
  final List<String> secondaryMuscles;
  final String equipmentNeeded;
  final String? commonMistakes;
  final bool isHomeFriendly;
  final String? videoUrl;

  const ExerciseData({
    required this.id,
    required this.name,
    this.description,
    required this.targetMuscle,
    required this.secondaryMuscles,
    required this.equipmentNeeded,
    this.commonMistakes,
    required this.isHomeFriendly,
    this.videoUrl,
  });

  factory ExerciseData.fromMap(Map<String, dynamic> map) {
    return ExerciseData(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      targetMuscle: map['target_muscle'] as String? ?? '',
      secondaryMuscles:
          (map['secondary_muscles'] as List?)?.cast<String>() ?? [],
      equipmentNeeded: map['equipment_needed'] as String? ?? 'none',
      commonMistakes: map['common_mistakes'] as String?,
      isHomeFriendly: map['is_home_friendly'] as bool? ?? true,
      videoUrl: map['video_url'] as String?,
    );
  }
}

class WorkoutExerciseData {
  final String id;
  final int sets;
  final String repsRange;
  final int restSeconds;
  final int orderIndex;
  final ExerciseData exercise;

  const WorkoutExerciseData({
    required this.id,
    required this.sets,
    required this.repsRange,
    required this.restSeconds,
    required this.orderIndex,
    required this.exercise,
  });

  factory WorkoutExerciseData.fromMap(Map<String, dynamic> map) {
    return WorkoutExerciseData(
      id: map['id'] as String,
      sets: (map['sets'] as num?)?.toInt() ?? 3,
      repsRange: map['reps_range'] as String? ?? '',
      restSeconds: (map['rest_seconds'] as num?)?.toInt() ?? 60,
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      exercise: ExerciseData.fromMap(map['exercises'] as Map<String, dynamic>),
    );
  }
}

class WorkoutDayData {
  final String id;
  final int dayNumber;
  final String dayName;
  final bool isRestDay;
  final List<WorkoutExerciseData> exercises;

  const WorkoutDayData({
    required this.id,
    required this.dayNumber,
    required this.dayName,
    required this.isRestDay,
    required this.exercises,
  });

  factory WorkoutDayData.fromMap(Map<String, dynamic> map) {
    final rawExercises = (map['workout_exercises'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(WorkoutExerciseData.fromMap)
        .toList();
    rawExercises.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return WorkoutDayData(
      id: map['id'] as String,
      dayNumber: (map['day_number'] as num).toInt(),
      dayName: map['day_name'] as String? ?? '',
      isRestDay: map['is_rest_day'] as bool? ?? false,
      exercises: rawExercises,
    );
  }
}

class WorkoutPlanData {
  final String title;
  final DateTime createdAt;
  final List<WorkoutDayData> days;

  const WorkoutPlanData({
    required this.title,
    required this.createdAt,
    required this.days,
  });

  // day_number يطابق يوم الأسبوع الحقيقي (ISO) بعد اختيار المستخدم أيام
  // تمرينه الفعلية في Onboarding — لا علاقة له بتاريخ إنشاء الخطة.
  int todayDayNumber() => currentIsoWeekday();
}

abstract class WorkoutState {}

class WorkoutLoading extends WorkoutState {}

class WorkoutNoActivePlan extends WorkoutState {}

class WorkoutLoaded extends WorkoutState {
  final WorkoutPlanData plan;
  // التمارين المُنهاة فعلياً محفوظة في قاعدة البيانات، مُجمَّعة حسب تاريخ
  // الإنهاء (yyyy-MM-dd) على مدى الدورة الأسبوعية الحالية كاملة — لازمة
  // لتحديد حالة كل يوم في شريط الاختيار (اكتمل/فائت)، وليس فقط اليوم الحالي.
  final Map<String, Set<String>> completionsByDate;
  WorkoutLoaded(this.plan, {this.completionsByDate = const {}});

  Set<String> get completedExerciseIds =>
      completionsByDate[_formatDate(DateTime.now())] ?? const {};

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class WorkoutError extends WorkoutState {
  final String message;
  WorkoutError(this.message);
}
