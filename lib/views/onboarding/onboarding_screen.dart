import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controllers/onboarding/medical_condition_entry.dart';
import '../../controllers/onboarding/onboarding_cubit.dart';
import '../../controllers/onboarding/onboarding_state.dart';
import '../../core/constants/app_colors.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

  // Step 1
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _gender;

  // Step 2
  String? _targetGoal;
  String? _fitnessLevel;

  // Step 3
  String _workoutLocation = 'home';
  // أيام التمرين الفعلية المختارة (ISO: 1=الاثنين...7=الأحد) — تحدَّد بالضبط
  // أيام workout_days في الخطة المولَّدة، بدل عدد تقريبي يوزّعه الذكاء
  // الاصطناعي كما كان سابقاً.
  final Set<int> _preferredWorkoutDays = {};
  TimeOfDay? _preferredWorkoutTime;
  String _activityLevel = 'moderately_active';
  double _sleepHours = 7;
  String _dietaryPreference = 'standard';

  // Step 4
  final List<MedicalConditionEntry> _conditions = [];

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep(bool isArabic) {
    if (_step == 0) {
      if (_ageController.text.trim().isEmpty ||
          _heightController.text.trim().isEmpty ||
          _weightController.text.trim().isEmpty ||
          _gender == null) {
        _showSnack(
            isArabic ? 'يرجى تعبئة كل الحقول' : 'Please fill all fields');
        return false;
      }
      if (int.tryParse(_ageController.text.trim()) == null ||
          double.tryParse(_heightController.text.trim()) == null ||
          double.tryParse(_weightController.text.trim()) == null) {
        _showSnack(
            isArabic ? 'يرجى إدخال أرقام صحيحة' : 'Please enter valid numbers');
        return false;
      }
    } else if (_step == 1) {
      if (_targetGoal == null || _fitnessLevel == null) {
        _showSnack(isArabic
            ? 'يرجى اختيار الهدف والمستوى'
            : 'Please choose your goal and level');
        return false;
      }
    } else if (_step == 2) {
      if (_preferredWorkoutDays.isEmpty) {
        _showSnack(isArabic
            ? 'يرجى اختيار أيام التمرين المناسبة لك'
            : 'Please choose your workout days');
        return false;
      }
    }
    return true;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.accentRed),
    );
  }

  void _next(bool isArabic) {
    if (!_validateCurrentStep(isArabic)) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _submit() {
    final sortedDays = _preferredWorkoutDays.toList()..sort();
    final time = _preferredWorkoutTime;
    final formattedTime = time == null
        ? null
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

    context.read<OnboardingCubit>().submit(
          age: int.parse(_ageController.text.trim()),
          gender: _gender!,
          heightCm: double.parse(_heightController.text.trim()),
          weightKg: double.parse(_weightController.text.trim()),
          targetGoal: _targetGoal!,
          fitnessLevel: _fitnessLevel!,
          workoutLocation: _workoutLocation,
          availableDaysPerWeek: sortedDays.length,
          preferredWorkoutDays: sortedDays,
          preferredWorkoutTime: formattedTime,
          activityLevel: _activityLevel,
          sleepHours: _sleepHours,
          dietaryPreference: _dietaryPreference,
          medicalConditions: _conditions,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: BlocConsumer<OnboardingCubit, OnboardingState>(
          listener: (context, state) {
            if (state is OnboardingError) {
              _showSnack(state.message);
            } else if (state is OnboardingSuccess) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            }
          },
          builder: (context, state) {
            final isSubmitting = state is OnboardingSubmitting;

            return Column(
              children: [
                _buildTopBar(isArabic),
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
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildBasicInfoStep(isArabic),
                        _buildGoalStep(isArabic),
                        _buildLifestyleStep(isArabic),
                        _buildMedicalStep(isArabic),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () => _next(isArabic),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _step == _totalSteps - 1
                                  ? (isArabic ? 'إنهاء' : 'Finish')
                                  : (isArabic ? 'التالي' : 'Next'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
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

  Widget _buildTopBar(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _step > 0
                  ? IconButton(
                      onPressed: _back,
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : const SizedBox(height: 24),
              Text(
                isArabic
                    ? 'الخطوة ${_step + 1} من $_totalSteps'
                    : 'Step ${_step + 1} of $_totalSteps',
                style:
                    const TextStyle(color: AppColors.grayLight, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'أخبرنا عن نفسك' : 'Tell us about yourself',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_totalSteps, (index) {
              final active = index <= _step;
              return Expanded(
                child: Container(
                  margin:
                      EdgeInsets.only(right: index == _totalSteps - 1 ? 0 : 6),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? AppColors.brandPrimary : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==================== الخطوة 1: البيانات الأساسية ====================
  Widget _buildBasicInfoStep(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(isArabic ? 'العمر' : 'Age'),
          _textField(_ageController, TextInputType.number,
              isArabic ? 'مثال: 25' : 'e.g. 25'),
          const SizedBox(height: 20),
          _fieldLabel(isArabic ? 'الجنس' : 'Gender'),
          Row(
            children: [
              _choiceChip(
                label: isArabic ? 'ذكر' : 'Male',
                selected: _gender == 'male',
                onTap: () => setState(() => _gender = 'male'),
              ),
              const SizedBox(width: 10),
              _choiceChip(
                label: isArabic ? 'أنثى' : 'Female',
                selected: _gender == 'female',
                onTap: () => setState(() => _gender = 'female'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _fieldLabel(isArabic ? 'الطول (سم)' : 'Height (cm)'),
          _textField(
              _heightController,
              const TextInputType.numberWithOptions(decimal: true),
              isArabic ? 'مثال: 175' : 'e.g. 175'),
          const SizedBox(height: 20),
          _fieldLabel(isArabic ? 'الوزن (كجم)' : 'Weight (kg)'),
          _textField(
              _weightController,
              const TextInputType.numberWithOptions(decimal: true),
              isArabic ? 'مثال: 70' : 'e.g. 70'),
        ],
      ),
    );
  }

  // ==================== الخطوة 2: الهدف والمستوى ====================
  Widget _buildGoalStep(bool isArabic) {
    final goals = {
      'cutting': isArabic ? 'تنشيف' : 'Cutting',
      'bulking': isArabic ? 'تضخيم' : 'Bulking',
      'fitness': isArabic ? 'لياقة عامة' : 'General fitness',
      'weight_loss': isArabic ? 'خسارة وزن' : 'Weight loss',
    };
    final levels = {
      'beginner': isArabic ? 'مبتدئ' : 'Beginner',
      'intermediate': isArabic ? 'متوسط' : 'Intermediate',
      'advanced': isArabic ? 'متقدم' : 'Advanced',
      'senior': isArabic ? 'كبار السن' : 'Senior',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(isArabic ? 'ما هو هدفك؟' : 'What is your goal?'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: goals.entries
                .map((e) => _choiceChip(
                      label: e.value,
                      selected: _targetGoal == e.key,
                      onTap: () => setState(() => _targetGoal = e.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          _fieldLabel(isArabic ? 'مستوى لياقتك' : 'Your fitness level'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: levels.entries
                .map((e) => _choiceChip(
                      label: e.value,
                      selected: _fitnessLevel == e.key,
                      onTap: () => setState(() => _fitnessLevel = e.key),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ==================== الخطوة 3: نمط الحياة ====================
  Widget _buildLifestyleStep(bool isArabic) {
    final activityLevels = {
      'sedentary': isArabic ? 'خامل' : 'Sedentary',
      'lightly_active': isArabic ? 'نشاط خفيف' : 'Lightly active',
      'moderately_active': isArabic ? 'نشاط متوسط' : 'Moderately active',
      'very_active': isArabic ? 'نشاط عالٍ' : 'Very active',
    };
    final diets = {
      'standard': isArabic ? 'عادي' : 'Standard',
      'vegetarian': isArabic ? 'نباتي' : 'Vegetarian',
      'vegan': isArabic ? 'نباتي صرف' : 'Vegan',
      'keto': isArabic ? 'كيتو' : 'Keto',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(isArabic ? 'مكان التمرين' : 'Workout location'),
          Row(
            children: [
              _choiceChip(
                label: isArabic ? 'المنزل' : 'Home',
                selected: _workoutLocation == 'home',
                onTap: () => setState(() => _workoutLocation = 'home'),
              ),
              const SizedBox(width: 10),
              _choiceChip(
                label: isArabic ? 'الجيم' : 'Gym',
                selected: _workoutLocation == 'gym',
                onTap: () => setState(() => _workoutLocation = 'gym'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _fieldLabel(isArabic
              ? 'أيام التمرين المناسبة لك'
              : 'Your preferred workout days'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final isoWeekday = index + 1; // 1=الاثنين...7=الأحد
              const namesAr = [
                'الاثنين',
                'الثلاثاء',
                'الأربعاء',
                'الخميس',
                'الجمعة',
                'السبت',
                'الأحد'
              ];
              const namesEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              return _choiceChip(
                label: isArabic ? namesAr[index] : namesEn[index],
                selected: _preferredWorkoutDays.contains(isoWeekday),
                onTap: () => setState(() {
                  if (_preferredWorkoutDays.contains(isoWeekday)) {
                    _preferredWorkoutDays.remove(isoWeekday);
                  } else {
                    _preferredWorkoutDays.add(isoWeekday);
                  }
                }),
              );
            }),
          ),
          const SizedBox(height: 24),
          _fieldLabel(
              isArabic ? 'الساعة المناسبة للتمرين' : 'Preferred workout time'),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _preferredWorkoutTime ?? TimeOfDay.now(),
              );
              if (picked != null) {
                setState(() => _preferredWorkoutTime = picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.grayLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grayLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 18, color: AppColors.brandPrimary),
                  const SizedBox(width: 10),
                  Text(
                    _preferredWorkoutTime != null
                        ? _preferredWorkoutTime!.format(context)
                        : (isArabic
                            ? 'اختر الساعة (اختياري)'
                            : 'Pick a time (optional)'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel(
              isArabic ? 'مستوى النشاط اليومي' : 'Daily activity level'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: activityLevels.entries
                .map((e) => _choiceChip(
                      label: e.value,
                      selected: _activityLevel == e.key,
                      onTap: () => setState(() => _activityLevel = e.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          _fieldLabel(isArabic
              ? 'ساعات النوم: ${_sleepHours.toStringAsFixed(1)}'
              : 'Sleep hours: ${_sleepHours.toStringAsFixed(1)}'),
          Slider(
            value: _sleepHours,
            min: 3,
            max: 12,
            divisions: 18,
            activeColor: AppColors.brandPrimary,
            label: _sleepHours.toStringAsFixed(1),
            onChanged: (v) => setState(() => _sleepHours = v),
          ),
          const SizedBox(height: 16),
          _fieldLabel(isArabic ? 'نوع الطعام المتوفر' : 'Available diet type'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: diets.entries
                .map((e) => _choiceChip(
                      label: e.value,
                      selected: _dietaryPreference == e.key,
                      onTap: () => setState(() => _dietaryPreference = e.key),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ==================== الخطوة 4: الأمراض والإصابات ====================
  Widget _buildMedicalStep(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(isArabic
              ? 'هل لديك أمراض أو إصابات؟ (اختياري)'
              : 'Any diseases or injuries? (optional)'),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'يساعدنا هذا في بناء خطة آمنة لك. استشر طبيبك دائماً في الحالات التي تتطلب ذلك.'
                : 'This helps us build a safer plan for you. Always consult your doctor when needed.',
            style: const TextStyle(color: AppColors.grayMedium, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ..._conditions.asMap().entries.map((entry) {
            final condition = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.grayLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          condition.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          '${condition.conditionType} · ${condition.severity}',
                          style: const TextStyle(
                              color: AppColors.grayMedium, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.accentRed),
                    onPressed: () =>
                        setState(() => _conditions.removeAt(entry.key)),
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => _showAddConditionDialog(isArabic),
            icon: const Icon(Icons.add, color: AppColors.textPrimary),
            label: Text(
              isArabic ? 'إضافة حالة' : 'Add condition',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.grayLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddConditionDialog(bool isArabic) {
    String type = 'disease';
    String severity = 'moderate';
    final nameController = TextEditingController();
    final bodyPartController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isArabic ? 'إضافة حالة' : 'Add condition'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _choiceChip(
                          label: isArabic ? 'مرض' : 'Disease',
                          selected: type == 'disease',
                          onTap: () => setDialogState(() => type = 'disease'),
                        ),
                        const SizedBox(width: 8),
                        _choiceChip(
                          label: isArabic ? 'إصابة' : 'Injury',
                          selected: type == 'injury',
                          onTap: () => setDialogState(() => type = 'injury'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الاسم' : 'Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bodyPartController,
                      decoration: InputDecoration(
                        labelText: isArabic
                            ? 'الجزء المصاب (اختياري)'
                            : 'Affected body part (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: ['mild', 'moderate', 'severe'].map((s) {
                        final labels = {
                          'mild': isArabic ? 'خفيف' : 'Mild',
                          'moderate': isArabic ? 'متوسط' : 'Moderate',
                          'severe': isArabic ? 'شديد' : 'Severe',
                        };
                        return _choiceChip(
                          label: labels[s]!,
                          selected: severity == s,
                          onTap: () => setDialogState(() => severity = s),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    setState(() {
                      _conditions.add(MedicalConditionEntry(
                        conditionType: type,
                        name: nameController.text.trim(),
                        affectedBodyPart: bodyPartController.text.trim(),
                        severity: severity,
                      ));
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isArabic ? 'إضافة' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== عناصر مشتركة ====================
  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _textField(
      TextEditingController controller, TextInputType type, String hint) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.grayLight),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.grayLight),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
        ),
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary
              : AppColors.grayLight.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.grayLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
