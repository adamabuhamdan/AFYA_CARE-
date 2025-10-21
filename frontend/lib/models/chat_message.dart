class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// في dashboard_page.dart - تحديث تعريف Questionnaire
class Questionnaire {
  final String question;
  final List<String> options;
  final String key; // أضف هذا السطر
  String? selectedAnswer;

  Questionnaire({
    required this.question,
    required this.options,
    required this.key, // أضف هذا السطر
    this.selectedAnswer,
  });
}
