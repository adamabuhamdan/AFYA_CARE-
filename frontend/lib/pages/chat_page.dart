import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/questionnaire_card.dart';
import '../widgets/gradient_button.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  final List<ChatMessage> _messages = [];
  bool _isUnderTreatment = false;
  bool _questionnaireCompleted = false;
  bool _treatmentStatusSelected = false;
  bool _isLoading = false;

  // أسئلة تقرير نهاية اليوم لمتابعة الأدوية
  final List<Questionnaire> _treatmentQuestions = [
    // السؤال 1: الالتزام
    Questionnaire(
      question: 'هل تناولت جميع أدويتك اليوم حسب الجدول؟',
      options: ['نعم', 'لا'],
      key: 'adherence',
    ),

    // السؤال 2 (الأصل 3): السبب
    // المنطق: يظهر فقط إذا كانت إجابة السؤال 1 هي "لا"
    // التعديل: تم تغيير الصيغة لتناسب نعم/لا
    Questionnaire(
      question: 'هل كان سبب عدم تناول الدواء هو النسيان؟',
      options: ['نعم', 'لا'],
      key: 'reason',
    ),

    // السؤال 3 (الأصل 4): الأعراض الجانبية
    Questionnaire(
      question: 'هل واجهت أي أعراض جانبية اليوم؟',
      options: ['نعم', 'لا'],
      key: 'side_effects',
    ),

    // السؤال 4 (الأصل 5): شدة الأعراض
    // المنطق: يظهر فقط إذا كانت إجابة السؤال 3 هي "نعم"
    // التعديل: تم تغيير الصيغة لتناسب نعم/لا
    Questionnaire(
      question: 'هل كانت الأعراض شديدة وتؤثر على نشاطك اليومي؟',
      options: ['نعم', 'لا'],
      key: 'symptom_severity',
    ),

    Questionnaire(
      question: 'هل تشعر بتحسن عام في صحتك اليوم؟',
      options: ['نعم', 'لا'],
      key: 'general_feeling',
    ),
  ];

  // أسئلة للمستخدمين غير الخاضعين للعلاج (وقاية)
  final List<Questionnaire> _preventionQuestions = [
    Questionnaire(
      question: 'ما هو نمط نومك؟',
      options: ['أقل من 6 ساعات', '6-8 ساعات', 'أكثر من 8 ساعات', 'غير منتظم'],
      key: 'sleep',
    ),
    Questionnaire(
      question: 'كم مرة تمارس الرياضة أسبوعياً؟',
      options: ['لا أمارس', '1-2 مرات', '3-4 مرات', 'يومياً'],
      key: 'exercise',
    ),
    Questionnaire(
      question: 'كيف تصف نظامك الغذائي؟',
      options: ['صحي جداً', 'صحي', 'متوسط', 'غير صحي'],
      key: 'diet',
    ),
    Questionnaire(
      question: 'هل تدخن أو تتناول الكحول؟',
      options: ['لا أدخن ولا أشرب', 'أدخن فقط', 'أشرب فقط', 'كلاهما'],
      key: 'habits',
    ),

    Questionnaire(
      question: 'هل لديك تاريخ عائلي لأمراض مزمنة؟',
      options: ['لا', 'سكري', 'ضغط', 'قلب', 'سرطان'],
      key: 'family_history',
    ),
  ];

  List<Questionnaire> get _currentQuestions =>
      _isUnderTreatment ? _treatmentQuestions : _preventionQuestions;

  void _setTreatmentStatus(bool isUnderTreatment) {
    setState(() {
      _isUnderTreatment = isUnderTreatment;
      _treatmentStatusSelected = true;
      _questionnaireCompleted = false;
    });
  }

  void _answerQuestion(int index, String answer) {
    setState(() {
      if (index < _currentQuestions.length) {
        _currentQuestions[index].selectedAnswer = answer;
      }
    });
  }

  Future<void> _completeQuestionnaire() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // جمع الإجابات بشكل صحيح
      Map<String, String> answers = {};

      for (var question in _currentQuestions) {
        if (question.selectedAnswer != null) {
          answers[question.key] = question.selectedAnswer!;
        }
      }

      // إرسال الاستبيان للخلفية الجديدة
      final response = await _apiService.analyzeQuestionnaire(
        userType: _isUnderTreatment ? 'treatment' : 'prevention',
        answers: answers,
      );

      setState(() {
        _questionnaireCompleted = true;
        _isLoading = false;
      });

      // إضافة رسالة الترحيب من الذكاء الاصطناعي
      _addMessage(response['welcome_message'], false);

      // إضافة التحليل من الذكاء الاصطناعي
      _addMessage(response['analysis'], false);

      // إضافة النصائح المخصصة
      _addMessage(response['personalized_advice'], false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('فشل في إرسال الاستبيان: $e');
    }
  }

  void _skipQuestionnaire() {
    final welcomeMessage = _isUnderTreatment
        ? 'مرحباً! أنا مساعدك الصحي. كيف يمكنني مساعدتك في متابعة علاجك اليوم؟ 💊'
        : 'مرحباً! أنا مساعدك الصحي. كيف يمكنني مساعدتك في الحفاظ على صحتك؟ 🌿';

    setState(() {
      _questionnaireCompleted = true;
    });
    _addMessage(welcomeMessage, false);
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isUser: isUser,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _addMessage(text, true);
    _textController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // إرسال السؤال للخلفية
      final response = await _apiService.sendChatMessage(
        question: text,
        userType: _isUnderTreatment ? 'treatment' : 'prevention',
      );

      setState(() {
        _isLoading = false;
      });

      _addMessage(response.answer, false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _addMessage('عذراً، حدث خطأ في المعالجة. يرجى المحاولة مرة أخرى.', false);
      _showError('فشل في إرسال الرسالة: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AFYA CARE - المساعد الصحي 🤖'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.appGradient),
        ),
        elevation: 4,
        foregroundColor: Colors.white,
        actions: [
          if (_questionnaireCompleted)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _showResetDialog();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_treatmentStatusSelected)
              _buildInitialSelectionView(context)
            else if (!_questionnaireCompleted)
              _buildQuestionnaireView(context)
            else
              _buildChatView(context),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة التعيين'),
        content: const Text(
          'هل تريد إعادة تعيين المحادثة واختيار نوع المستخدم من جديد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetChat();
            },
            child: const Text('نعم'),
          ),
        ],
      ),
    );
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
      _isUnderTreatment = false;
      _questionnaireCompleted = false;
      _treatmentStatusSelected = false;
      _isLoading = false;

      // إعادة تعيين جميع الإجابات
      for (var question in _treatmentQuestions) {
        question.selectedAnswer = null;
      }
      for (var question in _preventionQuestions) {
        question.selectedAnswer = null;
      }
    });
  }

  Widget _buildInitialSelectionView(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختر حالتك الصحية للحصول على المساعدة المناسبة:',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 32),

            // زر للمستخدمين تحت العلاج
            GradientButton(
              text: '💊 أنا تحت العلاج حاليًا',
              onPressed: () {
                _setTreatmentStatus(true);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'للمساعدة في متابعة الأدوية، إدارة الأعراض، والالتزام بالعلاج',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // زر للمستخدمين غير الخاضعين للعلاج
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.darkTurquoise],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: () {
                    _setTreatmentStatus(false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Center(
                      child: Text(
                        '🌿 أنا لست تحت العلاج',
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
            const SizedBox(height: 16),
            Text(
              'للحصول على نصائح وقائية، متابعة العادات الصحية، والوقاية من الأمراض',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // Skip Button
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _skipQuestionnaire,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'تخطي الأسئلة والبدء في المحادثة',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: AppTheme.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionnaireView(BuildContext context) {
    final answeredQuestions = _currentQuestions
        .where((q) => q.selectedAnswer != null)
        .length;
    final totalQuestions = _currentQuestions.length;

    List<Map<String, dynamic>> visibleItems = [];

    for (int i = 0; i < _currentQuestions.length; i++) {
      final question = _currentQuestions[i];
      bool isVisible = true;

      if (question.key == 'reason') {
        final adherenceQ = _currentQuestions.firstWhere(
          (q) => q.key == 'adherence',
        );
        if (adherenceQ.selectedAnswer != 'لا') isVisible = false;
      }

      if (question.key == 'symptom_severity') {
        final sideEffectsQ = _currentQuestions.firstWhere(
          (q) => q.key == 'side_effects',
        );
        if (sideEffectsQ.selectedAnswer != 'نعم') isVisible = false;
      }

      if (isVisible) {
        visibleItems.add({'question': question, 'originalIndex': i});
      }
    }

    return Expanded(
      child: Column(
        children: [
          // Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppTheme.background,
            child: Row(
              children: [
                Text(
                  'أسئلة ${_isUnderTreatment ? 'العلاج' : 'الصحة العامة'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '$answeredQuestions/$totalQuestions',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: totalQuestions > 0 ? answeredQuestions / totalQuestions : 0,
            backgroundColor: AppTheme.background,
            color: AppTheme.primary,
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              // نستخدم طول القائمة الظاهرة فقط
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                // استخراج البيانات من القائمة الجديدة
                final item = visibleItems[index];
                final question = item['question'] as Questionnaire;
                final originalIndex = item['originalIndex'] as int;

                return QuestionnaireCard(
                  questionnaire: question,

                  // التريك هنا: نمرر الـ index الجديد (0, 1, 2) ليظهر (1, 2, 3)
                  index: index,

                  onAnswerSelected: (answer) {
                    // عند الحفظ، نستخدم الـ originalIndex عشان نحفظ في المكان الصح
                    _answerQuestion(originalIndex, answer);
                  },
                );
              },
            ),
          ),

          // Bottom Buttons (نفس كودك السابق)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _skipQuestionnaire,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      side: BorderSide(color: AppTheme.primary),
                    ),
                    child: Text(
                      'تخطي',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Opacity(
                    opacity: answeredQuestions > 0 ? 1.0 : 0.5,
                    child: IgnorePointer(
                      ignoring: answeredQuestions == 0 || _isLoading,
                      child: GradientButton(
                        text: _isLoading
                            ? 'جاري التحليل...'
                            : 'إرسال الإجابات ($answeredQuestions/$totalQuestions)',
                        onPressed: _completeQuestionnaire,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          // Chat Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyChatState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ChatBubble(
                        message: message,
                        isUser: message.isUser,
                      );
                    },
                  ),
          ),

          // Loading Indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const CircularProgressIndicator(),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'اكتب سؤالك هنا...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        suffixIcon: _textController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  _textController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                      onSubmitted: (value) {
                        _sendMessage();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.darkTurquoise],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services,
            size: 80,
            color: AppTheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'مرحباً في AFYA CARE!',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            _isUnderTreatment
                ? 'يمكنني مساعدتك في متابعة علاجك والإجابة على استفساراتك الطبية'
                : 'يمكنني تقديم نصائح وقائية ومعلومات صحية مفيدة',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickQuestion('ما هي أعراض مرض السكري؟'),
              _buildQuickQuestion('كيف أعتني بضغط الدم؟'),
              _buildQuickQuestion('نصائح للنوم الجيد'),
              _buildQuickQuestion('تمارين رياضية منزلية'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestion(String question) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _textController.text = question;
          _sendMessage();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Text(
            question,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.primary),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
