import 'package:flutter_test/flutter_test.dart';

import 'package:murassikh_app/features/home/models/verse_card.dart';
import 'package:murassikh_app/services/home_context_service.dart';

void main() {
  ContextSnapshot snapshot({
    required String emotion,
    required double confidence,
    required String source,
    required DateTime timestamp,
  }) {
    return ContextSnapshot(
      dominantEmotion: emotion,
      confidence: confidence,
      signalSource: source,
      timestamp: timestamp,
    );
  }

  group('HomeContextPolicy.isSignificantChange', () {
    final baseTime = DateTime(2026, 1, 1, 12);

    test('detects a changed emotion', () {
      final old = snapshot(
        emotion: 'قلق',
        confidence: 0.8,
        source: 'face',
        timestamp: baseTime,
      );
      final candidate = snapshot(
        emotion: 'حزن',
        confidence: 0.8,
        source: 'face',
        timestamp: baseTime.add(const Duration(minutes: 1)),
      );

      expect(
        HomeContextPolicy.isSignificantChange(old, candidate, now: baseTime),
        isTrue,
      );
    });

    test('ignores a small confidence change before forced refresh', () {
      final old = snapshot(
        emotion: 'قلق',
        confidence: 0.50,
        source: 'history',
        timestamp: baseTime,
      );
      final candidate = snapshot(
        emotion: 'قلق',
        confidence: 0.70,
        source: 'history',
        timestamp: baseTime.add(const Duration(minutes: 1)),
      );

      expect(
        HomeContextPolicy.isSignificantChange(old, candidate, now: baseTime),
        isFalse,
      );
    });

    test('detects a confidence increase greater than 0.25', () {
      final old = snapshot(
        emotion: 'قلق',
        confidence: 0.40,
        source: 'history',
        timestamp: baseTime,
      );
      final candidate = snapshot(
        emotion: 'قلق',
        confidence: 0.70,
        source: 'face',
        timestamp: baseTime,
      );

      expect(
        HomeContextPolicy.isSignificantChange(old, candidate, now: baseTime),
        isTrue,
      );
    });

    test('forces a refresh after one hour', () {
      final old = snapshot(
        emotion: 'قلق',
        confidence: 0.8,
        source: 'face',
        timestamp: baseTime,
      );
      final candidate = snapshot(
        emotion: 'قلق',
        confidence: 0.8,
        source: 'face',
        timestamp: baseTime.add(const Duration(hours: 1, minutes: 1)),
      );

      expect(
        HomeContextPolicy.isSignificantChange(
          old,
          candidate,
          now: baseTime.add(const Duration(hours: 1, minutes: 1)),
        ),
        isTrue,
      );
    });
  });

  group('HomeContextPolicy.thresholdForSource', () {
    test('returns source thresholds', () {
      expect(HomeContextPolicy.thresholdForSource('face'), 0.65);
      expect(HomeContextPolicy.thresholdForSource('audio'), 0.60);
      expect(HomeContextPolicy.thresholdForSource('history'), 0.55);
      expect(HomeContextPolicy.thresholdForSource('time'), 0.0);
    });
  });

  group('HomeContextPolicy.shouldNotify', () {
    final baseTime = DateTime(2026, 1, 1, 12);
    final old = snapshot(
      emotion: 'قلق',
      confidence: 0.8,
      source: 'face',
      timestamp: baseTime,
    );

    test(
      'rejects a candidate during the debounce interval exactly at the boundary',
      () {
        final candidate = snapshot(
          emotion: 'حزن',
          confidence: 0.9,
          source: 'face',
          timestamp: baseTime.add(const Duration(seconds: 60)),
        );

        expect(
          HomeContextPolicy.shouldNotify(
            old: old,
            candidate: candidate,
            lastNotifyTime: baseTime,
            now: baseTime.add(const Duration(seconds: 60)),
          ),
          isFalse,
        );
      },
    );

    test('rejects a face signal below its confidence threshold', () {
      final candidate = snapshot(
        emotion: 'حزن',
        confidence: 0.64,
        source: 'face',
        timestamp: baseTime.add(const Duration(minutes: 4)),
      );

      expect(
        HomeContextPolicy.shouldNotify(
          old: old,
          candidate: candidate,
          lastNotifyTime: baseTime,
          now: baseTime.add(const Duration(minutes: 4)),
        ),
        isFalse,
      );
    });

    test('accepts a significant high-confidence change after debounce', () {
      final candidate = snapshot(
        emotion: 'حزن',
        confidence: 0.8,
        source: 'face',
        timestamp: baseTime.add(const Duration(minutes: 4)),
      );

      expect(
        HomeContextPolicy.shouldNotify(
          old: old,
          candidate: candidate,
          lastNotifyTime: baseTime,
          now: baseTime.add(const Duration(minutes: 4)),
        ),
        isTrue,
      );
    });
  });

  test('VerseCard preserves the API confidence field', () {
    final card = VerseCard.fromJson({
      'verse': 'آية اختبارية',
      'source': 'سورة الاختبار: ١',
      'emotion_context': 'قلق',
      'signal_used': 'face',
      'confidence': 0.8,
    });

    expect(card.confidence, 0.8);
    expect(card.toJson()['confidence'], 0.8);
  });
}
