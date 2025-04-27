import 'scent_profile.dart';

class ScentSuggestion {
  final String name;
  final String brand;
  final String description;
  final ScentProfile scentProfile;
  final List<String> bestFor;
  final List<String> similarScents;
  final String whyMatch;
  final String buyUrl;

  ScentSuggestion({
    required this.name,
    required this.brand,
    required this.description,
    required this.scentProfile,
    required this.bestFor,
    required this.similarScents,
    required this.whyMatch,
    required this.buyUrl,
  });

  factory ScentSuggestion.fromJson(Map<String, dynamic> json) {
    return ScentSuggestion(
      name: json['name'] ?? 'Unknown Fragrance',
      brand: json['brand'] ?? '',
      description: json['description'] ?? '',
      scentProfile: ScentProfile.fromJson(json['scent_profile'] ?? {}),
      bestFor: List<String>.from(json['best_for'] ?? []),
      similarScents: List<String>.from(json['similar_scents'] ?? []),
      whyMatch: json['why_match'] ?? '',
      buyUrl: json['buy_url'] ?? '',
    );
  }
} 