import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/medication_card.dart';
import '../widgets/gradient_button.dart';
import 'add_medication_page.dart';
import 'chat_page.dart';
import '../models/medication.dart';
import '../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final List<Medication> _medications = [];

  // متغيرات التقرير والتحليل
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

  // دالة جديدة لحذف الدواء
  void _deleteMedication(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدواء'),
        content: const Text('هل أنت متأكد من حذف هذا الدواء؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _medications.removeWhere((med) => med.id == id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف الدواء بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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

  // عرض نافذة التقرير
  void _showDailyReportDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyReportDialog(
        onSubmit: (answers) {
          _submitDailyReport(context, answers);
        },
      ),
    );
  }

  // ==========================================
  // دالة إرسال التقرير
  // ==========================================
  Future<void> _submitDailyReport(
    BuildContext context,
    Map<String, dynamic> answers,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. تحويل الأدوية لتنسيق الـ API
      final medicationsData = _medications
          .map(
            (med) => {
              'name': med.name,
              'time': med.time.format(context),
              'isTaken': med.isTaken,
            },
          )
          .toList();

      // 2. إرسال التقرير مع تحويل نوع الإجابات إلى String بشكل صريح
      final response = await _apiService.analyzeDailyReport(
        userType: 'treatment',
        medications: medicationsData,
        // التحويل هنا لتجنب خطأ Map<String, dynamic>
        questionnaireAnswers: Map<String, String>.from(answers),
        userName: 'آدم',
      );

      // 3. تحديث الواجهة بالنتيجة
      setState(() {
        _dailySummary = response.analysis;
        _recommendations = response.recommendations;
        _healthScore = response.healthScore;
        _warningLevel = response.warningLevel;
        _reportSubmittedToday = true;
      });

      // 4. عرض التفاصيل في نافذة منبثقة
      if (mounted) {
        _showDetailedAnalysis(context, response);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
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
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    // Health Score Widget
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

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

              // Close Button
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
      appBar: AppBar(
        title: const Text('AFYA CARE - لوحة التحكم'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.appGradient),
        ),
        elevation: 4,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً آدم 👋',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextMedication != null
                          ? 'الجرعة التالية: ${nextMedication.name} الساعة ${nextMedication.time.format(context)}'
                          : 'لا توجد جرعات قادمة',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Today's Medications
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
                              (medication) =>
                                  _buildMedicationCardWithDelete(medication),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // AI Summary Box
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

                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Scrollbar(
                                thumbVisibility: false,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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

                            // Report Button
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
                                          const SizedBox(
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
                      gradient: AppTheme.appGradient,
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

  // دالة جديدة لبناء بطاقة الدواء مع زر الحذف
  Widget _buildMedicationCardWithDelete(Medication medication) {
    return Stack(
      children: [
        MedicationCard(
          medication: medication,
          onToggle: () => _toggleMedicationStatus(medication.id),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: GestureDetector(
            onTap: () => _deleteMedication(medication.id),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// DailyReportDialog Widget (تصميم متناسق + شرطي)
// ==========================================

class DailyReportDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const DailyReportDialog({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<DailyReportDialog> createState() => _DailyReportDialogState();
}

class _DailyReportDialogState extends State<DailyReportDialog> {
  final Map<String, String> _answers = {};

  // القائمة الكاملة للأسئلة
  final List<Map<String, String>> _allQuestions = [
    {
      'key': 'adherence',
      'text': '1. هل تمكنت من أخذ جميع جرعات الدواء في مواعيدها المحددة؟',
    },
    {
      'key': 'improvement',
      'text': '2. هل تشعر بتحسن ملحوظ في الأعراض مقارنة بالأمس؟',
    },
    {
      'key': 'new_symptoms',
      'text': '3. هل ظهرت عليك أي أعراض جديدة مفاجئة اليوم؟',
    },
    {
      'key': 'pain_level',
      'text': '4. هل كان مستوى الألم يمنعك من ممارسة نشاطك الطبيعي؟',
    },
    {
      'key': 'vitals_normal',
      'text': '5. هل كانت مؤشراتك الحيوية (ضغط/سكر) ضمن المعدل الطبيعي؟',
    },
    {
      'key': 'sleep_quality',
      'text': '6. هل حصلت على نوم متواصل ومريح الليلة الماضية؟',
    },
    {'key': 'appetite', 'text': '7. هل كانت شهيتك للطعام جيدة وطبيعية اليوم؟'},
    {
      'key': 'energy_level',
      'text': '8. هل استطعت إكمال يومك دون الشعور بتعب أو إرهاق شديد؟',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // لون التطبيق الأساسي (الأزرق)
    const primaryColor = Color(0xFF4A80F0);

    // تصفية الأسئلة بناءً على الإجابات السابقة
    final visibleQuestions = _allQuestions.where((q) {
      if (q['key'] == 'pain_level') {
        // سؤال الألم يظهر فقط إذا كانت الإجابة على "new_symptoms" (سؤال 3) هي "نعم"
        return _answers['new_symptoms'] == 'نعم';
      }
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // رأس النافذة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in, color: primaryColor),
                const SizedBox(width: 10),
                const Text(
                  "التقرير اليومي",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // قائمة الأسئلة المصفاة
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              itemCount: visibleQuestions.length,
              separatorBuilder: (ctx, i) => const Divider(height: 30),
              itemBuilder: (context, index) {
                final q = visibleQuestions[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['text']!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOptionBtn(
                            "نعم",
                            _answers[q['key']] == "نعم",
                            () {
                              setState(() {
                                _answers[q['key']!] = "نعم";
                                // إذا تم تغيير إجابة السؤال 3 إلى "نعم" ولكن كانت "لا" سابقاً، قد نحتاج تنظيف
                                // (Logic is handled in 'No' case primarily)
                              });
                            },
                            primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildOptionBtn(
                            "لا",
                            _answers[q['key']] == "لا",
                            () {
                              setState(() {
                                _answers[q['key']!] = "لا";
                                // إذا أجاب "لا" على سؤال 3، نحذف إجابة سؤال 4 لأنه سيختفي
                                if (q['key'] == 'new_symptoms') {
                                  _answers.remove('pain_level');
                                }
                              });
                            },
                            primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // زر الإرسال
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A80F0), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  // التحقق من الإجابة على جميع الأسئلة الظاهرة فقط
                  bool allAnswered = visibleQuestions.every(
                    (q) => _answers.containsKey(q['key']),
                  );

                  if (!allAnswered) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("يرجى الإجابة على جميع الأسئلة الظاهرة"),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  widget.onSubmit(_answers);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "إرسال التقرير",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionBtn(
    String text,
    bool isSelected,
    VoidCallback onTap,
    Color activeColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
