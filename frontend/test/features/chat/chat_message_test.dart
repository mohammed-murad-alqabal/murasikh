import 'package:flutter_test/flutter_test.dart';
import 'package:murassikh_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:murassikh_app/features/recommendation/models/recommendation_model.dart';

void main() {
  group('ChatMessage Model Feedback Tests', () {
    test('ChatMessage can store and serialize positive feedback', () {
      final msg = ChatMessage(
        text: 'رسالة مواساة وتثبيت',
        isUser: false,
        feedback: 1,
      );

      expect(msg.feedback, 1);
      final map = msg.toMap();
      expect(map['feedback'], 1);

      final deserialized = ChatMessage.fromMap(map);
      expect(deserialized.feedback, 1);
      expect(deserialized.text, 'رسالة مواساة وتثبيت');
      expect(deserialized.isUser, false);
    });

    test('ChatMessage can store and serialize negative feedback', () {
      final msg = ChatMessage(
        text: 'رسالة مواساة',
        isUser: false,
        feedback: -1,
      );

      expect(msg.feedback, -1);
      final map = msg.toMap();
      expect(map['feedback'], -1);

      final deserialized = ChatMessage.fromMap(map);
      expect(deserialized.feedback, -1);
    });

    test('ChatMessage defaults feedback to null when unrated', () {
      final msg = ChatMessage(text: 'رسالة مستخدم', isUser: true);

      expect(msg.feedback, isNull);
      final map = msg.toMap();
      expect(map['feedback'], isNull);

      final deserialized = ChatMessage.fromMap(map);
      expect(deserialized.feedback, isNull);
    });

    test(
      'ChatMessage with recommendation preserves recommendation and feedback',
      () {
        final rec = RecommendationModel(
          emotion: 'حزن',
          confidence: 0.85,
          tier: 'moderate',
          message: 'لا تحزن إن الله معنا',
          source: 'سورة التوبة: 40',
        );

        final msg = ChatMessage(
          text: rec.message,
          isUser: false,
          recommendation: rec,
          feedback: 1,
        );

        final map = msg.toMap();
        final deserialized = ChatMessage.fromMap(map);

        expect(deserialized.feedback, 1);
        expect(deserialized.recommendation, isNotNull);
        expect(deserialized.recommendation?.source, 'سورة التوبة: 40');
      },
    );
  });
}
