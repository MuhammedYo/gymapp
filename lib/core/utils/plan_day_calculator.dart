/// يحسب رقم يوم الخطة الحالي (1-7) اعتماداً على تاريخ إنشاء الخطة نفسها،
/// وليس على يوم الأسبوع التقويمي — يوم 1 = يوم إنشاء الخطة، ويتكرر كل 7 أيام.
/// تُستخدم هذه الدالة في HomeCubit وWorkoutPlanData معاً لضمان تطابق
/// "تمرين اليوم" في كلا المكانين دائماً.
int calculatePlanDayNumber(DateTime planCreatedAt) {
  final start = planCreatedAt.toLocal();
  final startDate = DateTime(start.year, start.month, start.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daysSinceStart = today.difference(startDate).inDays;
  return (daysSinceStart % 7) + 1;
}

/// يحسب التاريخ الفعلي (ضمن الدورة الأسبوعية الحالية فقط) المقابل لرقم يوم
/// معيّن من الخطة. بعكس calculatePlanDayNumber (يحسب رقم يوم اليوم الحالي)،
/// هذه الدالة تعكس العملية: تُعطى رقم يوم فتُرجع تاريخه الحقيقي هذا الأسبوع
/// — لازمة لمعرفة هل يوم معيّن "مضى بالفعل" (ليُحكم عليه بنجاح/فشل) أم لم
/// يأتِ بعد.
DateTime dateForPlanDayNumber(DateTime planCreatedAt, int dayNumber) {
  final start = planCreatedAt.toLocal();
  final startDate = DateTime(start.year, start.month, start.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daysSinceStart = today.difference(startDate).inDays;
  final cycleStart = daysSinceStart - (daysSinceStart % 7);
  return startDate.add(Duration(days: cycleStart + (dayNumber - 1)));
}

enum PlanDayStatus {
  future, // يوم لم يأتِ بعد في هذه الدورة
  today, // يوم اليوم، لم يُكتمل بعد
  completed, // اكتمل (اليوم أو في الماضي)
  missed, // مضى دون إكماله
}

/// يحدد حالة يوم معيّن بناءً على تاريخه الفعلي هذا الأسبوع وهل اكتمل أم لا.
PlanDayStatus planDayStatus({
  required DateTime targetDate,
  required bool isCompleted,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (targetDate.isAtSameMomentAs(today)) {
    return isCompleted ? PlanDayStatus.completed : PlanDayStatus.today;
  } else if (targetDate.isBefore(today)) {
    return isCompleted ? PlanDayStatus.completed : PlanDayStatus.missed;
  }
  return PlanDayStatus.future;
}

/// تنسيق تاريخ موحّد (yyyy-MM-dd) يطابق صيغة أعمدة DATE في Postgres، تستخدمه
/// كل الأكواب/الشاشات التي تحتاج مطابقة تواريخ الخطة مع قاعدة البيانات.
String formatPlanDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

// ==========================================================================
// خطة التمارين تحديداً: بعد إضافة اختيار أيام التمرين الفعلية في Onboarding،
// أصبح day_number في workout_days يطابق يوم الأسبوع الحقيقي (ISO: 1=الاثنين
// ... 7=الأحد) بدل كونه نسبياً لتاريخ إنشاء الخطة. الدوال التالية خاصة بهذا
// النموذج، ومُستخدَمة فقط من كود التمارين (وليس التغذية، التي بقيت على
// النموذج القديم النسبي لتاريخ الإنشاء).
// ==========================================================================

/// رقم يوم الأسبوع الحالي بمعيار ISO (1=الاثنين ... 7=الأحد).
int currentIsoWeekday() => DateTime.now().weekday;

/// التاريخ الفعلي لهذا الأسبوع المطابق ليوم أسبوع معيّن (ISO 1-7).
DateTime dateForIsoWeekday(int isoWeekday) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.add(Duration(days: isoWeekday - today.weekday));
}
