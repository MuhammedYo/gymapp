import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/progress/body_scan_cubit.dart';
import '../../controllers/progress/body_scan_state.dart';
import '../../controllers/progress/progress_cubit.dart';
import '../../controllers/progress/progress_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_shapes.dart';

/// تبويب "التقدم": إحصائيات الالتزام الأسبوعية، الأوسمة المكتسبة، وسجل
/// تحليل صور الجسم بالذكاء الاصطناعي. مستقل عن باقي التبويبات (لا حاجة
/// لمشاركة حالته معها)، لذا يُنشئ الـ Cubits الخاصة به محلياً.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ProgressCubit()..fetchProgress()),
        BlocProvider(create: (_) => BodyScanCubit()..fetchScans()),
      ],
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  isArabic ? 'التقدم' : 'Progress',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                child: RefreshIndicator(
                  color: AppColors.brandPrimary,
                  onRefresh: () {
                    final progressCubit = context.read<ProgressCubit>();
                    final bodyScanCubit = context.read<BodyScanCubit>();
                    return Future.wait([
                      progressCubit.fetchProgress(),
                      bodyScanCubit.fetchScans(),
                    ]);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    children: [
                      _ProgressStatsSection(isArabic: isArabic),
                      const SizedBox(height: 24),
                      _BadgesSection(isArabic: isArabic),
                      const SizedBox(height: 24),
                      _BodyScanSection(isArabic: isArabic),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== إحصائيات الالتزام ====================
class _ProgressStatsSection extends StatelessWidget {
  final bool isArabic;
  const _ProgressStatsSection({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressCubit, ProgressState>(
      builder: (context, state) {
        if (state is ProgressLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            ),
          );
        }

        if (state is ProgressError) {
          return Center(
            child: Text(
              isArabic ? 'حدث خطأ أثناء التحميل' : 'Something went wrong',
              style: const TextStyle(color: AppColors.accentRed),
            ),
          );
        }

        final data = (state as ProgressLoaded).data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statCard(FontAwesomeIcons.fire, AppColors.accentOrange,
                    '${data.streakDays}', isArabic ? 'أيام متتالية' : 'Streak'),
                const SizedBox(width: 10),
                _statCard(FontAwesomeIcons.solidStar, AppColors.brandPrimary,
                    '${data.totalPoints}', isArabic ? 'نقطة' : 'Points'),
                const SizedBox(width: 10),
                _statCard(FontAwesomeIcons.chartLine, AppColors.accentBlue,
                    '${data.currentLevel}', isArabic ? 'المستوى' : 'Level'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              isArabic ? 'آخر 7 أيام' : 'Last 7 days',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShapes.cardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: data.last7Days
                    .map((day) => _dayColumn(day, isArabic))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShapes.cardShadow,
        ),
        child: Column(
          children: [
            FaIcon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayColumn(DayCheckinSummary day, bool isArabic) {
    const weekdaysAr = ['اث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    const weekdaysEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final label = (isArabic ? weekdaysAr : weekdaysEn)[day.date.weekday - 1];

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.grayMedium, fontSize: 11),
        ),
        const SizedBox(height: 8),
        _dayDot(day.completedWorkout, FontAwesomeIcons.dumbbell),
        const SizedBox(height: 4),
        _dayDot(day.followedDiet, FontAwesomeIcons.utensils),
        const SizedBox(height: 4),
        _dayDot(day.waterGoalReached, FontAwesomeIcons.droplet),
      ],
    );
  }

  Widget _dayDot(bool achieved, IconData icon) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: achieved
            ? AppColors.brandPrimary
            : AppColors.grayLight.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: FaIcon(
        icon,
        size: 10,
        color: achieved ? Colors.white : AppColors.grayLight,
      ),
    );
  }
}

// ==================== الأوسمة ====================
class _BadgesSection extends StatelessWidget {
  final bool isArabic;
  const _BadgesSection({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressCubit, ProgressState>(
      builder: (context, state) {
        if (state is! ProgressLoaded) return const SizedBox.shrink();
        final badges = state.data.badges;
        if (badges.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'الأوسمة' : 'Badges',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: badges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) =>
                  _BadgeTile(badge: badges[index], isArabic: isArabic),
            ),
          ],
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeInfo badge;
  final bool isArabic;
  const _BadgeTile({required this.badge, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showBadgeDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: badge.earned
              ? AppColors.brandPrimary.withOpacity(0.15)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.earned ? AppColors.brandPrimary : Colors.transparent,
          ),
          boxShadow: badge.earned ? null : AppShapes.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: badge.earned ? 1 : 0.35,
              child: Text(badge.icon, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name(isArabic),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color:
                    badge.earned ? AppColors.textPrimary : AppColors.grayMedium,
              ),
            ),
            if (!badge.earned) ...[
              const SizedBox(height: 4),
              const Icon(Icons.lock_outline,
                  size: 12, color: AppColors.grayLight),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              badge.name(isArabic),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description(isArabic),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grayMedium, fontSize: 13),
            ),
            if (badge.earned && badge.earnedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                isArabic
                    ? 'تم الحصول عليه في ${_formatDate(badge.earnedAt!)}'
                    : 'Earned on ${_formatDate(badge.earnedAt!)}',
                style: const TextStyle(
                    color: AppColors.brandPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ==================== تحليل صور الجسم ====================
class _BodyScanSection extends StatelessWidget {
  final bool isArabic;
  const _BodyScanSection({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'تحليل الجسم بالذكاء الاصطناعي' : 'AI Body Analysis',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            BlocBuilder<BodyScanCubit, BodyScanState>(
              builder: (context, state) {
                final isSubmitting =
                    state is BodyScanLoaded && state.isSubmitting;
                return TextButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => _pickAndAnalyze(context, isArabic),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.brandPrimary),
                        )
                      : const Icon(Icons.add_a_photo_outlined,
                          size: 16, color: AppColors.brandPrimary),
                  label: Text(
                    isSubmitting
                        ? (isArabic ? 'جارٍ التحليل...' : 'Analyzing...')
                        : (isArabic ? 'إضافة صورة' : 'Add photo'),
                    style: const TextStyle(
                        color: AppColors.brandPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        BlocBuilder<BodyScanCubit, BodyScanState>(
          builder: (context, state) {
            if (state is BodyScanLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppColors.brandPrimary),
                ),
              );
            }

            if (state is BodyScanError) {
              return Center(
                child: Text(
                  isArabic ? 'حدث خطأ أثناء التحميل' : 'Something went wrong',
                  style: const TextStyle(color: AppColors.accentRed),
                ),
              );
            }

            final scans = (state as BodyScanLoaded).scans;
            if (scans.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShapes.cardShadow,
                ),
                child: Text(
                  isArabic
                      ? 'أضف صورة لتتبع تقدمك بمساعدة الذكاء الاصطناعي'
                      : 'Add a photo to track your progress with AI',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.grayMedium, fontSize: 13),
                ),
              );
            }

            return Column(
              children: [
                for (final scan in scans)
                  _BodyScanCard(scan: scan, isArabic: isArabic),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickAndAnalyze(BuildContext context, bool isArabic) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.textPrimary),
              title: Text(isArabic ? 'التقاط صورة' : 'Take a photo',
                  style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.textPrimary),
              title: Text(isArabic ? 'اختيار من المعرض' : 'Choose from gallery',
                  style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (picked == null || !context.mounted) return;

    final locale = Localizations.localeOf(context).languageCode;
    try {
      await context.read<BodyScanCubit>().addScan(file: picked, locale: locale);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.accentRed),
      );
    }
  }
}

class _BodyScanCard extends StatefulWidget {
  final BodyScanItem scan;
  final bool isArabic;
  const _BodyScanCard({required this.scan, required this.isArabic});

  @override
  State<_BodyScanCard> createState() => _BodyScanCardState();
}

class _BodyScanCardState extends State<_BodyScanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final isArabic = widget.isArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShapes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: scan.signedUrl.isNotEmpty
                    ? Image.network(
                        scan.signedUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(scan.createdAt),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _statusChip(isArabic),
                  ],
                ),
              ),
              if (scan.status == 'done' && scan.analysis != null)
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.grayMedium,
                  ),
                ),
            ],
          ),
          if (_expanded && scan.analysis != null) ...[
            const Divider(height: 24),
            Text(
              scan.analysis!.summary,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
            if (scan.analysis!.observations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                isArabic ? 'ملاحظات' : 'Observations',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.accentBlue),
              ),
              const SizedBox(height: 4),
              for (final o in scan.analysis!.observations) _bullet(o),
            ],
            if (scan.analysis!.suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                isArabic ? 'اقتراحات' : 'Suggestions',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.brandPrimary),
              ),
              const SizedBox(height: 4),
              for (final s in scan.analysis!.suggestions) _bullet(s),
            ],
          ],
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.grayLight.withOpacity(0.2),
      child: const Icon(Icons.image_outlined, color: AppColors.grayLight),
    );
  }

  Widget _statusChip(bool isArabic) {
    late Color color;
    late String label;
    switch (widget.scan.status) {
      case 'done':
        color = AppColors.brandPrimary;
        label = isArabic ? 'اكتمل التحليل' : 'Analysis ready';
        break;
      case 'failed':
        color = AppColors.accentRed;
        label = isArabic ? 'فشل التحليل' : 'Analysis failed';
        break;
      default:
        color = AppColors.accentOrange;
        label = isArabic ? 'جارٍ التحليل...' : 'Analyzing...';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ',
              style: TextStyle(color: AppColors.grayMedium, fontSize: 12)),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(color: AppColors.grayMedium, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
