import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controllers/auth/auth_cubit.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/language/locale_cubit.dart';
import '../../core/constants/app_colors.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- دوال التحقق وفق المعايير الحديثة ---

  String? _validateName(String? value, bool isArabic) {
    if (value == null || value.trim().isEmpty) {
      return isArabic
          ? 'يرجى إدخال الاسم الكامل'
          : 'Please enter your full name';
    }
    final nameRegExp = RegExp(r"^[\p{L}\s']{3,50}$", unicode: true);
    if (!nameRegExp.hasMatch(value.trim())) {
      return isArabic
          ? 'الاسم يجب أن يتكون من 3 أحرف على الأقل وبدون أرقام'
          : 'Name must be at least 3 characters long and contain letters only';
    }
    return null;
  }

  String? _validateEmail(String? value, bool isArabic) {
    if (value == null || value.trim().isEmpty) {
      return isArabic
          ? 'يرجى إدخال البريد الإلكتروني'
          : 'Please enter your email';
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return isArabic
          ? 'يرجى إدخال صيغة بريد إلكتروني صحيحة'
          : 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value, bool isArabic) {
    if (value == null || value.isEmpty) {
      return isArabic ? 'يرجى إدخال كلمة المرور' : 'Please enter a password';
    }
    if (value.length < 8) {
      return isArabic
          ? 'كلمة المرور يجب أن تكون 8 خانات على الأقل'
          : 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return isArabic
          ? 'يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل (A-Z)'
          : 'Password must contain at least one uppercase letter (A-Z)';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return isArabic
          ? 'يجب أن تحتوي كلمة المرور على حرف صغير واحد على الأقل (a-z)'
          : 'Password must contain at least one lowercase letter (a-z)';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return isArabic
          ? 'يجب أن تحتوي كلمة المرور على رقم واحد على الأقل (0-9)'
          : 'Password must contain at least one number (0-9)';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return isArabic
          ? 'يجب أن تحتوي كلمة المرور على رمز خاص واحد على الأقل (!@#\$%)'
          : 'Password must contain at least one special character (!@#\$%)';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value, bool isArabic) {
    if (value == null || value.isEmpty) {
      return isArabic
          ? 'يرجى تأكيد كلمة المرور'
          : 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return isArabic ? 'كلمات المرور غير متطابقة' : 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الترويسة
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      InkWell(
                        onTap: () =>
                            context.read<LocaleCubit>().toggleLanguage(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.grayDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.brandPrimary.withOpacity(0.3)),
                          ),
                          child: Text(
                            isArabic ? 'English' : 'عربي',
                            style: const TextStyle(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? 'إنشاء\nحساب جديد' : 'Create Your\nAccount',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 32,
                          height: 1.25,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // النموذج الأبيض
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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(28.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // الاسم الكامل
                        Text(
                          isArabic ? 'الاسم الكامل' : 'Full Name',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'John Smith',
                            hintStyle: TextStyle(color: AppColors.grayLight),
                            enabledBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: AppColors.grayLight),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.brandPrimary, width: 2),
                            ),
                          ),
                          validator: (val) => _validateName(val, isArabic),
                        ),

                        const SizedBox(height: 20),

                        // البريد الإلكتروني
                        Text(
                          isArabic ? 'البريد الإلكتروني' : 'Email',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'john@email.com',
                            hintStyle: TextStyle(color: AppColors.grayLight),
                            enabledBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: AppColors.grayLight),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.brandPrimary, width: 2),
                            ),
                          ),
                          validator: (val) => _validateEmail(val, isArabic),
                        ),

                        const SizedBox(height: 20),

                        // كلمة المرور
                        Text(
                          isArabic ? 'كلمة المرور' : 'Password',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '******',
                            hintStyle:
                                const TextStyle(color: AppColors.grayLight),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.grayMedium,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: AppColors.grayLight),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.brandPrimary, width: 2),
                            ),
                          ),
                          validator: (val) => _validatePassword(val, isArabic),
                        ),

                        const SizedBox(height: 20),

                        // تأكيد كلمة المرور
                        Text(
                          isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '******',
                            hintStyle:
                                const TextStyle(color: AppColors.grayLight),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.grayMedium,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: AppColors.grayLight),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.brandPrimary, width: 2),
                            ),
                          ),
                          validator: (val) =>
                              _validateConfirmPassword(val, isArabic),
                        ),

                        const SizedBox(height: 32),

                        // زر انشاء الحساب
                        BlocConsumer<AuthCubit, AuthState>(
                          listener: (context, state) {
                            if (state is SignUpSuccess) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isArabic
                                        ? 'تم إنشاء الحساب بنجاح! لقد أرسلنا رسالة تحقق إلى بريدك الإلكتروني، يرجى تأكيده ثم تسجيل الدخول.'
                                        : 'Account created successfully! We sent a verification email to your inbox — please confirm it, then sign in.',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 5),
                                ),
                              );

                              // التحويل التلقائي لشاشة تسجيل الدخول
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                              );
                            } else if (state is AuthError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.message),
                                  backgroundColor: AppColors.accentRed,
                                ),
                              );
                            }
                          },
                          builder: (context, state) {
                            return SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          context.read<AuthCubit>().signUp(
                                                _emailController.text.trim(),
                                                _passwordController.text.trim(),
                                                _nameController.text.trim(),
                                              );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        isArabic ? 'إنشاء الحساب' : 'SIGN UP',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // العودة لتسجيل الدخول
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isArabic
                                  ? 'لديك حساب بالفعل؟ '
                                  : 'Already have an account? ',
                              style: const TextStyle(
                                color: AppColors.grayLight,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              },
                              child: Text(
                                isArabic ? 'تسجيل الدخول' : 'Sign In',
                                style: const TextStyle(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
