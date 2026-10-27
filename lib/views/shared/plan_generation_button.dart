import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/plan/plan_generation_cubit.dart';
import '../../controllers/plan/plan_generation_state.dart';
import '../../core/constants/app_colors.dart';

/// زر توليد خطة (تمارين أو تغذية، كل واحدة مستقلة عن الأخرى) بالذكاء
/// الاصطناعي، مع بار نسبة مئوية أثناء الانتظار.
///
/// ملاحظة صادقة: الخادم يرجع النتيجة دفعة واحدة (لا توجد تحديثات تقدّم
/// حقيقية من الخلفية)، لذا هذا شريط تقدّم **محاكى** يتحرك تدريجياً نحو 90%
/// أثناء الانتظار الفعلي، ويكتمل لـ100% فور وصول الرد الحقيقي من الخادم —
/// الهدف طمأنة المستخدم أن هناك عملية جارية وليس تجميداً، وليس قياساً دقيقاً.
class PlanGenerationButton extends StatefulWidget {
  final bool isArabic;
  final PlanType planType;
  final VoidCallback onGenerated;

  const PlanGenerationButton({
    super.key,
    required this.isArabic,
    required this.planType,
    required this.onGenerated,
  });

  @override
  State<PlanGenerationButton> createState() => _PlanGenerationButtonState();
}

class _PlanGenerationButtonState extends State<PlanGenerationButton> {
  bool _isGenerating = false;
  double _progress = 0.0;
  Timer? _timer;
  double _elapsedSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsedSeconds += 0.2;
      setState(() {
        _progress = 0.9 * (1 - math.exp(-_elapsedSeconds / 12));
      });
    });

    final cubit = PlanGenerationCubit();
    await cubit.generate(
      locale: widget.isArabic ? 'ar' : 'en',
      type: widget.planType,
    );
    final result = cubit.state;
    await cubit.close();

    _timer?.cancel();
    if (!mounted) return;

    if (result is PlanGenerationError) {
      setState(() {
        _isGenerating = false;
        _progress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(result.message, widget.isArabic)),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isGenerating = false);
    widget.onGenerated();
  }

  /// الخادم يعيد المحاولة تلقائياً (حتى تجربة نموذج احتياطي) عند ازدحام
  /// Gemini قبل أن يفشل نهائياً، فإن ظهرت هذه الرسالة يعني المشكلة استمرت
  /// أكثر من ذلك — نعرض رسالة مفهومة بدل نص الخطأ التقني الخام، مع تمييز
  /// 429 (تجاوز حصة المفتاح — يحتاج انتظاراً أطول أو ترقية للفوترة) عن 503
  /// (ازدحام مؤقت على خوادم Google نفسها) حتى يسهل التشخيص لاحقاً إن تكرر.
  String _friendlyError(String raw, bool isArabic) {
    final overloaded = raw.contains('503') ||
        raw.toLowerCase().contains('overloaded') ||
        raw.toLowerCase().contains('high demand');
    final rateLimited = raw.contains('429');

    if (rateLimited) {
      return isArabic
          ? 'تم تجاوز الحد المسموح لمفتاح الذكاء الاصطناعي حالياً (429)، يرجى المحاولة لاحقاً'
          : 'The AI key has hit its usage limit right now (429), please try again later';
    }
    if (overloaded) {
      return isArabic
          ? 'الخدمة مزدحمة حالياً (503)، يرجى المحاولة مرة أخرى بعد قليل'
          : 'The service is busy right now (503), please try again shortly';
    }
    return raw;
  }

  String _label() {
    final isWorkout = widget.planType == PlanType.workout;
    if (widget.isArabic) {
      return isWorkout
          ? 'توليد خطة التمارين بالذكاء الاصطناعي'
          : 'توليد خطة التغذية بالذكاء الاصطناعي';
    }
    return isWorkout
        ? 'Generate workout plan with AI'
        : 'Generate nutrition plan with AI';
  }

  String _progressLabel() {
    final percent = (_progress * 100).round();
    if (widget.isArabic) {
      return widget.planType == PlanType.workout
          ? 'جارٍ توليد خطة التمارين... $percent%'
          : 'جارٍ توليد خطة التغذية... $percent%';
    }
    return widget.planType == PlanType.workout
        ? 'Generating workout plan... $percent%'
        : 'Generating nutrition plan... $percent%';
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: AppColors.grayLight.withOpacity(0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _progressLabel(),
            style: const TextStyle(color: AppColors.grayMedium, fontSize: 12),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: _start,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        ),
        child: Text(
          _label(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
