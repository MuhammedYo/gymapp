import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  ProfileCubit() : super(ProfileLoading());

  Future<void> fetchProfile() async {
    try {
      emit(ProfileLoading());

      final user = _supabase.auth.currentUser!;
      final profile =
          await _supabase.from('profiles').select().eq('id', user.id).single();

      emit(ProfileLoaded(ProfileData(
        fullName: profile['full_name'] as String? ?? '',
        email: user.email ?? '',
        age: (profile['age'] as num?)?.toInt(),
        gender: profile['gender'] as String?,
        heightCm: (profile['height_cm'] as num?)?.toDouble(),
        weightKg: (profile['weight_kg'] as num?)?.toDouble(),
        targetGoal: profile['target_goal'] as String?,
        fitnessLevel: profile['fitness_level'] as String?,
        workoutLocation: profile['workout_location'] as String?,
        availableDaysPerWeek:
            (profile['available_days_per_week'] as num?)?.toInt(),
        activityLevel: profile['activity_level'] as String?,
        sleepHours: (profile['sleep_hours'] as num?)?.toDouble(),
        dietaryPreference: profile['dietary_preference'] as String?,
        targetCalories: (profile['target_calories'] as num?)?.toInt(),
        proteinG: (profile['protein_g'] as num?)?.toDouble(),
        carbsG: (profile['carbs_g'] as num?)?.toDouble(),
        fatsG: (profile['fats_g'] as num?)?.toDouble(),
        waterGoalLiters: (profile['water_goal_liters'] as num?)?.toDouble(),
      )));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
