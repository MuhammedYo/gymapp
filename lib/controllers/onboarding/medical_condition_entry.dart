class MedicalConditionEntry {
  final String conditionType; // 'disease' or 'injury'
  final String name;
  final String affectedBodyPart;
  final String severity; // 'mild', 'moderate', 'severe'

  const MedicalConditionEntry({
    required this.conditionType,
    required this.name,
    this.affectedBodyPart = '',
    this.severity = 'moderate',
  });
}
