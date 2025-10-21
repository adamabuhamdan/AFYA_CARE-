import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../app/theme.dart';
import '../widgets/gradient_button.dart';
import '../services/api_service.dart';

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

  // متغيرات جديدة للاقتراح
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
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // أضف هذا
          physics: const BouncingScrollPhysics(), // لإضافة تأثير جميل للتمرير
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
                                Icons.psychology,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Medications List
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

                  // Time Picker
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCard,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'وقت التذكير',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final TimeOfDay? pickedTime =
                                  await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                  );
                              if (pickedTime != null) {
                                setState(() {
                                  _selectedTime = pickedTime;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

                  // AI Suggestion Result Box - يظهر فقط عندما يكون هناك اقتراح
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
                          Row(
                            children: [
                              Expanded(
                                child: GradientButton(
                                  text: 'استخدام هذا الاقتراح',
                                  onPressed: () {
                                    // هنا يمكنك إضافة منطق لاستخدام الاقتراح
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم تطبيق الاقتراح'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // إزالة Spacer وإضافة مسافة ثابتة
                  const SizedBox(height: 20),

                  // Add Medication Button
                  GradientButton(
                    text: 'إضافة الدواء',
                    onPressed: () {
                      if (_formKey.currentState!.validate() &&
                          _nameController.text.isNotEmpty) {
                        final medication = Medication(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: _nameController.text,
                          time: _selectedTime,
                        );

                        widget.onMedicationAdded(medication);
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى إدخال اسم الدواء'),
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 20), // مسافة إضافية في الأسفل
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
