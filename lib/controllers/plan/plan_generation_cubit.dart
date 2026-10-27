import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'plan_generation_state.dart';

enum PlanType {
  workout('workout'),
  meal('meal');

  final String value;
  const PlanType(this.value);
}

/// يستدعي Edge Function "generate-plan" التي تطلب من الذكاء الاصطناعي إنشاء
/// خطة تمارين أو خطة تغذية بشكل مستقل (كل واحدة تُولَّد وتُحدَّث على حدة)،
/// وتكتبها في قاعدة البيانات مباشرة.
class PlanGenerationCubit extends Cubit<PlanGenerationState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  PlanGenerationCubit() : super(PlanGenerationInitial());

  Future<void> generate(
      {required String locale, required PlanType type}) async {
    try {
      emit(PlanGenerating());

      final response = await _supabase.functions.invoke(
        'generate-plan',
        body: {'locale': locale, 'type': type.value},
      );

      final data = response.data;
      if (response.status != 200) {
        final message =
            data is Map ? (data['error'] ?? response.status) : response.status;
        throw Exception(message);
      }

      emit(PlanGenerationSuccess());
    } catch (e) {
      emit(PlanGenerationError(e.toString()));
    }
  }
}
