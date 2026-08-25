import 'package:flutter/foundation.dart';

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

  bool get isBusy => _activeOperations.isNotEmpty;

  String get message => _activeOperations.isEmpty
      ? 'Please wait...'
      : _activeOperations.values.last;

  Future<T> run<T>({
    required Future<T> Function() action,
    String message = 'Please wait...',
  }) async {
    final token = ++_nextToken;

    _activeOperations[token] = message;
    notifyListeners();

    try {
      return await action();
    } finally {
      _activeOperations.remove(token);
      notifyListeners();
    }
  }
}
