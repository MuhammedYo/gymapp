import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../controllers/auth/auth_cubit.dart';
import '../../controllers/auth/auth_state.dart';
import '../../core/constants/app_colors.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        // 1. أثناء فحص الجلسة أو الانتظار بعد العودة من Google/Facebook
        if (state is AuthLoading) {
          return const Scaffold(
            backgroundColor: AppColors.primaryDark,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            ),
          );
        }

        // 2. إذا كان المستخدم مسجلاً دخوله بنجاح
        if (state is Authenticated) {
          return _PostAuthRouter(userId: state.userId);
        }

        // 3. في حال عدم وجود جلسة تسجيل دخول نشطة
        return const WelcomeScreen();
      },
    );
  }
}

/// يحدد هل يذهب المستخدم لصفحة استكمال البيانات (Onboarding) أم للرئيسية،
/// بناءً على profiles.onboarding_completed.
class _PostAuthRouter extends StatefulWidget {
  final String userId;
  const _PostAuthRouter({required this.userId});

  @override
  State<_PostAuthRouter> createState() => _PostAuthRouterState();
}

class _PostAuthRouterState extends State<_PostAuthRouter> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _isOnboardingCompleted(widget.userId);
  }

  void _retry() {
    setState(() => _future = _isOnboardingCompleted(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.primaryDark,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.primaryDark,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.accentRed, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }

  Future<bool> _isOnboardingCompleted(String userId) async {
    // maybeSingle بدل single: حساب بلا صف profiles بعد (مثلاً أُنشئ قبل
    // ضبط trigger الإنشاء التلقائي) يُعامَل كـ "لم يُكمل Onboarding" بدل
    // تعطيل التطبيق بالكامل على شاشة تحميل بلا نهاية.
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('onboarding_completed')
        .eq('id', userId)
        .maybeSingle();
    return profile?['onboarding_completed'] as bool? ?? false;
  }
}
