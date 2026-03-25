import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../app/theme.dart';
import '../widgets/gradient_button.dart';
import '../services/api_service.dart';
import 'package:flutter/cupertino.dart';

class AddMedicationPage extends StatefulWidget {
  final Function(Medication) onMedicationAdded;

  const AddMedicationPage({super.key, required this.onMedicationAdded});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<String> _medicationsList = [];

  // متغيرات الاقتراح
  bool _showSuggestion = false;
  String _aiSuggestion = '';

  void _showAISuggestionDialog() async {
    if (_medicationsList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى إضافة الأدوية أولاً')));
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AISuggestionDialog(medicationsList: _medicationsList);
      },
    );

    if (result != null) {
      setState(() {
        _aiSuggestion = result;
        _showSuggestion = true;
      });
    }
  }

  void _addMedicationToList() {
    if (_nameController.text.isNotEmpty) {
      setState(() {
        _medicationsList.add(_nameController.text);
        _nameController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة دواء جديد'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.appGradient),
        ),
        elevation: 4,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medication Name Input with Add Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCard,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'اكتب اسم الدواء...',
                              hintStyle: TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            onFieldSubmitted: (value) => _addMedicationToList(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _addMedicationToList,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.add, // تم تغيير الأيقونة لـ + لتكون أوضح
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Medications List (Chips)
                  if (_medicationsList.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'الأدوية المضافة (${_medicationsList.length})',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (_medicationsList.isNotEmpty)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _medicationsList.clear();
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Text(
                                        'مسح الكل',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _medicationsList
                                .map(
                                  (med) => Chip(
                                    label: Text(med),
                                    backgroundColor: AppTheme.primary
                                        .withOpacity(0.1),
                                    deleteIconColor: AppTheme.primary,
                                    onDeleted: () {
                                      setState(() {
                                        _medicationsList.remove(med);
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Time Picker & Day Selector
                  MedicationReminderWidget(
                    onDataChanged: (time, days) {
                      setState(() {
                        _selectedTime = time;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // AI Suggestion Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, color: Color(0xFF000000)),
                            const SizedBox(width: 8),
                            Text(
                              'اقتراح جدول مثالي من الذكاء الاصطناعي',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _showAISuggestionDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: Text(
                                    'استخدام الاقتراح الذكي',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
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
                  ),

                  const SizedBox(height: 20),

                  // AI Suggestion Result Box
                  if (_showSuggestion && _aiSuggestion.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.psychology,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'الاقتراح الذكي',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _showSuggestion = false;
                                    _aiSuggestion = '';
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 120,
                              maxHeight: 200,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _aiSuggestion,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      height: 1.5,
                                      color: AppTheme.textPrimary,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ==============================
                  // زر إضافة الدواء (تم التعديل هنا)
                  // ==============================
                  GradientButton(
                    text: 'إضافة الدواء',
                    onPressed: () {
                      // 1. إذا كان القائمة فارغة و مربع النص فارغ، أظهر خطأ
                      if (_medicationsList.isEmpty &&
                          _nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى إدخال اسم الدواء'),
                          ),
                        );
                        return;
                      }

                      // 2. إذا كتب نص ونسي يضيفه، نضيفه نحن
                      if (_nameController.text.isNotEmpty) {
                        _medicationsList.add(_nameController.text);
                      }

                      // 3. نقوم بحفظ كل الأدوية الموجودة في القائمة
                      // نقوم بعمل حلقة تكرار لإضافة كل دواء في القائمة
                      for (var medName in _medicationsList) {
                        final medication = Medication(
                          // نستخدم اسم الدواء كجزء من المعرف لضمان الاختلاف
                          id: "${DateTime.now().millisecondsSinceEpoch}_$medName",
                          name: medName,
                          time: _selectedTime,
                        );
                        widget.onMedicationAdded(medication);
                      }

                      // 4. نغلق الصفحة
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

// ==========================================================
// بقية الكلاسات كما هي (AISuggestionDialog و MedicationReminderWidget)
// ==========================================================

class AISuggestionDialog extends StatefulWidget {
  final List<String> medicationsList;

  const AISuggestionDialog({super.key, required this.medicationsList});

  @override
  State<AISuggestionDialog> createState() => _AISuggestionDialogState();
}

class _AISuggestionDialogState extends State<AISuggestionDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);

  Future<void> _getAISuggestion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String formatTimeOfDay(TimeOfDay time) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }

      final response = await _apiService.suggestMedicationSchedule(
        medications: widget.medicationsList,
        sleepTime: formatTimeOfDay(_sleepTime),
        wakeUpTime: formatTimeOfDay(_wakeUpTime),
      );

      if (mounted) {
        Navigator.pop(
          context,
          response['suggested_schedule'] ?? 'لا توجد اقتراحات متاحة',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, 'حدث خطأ في الحصول على الاقتراح: $e');
      }
    }
  }

  Future<void> _selectSleepTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _sleepTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _sleepTime = picked;
      });
    }
  }

  Future<void> _selectWakeUpTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _wakeUpTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _wakeUpTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: AppTheme.glassCard,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الاقتراح الذكي للجدولة',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: AppTheme.primary),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Medications List in Dialog
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medication, color: AppTheme.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'الأدوية المضافة',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.medicationsList
                        .map(
                          (med) => Chip(
                            label: Text(med),
                            backgroundColor: AppTheme.accent.withOpacity(0.1),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sleep and Wake-up Times
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وقت النوم',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _selectSleepTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_sleepTime.format(context)),
                                Icon(
                                  Icons.access_time,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وقت الاستيقاظ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _selectWakeUpTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_wakeUpTime.format(context)),
                                Icon(
                                  Icons.access_time,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Get Suggestion Button
            GradientButton(
              text: _isLoading
                  ? 'جاري إنشاء الاقتراح...'
                  : 'الحصول على الاقتراح',
              onPressed: _isLoading ? null : _getAISuggestion,
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationReminderWidget extends StatefulWidget {
  final Function(TimeOfDay, List<bool>) onDataChanged;

  const MedicationReminderWidget({Key? key, required this.onDataChanged})
    : super(key: key);

  @override
  _MedicationReminderWidgetState createState() =>
      _MedicationReminderWidgetState();
}

class _MedicationReminderWidgetState extends State<MedicationReminderWidget> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<bool> _selectedDays = List.filled(7, true);

  final List<String> _fullDayNames = [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  void _pickTime() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Text(
                "اختر وقت الجرعة",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.fontFamily,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(
                      2023,
                      1,
                      1,
                      _selectedTime.hour,
                      _selectedTime.minute,
                    ),
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime newTime) {
                      setState(() {
                        _selectedTime = TimeOfDay.fromDateTime(newTime);
                      });
                      widget.onDataChanged(_selectedTime, _selectedDays);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A80F0), Color(0xFF9C27B0)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text(
                        "تأكيد الوقت",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDaySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(25),
              height: 500,
              child: Column(
                children: [
                  const Text(
                    "تكرار الأيام",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _fullDayNames.length,
                      separatorBuilder: (c, i) =>
                          const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      itemBuilder: (context, index) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _fullDayNames[index],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          value: _selectedDays[index],
                          activeColor: const Color(0xFF4A80F0),
                          checkboxShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (val) {
                            setSheetState(
                              () => _selectedDays[index] = val ?? false,
                            );
                            setState(() {});
                            widget.onDataChanged(_selectedTime, _selectedDays);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A80F0), Color(0xFF9C27B0)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: Text(
                          "حفظ الاختيار",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final timeString = localizations.formatTimeOfDay(
      _selectedTime,
      alwaysUse24HourFormat: false,
    );

    int count = _selectedDays.where((d) => d).length;
    String daysString = count == 7 ? "يومياً" : "$count أيام محددة";
    if (count == 0) daysString = "مرة واحدة فقط";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A80F0).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsRow(
            icon: Icons.access_time_filled_rounded,
            title: "وقت الجرعة",
            value: timeString,
            isGradientIcon: true,
            onTap: _pickTime,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Divider(height: 1, color: Colors.grey[200]),
          ),

          _buildSettingsRow(
            icon: Icons.calendar_month_rounded,
            title: "تكرار التذكير",
            value: daysString,
            isGradientIcon: true,
            onTap: _openDaySelector,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isGradientIcon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4A80F0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [Color(0xFF4A80F0), Color(0xFF9C27B0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds);
                },
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A80F0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
