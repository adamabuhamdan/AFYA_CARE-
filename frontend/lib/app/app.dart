import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/pages/dashboard_page.dart';
import 'package:frontend/pages/add_medication_page.dart';
import 'package:frontend/pages/chat_page.dart';
import 'package:frontend/pages/settings_page.dart';
import 'theme.dart';

class HealthAIApp extends StatelessWidget {
  const HealthAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health AI Assistant',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,

      // إعدادات اللغة والتدويل
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'), // العربية
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],

      // تطبيق RTL على مستوى التطبيق كامل
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },

      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // مفتاح عالمي للوصول إلى DashboardPage
  final GlobalKey<DashboardPageState> _dashboardKey = GlobalKey();

  // قائمة بالصفحات مع مفاتيح للحفاظ على الحالة
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    // تهيئة الصفحات مع Directionality
    _initializePages();
  }

  void _initializePages() {
    _pages.addAll([
      DashboardPage(key: _dashboardKey),
      _buildPageWithDirectionality(
        AddMedicationPage(
          onMedicationAdded: (medication) {
            _dashboardKey.currentState?.addMedication(medication);
          },
        ),
      ),
      _buildPageWithDirectionality(const ChatPage()),
      _buildPageWithDirectionality(const SettingsPage()),
    ]);
  }

  // دالة مساعدة لتغليف الصفحات بـ Directionality
  Widget _buildPageWithDirectionality(Widget child) {
    return Directionality(textDirection: TextDirection.rtl, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          topLeft: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          topLeft: Radius.circular(32),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication),
              label: 'إضافة دواء',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'المحادثة'),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
