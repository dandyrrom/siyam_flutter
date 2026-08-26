import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../services/dashboard_service.dart';

// =============================================================================
// SOCIAL MEDIA TEMPLATE
// =============================================================================
//
// The caption is generated from the CURRENT Replenishment list and remains
// fully editable before Staff copies it.
//
// DAS-style goals:
// - reads like a warm sanctuary update rather than a system notice
// - explains why the supplies matter to the animals
// - asks people to like, comment, and share
// - keeps the current replenishment items easy to read
// - leaves payment details editable instead of inventing account numbers
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

  if (alerts.isEmpty) {
    buffer
      ..writeln('A little update from $shelterName 🐾')
      ..writeln()
      ..writeln(
        'Today our supply shelves are in good shape, and that is because '
        'people continue to remember the animals in our care. Every bag, '
        'bottle, box and small donation helps our team get through another '
        'day of feeding, cleaning and caring for our rescues.',
      )
      ..writeln()
      ..writeln(
        'Thank you to our staff, volunteers and supporters who keep showing '
        'up for the animals. We are very grateful for you. ❤️',
      )
      ..writeln()
      ..writeln(
        'Please like, comment and share this post so more people can continue '
        'to see updates from the sanctuary.',
      )
      ..writeln()
      ..writeln('Every Life Matters.')
      ..writeln()
      ..write(
        '#DumagueteAnimalSanctuary #EveryLifeMatters',
      );

    return buffer.toString();
  }

  buffer
    ..writeln('A little update from $shelterName 🐾')
    ..writeln()
    ..writeln(
      'Every day our team is feeding, cleaning, treating and caring for the '
      'animals who depend on us. Some of the supplies we use for them are '
      'running low, and we could really use a little help keeping the shelves '
      'ready for the days ahead.',
    )
    ..writeln()
    ..writeln(
      'These are the supplies we currently need:',
    );

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

  buffer
    ..writeln()
    ..writeln(
      'If you can help with any of these supplies, please send us a message '
      'so we can coordinate drop-off. For medicines or veterinary supplies, '
      'please message us first so we can confirm what is currently needed.',
    )
    ..writeln()
    ..writeln(
      'Please like, comment and share this post as soon as you see it. '
      'Sharing helps this update reach more people who may be able to help '
      'the animals.',
    )
    ..writeln()
    ..writeln(
      'Thank you to our staff, volunteers and supporters who continue to '
      'show up for the rescues every day. Every contribution, big or small, '
      'helps us keep going. ❤️',
    )
    ..writeln()
    ..writeln(
      'Special thanks to [add staff / volunteer / editor name here] for '
      'helping with this update.',
    )
    ..writeln()
    ..writeln('DONATION DETAILS')
    ..writeln('GCash — Christine Askew')
    ..writeln('• Number: [Add official DAS GCash number]')
    ..writeln()
    ..writeln('BDO')
    ..writeln('• Account name: [Add official DAS account name]')
    ..writeln('• Account number: [Add official DAS BDO account number]')
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

              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
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