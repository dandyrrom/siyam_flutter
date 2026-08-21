import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../services/dashboard_service.dart';

// =============================================================================
// SOCIAL MEDIA TEMPLATE
// =============================================================================
//
// PANEL REVISION:
// The generated replenishment caption should sound like an actual
// Dumaguete Animal Sanctuary post rather than a generic e-commerce / system
// announcement.
//
// IMPORTANT:
// - The caption is still generated from the CURRENT Replenishment list.
// - Staff can still edit the caption before copying it.
// - No database / Supabase changes are required.
// - The function names are preserved so StaffDashboard does not need changes.
//
// Tone:
// - direct and practical
// - grateful to supporters
// - centered on the animals in DAS care
// - restrained emojis
// - branded as Dumaguete Animal Sanctuary
// - uses the DAS "Every Life Matters" tagline
// =============================================================================

String buildReplenishmentCaption(
  List<ReplenishmentAlert> alerts, {
  String shelterName = 'Dumaguete Animal Sanctuary',
}) {
  final critical = alerts
      .where(
        (alert) =>
            alert.priority ==
            ReplenishmentPriority.critical,
      )
      .toList();

  final high = alerts
      .where(
        (alert) =>
            alert.priority ==
            ReplenishmentPriority.high,
      )
      .toList();

  final medium = alerts
      .where(
        (alert) =>
            alert.priority ==
            ReplenishmentPriority.medium,
      )
      .toList();

  String remainingLine(
    ReplenishmentAlert alert,
  ) {
    return '• ${alert.itemName} — '
        '${formatQty(alert.stockQty)} '
        '${alert.unitAbbr} remaining';
  }

  String criticalLine(
    ReplenishmentAlert alert,
  ) {
    return '• ${alert.itemName} — OUT OF STOCK';
  }

  final buffer = StringBuffer();

  // ===========================================================================
  // NOTHING CURRENTLY NEEDS REPLENISHMENT
  // ===========================================================================

  if (alerts.isEmpty) {
    buffer
      ..writeln('A little stock update from $shelterName 🐾')
      ..writeln()
      ..writeln(
        'Our essential supplies are currently in good shape. '
        'Thank you to everyone who continues to donate and support '
        'the animals in our care.',
      )
      ..writeln()
      ..writeln(
        'Your support helps us continue feeding, treating and caring '
        'for our rescues every day.',
      )
      ..writeln()
      ..writeln('Every Life Matters. ❤️')
      ..writeln()
      ..write(
        '#DumagueteAnimalSanctuary #EveryLifeMatters',
      );

    return buffer.toString();
  }

  // ===========================================================================
  // INTRO
  // ===========================================================================

  buffer
    ..writeln('WE NEED A LITTLE HELP WITH SUPPLIES 🐾')
    ..writeln()
    ..writeln(
      '$shelterName is currently running low on a few everyday supplies '
      'used for the animals in our care.',
    );

  // ===========================================================================
  // CRITICAL / OUT OF STOCK
  // ===========================================================================

  if (critical.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('🔴 URGENTLY NEEDED');

    for (final alert in critical) {
      buffer.writeln(
        criticalLine(alert),
      );
    }
  }

  // ===========================================================================
  // HIGH PRIORITY
  // ===========================================================================

  if (high.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('🟠 RUNNING LOW');

    for (final alert in high) {
      buffer.writeln(
        remainingLine(alert),
      );
    }
  }

  // ===========================================================================
  // MEDIUM PRIORITY
  // ===========================================================================

  if (medium.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('🟡 ALSO NEEDED');

    for (final alert in medium) {
      buffer.writeln(
        remainingLine(alert),
      );
    }
  }

  // ===========================================================================
  // CALL TO ACTION
  // ===========================================================================

  buffer
    ..writeln()
    ..writeln(
      'If you would like to donate any of these items, please send us '
      'a message so we can coordinate drop-off.',
    )
    ..writeln()
    ..writeln(
      'Donations in kind help us keep our rescues fed, comfortable and '
      'properly cared for. For medicines or veterinary supplies, please '
      'message us first so we can confirm what is currently needed.',
    )
    ..writeln()
    ..writeln(
      'Thank you so much to everyone who continues to support our rescues. '
      'Every contribution, big or small, makes a difference. ❤️',
    )
    ..writeln()
    ..writeln('Every Life Matters.')
    ..writeln()
    ..write(
      '#DumagueteAnimalSanctuary #EveryLifeMatters',
    );

  return buffer.toString();
}

// =============================================================================
// DIALOG
// =============================================================================

/// Shows the auto-composed social-media post for the current Replenishment
/// list, with an editable caption and a copy-to-clipboard action.
Future<void> showSocialPostDialog(
  BuildContext context, {
  required List<ReplenishmentAlert> alerts,
}) {
  final captionCtrl = TextEditingController(
    text: buildReplenishmentCaption(
      alerts,
    ),
  );

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final screen =
          MediaQuery.sizeOf(dialogContext);

      final dialogWidth =
          screen.width < 560
              ? screen.width - 32
              : 500.0;

      final dialogHeight =
          screen.height < 760
              ? screen.height * 0.86
              : 650.0;

      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding:
            const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // ===============================================================
              // HEADER
              // ===============================================================

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  18,
                  12,
                  14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .roleStaff
                            .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          11,
                        ),
                      ),
                      alignment:
                          Alignment.center,
                      child: const Icon(
                        Icons.campaign_outlined,
                        size: 20,
                        color:
                            AppColors.roleStaff,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Social Media Template',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Generated from current replenishment needs',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors
                                  .mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () =>
                          Navigator.of(
                        dialogContext,
                      ).pop(),
                      icon: const Icon(
                        Icons.close,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ===============================================================
              // CONTENT
              // ===============================================================

              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .secondary,
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          border: Border.all(
                            color:
                                AppColors.border,
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color:
                                  AppColors.primary,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'The caption is generated from the live Replenishment list. '
                                'Review and edit it before posting to the official DAS social media page.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: AppColors
                                      .mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'PREVIEW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w700,
                          color: AppColors
                              .mutedForeground,
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      _FacebookPreview(
                        controller:
                            captionCtrl,
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'EDIT CAPTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w700,
                          color: AppColors
                              .mutedForeground,
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      TextField(
                        controller:
                            captionCtrl,
                        maxLines: 16,
                        minLines: 10,
                        style:
                            const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                        decoration:
                            const InputDecoration(
                          isDense: true,
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // ===============================================================
              // ACTIONS
              // ===============================================================

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  10,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(
                        dialogContext,
                      ).pop(),
                      child: const Text(
                        'Close',
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.roleStaff,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                captionCtrl.text,
                          ),
                        );

                        if (!dialogContext
                            .mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Caption copied',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.copy_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        'Copy caption',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(
    captionCtrl.dispose,
  );
}

// =============================================================================
// FACEBOOK PREVIEW
// =============================================================================

/// Live preview of how the editable caption reads as a DAS Facebook post.
class _FacebookPreview
    extends StatelessWidget {
  final TextEditingController controller;

  const _FacebookPreview({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.border,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration:
                const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border,
                ),
              ),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.primary,
                  child: Text(
                    'DAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'Dumaguete Animal Sanctuary',
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Just now · Public',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxHeight: 260,
            ),
            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets.all(12),
              child: AnimatedBuilder(
                animation: controller,
                builder: (
                  context,
                  _,
                ) {
                  return Text(
                    controller.text,
                    style:
                        const TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
