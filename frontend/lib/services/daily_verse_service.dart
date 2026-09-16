import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../features/home/models/verse_card.dart';
import 'api_service.dart';
import 'home_context_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// DailyVerseService — خدمة الآية الديناميكية
///
/// تستمع لـ HomeContextService، وعند تغيير السياق تستدعي
/// GET /api/v1/home/verse لجلب آية مرشّحة مناسبة.
///
/// الضمانات:
/// - Debounce: لا استدعاء API إذا مرّ أقل من 3 دقائق على الآخير
/// - Offline fallback: إذا فشل الاتصال، يُعيد من الكاش المحلي
/// - لا stream spam: يُصدر فقط عند تغيير فعلي للمحتوى
/// ─────────────────────────────────────────────────────────────────────────
class DailyVerseService extends ChangeNotifier {
  static final DailyVerseService _instance = DailyVerseService._internal();
  factory DailyVerseService() => _instance;

  DailyVerseService._internal();

  static const String _cacheBoxName = 'daily_verse_cache';
  static const String _cacheKey = 'last_verse';
  static const Duration _debounce = Duration(minutes: 3);
  static const String _baseUrl = ApiService.baseUrl;

  final HomeContextService _contextService = HomeContextService();
  final StreamController<VerseCard> _controller =
      StreamController<VerseCard>.broadcast();

  Box<String>? _cacheBox;
  bool _initialized = false;
  bool _isFetching = false;
  DateTime _lastFetchTime = DateTime(2000);
  VerseCard? _lastCard;

  /// Stream يُصدر VerseCard كلما تغيّر المحتوى
  Stream<VerseCard> get verseStream => _controller.stream;

  /// آخر آية تم جلبها (للعرض الفوري)
  VerseCard? get currentVerse => _lastCard;

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // فتح الكاش المحلي
    _cacheBox = await Hive.openBox<String>(_cacheBoxName);

    // استمع لتغييرات السياق
    _contextService.addListener(_onContextChanged);

    // عرض الكاش فوراً إذا كان موجوداً
    final cached = _loadFromCache();
    if (cached != null) {
      _lastCard = cached;
      _controller.add(cached);
    }
  }

  void _onContextChanged() {
    final now = DateTime.now();

    // Debounce: تجاهل استدعاءات متكررة خلال الفترة المحددة
    if (now.difference(_lastFetchTime) < _debounce) return;

    _fetchVerse();
  }

  /// جلب آية بناءً على السياق الحالي — يُستدعى أيضاً يدوياً عند فتح الشاشة
  Future<void> fetchVerseForCurrentContext() async {
    await init();
    await _fetchVerse();
  }

  Future<void> _fetchVerse() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final ctx = _contextService.current;
      final timeOfDay = HomeContextService.currentTimeOfDay();

      final headers = await ApiService.getHeaders();
      final body = jsonEncode({
        'dominant_emotion':
            ctx.isNeutral ? null : ctx.dominantEmotion,
        'confidence': ctx.confidence,
        'signal_source': ctx.signalSource,
        'time_of_day': timeOfDay,
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/home/verse'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final card = VerseCard.fromJson(data);

        // لا تُصدر إذا كان المحتوى نفسه
        if (_lastCard == null ||
            _lastCard!.verse != card.verse ||
            _lastCard!.source != card.source) {
          _lastCard = card;
          _lastFetchTime = DateTime.now();
          _saveToCache(card);
          _controller.add(card);
        }
      } else {
        _emitFallback();
      }
    } on Exception catch (e) {
      debugPrint('DailyVerseService._fetchVerse error: $e');
      _emitFallback();
    } finally {
      _isFetching = false;
    }
  }

  /// إصدار نسخة احتياطية (كاش محلي أو fallback ثابت)
  void _emitFallback() {
    final cached = _loadFromCache();
    if (cached != null && _lastCard?.verse != cached.verse) {
      _lastCard = cached;
      _controller.add(cached);
    } else if (_lastCard == null) {
      final fb = VerseCard.fallback;
      _lastCard = fb;
      _controller.add(fb);
    }
  }

  // ── الكاش المحلي ──────────────────────────────────────────────────────────

  void _saveToCache(VerseCard card) {
    try {
      _cacheBox?.put(_cacheKey, jsonEncode(card.toJson()));
    } catch (e) {
      debugPrint('DailyVerseService._saveToCache error: $e');
    }
  }

  VerseCard? _loadFromCache() {
    try {
      final raw = _cacheBox?.get(_cacheKey);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return VerseCard.fromJson(data, cached: true);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _contextService.removeListener(_onContextChanged);
    _controller.close();
    super.dispose();
  }
}
