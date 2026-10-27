import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/nutrition_calculator.dart';
import 'medical_condition_entry.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  OnboardingCubit() : super(OnboardingInitial());

  Future<void> submit({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String targetGoal,
    required String fitnessLevel,
    required String workoutLocation,
    required int availableDaysPerWeek,
    required List<int> preferredWorkoutDays,
    String? preferredWorkoutTime,
    required String activityLevel,
    required double sleepHours,
    required String dietaryPreference,
    required List<MedicalConditionEntry> medicalConditions,
  }) async {
    try {
      emit(OnboardingSubmitting());

      final userId = _supabase.auth.currentUser!.id;

      final nutrition = NutritionCalculator.calculate(
        age: age,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        activityLevel: activityLevel,
        targetGoal: targetGoal,
      );

      await _supabase.from('profiles').update({
        'age': age,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'target_goal': targetGoal,
        'fitness_level': fitnessLevel,
        'workout_location': workoutLocation,
        'available_days_per_week': availableDaysPerWeek,
        'preferred_workout_days': preferredWorkoutDays,
        'preferred_workout_time': preferredWorkoutTime,
        'activity_level': activityLevel,
        'sleep_hours': sleepHours,
        'dietary_preference': dietaryPreference,
        'target_calories': nutrition.calories,
        'protein_g': nutrition.proteinG,
        'carbs_g': nutrition.carbsG,
        'fats_g': nutrition.fatsG,
        'water_goal_liters': nutrition.waterGoalLiters,
        'onboarding_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (medicalConditions.isNotEmpty) {
        await _supabase.from('user_medical_conditions').insert([
          for (final condition in medicalConditions)
            {
              'user_id': userId,
              'condition_type': condition.conditionType,
              'name': condition.name,
              'affected_body_part': condition.affectedBodyPart,
              'severity': condition.severity,
            },
        ]);
      }

      emit(OnboardingSuccess());
    } on PostgrestException catch (e) {
      emit(OnboardingError(e.message));
    } catch (e) {
      emit(OnboardingError(e.toString()));
    }
  }
}
