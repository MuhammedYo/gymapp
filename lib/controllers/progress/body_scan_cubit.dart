import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'body_scan_state.dart';

/// يدير قائمة صور تحليل الجسم بالذكاء الاصطناعي: رفع صورة جديدة إلى Storage،
/// إنشاء صف body_scans، استدعاء Edge Function "analyze-body-scan" للتحليل،
/// ثم عرض السجل كاملاً مع حالة كل صورة (قيد التحليل/منتهية/فشلت).
class BodyScanCubit extends Cubit<BodyScanState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  BodyScanCubit() : super(BodyScanLoading());

  Future<void> fetchScans() async {
    try {
      emit(BodyScanLoading());
      final userId = _supabase.auth.currentUser!.id;

      final rows = await _supabase
          .from('body_scans')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final items = <BodyScanItem>[];
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final path = row['image_path'] as String? ?? '';
        String signedUrl = '';
        if (path.isNotEmpty) {
          try {
            signedUrl = await _supabase.storage
                .from('body-scans')
                .createSignedUrl(path, 3600);
          } catch (_) {
            // نتجاهل فشل توليد رابط موقّت لصورة واحدة، تُعرض بدون صورة فقط
          }
        }

        BodyScanAnalysis? analysis;
        final rawSummary = row['ai_summary'] as String?;
        if (rawSummary != null) {
          try {
            analysis = BodyScanAnalysis.fromJson(
                jsonDecode(rawSummary) as Map<String, dynamic>);
          } catch (_) {}
        }

        items.add(BodyScanItem(
          id: row['id'] as String,
          imagePath: path,
          signedUrl: signedUrl,
          status: row['status'] as String? ?? 'pending',
          createdAt: DateTime.parse(row['created_at'] as String),
          analysis: analysis,
        ));
      }

      emit(BodyScanLoaded(scans: items));
    } catch (e) {
      emit(BodyScanError(e.toString()));
    }
  }

  Future<void> addScan({required XFile file, required String locale}) async {
    final current = state;
    final previousScans =
        current is BodyScanLoaded ? current.scans : <BodyScanItem>[];
    emit(BodyScanLoaded(scans: previousScans, isSubmitting: true));

    String? scanId;
    try {
      final userId = _supabase.auth.currentUser!.id;
      final bytes = await file.readAsBytes();
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('body-scans').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final inserted = await _supabase
          .from('body_scans')
          // image_url عمود قديم NOT NULL من المخطط الأصلي؛ نملؤه بنفس مسار
          // التخزين لأن الـ bucket خاص (private) ولا يوجد رابط عام فعلي.
          .insert({
            'user_id': userId,
            'image_path': path,
            'image_url': path,
            'status': 'pending',
          })
          .select('id')
          .single();
      scanId = inserted['id'] as String;

      final response = await _supabase.functions.invoke(
        'analyze-body-scan',
        body: {'scan_id': scanId, 'locale': locale},
      );

      if (response.status != 200) {
        final data = response.data;
        final message =
            data is Map ? (data['error'] ?? response.status) : response.status;
        throw Exception(message);
      }

      await fetchScans();
    } catch (e) {
      if (scanId != null) {
        try {
          await _supabase
              .from('body_scans')
              .update({'status': 'failed'}).eq('id', scanId);
        } catch (_) {}
      }
      await fetchScans();
      rethrow;
    }
  }
}
