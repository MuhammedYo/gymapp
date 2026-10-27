import '../../core/utils/plan_day_calculator.dart';

class MealItemData {
  final String id;
  final String mealType; // breakfast | lunch | dinner | snack
  final String foodName;
  final String? portionDescription;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;
  final String? alternatives;

  const MealItemData({
    required this.id,
    required this.mealType,
    required this.foodName,
    this.portionDescription,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    this.alternatives,
  });

  factory MealItemData.fromMap(Map<String, dynamic> map) {
    return MealItemData(
      id: map['id'] as String,
      mealType: map['meal_type'] as String? ?? 'snack',
      foodName: map['food_name'] as String? ?? '',
      portionDescription: map['portion_description'] as String?,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toDouble() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toDouble() ?? 0,
      alternatives: map['alternatives'] as String?,
    );
  }
}

class MealDayData {
  final int dayNumber;
  final List<MealItemData> meals;

  const MealDayData({
    required this.dayNumber,
    required this.meals,
  });

  int get totalCalories => meals.fold(0, (sum, m) => sum + m.calories);
  double get totalProteinG => meals.fold(0.0, (sum, m) => sum + m.proteinG);
  double get totalCarbsG => meals.fold(0.0, (sum, m) => sum + m.carbsG);
  double get totalFatsG => meals.fold(0.0, (sum, m) => sum + m.fatsG);

  List<MealItemData> mealsOfType(String type) =>
      meals.where((m) => m.mealType == type).toList();
}

class SupplementData {
  final String name;
  final String category; // protein | creatine | vitamin | omega3 | other
  final String? dosage;
  final String? timing;
  final String? reason;

  const SupplementData({
    required this.name,
    required this.category,
    this.dosage,
    this.timing,
    this.reason,
  });

  factory SupplementData.fromMap(Map<String, dynamic> map) {
    return SupplementData(
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'other',
      dosage: map['dosage'] as String?,
      timing: map['timing'] as String?,
      reason: map['reason'] as String?,
    );
  }
}

class MealPlanData {
  final DateTime createdAt;
  final List<MealDayData> days;
  final List<SupplementData> supplements;

  const MealPlanData({
    required this.createdAt,
    required this.days,
    required this.supplements,
  });

  int todayDayNumber() => calculatePlanDayNumber(createdAt);
}

abstract class NutritionState {}

class NutritionLoading extends NutritionState {}

class NutritionNoActivePlan extends NutritionState {}

class NutritionLoaded extends NutritionState {
  final MealPlanData plan;
  // الوجبات المُنهاة فعلياً (daily_meal_id) محفوظة في قاعدة البيانات،
  // مُجمَّعة حسب تاريخ الإنهاء (yyyy-MM-dd) على مدى الدورة الأسبوعية الحالية
  // كاملة — لازمة لتحديد حالة كل يوم في شريط الاختيار (اكتمل/فائت) بدقة
  // حقيقية مبنية على الوجبات الفعلية، بدل تخمين عام.
  final Map<String, Set<String>> completionsByDate;
  NutritionLoaded(this.plan, {this.completionsByDate = const {}});
}

class NutritionError extends NutritionState {
  final String message;
  NutritionError(this.message);
}
