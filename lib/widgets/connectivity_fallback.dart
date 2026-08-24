import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// App-wide network fallback.
///
/// The routed child is intentionally ALWAYS kept under the same Stack parent.
/// This avoids reparenting the Router/Navigator subtree when connectivity
/// changes, which is safer for Flutter's inherited-widget dependency tree.
class ConnectivityFallback extends StatefulWidget {
  final Widget child;

  const ConnectivityFallback({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityFallback> createState() =>
      _ConnectivityFallbackState();
}

class _ConnectivityFallbackState
    extends State<ConnectivityFallback> {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOffline = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final results = await _connectivity.checkConnectivity();

      if (!mounted) return;

      setState(() {
        _isOffline = !_hasConnection(results);
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isChecking = false;
      });
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any(
      (result) => result != ConnectivityResult.none,
    );
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    if (!mounted) return;

    final offline = !_hasConnection(results);

    if (_isOffline == offline) return;

    setState(() {
      _isOffline = offline;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final results = await _connectivity.checkConnectivity();

      if (!mounted) return;

      setState(() {
        _isOffline = !_hasConnection(results);
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // IMPORTANT:
        // The routed child always stays in this exact slot.
        widget.child,

        if (_isOffline)
          Positioned.fill(
            child: Material(
              color: AppColors.background,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 420,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.muted,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.wifi_off_rounded,
                                size: 32,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No internet connection',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please check your internet connection and try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isChecking ? null : _retry,
                                icon: _isChecking
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  _isChecking
                                      ? 'Checking...'
                                      : 'Try Again',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
