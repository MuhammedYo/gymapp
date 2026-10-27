import 'package:flutter/material.dart';

/// وضع داكن كامل بهوية "كوني/تقني": بنفسجي ← أزرق ← تركوازي، ممزوجة في
/// تدرجات، مع خلفيات وبطاقات داكنة في كل شاشات التطبيق (لا وجود لأي جسم
/// أبيض بعد الآن).
class AppColors {
  // خلفيات داكنة بطبقتين: خلفية الشاشة العميقة، وسطح البطاقات (أفتح قليلاً
  // لإعطاء إحساس ارتفاع/عمق بدل التعويل على الظلال فقط، وهو الأسلوب المتّبع
  // في التصميم الداكن الحديث).
  static const Color primaryDark = Color(0xFF120E1E);
  static const Color surfaceCard = Color(0xFF1E1A33);

  // نص فاتح رئيسي (بديل النص الداكن الذي كان يُستخدم على الجسم الأبيض سابقاً)
  static const Color textPrimary = Color(0xFFF3F1FA);

  // العلامة التجارية: تدرّج كوني بنفسجي ← أزرق ← تركوازي
  static const Color brandPrimary = Color(0xFF8B5CF6);
  static const Color brandBlue = Color(0xFF3B82F6);
  static const Color brandTeal = Color(0xFF14B8A6);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, brandBlue, brandTeal],
  );

  // رمادي بلمسة بنفسجية باردة، مُعاد ضبط إضاءته ليقرأ بوضوح على الأسطح
  // الداكنة (grayMedium أفتح وأوضح كنص ثانوي، grayLight أخفت كعناصر خافتة)
  static const Color grayLight = Color(0xFF6E6A8F);
  static const Color grayMedium = Color(0xFFB4B0D1);
  static const Color grayDark = Color(0xFF2A2645);

  // Accents
  static const Color accentPurple = Color(0xFFA78BFA);
  static const Color accentRed = Color(0xFFFF5470);
  static const Color accentOrange = Color(0xFFFFB84D);
  static const Color accentBlue = Color(0xFF38BDF8);
}
