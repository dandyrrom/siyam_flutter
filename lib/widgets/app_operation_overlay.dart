import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../state/app_operation_controller.dart';

/// Root-level loading shield for important async operations.
///
/// While an operation is active it:
/// - blocks pointer input so the same action cannot be submitted twice;
/// - keeps the routed page mounted underneath the overlay;
/// - shows a clear loading message to the user.
class AppOperationOverlay extends StatelessWidget {
  final Widget child;

  const AppOperationOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppOperationController.instance,
      builder: (context, _) {
        final controller = AppOperationController.instance;

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (controller.isBusy) ...[
              const ModalBarrier(
                dismissible: false,
                color: Color(0x22000000),
              ),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      maxWidth: 320,
                    ),
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 20,
                          spreadRadius: 1,
                          color: Color(0x18000000),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          controller.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Please keep this page open.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
