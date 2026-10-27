class NutritionTargets {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;
  final double waterGoalLiters;

  const NutritionTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.waterGoalLiters,
  });
}

/// حساب حتمي (غير مبني على AI) للسعرات والماكروز المستهدفة،
/// بمعادلة Mifflin-St Jeor لحساب BMR ثم عامل نشاط ثم تعديل حسب الهدف.
class NutritionCalculator {
  // حدود أمان: نمنع أي مخرجات متطرفة ناتجة عن حالات حدّية في المدخلات
  // (وزن/طول/نشاط غير معتاد) بدل الوثوق بالمعادلة الخام بلا سقف.
  static const _minCalories = 1200.0;
  static const _maxCalories = 4000.0;
  static const _minWaterLiters = 1.5;
  static const _maxWaterLiters = 3.0;

  static const _activityMultipliers = {
    'sedentary': 1.2,
    'lightly_active': 1.375,
    'moderately_active': 1.55,
    'very_active': 1.725,
  };

  // ملاحظة: 33 مل لكل كجم من وزن الجسم كقاعدة عامة شائعة، مع زيادة بسيطة
  // حسب مستوى النشاط اليومي (تعويض السوائل المفقودة بالتعرق/الحركة).
  static const _waterActivityBonusLiters = {
    'sedentary': 0.0,
    'lightly_active': 0.15,
    'moderately_active': 0.3,
    'very_active': 0.5,
  };

  static NutritionTargets calculate({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String targetGoal,
  }) {
    final bmr = gender == 'male'
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;

    final activityMultiplier = _activityMultipliers[activityLevel] ?? 1.55;
    final tdee = bmr * activityMultiplier;

    late final double targetCalories;
    late final double proteinPerKg;
    switch (targetGoal) {
      case 'cutting':
        targetCalories = tdee * 0.8; // عجز ~20%
        proteinPerKg = 2.2;
        break;
      case 'weight_loss':
        targetCalories = tdee * 0.8;
        proteinPerKg = 2.0;
        break;
      case 'bulking':
        targetCalories = tdee * 1.1; // فائض ~10%
        proteinPerKg = 1.8;
        break;
      case 'fitness':
      default:
        targetCalories = tdee;
        proteinPerKg = 1.8;
    }

    final clampedCalories =
        targetCalories.clamp(_minCalories, _maxCalories).toDouble();

    final proteinG = weightKg * proteinPerKg;
    final fatsG = (clampedCalories * 0.25) / 9;
    final remainingCalories = clampedCalories - (proteinG * 4) - (fatsG * 9);
    final carbsG = (remainingCalories / 4).clamp(0, double.infinity);

    final waterBonus = _waterActivityBonusLiters[activityLevel] ?? 0.3;
    final waterGoalLiters = ((weightKg * 0.033) + waterBonus)
        .clamp(_minWaterLiters, _maxWaterLiters);

    return NutritionTargets(
      calories: clampedCalories.round(),
      proteinG: double.parse(proteinG.toStringAsFixed(1)),
      carbsG: double.parse(carbsG.toStringAsFixed(1)),
      fatsG: double.parse(fatsG.toStringAsFixed(1)),
      waterGoalLiters: double.parse(waterGoalLiters.toStringAsFixed(1)),
    );
  }
}
