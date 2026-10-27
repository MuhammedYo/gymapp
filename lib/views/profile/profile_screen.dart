import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controllers/auth/auth_cubit.dart';
import '../../controllers/language/locale_cubit.dart';
import '../../controllers/profile/profile_cubit.dart';
import '../../controllers/profile/profile_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_shapes.dart';

String? _goalLabel(String? value, bool isArabic) {
  const labels = {
    'cutting': ['تنشيف', 'Cutting'],
    'bulking': ['تضخيم', 'Bulking'],
    'fitness': ['لياقة عامة', 'General fitness'],
    'weight_loss': ['خسارة وزن', 'Weight loss'],
  };
  final pair = labels[value];
  if (pair == null) return null;
  return isArabic ? pair[0] : pair[1];
}

String? _fitnessLevelLabel(String? value, bool isArabic) {
  const labels = {
    'beginner': ['مبتدئ', 'Beginner'],
    'intermediate': ['متوسط', 'Intermediate'],
    'advanced': ['متقدم', 'Advanced'],
  };
  final pair = labels[value];
  if (pair == null) return null;
  return isArabic ? pair[0] : pair[1];
}

String? _activityLevelLabel(String? value, bool isArabic) {
  const labels = {
    'sedentary': ['خامل', 'Sedentary'],
    'lightly_active': ['نشاط خفيف', 'Lightly active'],
    'moderately_active': ['نشاط متوسط', 'Moderately active'],
    'very_active': ['نشاط عالٍ', 'Very active'],
  };
  final pair = labels[value];
  if (pair == null) return null;
  return isArabic ? pair[0] : pair[1];
}

String? _dietLabel(String? value, bool isArabic) {
  const labels = {
    'standard': ['عادي', 'Standard'],
    'vegetarian': ['نباتي', 'Vegetarian'],
    'vegan': ['نباتي صرف', 'Vegan'],
    'keto': ['كيتو', 'Keto'],
  };
  final pair = labels[value];
  if (pair == null) return null;
  return isArabic ? pair[0] : pair[1];
}

String? _workoutLocationLabel(String? value, bool isArabic) {
  const labels = {
    'home': ['المنزل', 'Home'],
    'gym': ['الجيم', 'Gym'],
  };
  final pair = labels[value];
  if (pair == null) return null;
  return isArabic ? pair[0] : pair[1];
}

String? _genderLabel(String? value, bool isArabic) {
  const labels = {
    'male': ['ذكر', 'Male'],
    'female': ['أنثى', 'Female'],
  };
  final pair = labels[value];
  if (pair == null) return null;
  return isArabic ? pair[0] : pair[1];
}

/// تبويب "حسابي": عرض بيانات الملف الشخصي (المُدخلة عبر Onboarding) والأهداف
/// الغذائية المحسوبة، مع إعدادات اللغة وتسجيل الخروج. عرض فقط حالياً؛ تعديل
/// البيانات يمر عبر إعادة تعبئة Onboarding في نسخة لاحقة.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit()..fetchProfile(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              );
            }

            if (state is ProfileError) {
              return _buildErrorView(context, isArabic, state.message);
            }

            final data = (state as ProfileLoaded).data;

            return Column(
              children: [
                _buildHeader(isArabic, data),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(36),
                        topRight: Radius.circular(36),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionCard(
                            isArabic ? 'المعلومات الجسدية' : 'Body Info',
                            [
                              _row(isArabic ? 'العمر' : 'Age',
                                  data.age != null ? '${data.age}' : '—'),
                              _row(isArabic ? 'الجنس' : 'Gender',
                                  _genderLabel(data.gender, isArabic) ?? '—'),
                              _row(
                                  isArabic ? 'الطول' : 'Height',
                                  data.heightCm != null
                                      ? '${data.heightCm!.toStringAsFixed(0)} cm'
                                      : '—'),
                              _row(
                                  isArabic ? 'الوزن' : 'Weight',
                                  data.weightKg != null
                                      ? '${data.weightKg!.toStringAsFixed(0)} kg'
                                      : '—'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionCard(
                            isArabic ? 'الهدف واللياقة' : 'Goal & Fitness',
                            [
                              _row(isArabic ? 'الهدف' : 'Goal',
                                  _goalLabel(data.targetGoal, isArabic) ?? '—'),
                              _row(
                                  isArabic ? 'مستوى اللياقة' : 'Fitness level',
                                  _fitnessLevelLabel(
                                          data.fitnessLevel, isArabic) ??
                                      '—'),
                              _row(
                                  isArabic
                                      ? 'مكان التمرين'
                                      : 'Workout location',
                                  _workoutLocationLabel(
                                          data.workoutLocation, isArabic) ??
                                      '—'),
                              _row(
                                  isArabic
                                      ? 'أيام التمرين أسبوعياً'
                                      : 'Workout days/week',
                                  data.availableDaysPerWeek != null
                                      ? '${data.availableDaysPerWeek}'
                                      : '—'),
                              _row(
                                  isArabic ? 'مستوى النشاط' : 'Activity level',
                                  _activityLevelLabel(
                                          data.activityLevel, isArabic) ??
                                      '—'),
                              _row(
                                  isArabic ? 'ساعات النوم' : 'Sleep hours',
                                  data.sleepHours != null
                                      ? '${data.sleepHours!.toStringAsFixed(1)}h'
                                      : '—'),
                              _row(
                                  isArabic ? 'نوع الطعام' : 'Diet type',
                                  _dietLabel(
                                          data.dietaryPreference, isArabic) ??
                                      '—'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionCard(
                            isArabic ? 'الأهداف الغذائية' : 'Nutrition Targets',
                            [
                              _row(
                                  isArabic ? 'السعرات' : 'Calories',
                                  data.targetCalories != null
                                      ? '${data.targetCalories} kcal'
                                      : '—'),
                              _row(
                                  isArabic ? 'بروتين' : 'Protein',
                                  data.proteinG != null
                                      ? '${data.proteinG!.toStringAsFixed(0)}g'
                                      : '—'),
                              _row(
                                  isArabic ? 'كارب' : 'Carbs',
                                  data.carbsG != null
                                      ? '${data.carbsG!.toStringAsFixed(0)}g'
                                      : '—'),
                              _row(
                                  isArabic ? 'دهون' : 'Fats',
                                  data.fatsG != null
                                      ? '${data.fatsG!.toStringAsFixed(0)}g'
                                      : '—'),
                              _row(
                                  isArabic ? 'هدف الماء' : 'Water goal',
                                  data.waterGoalLiters != null
                                      ? '${data.waterGoalLiters!.toStringAsFixed(1)}L'
                                      : '—'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSettingsSection(context, isArabic),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, bool isArabic, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.accentRed, size: 40),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'تعذر تحميل البيانات' : 'Failed to load data',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<ProfileCubit>().fetchProfile(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
              ),
              child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isArabic, ProfileData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.grayDark,
            child: Icon(Icons.person, color: AppColors.brandPrimary, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            data.fullName.isNotEmpty
                ? data.fullName
                : (isArabic ? 'مستخدم' : 'User'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.email,
            style: const TextStyle(color: AppColors.grayLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShapes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppColors.grayMedium, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isArabic) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShapes.cardShadow,
      ),
      child: Column(
        children: [
          BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return ListTile(
                leading:
                    const Icon(Icons.language, color: AppColors.textPrimary),
                title: Text(
                  isArabic ? 'اللغة' : 'Language',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                trailing: Text(
                  locale.languageCode == 'ar' ? 'العربية' : 'English',
                  style: const TextStyle(color: AppColors.grayMedium),
                ),
                onTap: () => context.read<LocaleCubit>().toggleLanguage(),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.accentRed),
            title: Text(
              isArabic ? 'تسجيل الخروج' : 'Log out',
              style: const TextStyle(
                  color: AppColors.accentRed, fontWeight: FontWeight.w600),
            ),
            onTap: () => _confirmLogout(context, isArabic),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, bool isArabic) async {
    final authCubit = context.read<AuthCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'تسجيل الخروج' : 'Log out'),
        content: Text(isArabic
            ? 'هل أنت متأكد من تسجيل الخروج؟'
            : 'Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isArabic ? 'تسجيل الخروج' : 'Log out',
                style: const TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authCubit.signOut();
    }
  }
}
