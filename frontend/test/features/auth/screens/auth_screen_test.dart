import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:murassikh_app/features/auth/screens/auth_screen.dart';
import 'package:murassikh_app/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(home: AuthScreen(authService: mockAuthService));
  }

  group('AuthScreen Tests', () {
    testWidgets('Initial render should be in Login mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Verify AppBar title
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('دخول'), findsOneWidget); // Button text
      expect(
        find.text('لا تملك حساباً؟ سجل الآن'),
        findsOneWidget,
      ); // Toggle button
    });

    testWidgets('Toggle button should switch to Register mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap toggle button
      await tester.tap(find.text('لا تملك حساباً؟ سجل الآن'));
      await tester.pumpAndSettle();

      // Verify Register mode
      expect(find.text('حساب جديد'), findsWidgets);
      expect(find.text('تسجيل حساب جديد'), findsOneWidget); // Button text
      expect(
        find.text('لديك حساب؟ سجل الدخول'),
        findsOneWidget,
      ); // Toggle button
    });

    testWidgets('Validation should fail on empty input', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap submit button without entering anything
      await tester.tap(find.text('دخول'));
      await tester.pump();

      // Verify validation errors
      expect(find.text('مطلوب'), findsOneWidget); // Username validation
      expect(
        find.text('مطلوب (4 أحرف على الأقل)'),
        findsOneWidget,
      ); // Password validation
    });

    testWidgets('Validation should fail on short password', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter valid username but short password
      await tester.enterText(find.byType(TextFormField).first, 'testuser');
      await tester.enterText(find.byType(TextFormField).last, '123');

      await tester.tap(find.text('دخول'));
      await tester.pump();

      // Verify password validation error
      expect(find.text('مطلوب (4 أحرف على الأقل)'), findsOneWidget);
    });

    testWidgets('Successful login should show Snackbar and pop', (
      WidgetTester tester,
    ) async {
      when(() => mockAuthService.login(any(), any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField).first, 'testuser');
      await tester.enterText(find.byType(TextFormField).last, 'password');

      await tester.tap(find.text('دخول'));

      // Let the animation finish so it attempts to pop
      await tester.pumpAndSettle();

      verify(() => mockAuthService.login('testuser', 'password')).called(1);

      // We expect the auth screen to have popped, removing its text elements.
      expect(find.text('تسجيل الدخول'), findsNothing);
    });

    testWidgets('Failed login should show error Snackbar', (
      WidgetTester tester,
    ) async {
      when(() => mockAuthService.login(any(), any()))
          .thenAnswer((_) async => 'Invalid credentials');

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField).first, 'testuser');
      await tester.enterText(find.byType(TextFormField).last, 'password');

      await tester.tap(find.text('دخول'));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.login('testuser', 'password')).called(1);

      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('Successful registration should show Snackbar and pop', (
      WidgetTester tester,
    ) async {
      when(() => mockAuthService.register(any(), any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(createWidgetUnderTest());

      // Toggle to register mode
      await tester.tap(find.text('لا تملك حساباً؟ سجل الآن'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'newuser');
      await tester.enterText(find.byType(TextFormField).last, 'newpassword');

      await tester.tap(find.text('تسجيل حساب جديد'));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.register('newuser', 'newpassword'))
          .called(1);

      // We expect the auth screen to have popped, removing its text elements.
      expect(find.text('حساب جديد'), findsNothing);
    });

    testWidgets('Failed registration should show error Snackbar', (
      WidgetTester tester,
    ) async {
      when(() => mockAuthService.register(any(), any()))
          .thenAnswer((_) async => 'Registration failed');

      await tester.pumpWidget(createWidgetUnderTest());

      // Toggle to register mode
      await tester.tap(find.text('لا تملك حساباً؟ سجل الآن'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'newuser');
      await tester.enterText(find.byType(TextFormField).last, 'newpassword');

      await tester.tap(find.text('تسجيل حساب جديد'));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.register('newuser', 'newpassword')).called(1);

      expect(find.text('Registration failed'), findsOneWidget);
    });

    testWidgets('Loading indicator is shown during submission', (
      WidgetTester tester,
    ) async {
      when(() => mockAuthService.login(any(), any()))
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return null;
          });

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField).first, 'testuser');
      await tester.enterText(find.byType(TextFormField).last, 'password');

      await tester.tap(find.text('دخول'));
      await tester.pump(); // Start the animation

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Finish the animation
    });

  });
}
