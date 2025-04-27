class ScentProfile {
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;

  ScentProfile({
    required this.topNotes,
    required this.middleNotes,
    required this.baseNotes,
  });

  factory ScentProfile.fromJson(Map<String, dynamic> json) {
    return ScentProfile(
      topNotes: List<String>.from(json['top_notes'] ?? []),
      middleNotes: List<String>.from(json['middle_notes'] ?? []),
      baseNotes: List<String>.from(json['base_notes'] ?? []),
    );
  }

  bool get isEmpty => topNotes.isEmpty && middleNotes.isEmpty && baseNotes.isEmpty;
  bool get isNotEmpty => !isEmpty;
} 