import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/workout/workout_state.dart';
import '../../core/constants/app_colors.dart';

enum _SessionPhase { idle, working, resting, done }

/// شاشة تفاصيل تمرين واحد + تنفيذه فعلياً كجلسة: مجموعات متتالية، كل واحدة
/// بمؤقّت عدّ تصاعدي حر (لأن التكرارات غير مرتبطة بزمن ثابت) ثم مؤقّت راحة
/// تنازلي تلقائي بين المجموعات، حتى إتمام كل المجموعات.
class ExerciseSessionScreen extends StatefulWidget {
  final WorkoutExerciseData item;
  final VoidCallback onCompleted;
  const ExerciseSessionScreen({
    super.key,
    required this.item,
    required this.onCompleted,
  });

  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> {
  _SessionPhase _phase = _SessionPhase.idle;
  int _currentSet = 1;
  int _workSeconds = 0;
  int _restRemaining = 0;
  Timer? _timer;

  int get _totalSets => widget.item.sets;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startExercise() {
    setState(() {
      _phase = _SessionPhase.working;
      _currentSet = 1;
      _workSeconds = 0;
    });
    _startWorkTimer();
  }

  void _startWorkTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _workSeconds++);
    });
  }

  void _finishSet() {
    _timer?.cancel();
    if (_currentSet >= _totalSets) {
      setState(() => _phase = _SessionPhase.done);
      widget.onCompleted();
      return;
    }
    setState(() {
      _phase = _SessionPhase.resting;
      _restRemaining = widget.item.restSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_restRemaining <= 1) {
        _advanceToNextSet();
      } else {
        setState(() => _restRemaining--);
      }
    });
  }

  void _skipRest() {
    _timer?.cancel();
    _advanceToNextSet();
  }

  void _advanceToNextSet() {
    _timer?.cancel();
    // تنبيه صوتي + اهتزاز خفيف عند انتهاء الراحة (أو تخطّيها)، ليعرف
    // المستخدم أن المجموعة التالية بدأت دون الحاجة للنظر إلى الشاشة.
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
    setState(() {
      _currentSet++;
      _phase = _SessionPhase.working;
      _workSeconds = 0;
    });
    _startWorkTimer();
  }

  Future<bool> _confirmExit(bool isArabic) async {
    if (_phase == _SessionPhase.idle || _phase == _SessionPhase.done) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'الخروج من التمرين؟' : 'Exit workout?'),
        content: Text(isArabic
            ? 'لم تُتم كل المجموعات بعد، هل تريد الخروج؟'
            : "You haven't finished all sets yet. Exit anyway?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isArabic ? 'استمرار' : 'Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isArabic ? 'خروج' : 'Exit',
                style: const TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final ex = widget.item.exercise;

    return PopScope(
      canPop: _phase == _SessionPhase.idle || _phase == _SessionPhase.done,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final confirmed = await _confirmExit(isArabic);
        if (confirmed && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(context, isArabic, ex.name),
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
                    child: _buildBody(isArabic),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isArabic, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (await _confirmExit(isArabic)) {
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isArabic) {
    switch (_phase) {
      case _SessionPhase.idle:
        return _buildDetails(isArabic);
      case _SessionPhase.working:
        return _buildWorking(isArabic);
      case _SessionPhase.resting:
        return _buildResting(isArabic);
      case _SessionPhase.done:
        return _buildDone(isArabic);
    }
  }

  // ==================== حالة التفاصيل (قبل البدء) ====================
  Widget _buildDetails(bool isArabic) {
    final ex = widget.item.exercise;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(ex.targetMuscle, AppColors.brandPrimary),
              if (ex.equipmentNeeded != 'none')
                _tag(ex.equipmentNeeded, AppColors.accentBlue),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _infoBlock(isArabic ? 'مجموعات' : 'Sets', '${widget.item.sets}'),
              _infoBlock(isArabic ? 'تكرارات' : 'Reps', widget.item.repsRange),
              _infoBlock(
                  isArabic ? 'راحة' : 'Rest', '${widget.item.restSeconds}s'),
            ],
          ),
          if (ex.description != null) ...[
            const SizedBox(height: 24),
            Text(
              isArabic ? 'طريقة الأداء' : 'How to perform',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              ex.description!,
              style: const TextStyle(
                  color: AppColors.grayMedium, fontSize: 13, height: 1.5),
            ),
          ],
          if (ex.commonMistakes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ex.commonMistakes!,
                      style: const TextStyle(
                          color: AppColors.accentOrange,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (ex.videoUrl != null) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _openVideo(ex.videoUrl!),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline,
                      size: 18, color: AppColors.accentBlue),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'مشاهدة فيديو توضيحي' : 'Watch tutorial video',
                    style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _startExercise,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: Text(
                isArabic ? 'ابدأ التمرين' : 'Start Exercise',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.grayMedium, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ==================== حالة أداء المجموعة ====================
  Widget _buildWorking(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic
                  ? 'المجموعة $_currentSet من $_totalSets'
                  : 'Set $_currentSet of $_totalSets',
              style: const TextStyle(
                  color: AppColors.grayMedium,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildSetDots(),
            const SizedBox(height: 32),
            // حلقة تمتلئ كل 60 ثانية (بدل مؤقّت لا نهائي بلا مرجعية بصرية)،
            // مع الوقت التصاعدي في المنتصف.
            _buildCircularTimer(
              value: (_workSeconds % 60) / 60,
              color: AppColors.brandPrimary,
              label: _formatTime(_workSeconds),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'استهدف ${widget.item.repsRange} تكرار'
                  : 'Aim for ${widget.item.repsRange} reps',
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 13),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _finishSet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  isArabic ? 'إنهاء المجموعة' : 'Finish Set',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== حالة الراحة ====================
  Widget _buildResting(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isArabic ? 'راحة' : 'Rest',
                style: const TextStyle(
                    color: AppColors.accentBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            // حلقة تنازلية تفرغ فعلياً مع اقتراب انتهاء الراحة.
            _buildCircularTimer(
              value: widget.item.restSeconds > 0
                  ? _restRemaining / widget.item.restSeconds
                  : 0,
              color: AppColors.accentBlue,
              label: _formatTime(_restRemaining),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'التالي: المجموعة ${_currentSet + 1} من $_totalSets'
                  : 'Next: Set ${_currentSet + 1} of $_totalSets',
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 13),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _skipRest,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.grayLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  isArabic ? 'تخطي الراحة' : 'Skip Rest',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularTimer({
    required double value,
    required Color color,
    required String label,
  }) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor: AppColors.grayLight.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 44,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSets, (index) {
        final setNumber = index + 1;
        final completed = setNumber < _currentSet;
        final current = setNumber == _currentSet;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 10 : 8,
          height: current ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed || current
                ? AppColors.brandPrimary
                : AppColors.grayLight.withOpacity(0.3),
          ),
        );
      }),
    );
  }

  // ==================== حالة الاكتمال ====================
  Widget _buildDone(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events,
                color: AppColors.brandPrimary, size: 64),
            const SizedBox(height: 16),
            Text(
              isArabic
                  ? 'أحسنت! أتممت التمرين 💪'
                  : 'Great job! Exercise done 💪',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'أتممت $_totalSets مجموعات من ${widget.item.exercise.name}'
                  : 'You completed $_totalSets sets of ${widget.item.exercise.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 13),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  isArabic ? 'رجوع' : 'Back',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
