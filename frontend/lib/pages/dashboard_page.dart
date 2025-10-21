import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/medication_card.dart';
import '../widgets/gradient_button.dart';
import 'add_medication_page.dart';
import 'chat_page.dart';
import '../models/medication.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List<Medication> _medications = [];

  // أسئلة تقرير نهاية اليوم مع حقول نصية
  final List<DailyQuestion> _dailyReportQuestions = [
    DailyQuestion(
      question: 'هل تناولت جميع أدويتك اليوم حسب الجدول؟',
      hint: 'مثال: نعم جميع الأدوية / معظم الأدوية / لم أتناول بعضها',
      key: 'adherence',
      isRequired: true,
    ),
    DailyQuestion(
      question: 'ما هي الأدوية التي لم تتناولها (إن وجدت)؟',
      hint: 'مثال: نسيت جرعة الصباح / تناولت جميع الأدوية',
      key: 'missed_meds',
      isRequired: false,
    ),
    DailyQuestion(
      question: 'ما هو سبب عدم تناول الدواء (إن وجد)؟',
      hint: 'مثال: نسيت الموعد / شعرت بتحسن / أعراض جانبية',
      key: 'reason',
      isRequired: false,
    ),
    DailyQuestion(
      question: 'هل واجهت أي أعراض جانبية اليوم؟',
      hint: 'مثال: لا توجد أعراض / غثيان خفيف / صداع',
      key: 'side_effects',
      isRequired: false,
    ),
    DailyQuestion(
      question: 'ما هي شدة الأعراض التي شعرت بها؟',
      hint: 'مثال: لا توجد أعراض / خفيفة / متوسطة / شديدة',
      key: 'symptom_severity',
      isRequired: false,
    ),
    DailyQuestion(
      question: 'كيف كان شعورك العام اليوم؟',
      hint: 'مثال: ممتاز / جيد / متوسط / سيء',
      key: 'general_feeling',
      isRequired: true,
    ),
    DailyQuestion(
      question: 'هل هناك أي ملاحظات تريد إضافتها؟',
      hint: 'مثال: لا توجد ملاحظات / تحسنت الأعراض / أحتاج استشارة',
      key: 'notes',
      isRequired: false,
      maxLines: 3,
    ),
  ];

  Map<String, String> _dailyReportAnswers = {};
  final Map<String, TextEditingController> _controllers = {};
  String _dailySummary = 'لم يتم إرسال تقرير اليوم بعد.';
  bool _reportSubmittedToday = false;
  bool _isLoading = false;
  int _healthScore = 0;
  String _warningLevel = 'medium';
  String _recommendations = '';

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // إنشاء controllers لكل سؤال
    for (var question in _dailyReportQuestions) {
      _controllers[question.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // تنظيف controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void addMedication(Medication medication) {
    setState(() {
      _medications.add(medication);
    });
  }

  void _toggleMedicationStatus(String id) {
    setState(() {
      final index = _medications.indexWhere((med) => med.id == id);
      if (index != -1) {
        _medications[index] = _medications[index].copyWith(
          isTaken: !_medications[index].isTaken,
        );
      }
    });
  }

  Medication? _getNextMedication() {
    final now = TimeOfDay.now();
    final upcoming = _medications
        .where((med) => _isTimeAfter(med.time, now))
        .toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => _timeToMinutes(a.time) - _timeToMinutes(b.time));
    return upcoming.first;
  }

  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour > time2.hour) return true;
    if (time1.hour == time2.hour) return time1.minute > time2.minute;
    return false;
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  void _showDailyReportDialog(BuildContext context) {
    // إعادة تعيين الـ controllers إذا كان هذا تقرير جديد
    if (!_reportSubmittedToday) {
      for (var controller in _controllers.values) {
        controller.clear();
      }
      _dailyReportAnswers.clear();
    } else {
      // ملء القيم السابقة إذا كان تحديث
      for (var entry in _dailyReportAnswers.entries) {
        if (_controllers.containsKey(entry.key)) {
          _controllers[entry.key]!.text = entry.value;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.summarize, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('تقرير نهاية اليوم'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ساعدنا في تحسين رعايتك الصحية من خلال مشاركة تجربتك اليومية',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // عرض الأدوية الحالية
                  if (_medications.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'أدويتك اليوم:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._medications
                              .map(
                                (med) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        med.isTaken
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: med.isTaken
                                            ? Colors.green
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          med.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        med.time.format(context),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // حقول الإدخال النصية
                  ..._dailyReportQuestions.map((question) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  question.question,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (question.isRequired)
                                const Text(
                                  '*',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _controllers[question.key],
                            maxLines: question.maxLines,
                            decoration: InputDecoration(
                              hintText: question.hint,
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                _dailyReportAnswers[question.key] = value;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  _submitDailyReport(context);
                },
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إرسال التقرير'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitDailyReport(BuildContext context) async {
    // جمع الإجابات من الـ controllers
    for (var entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        _dailyReportAnswers[entry.key] = text;
      }
    }

    // التحقق من الإجابات الأساسية المطلوبة
    bool hasEssentialAnswers = true;
    List<String> missingFields = [];

    for (var question in _dailyReportQuestions) {
      if (question.isRequired) {
        if (!_dailyReportAnswers.containsKey(question.key) ||
            _dailyReportAnswers[question.key]!.isEmpty) {
          hasEssentialAnswers = false;
          missingFields.add(question.question.substring(0, 30) + '...');
        }
      }
    }

    if (!hasEssentialAnswers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى الإجابة على الأسئلة المطلوبة (*): \n${missingFields.join('\n')}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // تحويل الأدوية إلى تنسيق مناسب للـ API
      final medicationsData = _medications
          .map(
            (med) => {
              'name': med.name,
              'time': med.time.format(context),
              'isTaken': med.isTaken,
            },
          )
          .toList();

      // إرسال التقرير إلى الـ API
      final response = await _apiService.analyzeDailyReport(
        userType: 'treatment',
        medications: medicationsData,
        questionnaireAnswers: _dailyReportAnswers,
        userName: 'آدم',
      );

      setState(() {
        _dailySummary = response.analysis;
        _recommendations = response.recommendations;
        _healthScore = response.healthScore;
        _warningLevel = response.warningLevel;
        _reportSubmittedToday = true;
      });

      Navigator.pop(context);

      // عرض التحليل المفصل
      _showDetailedAnalysis(context, response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إرسال التقرير: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDetailedAnalysis(
    BuildContext context,
    DailyReportResponse response,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header ثابت
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header مع الأيقونة والعنوان
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getWarningColor(
                              response.warningLevel,
                            ).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.psychology,
                            color: _getWarningColor(response.warningLevel),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'تحليل اليوم بالذكاء الاصطناعي',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // درجة الصحة
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getHealthScoreColor(response.healthScore),
                            _getHealthScoreColor(
                              response.healthScore,
                            ).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _getHealthScoreColor(
                              response.healthScore,
                            ).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'درجة صحتك اليوم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${response.healthScore}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getHealthStatusText(response.healthScore),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // المحتوى القابل للتمرير
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // التحليل
                      const Text(
                        '📊 التحليل',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          response.analysis,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // التوصيات
                      const Text(
                        '💡 التوصيات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          response.recommendations,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // زر الإغلاق (ثابت في الأسفل)
              Container(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                          child: const Center(
                            child: Text(
                              'حسناً، فهمت',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getHealthStatusText(int score) {
    if (score >= 90) return 'صحة ممتازة! 💪';
    if (score >= 80) return 'صحة جيدة جداً 👍';
    if (score >= 70) return 'صحة جيدة 😊';
    if (score >= 60) return 'صحة مقبولة 👌';
    if (score >= 50) return 'تحتاج لتحسين 📈';
    return 'تحتاج عناية فورية 🚨';
  }

  Color _getWarningColor(String warningLevel) {
    switch (warningLevel) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return AppTheme.primary;
    }
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getMedicationStatus() {
    final takenMeds = _medications.where((med) => med.isTaken).length;
    final totalMeds = _medications.length;

    if (totalMeds == 0) return 'لا توجد أدوية مضافة';

    if (takenMeds == totalMeds) {
      return 'ممتاز! تناولت جميع أدويتك اليوم 💊';
    } else if (takenMeds >= totalMeds * 0.7) {
      return 'جيد! تناولت $takenMeds/$totalMeds من الأدوية';
    } else {
      return 'انتبه! تناولت $takenMeds/$totalMeds من الأدوية فقط';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextMedication = _getNextMedication();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'صباح الخير، آدم',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextMedication != null
                        ? 'الجرعة التالية: ${nextMedication.name} الساعة ${nextMedication.time.format(context)}'
                        : 'لا توجد جرعات قادمة',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Today's Medications Card
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.glassCard,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.medication, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'أدوية اليوم',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _getMedicationStatus(),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            ..._medications.map(
                              (medication) => MedicationCard(
                                medication: medication,
                                onToggle: () =>
                                    _toggleMedicationStatus(medication.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // AI Summary Box مع تقرير اليوم
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.glassCard,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  _reportSubmittedToday
                                      ? 'ملخص اليوم بالذكاء الاصطناعي'
                                      : 'ملخص الصحة بالذكاء الاصطناعي',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_reportSubmittedToday) ...[
                              // عرض درجة الصحة إذا كان هناك تقرير
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      _getHealthScoreColor(_healthScore),
                                      _getHealthScoreColor(
                                        _healthScore,
                                      ).withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'درجة صحتك اليوم',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_healthScore%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getHealthStatusText(_healthScore),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // إضافة تمرير للملخص في الصندوق الرئيسي
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // التحليل
                                      const Text(
                                        '📊 التحليل:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _dailySummary,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(height: 1.5),
                                      ),

                                      // التوصيات إذا كانت موجودة
                                      if (_recommendations.isNotEmpty &&
                                          _reportSubmittedToday) ...[
                                        const SizedBox(height: 16),
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '💡 التوصيات:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _recommendations,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                height: 1.5,
                                                color: Colors.black87,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // زر تقرير اليومي
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    _showDailyReportDialog(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (_isLoading)
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        else
                                          Icon(
                                            _reportSubmittedToday
                                                ? Icons.update
                                                : Icons.summarize,
                                            color: Colors.white,
                                          ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isLoading
                                              ? 'جاري التحليل...'
                                              : _reportSubmittedToday
                                              ? 'تحديث التقرير اليومي'
                                              : 'تقرير نهاية اليوم',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            if (_reportSubmittedToday) ...[
                              const SizedBox(height: 12),
                              Text(
                                'آخر تحديث: ${TimeOfDay.now().format(context)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Buttons
              const SizedBox(height: 20),
              Column(
                children: [
                  GradientButton(
                    text: 'إضافة دواء',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddMedicationPage(
                            onMedicationAdded: addMedication,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.darkTurquoise,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatPage(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: const Center(
                            child: Text(
                              'المحادثة الذكية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// كلاس جديد لتمثيل الأسئلة مع حقول نصية
class DailyQuestion {
  final String question;
  final String hint;
  final String key;
  final bool isRequired;
  final int maxLines;

  DailyQuestion({
    required this.question,
    required this.hint,
    required this.key,
    this.isRequired = false,
    this.maxLines = 1,
  });
}
