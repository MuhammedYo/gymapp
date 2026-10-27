class HomeData {
  final String fullName;

  final int targetCalories;
  final double proteinG;
  final double carbsG;
  final double fatsG;

  final int streakDays;
  final int totalPoints;
  final int currentLevel;

  final bool followedDiet;
  final bool completedWorkout;
  final double waterLiters;
  final double waterGoalLiters;

  final bool hasActiveWorkoutPlan;
  final bool isRestDay;
  final String workoutDayName;
  final int workoutExerciseCount;

  final bool hasActiveMealPlan;
  final int consumedCalories;
  final double consumedProteinG;
  final double consumedCarbsG;
  final double consumedFatsG;

  const HomeData({
    required this.fullName,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.streakDays,
    required this.totalPoints,
    required this.currentLevel,
    required this.followedDiet,
    required this.completedWorkout,
    required this.waterLiters,
    required this.waterGoalLiters,
    required this.hasActiveWorkoutPlan,
    required this.isRestDay,
    required this.workoutDayName,
    required this.workoutExerciseCount,
    required this.hasActiveMealPlan,
    required this.consumedCalories,
    required this.consumedProteinG,
    required this.consumedCarbsG,
    required this.consumedFatsG,
  });

  HomeData copyWith({
    int? streakDays,
    int? totalPoints,
    int? currentLevel,
    bool? followedDiet,
    bool? completedWorkout,
    double? waterLiters,
  }) {
    return HomeData(
      fullName: fullName,
      targetCalories: targetCalories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatsG: fatsG,
      streakDays: streakDays ?? this.streakDays,
      totalPoints: totalPoints ?? this.totalPoints,
      currentLevel: currentLevel ?? this.currentLevel,
      followedDiet: followedDiet ?? this.followedDiet,
      completedWorkout: completedWorkout ?? this.completedWorkout,
      waterLiters: waterLiters ?? this.waterLiters,
      waterGoalLiters: waterGoalLiters,
      hasActiveWorkoutPlan: hasActiveWorkoutPlan,
      isRestDay: isRestDay,
      workoutDayName: workoutDayName,
      workoutExerciseCount: workoutExerciseCount,
      hasActiveMealPlan: hasActiveMealPlan,
      consumedCalories: consumedCalories,
      consumedProteinG: consumedProteinG,
      consumedCarbsG: consumedCarbsG,
      consumedFatsG: consumedFatsG,
    );
  }
}

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final HomeData data;
  HomeLoaded(this.data);
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}
