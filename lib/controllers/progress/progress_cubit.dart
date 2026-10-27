import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'progress_state.dart';

class ProgressCubit extends Cubit<ProgressState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  ProgressCubit() : super(ProgressLoading());

  Future<void> fetchProgress() async {
    try {
      emit(ProgressLoading());

      final userId = _supabase.auth.currentUser!.id;
      final today = DateTime.now();
      final sevenDaysAgo = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 6));

      final gamificationFuture = _supabase
          .from('user_gamification')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final profileFuture = _supabase
          .from('profiles')
          .select('water_goal_liters')
          .eq('id', userId)
          .single();
      final checkinsFuture = _supabase
          .from('daily_checkins')
          .select()
          .eq('user_id', userId)
          .gte('checkin_date', _formatDate(sevenDaysAgo))
          .lte('checkin_date', _formatDate(today));
      final badgesFuture =
          _supabase.from('badges').select().order('requirement_value');
      final userBadgesFuture = _supabase
          .from('user_badges')
          .select('badge_id, earned_at')
          .eq('user_id', userId);

      final gamification = await gamificationFuture;
      final profile = await profileFuture;
      final checkins = await checkinsFuture;
      final badgeRows = await badgesFuture;
      final userBadgeRows = await userBadgesFuture;

      final waterGoal =
          (profile['water_goal_liters'] as num?)?.toDouble() ?? 2.5;

      final checkinByDate = <String, Map<String, dynamic>>{
        for (final c in checkins.cast<Map<String, dynamic>>())
          c['checkin_date'] as String: c,
      };

      final last7Days = List.generate(7, (i) {
        final date = sevenDaysAgo.add(Duration(days: i));
        final row = checkinByDate[_formatDate(date)];
        return DayCheckinSummary(
          date: date,
          followedDiet: row?['followed_diet'] as bool? ?? false,
          completedWorkout: row?['completed_workout'] as bool? ?? false,
          waterGoalReached:
              ((row?['water_liters'] as num?)?.toDouble() ?? 0) >= waterGoal,
        );
      });

      final earnedMap = <String, DateTime>{
        for (final b in userBadgeRows.cast<Map<String, dynamic>>())
          b['badge_id'] as String: DateTime.parse(b['earned_at'] as String),
      };

      final badges = badgeRows.cast<Map<String, dynamic>>().map((b) {
        final id = b['id'] as String;
        return BadgeInfo(
          id: id,
          code: b['code'] as String? ?? '',
          nameAr: b['name_ar'] as String? ?? '',
          nameEn: b['name_en'] as String? ?? '',
          descriptionAr: b['description_ar'] as String? ?? '',
          descriptionEn: b['description_en'] as String? ?? '',
          icon: b['icon'] as String? ?? '🏅',
          earned: earnedMap.containsKey(id),
          earnedAt: earnedMap[id],
        );
      }).toList();

      emit(ProgressLoaded(ProgressData(
        streakDays:
            (gamification?['current_streak_days'] as num?)?.toInt() ?? 0,
        totalPoints: (gamification?['total_points'] as num?)?.toInt() ?? 0,
        currentLevel: (gamification?['current_level'] as num?)?.toInt() ?? 1,
        last7Days: last7Days,
        badges: badges,
      )));
    } catch (e) {
      emit(ProgressError(e.toString()));
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
