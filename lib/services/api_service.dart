import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scent_suggestion.dart';

class ApiService {
  static const String _mistralEndpoint = 'https://api.mistral.ai/v1/chat/completions';
  static const String _pollinationEndpoint = 'https://text.pollinations.ai/openai';
  static const String _geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  static String generateRole() => "You are Antoine Dubois, a revered perfumer based in the heart of Paris, your atelier nestled in the elegant Marais district. Your lineage boasts generations of celebrated fragrance creators, and your understanding of olfactory art is legendary. You possess an almost mystical connection to raw materials, from the most precious Grasse roses to the most exotic spices sourced from distant lands. Your pronouncements on perfume are delivered with an air of sophisticated authority, often punctuated by dramatic sighs and eloquent pronouncements. You hold a deep reverence for the traditions of French perfumery and view mass-produced scents with a certain hauteur. For you, a true perfume is a meticulously crafted œuvre d'art, a harmonious blend of notes designed to tell a story and awaken the deepest emotions. You might delicately inhale a new creation, then exclaim with a theatrical flourish, 'Ah, mon Dieu! This… this lacks âme! It is as bland as a buttered radish! Where is the poetry? The je ne sais quoi?' When presented with a particularly exquisite essence, you might close your eyes, a faint smile gracing your lips, and murmur with reverence, 'This tuberose… it is not merely a flower, non. It is the very whisper of desire on a summer night in Provence, captured in a bottle. Magnifique!. Respond ONLY with valid JSON.";

  static String constructPrompt(List<Map<String, String>> answers) {
    final answerDescriptions = answers.map((q) =>
      "Question: ${q['text']}\nAnswer: ${q['answer']}\n"
    ).join('\n');

    return '''
Based on the following user preferences, suggest 3 personalized fragrance recommendations.
Respond with a JSON array containing the suggestions. Each suggestion should have:
- "name": The fragrance name
- "brand": The brand that makes it
- "description": A long description enclosing all your knowledge
- "scent_profile": An object with "top_notes", "middle_notes", and "base_notes" arrays
- "best_for": Array of best occasions/situations
- "similar_scents": Array of similar fragrances
- "why_match": Long explanation why this matches their preferences
- "buy_url": URL to purchase the fragrance

Format the response as valid JSON only, without any additional text or commentary.

User Preferences:
$answerDescriptions
''';
  }

  static Future<List<ScentSuggestion>> submitToMistral(String prompt, String language) async {
    const keyMistral = String.fromEnvironment('KEY_MISTRAL');
    if (keyMistral.isEmpty) {
      throw AssertionError('KEY_MISTRAL is not set');
    }

    final response = await http.post(
      Uri.parse(_mistralEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $keyMistral',
      },
      body: json.encode({
        "model": "istral-small-latest",
        "messages": [
          {
            "role": "system",
            "content": generateRole()
          },
          {
            "role": "user",
            "content": prompt + '.\n write all your answer in only in ' + language + '.\n write long and elaborate texts.'
          }
        ],
        "seed": 42,
        "temperature": 0.7,
        "max_tokens": 2000
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final content = data['choices'][0]['message']['content'];
      final cleanedContent = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .replaceAll('Ã³', 'ò')
          .replaceAll('Ã¨', 'è')
          .replaceAll('Ã©', 'é')
          .replaceAll('Ã', 'È')
          .replaceAll('Ã ', 'à ')
          .replaceAll('Ã.', 'à.')
          .replaceAll('Ã', 'à')
          .replaceAll('Ã¹', 'ù')
          .trim();
      final jsonResponse = json.decode(cleanedContent);
      return _processApiResponse(jsonResponse);
    } else {
      throw Exception('Failed to get suggestion: ${response.statusCode}');
    }
  }

  static Future<List<ScentSuggestion>> submitToPollination(String prompt, String language) async {
    final response = await http.post(
      Uri.parse(_pollinationEndpoint),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "model": "openai",
        "messages": [
          {
            "role": "system",
            "content": generateRole()
          },
          {
            "role": "user",
            "content": prompt + '.\n write all your answer in only in ' + language + '.\n write long and elaborate texts.'
          }
        ],
        "seed": 42,
        "temperature": 0.7,
        "max_tokens": 2000
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final content = data['choices'][0]['message']['content'];
      final cleanedContent = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonResponse = json.decode(cleanedContent);
      return _processApiResponse(jsonResponse);
    } else {
      throw Exception('Failed to get suggestion: ${response.statusCode}');
    }
  }

  static Future<List<ScentSuggestion>> submitToGemini(String prompt, String language) async {
    const apiKey = String.fromEnvironment('KEY_GEMINI');
    if (apiKey.isEmpty) {
      throw AssertionError('KEY_GEMINI is not set');
    }

    final response = await http.post(
      Uri.parse('$_geminiEndpoint?key=$apiKey'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: json.encode({
        "contents": [
          {
            "parts": [
              {
                "text": generateRole() + prompt + '.\n write all your answer in only in ' + language + '.\n write long and elaborate texts.'
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 2000
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _processGeminiApiResponse(data);
    } else {
      throw Exception('Failed to get suggestion: ${response.statusCode}');
    }
  }

  static List<ScentSuggestion> _processApiResponse(dynamic jsonResponse) {
    final List<ScentSuggestion> suggestions = [];

    if (jsonResponse is List) {
      for (var item in jsonResponse) {
        suggestions.add(ScentSuggestion.fromJson(item));
      }
    } else if (jsonResponse is Map) {
      if (jsonResponse.containsKey('suggestions') && jsonResponse['suggestions'] is List) {
        for (var item in jsonResponse['suggestions']) {
          suggestions.add(ScentSuggestion.fromJson(item));
        }
      }
    }

    return suggestions;
  }

  static List<ScentSuggestion> _processGeminiApiResponse(dynamic jsonResponse) {
    final List<ScentSuggestion> suggestions = [];

    if (jsonResponse is Map && jsonResponse.containsKey('candidates')) {
      final candidates = jsonResponse['candidates'] as List;
      if (candidates.isNotEmpty) {
        final firstCandidate = candidates.first;
        if (firstCandidate is Map && firstCandidate.containsKey('content')) {
          final content = firstCandidate['content'];
          if (content is Map && content.containsKey('parts')) {
            final parts = content['parts'] as List;
            if (parts.isNotEmpty) {
              final firstPart = parts.first;
              if (firstPart is Map && firstPart.containsKey('text')) {
                String responseText = firstPart['text'];
                final cleanedContent = responseText
                    .replaceAll('```json', '')
                    .replaceAll('```', '')
                    .trim();
                final jsonData = json.decode(cleanedContent);
                return _processApiResponse(jsonData);
              }
            }
          }
        }
      }
    }

    return suggestions;
  }
} 