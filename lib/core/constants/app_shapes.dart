import 'package:flutter/material.dart';

/// ثوابت مشتركة لظلال/توهّج البطاقات في الوضع الداكن. العمق هنا يعتمد
/// أساساً على فرق إضاءة السطح (surfaceCard أفتح من الخلفية primaryDark)،
/// والظل هنا إضافي فقط لعزل حواف البطاقة عن الخلفية الداكنة.
class AppShapes {
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> floatingNavShadow = [
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  // توهّج خفيف بلون العلامة التجارية، يُستخدم على الأزرار الرئيسية لإحساس
  // "كوني" حديث بدل ظل أسود عادي.
  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x408B5CF6),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}
