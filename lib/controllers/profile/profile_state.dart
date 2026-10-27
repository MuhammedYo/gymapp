class ProfileData {
  final String fullName;
  final String email;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? targetGoal;
  final String? fitnessLevel;
  final String? workoutLocation;
  final int? availableDaysPerWeek;
  final String? activityLevel;
  final double? sleepHours;
  final String? dietaryPreference;
  final int? targetCalories;
  final double? proteinG;
  final double? carbsG;
  final double? fatsG;
  final double? waterGoalLiters;

  const ProfileData({
    required this.fullName,
    required this.email,
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.targetGoal,
    this.fitnessLevel,
    this.workoutLocation,
    this.availableDaysPerWeek,
    this.activityLevel,
    this.sleepHours,
    this.dietaryPreference,
    this.targetCalories,
    this.proteinG,
    this.carbsG,
    this.fatsG,
    this.waterGoalLiters,
  });
}

abstract class ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final ProfileData data;
  ProfileLoaded(this.data);
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}
