import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Reusable dashboard metric card.
///
/// [onTap] is optional so existing dashboards that do not need navigation
/// continue working without modification.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? actionLabel;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.primary,
    this.onTap,
    this.tooltip,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(20),
        hoverColor: onTap == null
            ? Colors.transparent
            : accent.withValues(alpha: 0.04),
        highlightColor: onTap == null
            ? Colors.transparent
            : accent.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
                  const Spacer(),

                  // ===========================================================
                  // CLICKABLE CARD INDICATOR
                  // ===========================================================

                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppColors.mutedForeground,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedForeground,
                ),
              ),

              if (onTap != null && actionLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return card;
    }

    return Tooltip(
      message: tooltip!,
      child: card,
    );
  }
}

/// Responsive wrap of dashboard metric cards.
class StatCardRow extends StatelessWidget {
  final List<StatCard> cards;

  const StatCardRow({
    super.key,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width > 1100
            ? 4
            : width > 600
                ? 2
                : 1;

        final cardWidth =
            (width - (columns - 1) * 16) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }
}

class DashboardHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const DashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ComingSoonNotice extends StatelessWidget {
  final String text;

  const ComingSoonNotice({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
