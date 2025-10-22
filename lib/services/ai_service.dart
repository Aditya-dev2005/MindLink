import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _geminiApiKey =
      'AIzaSyDcxg8jaxMqOa-5tAc1XNMfa656xLlxyC0'; // Replace with your actual key
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  // Real Gemini API for chat summaries
  static Future<String> generateChatSummary(
      List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) {
      return 'No messages to summarize yet. Start chatting!';
    }

    try {
      // Prepare recent messages for AI
      final recentMessages = messages.reversed
          .take(15)
          .map((msg) {
            final text = msg['original_text'] ?? msg['text'];
            final sender = msg['sender'] ?? 'Unknown';
            return '$sender: $text';
          })
          .toList()
          .join('\n');

      final prompt = '''
Analyze this chat conversation and provide a concise summary with these sections:
1. Main topics discussed
2. Key decisions or action items
3. Overall tone and mood

Chat messages:
$recentMessages

Provide the summary in a clean, bullet-point format suitable for a study group.
''';

      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final summary = data['candidates'][0]['content']['parts'][0]['text'];
        return '🧠 AI Summary (Powered by Gemini)\n\n$summary';
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini API error: $e');
      // Fallback to simulated summary
      return _generateFallbackSummary(messages);
    }
  }

  // Real sentiment analysis with Gemini
  static Future<String> analyzeSentimentReal(List<String> messages) async {
    if (messages.isEmpty) return '😐 Neutral';

    try {
      final chatContext = messages.take(10).join('\n');

      final prompt = '''
Analyze the sentiment of this chat conversation. Return ONLY one of these three options:
- "😊 Positive" 
- "😐 Neutral"
- "😔 Negative"

Base your analysis on the overall tone and emotion.

Chat messages:
$chatContext
''';

      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 10,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sentiment =
            data['candidates'][0]['content']['parts'][0]['text'].trim();
        return sentiment;
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini sentiment error: $e');
      return analyzeSentiment(messages); // Fallback to basic analysis
    }
  }

  // Enhanced reminder detection with AI
  static Future<List<String>> extractRemindersAI(String message) async {
    try {
      final prompt = '''
Extract any reminders, tasks, or action items from this message. Return ONLY the specific tasks as a JSON array. If no reminders, return empty array.

Message: "$message"

Example response: ["study for exam", "complete project"]
''';

      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 100,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'].trim();

        // Parse JSON response
        try {
          final reminders = json.decode(responseText) as List;
          return reminders.cast<String>();
        } catch (e) {
          return extractReminders(message); // Fallback to regex
        }
      } else {
        return extractReminders(message); // Fallback to regex
      }
    } catch (e) {
      print('Gemini reminder error: $e');
      return extractReminders(message); // Fallback to regex
    }
  }

  // Fallback methods (keep your existing ones)
  static String analyzeSentiment(List<String> messages) {
    final allText = messages.join(' ').toLowerCase();

    final positiveWords = [
      'good',
      'great',
      'awesome',
      'thanks',
      'perfect',
      'yes',
      'okay',
      'happy',
      'love',
      'nice',
      'excellent',
      'amazing',
      'wonderful'
    ];
    final negativeWords = [
      'bad',
      'terrible',
      'hate',
      'no',
      'angry',
      'sad',
      'problem',
      'worse',
      'upset',
      'annoying',
      'frustrating',
      'disappointed'
    ];

    int positiveCount =
        positiveWords.where((word) => allText.contains(word)).length;
    int negativeCount =
        negativeWords.where((word) => allText.contains(word)).length;

    if (positiveCount > negativeCount + 2) return '😊 Positive';
    if (negativeCount > positiveCount + 2) return '😔 Negative';
    return '😐 Neutral';
  }

  static List<String> extractReminders(String message) {
    final reminderPatterns = [
      RegExp(r'remind me to (.+?)(?:tomorrow|tonight|later|today|now)',
          caseSensitive: false),
      RegExp(r'remember to (.+?)(?:tomorrow|today|now|later)',
          caseSensitive: false),
      RegExp(r'we should (.+?)(?:tomorrow|next|today|soon)',
          caseSensitive: false),
      RegExp(r'don\t forget to (.+?)(?:tomorrow|today)', caseSensitive: false),
      RegExp(r'I need to (.+?)(?:tomorrow|today)', caseSensitive: false),
    ];

    final reminders = <String>[];
    for (final pattern in reminderPatterns) {
      final matches = pattern.allMatches(message);
      for (final match in matches) {
        if (match.group(1) != null) {
          reminders.add(match.group(1)!.trim());
        }
      }
    }
    return reminders;
  }

  static String _generateFallbackSummary(List<Map<String, dynamic>> messages) {
    final recentMessages =
        messages.take(10).map((msg) => msg['text'].toString()).toList();
    final messageCount = messages.length;

    final topics = _extractTopics(recentMessages);
    final keyPoints = _extractKeyPoints(recentMessages);
    final actionItems = _extractActionItems(recentMessages);

    return '''📊 Chat Summary (Fallback):
• Total Messages: $messageCount
• Recent Topics: $topics
• Key Discussions: 
$keyPoints
• Suggested Action Items: 
$actionItems''';
  }

  static String _extractTopics(List<String> messages) {
    final topics = [
      'study',
      'project',
      'exam',
      'homework',
      'meeting',
      'assignment',
      'quiz',
      'test',
      'presentation',
      'research'
    ];
    final foundTopics = topics
        .where(
            (topic) => messages.any((msg) => msg.toLowerCase().contains(topic)))
        .toList();
    return foundTopics.isNotEmpty
        ? foundTopics.join(', ')
        : 'General discussion';
  }

  static String _extractKeyPoints(List<String> messages) {
    if (messages.isEmpty) return '• No recent discussions';

    final keyMessages = messages.take(3).map((msg) {
      final cleanMsg = msg.length > 50 ? '${msg.substring(0, 50)}...' : msg;
      return '• $cleanMsg';
    }).toList();

    return keyMessages.join('\n');
  }

  static String _extractActionItems(List<String> messages) {
    final actionWords = [
      'need to',
      'should',
      'must',
      'have to',
      'complete',
      'finish',
      'submit',
      'prepare',
      'work on',
      'start'
    ];
    final actionMessages = messages
        .where((msg) =>
            actionWords.any((word) => msg.toLowerCase().contains(word)))
        .toList();

    if (actionMessages.isEmpty) return '• No specific action items detected';

    return actionMessages.take(2).map((action) => '• $action').join('\n');
  }
}
