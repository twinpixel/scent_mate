import 'dart:math';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scent_mate/theme/app_theme.dart';

void main() {
  runApp(const ScentSuggestionApp());
}

class ScentSuggestionApp extends StatelessWidget {
  const ScentSuggestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scent Suggestions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Montserrat',
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const ScentSuggestionHomePage(),
    );
  }
}

class ScentSuggestionHomePage extends StatefulWidget {
  const ScentSuggestionHomePage({super.key});

  @override
  State<ScentSuggestionHomePage> createState() => _ScentSuggestionHomePageState();
}

class _ScentSuggestionHomePageState extends State<ScentSuggestionHomePage> {
  String _currentLanguage = 'en';
  List<Question> _questions = [];
  Map<String, String?> _answers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<ScentSuggestion> _suggestions = [];
  int _currentQuestionIndex = 0;
  late SharedPreferences _prefs; // Add this line

  @override
  void initState() {
    super.initState();
    _initPrefs().then((_) => _loadQuestions());
  }
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLanguage = _prefs.getString('selectedLanguage') ?? 'en';
    });
  }
  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _suggestions = [];
    });
    try {
      final path = 'assets/questions/q${_currentLanguage}.json';
      final data = await rootBundle.loadString(path);
      final jsonData = json.decode(data) as List;

      _questions = jsonData.map((q) => Question.fromJson(q)).toList();
      _answers = {for (var q in _questions) q.id: null};
      _currentQuestionIndex = 0;
    } catch (e) {
      debugPrint('Error loading questions: $e');
      if (_currentLanguage != 'en') {
        _currentLanguage = 'en';
        await _loadQuestions();
        return;
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeLanguage(String newLanguage) async {
    if (newLanguage != _currentLanguage) {
      await _prefs.setString('selectedLanguage', newLanguage); // Save to preferences
      setState(() => _currentLanguage = newLanguage);
      await _loadQuestions();
    }
  }

  void _answerQuestion(String questionId, String answer) {
    setState(() {
      _answers[questionId] = answer;
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        // Check if all questions are answered
        bool allAnswered = _answers.values.every((answer) => answer != null);
        if (allAnswered) {
          submitAnswers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_getTranslation('complete_all_questions'))),
          );
        }
      }
    });
  }
  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  Future<void> _submitAnswersMistral() async {
    print("Mistral...");
    const keyMistral = String.fromEnvironment('KEY_MISTRAL');
    if (keyMistral.isEmpty) {
      throw AssertionError('KEY_MISTRAL is not set');
    }
    setState(() {
      _isSubmitting = true;
      _suggestions = [];
    });

    try {
      final prompt = _constructPrompt();

      final response = await http.post(
        Uri.parse('https://api.mistral.ai/v1/chat/completions'),
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
              "content": prompt+'.\n write all your answer in only in'+_getLanguageName(_prefs.getString('selectedLanguage') ?? 'en')+'.\n write long and ealborate texts.'
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
        _processApiResponse(jsonResponse);
      } else {
        throw Exception('Failed to get suggestion: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getTranslation('submission_error'))),
      );
      debugPrint('Error submitting answers: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
  Future<void> _submitAnswersPollination() async {

    print("Pollination...");
    setState(() {
      _isSubmitting = true;
      _suggestions = [];
    });

    try {
      final prompt = _constructPrompt();

      final response = await http.post(
        Uri.parse('https://text.pollinations.ai/openai'),
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
              "content": prompt+'.\n write all your answer in only in'+_getLanguageName(_prefs.getString('selectedLanguage') ?? 'en')+'.\n write long and ealborate texts.'
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
        final cleanedContent =
        content.replaceAll('```json', '').replaceAll('```', '').trim();
        final jsonResponse = json.decode(cleanedContent);
        _processApiResponse(jsonResponse);
      } else {
        throw Exception('Failed to get suggestion: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getTranslation('submission_error'))),
      );
      debugPrint('Error submitting answers: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  String generateRole() => "You are Antoine Dubois, a revered perfumer based in the heart of Paris, your atelier nestled in the elegant Marais district. Your lineage boasts generations of celebrated fragrance creators, and your understanding of olfactory art is legendary. You possess an almost mystical connection to raw materials, from the most precious Grasse roses to the most exotic spices sourced from distant lands. Your pronouncements on perfume are delivered with an air of sophisticated authority, often punctuated by dramatic sighs and eloquent pronouncements. You hold a deep reverence for the traditions of French perfumery and view mass-produced scents with a certain hauteur. For you, a true perfume is a meticulously crafted œuvre d'art, a harmonious blend of notes designed to tell a story and awaken the deepest emotions. You might delicately inhale a new creation, then exclaim with a theatrical flourish, 'Ah, mon Dieu! This… this lacks âme! It is as bland as a buttered radish! Where is the poetry? The je ne sais quoi?' When presented with a particularly exquisite essence, you might close your eyes, a faint smile gracing your lips, and murmur with reverence, 'This tuberose… it is not merely a flower, non. It is the very whisper of desire on a summer night in Provence, captured in a bottle. Magnifique!. Respond ONLY with valid JSON.";


  String _constructPrompt() {
    final answerDescriptions = _questions.map((q) =>
    "Question: ${q.text}\nAnswer: ${_answers[q.id]}\n"
    ).join('\n');

    return '''
Based on the following user preferences, suggest 3 personalized fragrance recommendations.
Respond with a JSON array containing the suggestions. Each suggestion should have:
- "name": The fragrance name
- "brand": The brand that makes it
- "description": A long  description enclosing all your knowledge
- "scent_profile": An object with "top_notes", "middle_notes", and "base_notes" arrays
- "best_for": Array of best occasions/situations
- "similar_scents": Array of similar fragrances
- "why_match": Long explanation why this matches their preferences 

Format the response as valid JSON only, without any additional text or commentary.

User Preferences:
$answerDescriptions
''';
  }

  void _processApiResponse(dynamic jsonResponse) {
    try {
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

      setState(() => _suggestions = suggestions);
    } catch (e) {
      debugPrint('Error processing API response: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getTranslation('submission_error'))),
      );
    }
  }
  Future<void> _submitAnswersGemini() async {
    print("Gemini...");
    const apiKey = String.fromEnvironment('KEY_GEMINI');
    if (apiKey.isEmpty) {
      throw AssertionError('KEY_GEMINI is not set');
    }
    setState(() {
      _isSubmitting = true;
      _suggestions = [];
    });

    try {
      final prompt = _constructPrompt();

      var body = json.encode({
        "contents": [
          {
            "parts": [
              {
                "text": generateRole() + prompt + '.\n write all your answer in only in ' +
                    _getLanguageName(_prefs.getString('selectedLanguage') ?? 'en') +
                    '.\n write long and elaborate texts.'
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 2000
        }
      });

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _processGeminiApiResponse(data);
      } else {
        throw Exception('Failed to get suggestion: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getTranslation('submission_error'))),
      );
      debugPrint('Error submitting answers: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _processGeminiApiResponse(dynamic jsonResponse) {
    try {
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

                  // Clean the response text
                  final cleanedContent = responseText
                      .replaceAll('```json', '')
                      .replaceAll('```', '')
                      .trim();

                  // Parse the JSON
                  final jsonData = json.decode(cleanedContent);

                  // Process the suggestions
                  if (jsonData is List) {
                    for (var item in jsonData) {
                      suggestions.add(ScentSuggestion.fromJson(item));
                    }
                  } else if (jsonData is Map) {
                    if (jsonData.containsKey('suggestions') && jsonData['suggestions'] is List) {
                      for (var item in jsonData['suggestions']) {
                        suggestions.add(ScentSuggestion.fromJson(item));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      setState(() => _suggestions = suggestions);
    } catch (e) {
      debugPrint('Error processing Gemini API response: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getTranslation('submission_error'))),
      );
    }
  }

  void _restartQuestionnaire() {
    setState(() {
      _answers = {for (var q in _questions) q.id: null};
      _currentQuestionIndex = 0;
      _suggestions = [];
    });
  }

  String _getTranslation(String key) {
    final translations = {
      'en': {
        'app_title': 'Scent Suggestions',
        'language': 'Language',
        'complete_all_questions': 'Please answer all questions before submitting.',
        'submission_error': 'Error getting suggestion. Please try again.',
        'previous': 'Previous',
        'next': 'Next',
        'submit': 'Get Suggestion',
        'restart': 'Start Over',
        'suggestion_title': 'Your Scent Suggestions',
        'loading': 'Loading...',
        'brand': 'Brand',
        'description': 'Description',
        'scent_profile': 'Scent Profile',
        'best_for': 'Best For',
        'similar_scents': 'Similar Scents',
        'why_match': 'Why This Match',
        'buy': 'Buy',
        'top_notes': 'Top Notes',
        'middle_notes': 'Middle Notes',
        'base_notes': 'Base Notes',
        'loading_suggestions': 'Analyzing your preferences...',
      },
      'es': { 'buy': 'Comprar',
        'app_title': 'Sugerencias de Aroma',
        'language': 'Idioma',
        'complete_all_questions': 'Por favor responda todas las preguntas antes de enviar.',
        'submission_error': 'Error al obtener sugerencia. Por favor intente nuevamente.',
        'previous': 'Anterior',
        'next': 'Siguiente',
        'submit': 'Obtener Sugerencia',
        'restart': 'Comenzar de Nuevo',
        'suggestion_title': 'Tus Sugerencias de Aroma',
        'loading': 'Cargando...',
        'brand': 'Marca',
        'description': 'Descripción',
        'scent_profile': 'Perfil de Aroma',
        'best_for': 'Mejor Para',
        'similar_scents': 'Aromas Similares',
        'why_match': 'Por Qué Coincide',
        'top_notes': 'Notas Superiores',
        'middle_notes': 'Notas Medias',
        'base_notes': 'Notas Base',
      },
      'fr': {'buy': 'Acheter',
        'app_title': 'Suggestions de Parfum',
        'language': 'Langue',
        'complete_all_questions': 'Veuillez répondre à toutes les questions avant de soumettre.',
        'submission_error': 'Erreur lors de la récupération de la suggestion. Veuillez réessayer.',
        'previous': 'Précédent',
        'next': 'Suivant',
        'submit': 'Obtenir une Suggestion',
        'restart': 'Recommencer',
        'suggestion_title': 'Vos Suggestions de Parfum',
        'loading': 'Chargement...',
        'brand': 'Marque',
        'description': 'Description',
        'scent_profile': 'Profil Olfactif',
        'best_for': 'Idéal Pour',
        'similar_scents': 'Parfums Similaires',
        'why_match': 'Pourquoi Ce Choix',
        'top_notes': 'Notes de Tête',
        'middle_notes': 'Notes de Cœur',
        'base_notes': 'Notes de Fond',
      },
      'ru': { 'buy': 'Купить',
        'app_title': 'Ароматические предложения',
        'language': 'Язык',
        'complete_all_questions': 'Пожалуйста, ответьте на все вопросы перед отправкой.',
        'submission_error': 'Ошибка при получении предложения. Пожалуйста, попробуйте снова.',
        'previous': 'Назад',
        'next': 'Далее',
        'submit': 'Получить предложение',
        'restart': 'Начать заново',
        'suggestion_title': 'Ваши ароматические предложения',
        'loading': 'Загрузка...',
        'brand': 'Бренд',
        'description': 'Описание',
        'scent_profile': 'Ароматический профиль',
        'best_for': 'Лучшее для',
        'similar_scents': 'Похожие ароматы',
        'why_match': 'Почему это совпадение',
        'top_notes': 'Верхние ноты',
        'middle_notes': 'Средние ноты',
        'base_notes': 'Базовые ноты',
      },
      'it': {   'buy': 'Acquista',
        'app_title': 'Suggerimenti di Profumo',
        'language': 'Lingua',
        'complete_all_questions': 'Per favore rispondi a tutte le domande prima di inviare.',
        'submission_error': 'Errore durante il recupero del suggerimento. Per favore riprova.',
        'previous': 'Precedente',
        'next': 'Successivo',
        'submit': 'Ottieni Suggerimento',
        'restart': 'Ricominciare',
        'suggestion_title': 'I tuoi suggerimenti di profumo',
        'loading': 'Caricamento...',
        'brand': 'Marca',
        'description': 'Descrizione',
        'scent_profile': 'Profilo olfattivo',
        'best_for': 'Migliore per',
        'similar_scents': 'Profumi simili',
        'why_match': 'Perché questa corrispondenza',
        'top_notes': 'Note di testa',
        'middle_notes': 'Note di cuore',
        'base_notes': 'Note di base',
        'loading_suggestions': 'Analisi delle tue preferenze...',
      },
    };

    return translations[_currentLanguage]?[key] ?? translations['en']![key]!;
  }

  Future<void> _showLanguageDialog() async {
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getTranslation('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'en',
                groupValue: _currentLanguage,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: const Text('Español'),
              leading: Radio<String>(
                value: 'es',
                groupValue: _currentLanguage,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: const Text('Français'),
              leading: Radio<String>(
                value: 'fr',
                groupValue: _currentLanguage,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: const Text('Italiano'),
              leading: Radio<String>(
                value: 'it',
                groupValue: _currentLanguage,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: const Text('Русский'),
              leading: Radio<String>(
                value: 'ru',
                groupValue: _currentLanguage,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedLanguage != null) {
      await _changeLanguage(selectedLanguage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _getTranslation('app_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _showLanguageDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getTranslation('loading'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              )
            : _suggestions.isNotEmpty
                ? _buildSuggestionsView()
                : _buildQuestionnaire(),
      ),
    );
  }
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getTranslation('app_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Developed by Andrea Poltronieri'),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () => launch('https://github.com/twinpixel/scent_mate'),
              child: Text(
                'Source: https://github.com/twinpixel/scent_mate',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text('BSD 3-Clause License'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  Widget _buildQuestionnaire() {
    if (_isSubmitting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _getTranslation('loading_suggestions'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
            ),
          ],
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: Colors.grey.shade200,
              color: Theme.of(context).colorScheme.primary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            currentQuestion.text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),
          ...currentQuestion.options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answers[currentQuestion.id] == option
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    foregroundColor: _answers[currentQuestion.id] == option
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    ),
                  ),
                  onPressed: () => _answerQuestion(currentQuestion.id, option),
                  child: Text(
                    option,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              )),
          const SizedBox(height: 24),
          if (_currentQuestionIndex > 0)
            OutlinedButton.icon(
              onPressed: _previousQuestion,
              icon: const Icon(Icons.arrow_back),
              label: Text(_getTranslation('previous')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void submitAnswers() async {
    // Create a random number generator
    final random = Random();
    // Generate a random number (0 or 1)
    final choice = random.nextInt(2); // 0 or 1

    // Choose randomly between Gemini and Pollination
    if (choice == 0) {
      await _submitAnswersGemini();
    } else {
      await _submitAnswersPollination();
    }
  }

  Widget _buildSuggestionsView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _getTranslation('suggestion_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return _buildSuggestionCard(suggestion);
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _restartQuestionnaire,
            icon: const Icon(Icons.refresh),
            label: Text(_getTranslation('restart')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(ScentSuggestion suggestion) {
    Future<void> _openGoogleSearch(String query) async {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://www.google.com/search?q=$encodedQuery';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (suggestion.brand.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          suggestion.brand,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _openGoogleSearch(
                    '${_getTranslation('buy')} ${suggestion.name} ${suggestion.brand}',
                  ),
                  tooltip: 'Search online',
                ),
              ],
            ),
            if (suggestion.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                suggestion.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (suggestion.scentProfile.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildScentProfileSection(suggestion.scentProfile),
            ],
            if (suggestion.bestFor.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTranslation('best_for'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestion.bestFor
                        .map((item) => Chip(
                              label: Text(item),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ],
            if (suggestion.similarScents.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTranslation('similar_scents'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestion.similarScents
                        .map((item) => InkWell(
                              onTap: () => _openGoogleSearch(
                                '${_getTranslation('buy')} $item',
                              ),
                              child: Chip(
                                label: Text(item),
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ],
            if (suggestion.whyMatch.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTranslation('why_match'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(suggestion.whyMatch),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScentProfileSection(ScentProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTranslation('scent_profile'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (profile.topNotes.isNotEmpty)
          _buildNoteSection(_getTranslation('top_notes'), profile.topNotes),
        if (profile.middleNotes.isNotEmpty)
          _buildNoteSection(_getTranslation('middle_notes'), profile.middleNotes),
        if (profile.baseNotes.isNotEmpty)
          _buildNoteSection(_getTranslation('base_notes'), profile.baseNotes),
      ],
    );
  }

  Widget _buildNoteSection(String title, List<String> notes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: notes
                .map((note) => Chip(
                      label: Text(note),
                      backgroundColor:
                          Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class Question {
  final String id;
  final String text;
  final List<String> options;

  Question({
    required this.id,
    required this.text,
    required this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      text: json['text'],
      options: List<String>.from(json['options']),
    );
  }
}

class ScentSuggestion {
  final String name;
  final String brand;
  final String description;
  final ScentProfile scentProfile;
  final List<String> bestFor;
  final List<String> similarScents;
  final String whyMatch;

  ScentSuggestion({
    required this.name,
    required this.brand,
    required this.description,
    required this.scentProfile,
    required this.bestFor,
    required this.similarScents,
    required this.whyMatch,
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
    );
  }
}

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

String _getLanguageName(String languageCode) {
  switch (languageCode.toLowerCase()) {
    case 'it':
      return 'Italiano';
    case 'en':
      return 'English';
    case 'es':
      return 'Español';
    case 'fr':
      return 'Français';
    case 'de':
      return 'Deutsch';
    case 'ru':
      return 'Russian';
    default:
      return 'English';
  }
}

