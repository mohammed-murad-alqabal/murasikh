import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:murassikh_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:murassikh_app/features/recommendation/bloc/recommendation_bloc.dart';
import 'package:murassikh_app/features/recommendation/models/recommendation_model.dart';

// --- Mocks ---
class MockRecommendationBloc
    extends MockBloc<RecommendationEvent, RecommendationState>
    implements RecommendationBloc {}

class FakeGetRecommendationEvent extends Fake
    implements GetRecommendationEvent {}

class FakeAnalyzeAudioEvent extends Fake implements AnalyzeAudioEvent {}

void main() {
  late MockRecommendationBloc mockRecommendationBloc;
  late Directory tempDir;

  setUpAll(() async {
    // Setup temporary directory for Hive
    tempDir = await Directory.systemTemp.createTemp('murassikh_chat_test_');
    Hive.init(tempDir.path);

    // Register fallback value for Mocktail
    registerFallbackValue(FakeGetRecommendationEvent());
    registerFallbackValue(FakeAnalyzeAudioEvent());
  });

  tearDownAll(() async {
    // Clean up temporary directory
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    mockRecommendationBloc = MockRecommendationBloc();
    when(
      () => mockRecommendationBloc.state,
    ).thenReturn(RecommendationInitial());
  });

  tearDown(() async {
    if (Hive.isBoxOpen('murassikh_chat_box')) {
      await Hive.box<String>('murassikh_chat_box').clear();
    }
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<RecommendationBloc>.value(
          value: mockRecommendationBloc,
          child: const ChatScreen(enableImplicitContext: false),
        ),
      ),
    );
  }

  group('ChatScreen Widget Tests', () {
    testWidgets('ChatScreen renders empty initial state correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());

      // Wait for async operations (Hive init)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check input field exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('شاركني ما تشعر به...'), findsOneWidget); // Hint text

      // Check send button exists
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Sending a text message updates UI and calls bloc', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter text
      await tester.enterText(find.byType(TextField), 'أشعر بالحزن والضيق');

      // Tap send
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(); // Start animation

      // Verify bloc event was added
      verify(
        () => mockRecommendationBloc.add(
          any(that: isA<GetRecommendationEvent>()),
        ),
      ).called(1);

      // Allow animation to complete
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Displays recommendation when bloc yields RecommendationLoaded', (
      WidgetTester tester,
    ) async {
      // Create a recommendation
      final recommendation = RecommendationModel(
        emotion: 'حزن',
        confidence: 0.9,
        tier: 'moderate',
        message: 'لا تحزن إن الله معنا',
        source: 'سورة التوبة: 40',
        tafsir: 'تفسير مبسط',
      );

      // We need to simulate the user sending a message first, then the state changing
      whenListen(
        mockRecommendationBloc,
        Stream.fromIterable([
          RecommendationLoading(),
          RecommendationLoaded(recommendation),
        ]),
        initialState: RecommendationInitial(),
      );

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type and send
      await tester.enterText(find.byType(TextField), 'رسالة');
      await tester.tap(find.byIcon(Icons.send));

      // Let the stream events process
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should display the recommendation message
      expect(find.text('لا تحزن إن الله معنا'), findsOneWidget);

      // Should display the source
      expect(find.text('سورة التوبة: 40'), findsOneWidget);

      // Should display tafsir
      expect(find.text('تفسير مبسط'), findsOneWidget);
    });

    testWidgets('Displays error when bloc yields RecommendationError', (
      WidgetTester tester,
    ) async {
      whenListen(
        mockRecommendationBloc,
        Stream.fromIterable([
          RecommendationLoading(),
          RecommendationError('حدث خطأ في الشبكة'),
        ]),
        initialState: RecommendationInitial(),
      );

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type and send
      await tester.enterText(find.byType(TextField), 'رسالة');
      await tester.tap(find.byIcon(Icons.send));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The screen deliberately shows a sanitized inline error message.
      expect(
        find.text(
          'عذراً، تعذّر الاتصال بالخادم. تأكد من اتصالك بالإنترنت وحاول مجدداً. 🔄',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ChatScreen dispose cancels timer properly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The widget will be disposed when the test finishes.
      // If the timer is not canceled, the test environment will complain about pending timers.
    });
  });
}
