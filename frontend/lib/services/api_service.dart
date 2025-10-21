import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // دالة جديدة لتحليل تقرير اليوم
  Future<DailyReportResponse> analyzeDailyReport({
    required String userType,
    required List<Map<String, dynamic>> medications,
    required Map<String, String> questionnaireAnswers,
    required String userName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze_daily_report'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Accept-Charset': 'utf-8',
      },
      encoding: Encoding.getByName('utf-8')!,
      body: jsonEncode({
        'user_type': userType,
        'medications': medications,
        'questionnaire_answers': questionnaireAnswers,
        'user_name': userName,
      }),
    );

    if (response.statusCode == 200) {
      final String decodedBody = utf8.decode(response.bodyBytes);
      return DailyReportResponse.fromJson(jsonDecode(decodedBody));
    } else {
      throw Exception(
        'Failed to analyze daily report: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> analyzeQuestionnaire({
    required String userType,
    required Map<String, String> answers,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze_questionnaire'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Accept-Charset': 'utf-8',
      },
      encoding: Encoding.getByName('utf-8')!,
      body: jsonEncode({'user_type': userType, 'answers': answers}),
    );

    if (response.statusCode == 200) {
      final String decodedBody = utf8.decode(response.bodyBytes);
      return jsonDecode(decodedBody);
    } else {
      throw Exception(
        'Failed to analyze questionnaire: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<ChatResponse> sendChatMessage({
    required String question,
    required String userType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Accept-Charset': 'utf-8',
      },
      encoding: Encoding.getByName('utf-8')!,
      body: jsonEncode({'question': question, 'user_type': userType}),
    );

    if (response.statusCode == 200) {
      final String decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      return ChatResponse.fromJson(data);
    } else if (response.statusCode == 500) {
      throw Exception('خطأ في الخادم: ${response.body}');
    } else {
      throw Exception('فشل في إرسال الرسالة: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> suggestMedicationSchedule({
    required List<String> medications,
    required String sleepTime,
    required String wakeUpTime,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/suggest_medication_schedule'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Accept-Charset': 'utf-8',
      },
      encoding: Encoding.getByName('utf-8')!,
      body: jsonEncode({
        'medications': medications,
        'sleep_time': sleepTime,
        'wake_up_time': wakeUpTime,
      }),
    );

    if (response.statusCode == 200) {
      final String decodedBody = utf8.decode(response.bodyBytes);
      return jsonDecode(decodedBody);
    } else {
      throw Exception(
        'Failed to get medication schedule: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // دالة مساعدة للتحقق من اتصال الخادم
  Future<bool> checkServerConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/'),
            headers: {'Accept': 'application/json; charset=utf-8'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class DailyReportResponse {
  final String analysis;
  final String recommendations;
  final int healthScore;
  final String warningLevel;
  final double processingTime;

  DailyReportResponse({
    required this.analysis,
    required this.recommendations,
    required this.healthScore,
    required this.warningLevel,
    required this.processingTime,
  });

  factory DailyReportResponse.fromJson(Map<String, dynamic> json) {
    return DailyReportResponse(
      analysis: json['analysis'] ?? 'لا يوجد تحليل متاح',
      recommendations: json['recommendations'] ?? 'لا توجد توصيات',
      healthScore: json['health_score'] ?? 0,
      warningLevel: json['warning_level'] ?? 'medium',
      processingTime: (json['processing_time'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysis': analysis,
      'recommendations': recommendations,
      'health_score': healthScore,
      'warning_level': warningLevel,
      'processing_time': processingTime,
    };
  }
}

class ChatResponse {
  final String answer;
  final List<dynamic> sources;
  final double processingTime;
  final String userType;

  ChatResponse({
    required this.answer,
    required this.sources,
    required this.processingTime,
    required this.userType,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] ?? 'لم يتم استلام رد',
      sources: json['sources'] ?? [],
      processingTime: (json['processing_time'] ?? 0.0).toDouble(),
      userType: json['user_type'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'sources': sources,
      'processing_time': processingTime,
      'user_type': userType,
    };
  }
}
