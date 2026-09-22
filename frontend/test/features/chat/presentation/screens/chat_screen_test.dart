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

import "package:murassikh_app/features/chat/presentation/screens/chat_dependencies.dart";
import "package:murassikh_app/services/history_service.dart";
import "package:murassikh_app/services/local_account_scope.dart";
class FakeChatStorage implements ChatStorage {
  final List<ChatMessage> messages = [];

  @override
  Future<void> init() async {}

  @override
  List<ChatMessage> loadMessages() => messages;

  @override
  Future<void> saveMessage(ChatMessage msg) async {
    messages.add(msg);
  }

  @override
  Future<void> clear() async {
    messages.clear();
  }

  @override
  Future<void> updateMessage(int index, ChatMessage msg) async {
    if (index >= 0 && index < messages.length) {
      messages[index] = msg;
    }
  }
}

class FakeDelayedResponseProvider implements DelayedResponseProvider {
  @override
  Future<List<DelayedResponseItem>> getDueResponses() async => [];

  @override
  bool get shouldPoll => false;
}
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
    final chatBoxName = LocalAccountScope.boxName('chat');
    if (Hive.isBoxOpen(chatBoxName)) {
      await Hive.box<String>(chatBoxName).clear();
    }
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<RecommendationBloc>.value(
          value: mockRecommendationBloc,
          child: ChatScreen(
            storage: FakeChatStorage(),
            delayedResponseProvider: FakeDelayedResponseProvider(),
            enableImplicitContext: false,
          ),
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

      // Error messages should be shown as a chat message
      expect(
        find.text('عذراً، تعذّر الاتصال بالخادم. تأكد من اتصالك بالإنترنت وحاول مجدداً. 🔄'),
        findsWidgets,
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
