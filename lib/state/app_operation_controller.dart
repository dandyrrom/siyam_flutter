import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// App-wide operation guard used for important async actions such as saving,
/// approving, recording, or other work that should temporarily block input.
///
/// The controller is intentionally a singleton so it can be used from any page
/// without changing the existing Auth/Provider wiring.
class AppOperationController extends ChangeNotifier {
  AppOperationController._();

  static final AppOperationController instance =
      AppOperationController._();

  final Map<int, String> _activeOperations = <int, String>{};

  int _nextToken = 0;
  bool _notificationQueued = false;

  bool get isBusy => _activeOperations.isNotEmpty;

  String get message => _activeOperations.isEmpty
      ? 'Please wait...'
      : _activeOperations.values.last;

  /// Notifies listeners safely.
  ///
  /// If an operation starts while Flutter is currently building widgets,
  /// notifying immediately can cause:
  ///
  /// "setState() or markNeedsBuild() called during build"
  ///
  /// In that situation, wait until the current frame finishes.
  /// Multiple requests during the same frame are collapsed into one update.
  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;

    if (phase == SchedulerPhase.persistentCallbacks) {
      if (_notificationQueued) return;

      _notificationQueued = true;

      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationQueued = false;
        notifyListeners();
      });

      return;
    }

    notifyListeners();
  }

  Future<T> run<T>({
    required Future<T> Function() action,
    String message = 'Please wait...',
  }) async {
    final token = ++_nextToken;

    _activeOperations[token] = message;
    _notifySafely();

    try {
      return await action();
    } finally {
      _activeOperations.remove(token);
      _notifySafely();
    }
  }
}