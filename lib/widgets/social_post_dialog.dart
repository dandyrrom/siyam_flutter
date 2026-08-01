import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../services/dashboard_service.dart';

/// Builds the Facebook-ready caption text from the current Replenishment
/// list -- the same [ReplenishmentAlert] rows the Staff Dashboard's
/// Replenishment card counts, grouped into the same critical/high/medium
/// tiers, so the post always matches what staff see on the dashboard.
String buildReplenishmentCaption(
  List<ReplenishmentAlert> alerts, {
  String shelterName = 'SIYAM Animal Shelter',
}) {
  final critical = alerts.where((a) => a.priority == ReplenishmentPriority.critical).toList();
  final high = alerts.where((a) => a.priority == ReplenishmentPriority.high).toList();
  final medium = alerts.where((a) => a.priority == ReplenishmentPriority.medium).toList();

  String bullet(ReplenishmentAlert a) =>
      '• ${a.itemName} — ${formatQty(a.stockQty)} ${a.unitAbbr} left';

  final buf = StringBuffer()
    ..writeln('🐾 Stock Update — $shelterName 🐾')
    ..writeln()
    ..writeln(
        "We're running low on some essential supplies for our rescued animals. "
        'If you\'re able to help, every donation keeps a rescue fed, treated, or bandaged. 🙏')
    ..writeln()
    ..writeln('🔴 OUT OF STOCK');
  if (critical.isEmpty) {
    buf.writeln("None right now — thank you to everyone who's helped keep us stocked! 🎉");
  } else {
    critical.map(bullet).forEach(buf.writeln);
  }

  if (high.isNotEmpty) {
    buf
      ..writeln()
      ..writeln('🟠 LOW STOCK — needs restocking soon');
    high.map(bullet).forEach(buf.writeln);
  }

  if (medium.isNotEmpty) {
    buf
      ..writeln()
      ..writeln('🟡 NEEDS RESTOCK');
    medium.map(bullet).forEach(buf.writeln);
  }

  buf
    ..writeln()
    ..writeln('📍 Drop off at [Shelter Address] or message us to arrange pickup.')
    ..writeln('Thank you for helping us keep our rescues healthy! 🐶🐱')
    ..writeln()
    ..write('#AdoptDontShop #AnimalShelterPH #DonationDrive');

  return buf.toString();
}

/// Shows the auto-composed social-media post for the current Replenishment
/// list, with an editable caption and a copy-to-clipboard action.
Future<void> showSocialPostDialog(
  BuildContext context, {
  required List<ReplenishmentAlert> alerts,
}) {
  final captionCtrl = TextEditingController(text: buildReplenishmentCaption(alerts));

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.campaign_outlined, size: 18, color: AppColors.roleStaff),
          SizedBox(width: 8),
          Text('Social Media Post'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto-composed from the current Replenishment list. Edit before posting.',
                style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 14),
              _FacebookPreview(controller: captionCtrl),
              const SizedBox(height: 14),
              const Text('EDIT CAPTION',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                      letterSpacing: 0.4)),
              const SizedBox(height: 6),
              TextField(
                controller: captionCtrl,
                maxLines: 14,
                minLines: 8,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.roleStaff),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: captionCtrl.text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Caption copied')));
          },
          icon: const Icon(Icons.copy_outlined, size: 16),
          label: const Text('Copy caption'),
        ),
      ],
    ),
  );
}

/// A live-updating mock of how the caption reads as a Facebook post, purely
/// for staff to sanity-check formatting before copying it out.
class _FacebookPreview extends StatelessWidget {
  final TextEditingController controller;
  const _FacebookPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text('S',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIYAM Animal Shelter',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Just now · Public',
                        style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  ],
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => Text(
                  controller.text,
                  style: const TextStyle(fontSize: 12.5, height: 1.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
