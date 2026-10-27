class ProfileModel {
  final String id;
  final String? fullName;
  final int? age;
  final double? weightKg;
  final double? heightCm;

  ProfileModel({
    required this.id,
    this.fullName,
    this.age,
    this.weightKg,
    this.heightCm,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      fullName: json['full_name'],
      age: json['age'],
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'age': age,
      'weight_kg': weightKg,
      'height_cm': heightCm,
    };
  }
}
