class BodyScanAnalysis {
  final String summary;
  final List<String> observations;
  final List<String> suggestions;

  const BodyScanAnalysis({
    required this.summary,
    required this.observations,
    required this.suggestions,
  });

  factory BodyScanAnalysis.fromJson(Map<String, dynamic> json) {
    return BodyScanAnalysis(
      summary: json['summary'] as String? ?? '',
      observations: (json['observations'] as List?)?.cast<String>() ?? [],
      suggestions: (json['suggestions'] as List?)?.cast<String>() ?? [],
    );
  }
}

class BodyScanItem {
  final String id;
  final String imagePath;
  final String signedUrl;
  final String status; // pending | done | failed
  final DateTime createdAt;
  final BodyScanAnalysis? analysis;

  const BodyScanItem({
    required this.id,
    required this.imagePath,
    required this.signedUrl,
    required this.status,
    required this.createdAt,
    this.analysis,
  });
}

abstract class BodyScanState {}

class BodyScanLoading extends BodyScanState {}

class BodyScanError extends BodyScanState {
  final String message;
  BodyScanError(this.message);
}

class BodyScanLoaded extends BodyScanState {
  final List<BodyScanItem> scans;
  final bool isSubmitting;
  BodyScanLoaded({required this.scans, this.isSubmitting = false});

  BodyScanLoaded copyWith({List<BodyScanItem>? scans, bool? isSubmitting}) {
    return BodyScanLoaded(
      scans: scans ?? this.scans,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
