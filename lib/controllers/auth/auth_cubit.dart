import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription? _authSubscription;

  AuthCubit() : super(AuthInitial()) {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        emit(Authenticated(session.user.id));
      } else {
        if (state is! SignUpSuccess) {
          emit(Unauthenticated());
        }
      }
    });
  }

  void checkAuthStatus() {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      emit(Authenticated(session.user.id));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      emit(AuthLoading());
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        emit(Authenticated(res.user!.id));
      } else {
        emit(Unauthenticated());
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUp(String email, String password, String fullName) async {
    try {
      emit(AuthLoading());

      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      if (res.user != null) {
        // ملاحظة: صف profiles يُنشأ تلقائياً عبر trigger على auth.users
        // (راجع supabase/sql/handle_new_user.sql)، لذا لا حاجة لإدراجه هنا.
        await _supabase.auth.signOut();

        emit(SignUpSuccess());
      } else {
        emit(AuthError('تعذر إنشاء الحساب، يرجى المحاولة لاحقاً'));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      emit(AuthLoading());
      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
      if (!success) {
        emit(Unauthenticated());
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
