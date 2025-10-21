import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';

void main() {
  testWidgets('Health AI App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthAIApp());
    expect(find.text('صباح الخير، آدم'), findsOneWidget);
    expect(find.text('أدوية اليوم'), findsOneWidget);
  });

  testWidgets('Navigation between pages works', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthAIApp());

    // استخدام الفهرس للتنقل بين الصفحات
    final bottomNavBar = find.byType(BottomNavigationBar);
    expect(bottomNavBar, findsOneWidget);

    // الانتقال لصفحة المحادثة (المؤشر 2)
    await tester.tap(find.text('المحادثة').last);
    await tester.pumpAndSettle();
    expect(find.text('المساعد الصحي الذكي 🤖'), findsAtLeastNWidgets(1));

    // الانتقال لصفحة الإعدادات (المؤشر 3)
    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    expect(find.text('الملف الشخصي'), findsOneWidget);

    // العودة للرئيسية (المؤشر 0)
    await tester.tap(find.text('الرئيسية').last);
    await tester.pumpAndSettle();
    expect(find.text('صباح الخير، آدم'), findsOneWidget);
  });

  testWidgets('Medications are displayed correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthAIApp());
    expect(find.text('فيتامين D'), findsOneWidget);
    expect(find.text('أموكسيسيلين'), findsOneWidget);
  });

  testWidgets('Add medication from dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthAIApp());

    // الضغط على زر إضافة دواء في Dashboard (الأول)
    await tester.tap(find.text('إضافة دواء').first);
    await tester.pumpAndSettle();

    expect(find.text('إضافة دواء جديد'), findsOneWidget);
  });

  testWidgets('All bottom navigation items exist', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthAIApp());

    // التحقق من وجود جميع عناصر التنقل (النسخ في bottom navigation)
    expect(find.text('الرئيسية').last, findsOneWidget);
    expect(find.text('إضافة دواء').last, findsOneWidget);
    expect(find.text('المحادثة').last, findsOneWidget);
    expect(find.text('الإعدادات').last, findsOneWidget);
  });
}
