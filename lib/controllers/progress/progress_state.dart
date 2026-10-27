class DayCheckinSummary {
  final DateTime date;
  final bool followedDiet;
  final bool completedWorkout;
  final bool waterGoalReached;

  const DayCheckinSummary({
    required this.date,
    required this.followedDiet,
    required this.completedWorkout,
    required this.waterGoalReached,
  });
}

class BadgeInfo {
  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final String icon;
  final bool earned;
  final DateTime? earnedAt;

  const BadgeInfo({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.icon,
    required this.earned,
    this.earnedAt,
  });

  String name(bool isArabic) => isArabic ? nameAr : nameEn;
  String description(bool isArabic) => isArabic ? descriptionAr : descriptionEn;
}

class ProgressData {
  final int streakDays;
  final int totalPoints;
  final int currentLevel;
  final List<DayCheckinSummary> last7Days;
  final List<BadgeInfo> badges;

  const ProgressData({
    required this.streakDays,
    required this.totalPoints,
    required this.currentLevel,
    required this.last7Days,
    required this.badges,
  });
}

abstract class ProgressState {}

class ProgressLoading extends ProgressState {}

class ProgressLoaded extends ProgressState {
  final ProgressData data;
  ProgressLoaded(this.data);
}

class ProgressError extends ProgressState {
  final String message;
  ProgressError(this.message);
}
