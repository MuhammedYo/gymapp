import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../controllers/home/home_cubit.dart';
import '../../controllers/home/home_state.dart';
import '../../controllers/nutrition/nutrition_cubit.dart';
import '../../controllers/plan/plan_generation_cubit.dart';
import '../../controllers/workout/workout_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_shapes.dart';
import '../nutrition/nutrition_screen.dart';
import '../progress/progress_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/plan_generation_button.dart';
import '../workout/workout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // نُبقي HomeCubit وWorkoutCubit حيّين على مستوى القشرة (Shell) بدل كل
    // تبويب على حدة، لأن IndexedStack يبني كل التبويبات مرة واحدة ولا يعيد
    // بناءها عند التنقل بينها — فتوليد خطة من أي مكان يجب أن يحدّث كليهما.
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeCubit()..fetchHomeData()),
        BlocProvider(create: (_) => WorkoutCubit()..fetchWorkoutPlan()),
        BlocProvider(create: (_) => NutritionCubit()..fetchMealPlan()),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      // يطابق لون سطح البطاقات (surfaceCard) الذي ينتهي عنده جسم كل تبويب،
      // حتى تبدو الفراغات حول شريط التنقل العائم متصلة بلون الشاشة.
      backgroundColor: AppColors.surfaceCard,
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _buildHomeTab(isArabic),
          const ProgressScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isArabic),
    );
  }

  Widget _buildHomeTab(bool isArabic) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading || state is HomeInitial) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              );
            }

            if (state is HomeError) {
              return _buildErrorView(context, isArabic, state.message);
            }

            final data = (state as HomeLoaded).data;

            return RefreshIndicator(
              color: AppColors.brandPrimary,
              onRefresh: () =>
                  context.read<HomeCubit>().fetchHomeData(silent: true),
              child: Column(
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
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCheckinRow(isArabic, data),
                            const SizedBox(height: 24),
                            _buildWorkoutCard(context, isArabic, data),
                            const SizedBox(height: 20),
                            _buildMealsCard(context, isArabic, data),
                            const SizedBox(height: 20),
                            _buildProgressCard(isArabic),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // بعد إلغاء تبويبي التمارين والتغذية من شريط التنقل، أصبحا يُفتحان كصفحة
  // مدفوعة (push) من أزرار في الرئيسية بدل تبويب ثابت. نمرّر نفس نسخة
  // الكوبت الحيّة أصلاً في القشرة (وليس نسخة جديدة) عبر BlocProvider.value،
  // حتى تبقى الحالة (وما تعرضه بطاقات الرئيسية) متزامنة مع ما يحدث داخل
  // الصفحة المفتوحة دون إعادة جلب مكرر للبيانات.
  void _openWorkout(BuildContext context) {
    final homeCubit = context.read<HomeCubit>();
    final workoutCubit = context.read<WorkoutCubit>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: homeCubit),
            BlocProvider.value(value: workoutCubit),
          ],
          child: const WorkoutScreen(),
        ),
      ),
    );
  }

  void _openNutrition(BuildContext context) {
    final homeCubit = context.read<HomeCubit>();
    final nutritionCubit = context.read<NutritionCubit>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: homeCubit),
            BlocProvider.value(value: nutritionCubit),
          ],
          child: const NutritionScreen(),
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
              onPressed: () => context.read<HomeCubit>().fetchHomeData(),
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

  // ==================== الترويسة ====================
  Widget _buildHeader(bool isArabic, HomeData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.grayDark,
                child: Icon(Icons.person, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'أهلاً بعودتك' : 'Welcome back',
                    style: const TextStyle(
                      color: AppColors.grayLight,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    data.fullName.isNotEmpty
                        ? data.fullName
                        : (isArabic ? 'مستخدم' : 'User'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // بطاقة النقاط والستريك
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.grayDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _statItem(
                  icon: FontAwesomeIcons.fire,
                  color: AppColors.accentOrange,
                  value: '${data.streakDays}',
                  label: isArabic ? 'أيام متتالية' : 'Day streak',
                ),
                _verticalDivider(),
                _statItem(
                  icon: FontAwesomeIcons.solidStar,
                  color: AppColors.brandPrimary,
                  value: '${data.totalPoints}',
                  label: isArabic ? 'نقطة' : 'Points',
                ),
                _verticalDivider(),
                _statItem(
                  icon: FontAwesomeIcons.chartLine,
                  color: AppColors.accentBlue,
                  value: isArabic
                      ? 'المستوى ${data.currentLevel}'
                      : 'Level ${data.currentLevel}',
                  label: isArabic ? 'مستواك' : 'Your level',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          FaIcon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grayLight, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white12,
    );
  }

  // ==================== صف المتابعة اليومية ====================
  Widget _buildCheckinRow(bool isArabic, HomeData data) {
    return Row(
      children: [
        Expanded(
          child: _checkinChip(
            icon: FontAwesomeIcons.utensils,
            label: isArabic ? 'النظام الغذائي' : 'Diet',
            done: data.followedDiet,
            // لا يُفعَّل يدوياً بالضغط أبداً — تُفعَّل هذه العلامة تلقائياً
            // فقط عند تأشير كل وجبات اليوم فعلياً كمأكولة من تبويب التغذية
            // (NutritionScreen يستدعي toggleDiet عند اكتمال وجبات اليوم)،
            // بنفس نمط بطاقة "التمرين".
            onTap: null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _checkinChip(
            icon: FontAwesomeIcons.dumbbell,
            label: isArabic ? 'التمرين' : 'Workout',
            done: data.completedWorkout,
            // لا يُفعَّل يدوياً بالضغط أبداً — تُفعَّل هذه العلامة تلقائياً
            // فقط عند إنهاء كل تمارين اليوم فعلياً من شاشة جلسة التمرين
            // (WorkoutScreen يستدعي toggleWorkout عند اكتمال اليوم).
            onTap: null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _checkinChip(
            icon: FontAwesomeIcons.droplet,
            label:
                '${data.waterLiters.toStringAsFixed(1)}/${data.waterGoalLiters.toStringAsFixed(1)}L',
            done: data.waterLiters >= data.waterGoalLiters,
            // تعطيل الزر عند بلوغ الهدف لمنع تجاوزه (القيمة مقيّدة أيضاً
            // من قاعدة البيانات كحماية إضافية).
            onTap: data.waterLiters >= data.waterGoalLiters
                ? null
                : () => _runCheckinAction(
                    () => context.read<HomeCubit>().addWater(0.25)),
          ),
        ),
      ],
    );
  }

  Future<void> _runCheckinAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.accentRed),
      );
    }
  }

  Widget _checkinChip({
    required IconData icon,
    required String label,
    required bool done,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: done
              ? AppColors.brandPrimary.withOpacity(0.18)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done ? AppColors.brandPrimary : Colors.transparent,
          ),
          boxShadow: done ? null : AppShapes.cardShadow,
        ),
        child: Column(
          children: [
            FaIcon(
              icon,
              size: 18,
              color: done ? AppColors.brandPrimary : AppColors.grayMedium,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: done ? AppColors.textPrimary : AppColors.grayMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== بطاقة تمرين اليوم ====================
  Widget _buildWorkoutCard(BuildContext context, bool isArabic, HomeData data) {
    if (!data.hasActiveWorkoutPlan) {
      return _sectionCard(
        title: isArabic ? 'تمرين اليوم' : "Today's Workout",
        trailing: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'لا توجد خطة تدريبية نشطة بعد'
                  : 'No active workout plan yet',
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 13),
            ),
            const SizedBox(height: 12),
            PlanGenerationButton(
              isArabic: isArabic,
              planType: PlanType.workout,
              onGenerated: () {
                context.read<HomeCubit>().fetchHomeData(silent: true);
                context.read<WorkoutCubit>().fetchWorkoutPlan();
              },
            ),
          ],
        ),
      );
    }

    if (data.isRestDay) {
      return _sectionCard(
        title: isArabic ? 'تمرين اليوم' : "Today's Workout",
        trailing: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.self_improvement, color: AppColors.accentBlue),
                const SizedBox(width: 10),
                Text(
                  isArabic
                      ? 'يوم راحة، استمتع به!'
                      : "It's a rest day, enjoy it!",
                  style: const TextStyle(
                      color: AppColors.grayMedium, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _viewPlanButton(isArabic, () => _openWorkout(context)),
          ],
        ),
      );
    }

    return _sectionCard(
      title: isArabic ? 'تمرين اليوم' : "Today's Workout",
      trailing: data.workoutDayName,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.grayDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center,
                    color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.workoutDayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic
                          ? '${data.workoutExerciseCount} تمارين'
                          : '${data.workoutExerciseCount} exercises',
                      style: const TextStyle(
                        color: AppColors.grayMedium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => _openWorkout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
              child: Text(
                isArabic ? 'ابدأ التمرين' : 'Start Workout',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // زر ثانوي (outline) لفتح الصفحة الكاملة دون إيحاء ببدء فعل مباشر، يُستخدم
  // في حالتي يوم الراحة وبطاقة التغذية.
  Widget _viewPlanButton(bool isArabic, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.brandPrimary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
        ),
        child: Text(
          isArabic ? 'عرض الخطة الكاملة' : 'View full plan',
          style: const TextStyle(
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ==================== بطاقة وجبات اليوم ====================
  Widget _buildMealsCard(BuildContext context, bool isArabic, HomeData data) {
    if (!data.hasActiveMealPlan) {
      return _sectionCard(
        title: isArabic ? 'التغذية اليوم' : "Today's Nutrition",
        trailing: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'لا توجد خطة تغذية نشطة بعد'
                  : 'No active meal plan yet',
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 13),
            ),
            const SizedBox(height: 12),
            PlanGenerationButton(
              isArabic: isArabic,
              planType: PlanType.meal,
              onGenerated: () {
                context.read<HomeCubit>().fetchHomeData(silent: true);
                context.read<NutritionCubit>().fetchMealPlan();
              },
            ),
          ],
        ),
      );
    }

    final target = data.targetCalories > 0 ? data.targetCalories : 1;
    final progress = (data.consumedCalories / target).clamp(0.0, 1.0);

    return _sectionCard(
      title: isArabic ? 'التغذية اليوم' : "Today's Nutrition",
      trailing: '${data.consumedCalories} / ${data.targetCalories} kcal',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.grayLight.withOpacity(0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macroItem(
                  isArabic ? 'بروتين' : 'Protein',
                  '${data.consumedProteinG.toStringAsFixed(0)}g',
                  AppColors.accentBlue),
              _macroItem(
                  isArabic ? 'كارب' : 'Carbs',
                  '${data.consumedCarbsG.toStringAsFixed(0)}g',
                  AppColors.accentOrange),
              _macroItem(
                  isArabic ? 'دهون' : 'Fats',
                  '${data.consumedFatsG.toStringAsFixed(0)}g',
                  AppColors.accentPurple),
            ],
          ),
          const SizedBox(height: 16),
          _viewPlanButton(isArabic, () => _openNutrition(context)),
        ],
      ),
    );
  }

  Widget _macroItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.grayMedium, fontSize: 11),
        ),
      ],
    );
  }

  // ==================== بطاقة التقدم ====================
  Widget _buildProgressCard(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShapes.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.camera_alt_outlined,
              color: AppColors.brandPrimary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'وثّق تقدمك' : 'Track your progress',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'أضف صورة لتحليل التقدم بالذكاء الاصطناعي'
                      : 'Add a photo for AI progress analysis',
                  style: const TextStyle(
                    color: AppColors.grayLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: AppColors.brandPrimary, size: 16),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String trailing,
    required Widget child,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              if (trailing.isNotEmpty)
                Text(
                  trailing,
                  style: const TextStyle(
                    color: AppColors.grayMedium,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ==================== شريط التنقل السفلي ====================
  Widget _buildBottomNav(bool isArabic) {
    final items = [
      (FontAwesomeIcons.house, isArabic ? 'الرئيسية' : 'Home'),
      (FontAwesomeIcons.chartSimple, isArabic ? 'التقدم' : 'Progress'),
      (FontAwesomeIcons.user, isArabic ? 'حسابي' : 'Profile'),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShapes.floatingNavShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final selected = index == _selectedTab;
            return InkWell(
              onTap: () => setState(() => _selectedTab = index),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.brandPrimary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      items[index].$1,
                      size: 18,
                      color: selected
                          ? AppColors.brandPrimary
                          : AppColors.grayLight,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[index].$2,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected
                            ? AppColors.brandPrimary
                            : AppColors.grayLight,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
