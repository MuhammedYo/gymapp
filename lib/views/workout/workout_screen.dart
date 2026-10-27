import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/home/home_cubit.dart';
import '../../controllers/plan/plan_generation_cubit.dart';
import '../../controllers/workout/workout_cubit.dart';
import '../../controllers/workout/workout_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_shapes.dart';
import '../../core/utils/plan_day_calculator.dart';
import '../shared/plan_generation_button.dart';
import 'exercise_session_screen.dart';

/// تبويب "التمارين": يعرض خطة المستخدم الأسبوعية كاملة (وليس يوم اليوم فقط
/// كما في بطاقة Home)، مع إمكانية التنقل بين الأيام السبعة وعرض تفاصيل
/// كل تمرين (الوصف، العضلة المستهدفة، الأخطاء الشائعة، رابط فيديو إن وُجد).
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // WorkoutCubit يُوفَّر من القشرة (HomeScreen) وليس هنا، حتى يبقى
    // حياً ومحدَّثاً حتى عندما لا يكون هذا التبويب معروضاً.
    return const _WorkoutView();
  }
}

class _WorkoutView extends StatefulWidget {
  const _WorkoutView();

  @override
  State<_WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<_WorkoutView> {
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
                      isArabic ? 'خطة التمارين' : 'Workout Plan',
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
                  child: BlocBuilder<WorkoutCubit, WorkoutState>(
                    builder: (context, state) {
                      if (state is WorkoutLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.brandPrimary),
                        );
                      }

                      if (state is WorkoutError) {
                        return Center(
                          child: Text(
                            isArabic
                                ? 'حدث خطأ أثناء التحميل'
                                : 'Something went wrong',
                            style:
                                const TextStyle(color: AppColors.accentRed),
                          ),
                        );
                      }

                      if (state is WorkoutNoActivePlan) {
                        return _buildEmptyState(isArabic);
                      }

                      final workoutState = state as WorkoutLoaded;
                      final plan = workoutState.plan;
                      // نحدد اليوم المعروض افتراضياً مرة واحدة فقط (لا نُعيد
                      // ضبطه عند كل تحديث) بناءً على تاريخ إنشاء الخطة نفسها،
                      // وليس على يوم الأسبوع التقويمي.
                      _selectedDay ??= plan.todayDayNumber();
                      final selectedDay = plan.days.firstWhere(
                        (d) => d.dayNumber == _selectedDay,
                        orElse: () => plan.days.first,
                      );

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                plan.title,
                                style: const TextStyle(
                                  color: AppColors.grayMedium,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          _buildDaySelector(_orderedDays(plan)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: selectedDay.isRestDay
                                ? _buildRestDay(isArabic)
                                : _buildExerciseList(
                                    plan,
                                    selectedDay,
                                    workoutState.completionsByDate[
                                            formatPlanDate(dateForIsoWeekday(
                                                selectedDay.dayNumber))] ??
                                        const {},
                                  ),
                          ),
                        ],
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

  Widget _buildEmptyState(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic
                  ? 'لا توجد خطة تدريبية نشطة بعد'
                  : 'No active workout plan yet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 14),
            ),
            const SizedBox(height: 16),
            PlanGenerationButton(
              isArabic: isArabic,
              planType: PlanType.workout,
              onGenerated: () {
                context.read<WorkoutCubit>().fetchWorkoutPlan();
                context.read<HomeCubit>().fetchHomeData(silent: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _weekdaysAr = ['اث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
  static const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // day_number يُفترض أن يكون 1-7 دائماً (يوم أسبوع ISO)، لكن خططاً قديمة
  // أُنشئت قبل اعتماد هذا النظام قد تحمل قيماً خارج هذا النطاق — الفهرسة
  // المباشرة List[day.dayNumber - 1] كانت تُسبب RangeError يُظهر التطبيق
  // "متجمّداً" بمربع خطأ أحمر يملأ شريط الأيام كاملاً. اللف الآمن (% 7) هنا
  // يمنع الانهيار نهائياً بغض النظر عن قيمة day_number الفعلية في القاعدة.
  String _weekdayLabel(int dayNumber, bool isArabic) {
    final list = isArabic ? _weekdaysAr : _weekdaysEn;
    final index = ((dayNumber - 1) % 7 + 7) % 7;
    return list[index];
  }

  /// يعيد ترتيب أيام الأسبوع بحيث يكون أول يوم يظهر في الشريط هو يوم إنشاء
  /// الخطة نفسها (وهو عملياً يوم تسجيل/تنزيل المستخدم للتطبيق لأن الخطة
  /// تُولَّد مباشرة بعد onboarding)، بدل أن يبدأ الشريط دائماً من الاثنين.
  /// ترقيم day_number (المستخدم لتحديد يوم اليوم الفعلي وقفل بدء التمرين)
  /// لا يتغير هنا — هذا تعديل على ترتيب العرض فقط.
  List<WorkoutDayData> _orderedDays(WorkoutPlanData plan) {
    final startWeekday = plan.createdAt.weekday;
    final sorted = [...plan.days];
    sorted.sort((a, b) {
      final offsetA = (a.dayNumber - startWeekday + 7) % 7;
      final offsetB = (b.dayNumber - startWeekday + 7) % 7;
      return offsetA.compareTo(offsetB);
    });
    return sorted;
  }

  Widget _buildDaySelector(List<WorkoutDayData> days) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // الاتجاه يتبع لغة الواجهة (RTL في العربية، LTR في الإنجليزية) مثل تبويب
    // التغذية تماماً — لا يوجد فرض اتجاه ثابت بعد الآن.
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = day.dayNumber == _selectedDay;
          final status = context.read<WorkoutCubit>().dayStatus(day);
          return InkWell(
            onTap: () => setState(() => _selectedDay = day.dayNumber),
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandPrimary
                        : AppColors.grayLight.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: selected ? AppShapes.cardShadow : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        day.isRestDay
                            ? Icons.self_improvement
                            : Icons.fitness_center,
                        size: 18,
                        color: selected ? Colors.white : AppColors.grayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _weekdayLabel(day.dayNumber, isArabic),
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.grayMedium,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

  Widget _buildRestDay(bool isArabic) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.self_improvement,
              color: AppColors.accentBlue, size: 40),
          const SizedBox(height: 12),
          Text(
            isArabic ? 'يوم راحة، استمتع به!' : "It's a rest day, enjoy it!",
            style: const TextStyle(color: AppColors.grayMedium, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(
      WorkoutPlanData plan, WorkoutDayData day, Set<String> completedIds) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: day.exercises.length,
      itemBuilder: (context, index) {
        final item = day.exercises[index];
        return _ExerciseCard(
          item: item,
          day: day,
          plan: plan,
          isCompleted: completedIds.contains(item.id),
        );
      },
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final WorkoutExerciseData item;
  final WorkoutDayData day;
  final WorkoutPlanData plan;
  final bool isCompleted;
  const _ExerciseCard({
    required this.item,
    required this.day,
    required this.plan,
    required this.isCompleted,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final ex = widget.item.exercise;
    final isToday = widget.day.dayNumber == widget.plan.todayDayNumber();
    final locked = !widget.isCompleted && !isToday;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      // بمجرد إتمام التمرين، تُقفَل البطاقة (onTap: null) لمنع إعادة تنفيذه
      // بالخطأ من نفس الجلسة. كذلك يُقفَل فعل "بدء التمرين" لأي يوم غير
      // يوم اليوم الفعلي — يمكن تصفّح أي يوم، لكن لا يمكن بدؤه إلا في يومه.
      onTap: widget.isCompleted
          ? null
          : locked
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isArabic
                          ? 'لا يمكن بدء هذا التمرين إلا في يومه المحدد'
                          : 'This exercise can only be started on its scheduled day'),
                      backgroundColor: AppColors.accentRed,
                    ),
                  )
              : () {
                  final workoutCubit = context.read<WorkoutCubit>();
                  final homeCubit = context.read<HomeCubit>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseSessionScreen(
                        item: widget.item,
                        onCompleted: () {
                          workoutCubit.markExerciseCompleted(widget.item.id);
                          // إن كان هذا يوم اليوم الفعلي وأصبحت كل تمارينه
                          // منتهية، فعّل تلقائياً بطاقة "التمرين" في الرئيسية.
                          if (workoutCubit.isDayFullyCompleted(widget.day)) {
                            homeCubit.toggleWorkout(true);
                          }
                        },
                      ),
                    ),
                  );
                },
      child: Container(
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
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ex.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.isCompleted)
                    const Icon(Icons.check_circle,
                        color: AppColors.brandPrimary, size: 20)
                  else if (locked)
                    const Icon(Icons.lock_outline,
                        color: AppColors.grayLight, size: 18)
                  else
                    const Icon(Icons.chevron_right,
                        color: AppColors.grayLight, size: 18),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ex.targetMuscle,
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
                  _infoChip(Icons.repeat,
                      '${widget.item.sets} × ${widget.item.repsRange}'),
                  const SizedBox(width: 8),
                  _infoChip(
                      Icons.timer_outlined,
                      isArabic
                          ? 'راحة ${widget.item.restSeconds}ث'
                          : '${widget.item.restSeconds}s rest'),
                ],
              ),
              if (ex.description != null || ex.commonMistakes != null) ...[
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
                  if (ex.description != null) ...[
                    const SizedBox(height: 6),
                    Text(ex.description!,
                        style: const TextStyle(
                            color: AppColors.grayMedium, fontSize: 12)),
                  ],
                  if (ex.commonMistakes != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.accentOrange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ex.commonMistakes!,
                            style: const TextStyle(
                                color: AppColors.accentOrange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 8),
              InkWell(
                onTap:
                    ex.videoUrl != null ? () => _openVideo(ex.videoUrl!) : null,
                child: Row(
                  children: [
                    Icon(
                      ex.videoUrl != null
                          ? Icons.play_circle_outline
                          : Icons.videocam_off_outlined,
                      size: 16,
                      color: ex.videoUrl != null
                          ? AppColors.accentBlue
                          : AppColors.grayLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ex.videoUrl != null
                          ? (isArabic ? 'مشاهدة الفيديو' : 'Watch video')
                          : (isArabic
                              ? 'الفيديو غير متوفر بعد'
                              : 'Video not available yet'),
                      style: TextStyle(
                        color: ex.videoUrl != null
                            ? AppColors.accentBlue
                            : AppColors.grayLight,
                        fontSize: 11,
                        fontWeight: ex.videoUrl != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.grayLight.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.grayMedium),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: AppColors.grayMedium, fontSize: 11)),
        ],
      ),
    );
  }
}
