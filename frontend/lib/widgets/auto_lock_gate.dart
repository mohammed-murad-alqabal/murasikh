import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/auto_lock_service.dart';
import '../services/settings_service.dart';

class AutoLockGate extends StatefulWidget {
  const AutoLockGate({required this.child, super.key});

  final Widget child;

  @override
  State<AutoLockGate> createState() => _AutoLockGateState();
}

class _AutoLockGateState extends State<AutoLockGate>
    with WidgetsBindingObserver {
  final AutoLockService _lockService = AutoLockService();
  Timer? _timer;
  late DateTime _lastActivity;
  DateTime? _backgroundedAt;
  bool _locked = false;
  bool _unlocking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastActivity = DateTime.now();
    final settings = SettingsService().getSettings();
    _locked = settings.enableBiometricAuth;
    _scheduleTimer();
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _attemptUnlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= now;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final settings = SettingsService().getSettings();
      if (AutoLockPolicy.shouldLock(
        settings: settings,
        lastActivity: _lastActivity,
        now: now,
        backgroundedAt: _backgroundedAt,
      )) {
        _lock();
      }
      _backgroundedAt = null;
      _lastActivity = now;
      _scheduleTimer();
    }
  }

  void _recordActivity() {
    if (_locked) return;
    _lastActivity = DateTime.now();
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    final settings = SettingsService().getSettings();
    if (!settings.autoLockEnabled || _locked) return;
    _timer = Timer(AutoLockPolicy.timeoutFor(settings), _lockIfDue);
  }

  void _lockIfDue() {
    final settings = SettingsService().getSettings();
    if (AutoLockPolicy.shouldLock(
      settings: settings,
      lastActivity: _lastActivity,
      now: DateTime.now(),
      backgroundedAt: _backgroundedAt,
    )) {
      _lock();
    } else {
      _scheduleTimer();
    }
  }

  void _lock() {
    if (!mounted || _locked) return;
    _timer?.cancel();
    setState(() {
      _locked = true;
      _error = null;
    });
    _attemptUnlock();
  }

  Future<void> _attemptUnlock() async {
    if (!_locked || _unlocking) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });
    final unlocked = await _lockService.unlock();
    if (!mounted) return;
    setState(() {
      _unlocking = false;
      if (unlocked) {
        _locked = false;
        _lastActivity = DateTime.now();
      } else {
        _error = 'تعذر التحقق من الهوية. حاول مرة أخرى.';
      }
    });
    if (unlocked) _scheduleTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _recordActivity(),
      child: Stack(
        children: [
          widget.child,
          if (_locked)
            Positioned.fill(
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            color: AppColors.primary,
                            size: 64,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'التطبيق مقفل',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'تحقق من هويتك للمتابعة',
                            textAlign: TextAlign.center,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _unlocking ? null : _attemptUnlock,
                            icon: const Icon(Icons.fingerprint),
                            label: Text(_unlocking ? 'جارٍ التحقق...' : 'فتح التطبيق'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
