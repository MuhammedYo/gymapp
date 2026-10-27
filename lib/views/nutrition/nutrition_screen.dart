import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controllers/home/home_cubit.dart';
import '../../controllers/nutrition/nutrition_cubit.dart';
import '../../controllers/nutrition/nutrition_state.dart';
import '../../controllers/plan/plan_generation_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_shapes.dart';
import '../../core/utils/plan_day_calculator.dart';
import '../shared/plan_generation_button.dart';

const List<String> _mealTypeOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

String _mealTypeLabel(String type, bool isArabic) {
  switch (type) {
    case 'breakfast':
      return isArabic ? 'الفطور' : 'Breakfast';
    case 'lunch':
      return isArabic ? 'الغداء' : 'Lunch';
    case 'dinner':
      return isArabic ? 'العشاء' : 'Dinner';
    default:
      return isArabic ? 'وجبة خفيفة' : 'Snack';
  }
}

IconData _mealTypeIcon(String type) {
  switch (type) {
    case 'breakfast':
      return Icons.free_breakfast_outlined;
    case 'lunch':
      return Icons.lunch_dining_outlined;
    case 'dinner':
      return Icons.dinner_dining_outlined;
    default:
      return Icons.cookie_outlined;
  }
}

String _supplementCategoryLabel(String category, bool isArabic) {
  switch (category) {
    case 'protein':
      return isArabic ? 'بروتين' : 'Protein';
    case 'creatine':
      return isArabic ? 'كرياتين' : 'Creatine';
    case 'vitamin':
      return isArabic ? 'فيتامينات' : 'Vitamins';
    case 'omega3':
      return isArabic ? 'أوميغا-3' : 'Omega-3';
    default:
      return isArabic ? 'أخرى' : 'Other';
  }
}

IconData _supplementCategoryIcon(String category) {
  switch (category) {
    case 'protein':
      return Icons.fitness_center;
    case 'creatine':
      return Icons.bolt_outlined;
    case 'vitamin':
      return Icons.eco_outlined;
    case 'omega3':
      return Icons.water_drop_outlined;
    default:
      return Icons.medication_outlined;
  }
}

/// تبويب "التغذية": يعرض خطة الوجبات الأسبوعية كاملة (7 أيام مختلفة، تماماً
/// كخطة التمارين)، مع إمكانية التنقل بين الأيام وعرض تفاصيل كل وجبة.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // NutritionCubit يُوفَّر من القشرة (HomeScreen) وليس هنا، حتى يبقى
    // حياً ومحدَّثاً حتى عندما لا يكون هذا التبويب معروضاً (نفس نمط WorkoutCubit).
    return const _NutritionView();
  }
}

class _NutritionView extends StatefulWidget {
  const _NutritionView();

  @override
  State<_NutritionView> createState() => _NutritionViewState();
}

class _NutritionViewState extends State<_NutritionView> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // بعد إلغاء التبويب الثابت وتحويل هذه الشاشة إلى صفحة مدفوعة (push)
    // مستقلة، لم تعد داخل Scaffold تابع للرئيسية — فتحتاج Scaffold خاصاً
    // بها (حتى لو بلا AppBar/خلفية مرئية) لتوفير Material ancestor، وإلا
    // ترمي كل InkWell/BackButton هنا خطأ "No Material widget found."
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Text(
                      isArabic ? 'خطة التغذية' : 'Nutrition Plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
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
                  child: BlocBuilder<NutritionCubit, NutritionState>(
                    builder: (context, state) {
                      if (state is NutritionLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.brandPrimary),
                        );
                      }

                      if (state is NutritionError) {
                        return Center(
                          child: Text(
                            isArabic
                                ? 'حدث خطأ أثناء التحميل'
                                : 'Something went wrong',
                            style: const TextStyle(color: AppColors.accentRed),
                          ),
                        );
                      }

                      if (state is NutritionNoActivePlan) {
                        return _buildEmptyState(context, isArabic);
                      }

                      final nutritionState = state as NutritionLoaded;
                      final plan = nutritionState.plan;
                      if (plan.days.isEmpty) {
                        return _buildEmptyState(context, isArabic);
                      }

                      // نحدد اليوم المعروض افتراضياً مرة واحدة فقط، بناءً
                      // على تاريخ إنشاء الخطة نفسها (نفس منطق تبويب التمارين).
                      _selectedDay ??= plan.todayDayNumber();
                      final selectedDay = plan.days.firstWhere(
                        (d) => d.dayNumber == _selectedDay,
                        orElse: () => plan.days.first,
                      );
                      final selectedDayDate = dateForPlanDayNumber(
                          plan.createdAt, selectedDay.dayNumber);
                      final completedMealIds = nutritionState.completionsByDate[
                              formatPlanDate(selectedDayDate)] ??
                          const <String>{};

                      return RefreshIndicator(
                        color: AppColors.brandPrimary,
                        onRefresh: () =>
                            context.read<NutritionCubit>().fetchMealPlan(),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            _buildDaySelector(plan.days),
                            const SizedBox(height: 4),
                            Expanded(
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 20, 20),
                                children: [
                                  _buildSummaryCard(isArabic, selectedDay),
                                  const SizedBox(height: 20),
                                  for (final type in _mealTypeOrder)
                                    if (selectedDay
                                        .mealsOfType(type)
                                        .isNotEmpty)
                                      _buildMealSection(
                                          isArabic,
                                          type,
                                          selectedDay.mealsOfType(type),
                                          completedMealIds,
                                          selectedDay,
                                          plan),
                                  if (plan.supplements.isNotEmpty)
                                    _buildSupplementsSection(
                                        isArabic, plan.supplements),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic
                  ? 'لا توجد خطة تغذية نشطة بعد'
                  : 'No active meal plan yet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 14),
            ),
            const SizedBox(height: 16),
            PlanGenerationButton(
              isArabic: isArabic,
              planType: PlanType.meal,
              onGenerated: () {
                context.read<NutritionCubit>().fetchMealPlan();
                context.read<HomeCubit>().fetchHomeData(silent: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(List<MealDayData> days) {
    // نترك الاتجاه يتبع لغة الواجهة (RTL في العربية) عمداً هنا خلافاً لتبويب
    // التمارين، ليبدأ اليوم 1 من اليمين في الوضع العربي.
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = day.dayNumber == _selectedDay;
          final status = context.read<NutritionCubit>().dayStatus(day);
          return InkWell(
            onTap: () => setState(() => _selectedDay = day.dayNumber),
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandPrimary
                        : AppColors.grayLight.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selected ? AppShapes.cardShadow : null,
                  ),
                  child: Center(
                    child: Text(
                      '${day.dayNumber}',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.grayMedium,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (status == PlanDayStatus.completed ||
                    status == PlanDayStatus.missed)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _buildDayStatusBadge(status),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayStatusBadge(PlanDayStatus status) {
    final completed = status == PlanDayStatus.completed;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? AppColors.brandTeal : AppColors.accentRed,
        border: Border.all(color: AppColors.surfaceCard, width: 2),
      ),
      child: Icon(
        completed ? Icons.check : Icons.close,
        size: 12,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSummaryCard(bool isArabic, MealDayData day) {
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
                isArabic ? 'إجمالي اليوم' : "Day's Total",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${day.totalCalories} kcal',
                style: const TextStyle(
                  color: AppColors.grayMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macroItem(
                  isArabic ? 'بروتين' : 'Protein',
                  '${day.totalProteinG.toStringAsFixed(0)}g',
                  AppColors.accentBlue),
              _macroItem(
                  isArabic ? 'كارب' : 'Carbs',
                  '${day.totalCarbsG.toStringAsFixed(0)}g',
                  AppColors.accentOrange),
              _macroItem(
                  isArabic ? 'دهون' : 'Fats',
                  '${day.totalFatsG.toStringAsFixed(0)}g',
                  AppColors.accentPurple),
            ],
          ),
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

  Widget _buildMealSection(bool isArabic, String type, List<MealItemData> meals,
      Set<String> completedMealIds, MealDayData day, MealPlanData plan) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_mealTypeIcon(type), size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                _mealTypeLabel(type, isArabic),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final meal in meals)
            _MealCard(
              meal: meal,
              day: day,
              plan: plan,
              isCompleted: completedMealIds.contains(meal.id),
            ),
        ],
      ),
    );
  }

  // ==================== المكملات المقترحة ====================
  Widget _buildSupplementsSection(
      bool isArabic, List<SupplementData> supplements) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication_outlined,
                  size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'مكملات مقترحة' : 'Suggested Supplements',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final supplement in supplements)
            _SupplementCard(supplement: supplement, isArabic: isArabic),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.accentOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'هذه اقتراحات عامة لمكملات غذائية رياضية شائعة، وليست بديلاً عن استشارة طبيب أو أخصائي تغذية. استشر مختصاً قبل البدء بأي مكمل، خصوصاً مع أي حالة صحية.'
                        : 'These are general suggestions for common sports supplements, not a substitute for professional advice. Consult a doctor or nutritionist before starting any supplement, especially with any health condition.',
                    style: const TextStyle(
                        color: AppColors.grayMedium, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplementCard extends StatelessWidget {
  final SupplementData supplement;
  final bool isArabic;
  const _SupplementCard({required this.supplement, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShapes.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_supplementCategoryIcon(supplement.category),
                size: 18, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        supplement.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.grayLight.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _supplementCategoryLabel(supplement.category, isArabic),
                        style: const TextStyle(
                            color: AppColors.grayMedium,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (supplement.dosage != null || supplement.timing != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [supplement.dosage, supplement.timing]
                        .whereType<String>()
                        .join(' • '),
                    style: const TextStyle(
                        color: AppColors.grayMedium, fontSize: 11),
                  ),
                ],
                if (supplement.reason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    supplement.reason!,
                    style: const TextStyle(
                        color: AppColors.grayMedium, fontSize: 11, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatefulWidget {
  final MealItemData meal;
  final MealDayData day;
  final MealPlanData plan;
  final bool isCompleted;
  const _MealCard({
    required this.meal,
    required this.day,
    required this.plan,
    required this.isCompleted,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final meal = widget.meal;
    final hasDetails =
        meal.portionDescription != null || meal.alternatives != null;
    // تأكيد "تم تناولها" مقفول ليوم اليوم الفعلي فقط — نفس قيد بدء التمرين —
    // لأن completion_date يُسجَّل دائماً بتاريخ اليوم الحقيقي، فتأكيد وجبة من
    // يوم آخر (أثناء تصفّح الخطة) كان سيُسجَّل تحت تاريخ خاطئ لا يطابق يومها.
    final isToday = widget.day.dayNumber == widget.plan.todayDayNumber();
    final locked = !widget.isCompleted && !isToday;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isCompleted
            ? AppColors.brandPrimary.withOpacity(0.12)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: widget.isCompleted
            ? Border.all(color: AppColors.brandPrimary)
            : null,
        boxShadow: widget.isCompleted ? null : AppShapes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meal.foodName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.isCompleted)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.check_circle,
                      color: AppColors.brandPrimary, size: 20),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${meal.calories} kcal',
                  style: const TextStyle(
                    color: AppColors.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _infoChip(isArabic
                  ? 'بروتين ${meal.proteinG.toStringAsFixed(0)}g'
                  : 'Protein ${meal.proteinG.toStringAsFixed(0)}g'),
              const SizedBox(width: 8),
              _infoChip(isArabic
                  ? 'كارب ${meal.carbsG.toStringAsFixed(0)}g'
                  : 'Carbs ${meal.carbsG.toStringAsFixed(0)}g'),
              const SizedBox(width: 8),
              _infoChip(isArabic
                  ? 'دهون ${meal.fatsG.toStringAsFixed(0)}g'
                  : 'Fats ${meal.fatsG.toStringAsFixed(0)}g'),
            ],
          ),
          if (hasDetails) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    isArabic ? 'التفاصيل' : 'Details',
                    style: const TextStyle(
                      color: AppColors.grayMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.grayMedium,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              if (meal.portionDescription != null) ...[
                const SizedBox(height: 6),
                Text(meal.portionDescription!,
                    style: const TextStyle(
                        color: AppColors.grayMedium, fontSize: 12)),
              ],
              if (meal.alternatives != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.swap_horiz,
                        size: 16, color: AppColors.accentBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        meal.alternatives!,
                        style: const TextStyle(
                            color: AppColors.accentBlue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
          if (!widget.isCompleted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: locked
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isArabic
                                ? 'لا يمكن تأكيد هذه الوجبة إلا في يومها الفعلي'
                                : 'This meal can only be marked on its scheduled day'),
                            backgroundColor: AppColors.accentRed,
                          ),
                        )
                    : () async {
                        final nutritionCubit = context.read<NutritionCubit>();
                        final homeCubit = context.read<HomeCubit>();
                        await nutritionCubit.markMealCompleted(meal.id);
                        // إن اكتملت كل وجبات اليوم الفعلي، فعّل تلقائياً
                        // بطاقة "النظام الغذائي" في الرئيسية — بلا تفعيل يدوي.
                        if (nutritionCubit.isDayFullyCompleted(widget.day)) {
                          homeCubit.toggleDiet(true);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: locked
                          ? AppColors.grayLight
                          : AppColors.brandPrimary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19)),
                ),
                child: Text(
                  isArabic ? 'تم تناول هذه الوجبة' : 'Mark as eaten',
                  style: TextStyle(
                    color:
                        locked ? AppColors.grayLight : AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.grayLight.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.grayMedium, fontSize: 11)),
    );
  }
}
