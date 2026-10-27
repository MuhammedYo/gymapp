import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocaleCubit extends Cubit<Locale> {
  // اللغة الافتراضية: العربية
  LocaleCubit() : super(const Locale('ar'));

  void changeLanguage(String languageCode) {
    emit(Locale(languageCode));
  }

  void toggleLanguage() {
    if (state.languageCode == 'ar') {
      emit(const Locale('en'));
    } else {
      emit(const Locale('ar'));
    }
  }
}
