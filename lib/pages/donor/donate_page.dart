import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../services/dashboard_service.dart';
import '../../services/donation_service.dart';
import '../../state/auth_state.dart';

class DonatePage extends StatefulWidget {
  const DonatePage({super.key});

  @override
  State<DonatePage> createState() =>
      _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final DonationService _service =
      DonationService();

  final DashboardService _dashboardService =
      DashboardService();

  final SupabaseClient _client =
      Supabase.instance.client;

  final ImagePicker _imagePicker =
      ImagePicker();

  // ==========================================================================
  // FORM
  // ==========================================================================

  final _formKey =
      GlobalKey<FormState>();

  final TextEditingController _notesCtrl =
      TextEditingController();

  DateTime? _schedDate;

  XFile? _proofImage;

  Uint8List? _proofImageBytes;

  bool _submitting = false;

  bool _proofImageError = false;

  // ==========================================================================
  // CURRENTLY NEEDED ITEMS
  // ==========================================================================

  List<ReplenishmentAlert> _currentNeeds = [];

  bool _needsLoading = true;

  bool _needsLoadInProgress = false;

  String? _needsError;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _loadCurrentNeeds();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();

    super.dispose();
  }

  // ==========================================================================
  // CHECK IF USER CAME FROM CURRENTLY NEEDED
  // ==========================================================================

  bool get _fromCurrentlyNeeded {
    return GoRouterState.of(context)
            .uri
            .queryParameters['from'] ==
        'currently-needed';
  }

  // ==========================================================================
  // LOAD CURRENTLY NEEDED
  // ==========================================================================

  Future<void> _loadCurrentNeeds() async {
    if (_needsLoadInProgress) return;

    _needsLoadInProgress = true;

    if (mounted) {
      setState(() {
        _needsLoading = true;
        _needsError = null;
      });
    }

    try {
      final needs =
          await _dashboardService
              .fetchReplenishmentAlerts();

      if (!mounted) return;

      setState(() {
        _currentNeeds = needs;

        _needsLoading = false;

        _needsError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _needsError =
            'Could not load currently needed items.';

        _needsLoading = false;
      });
    } finally {
      _needsLoadInProgress = false;
    }
  }

  // ==========================================================================
  // VIEW ALL CURRENTLY NEEDED
  // ==========================================================================

  Future<void> _showAllNeededItems() async {
    final screenSize =
        MediaQuery.sizeOf(context);

    final dialogWidth =
        screenSize.width < 560
            ? screenSize.width - 32
            : 520.0;

    final dialogHeight =
        screenSize.height < 640
            ? screenSize.height - 48
            : 560.0;

    await showDialog<void>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return Dialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: [
                // ============================================================
                // HEADER
                // ============================================================

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    18,
                    10,
                    14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .warning
                              .withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .priority_high_rounded,
                          size: 19,
                          color: AppColors
                              .warning,
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Currently Needed',
                              style:
                                  TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),

                            SizedBox(
                              height: 2,
                            ),

                            Text(
                              'Items currently needed by the sanctuary.',
                              style:
                                  TextStyle(
                                fontSize:
                                    11.5,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        tooltip: 'Close',
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                        icon:
                            const Icon(
                          Icons.close,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                ),

                // ============================================================
                // LIST
                // ============================================================
                //
                // This is intentionally a normal lazy ListView.
                //
                // No shrinkWrap.
                // No intrinsic sizing.
                // Only visible rows are built.
                //

                Expanded(
                  child: _currentNeeds
                          .isEmpty
                      ? const Center(
                          child: Padding(
                            padding:
                                EdgeInsets
                                    .all(
                              24,
                            ),
                            child: Text(
                              'There are no currently needed items at the moment.',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  TextStyle(
                                fontSize:
                                    12.5,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                18,
                            vertical: 8,
                          ),
                          itemCount:
                              _currentNeeds
                                  .length,
                          separatorBuilder:
                              (
                            context,
                            index,
                          ) =>
                                  const Divider(
                            height: 1,
                          ),
                          itemBuilder: (
                            context,
                            index,
                          ) {
                            final item =
                                _currentNeeds[
                                    index];

                            return _NeededItemRow(
                              item:
                                  item,
                            );
                          },
                        ),
                ),

                const Divider(
                  height: 1,
                ),

                // ============================================================
                // FOOTER
                // ============================================================

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_currentNeeds.length} '
                          '${_currentNeeds.length == 1 ? 'item' : 'items'} currently needed',
                          style:
                              const TextStyle(
                            fontSize: 11.5,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ),

                      TextButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                        child:
                            const Text(
                          'Close',
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
    );
  }

  // ==========================================================================
  // DATE PICKER
  // ==========================================================================

  Future<void> _pickDate() async {
    final now =
        DateTime.now();

    final picked =
        await showDatePicker(
      context: context,
      initialDate:
          _schedDate ??
          now.add(
            const Duration(
              days: 1,
            ),
          ),
      firstDate: now,
      lastDate: now.add(
        const Duration(
          days: 365,
        ),
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _schedDate = picked;
    });
  }

  // ==========================================================================
  // IMAGE PICKER
  // ==========================================================================

  Future<void> _pickProofImage() async {
    final picked =
        await _imagePicker.pickImage(
      source:
          ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) {
      return;
    }

    final bytes =
        await picked.readAsBytes();

    if (!mounted) return;

    setState(() {
      _proofImage = picked;

      _proofImageBytes =
          bytes;

      _proofImageError =
          false;
    });
  }

  // ==========================================================================
  // UPLOAD IMAGE
  // ==========================================================================

  Future<String> _uploadProofImage(
    String donorId,
  ) async {
    if (_proofImage == null) {
      throw Exception(
        'Donation proof image is required.',
      );
    }

    final extension =
        _proofImage!.name.contains('.')
            ? _proofImage!.name
                .split('.')
                .last
                .toLowerCase()
            : 'jpg';

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$extension';

    final storagePath =
        '$donorId/$fileName';

    final bytes =
        _proofImageBytes ??
        await _proofImage!
            .readAsBytes();

    await _client.storage
        .from(
          'donation-proofs',
        )
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions:
              const FileOptions(
            upsert: false,
          ),
        );

    return storagePath;
  }

  // ==========================================================================
  // SUBMIT
  // ==========================================================================

  Future<void> _submit() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_proofImage == null) {
      setState(() {
        _proofImageError =
            true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Donation photo is required before submitting.',
          ),
        ),
      );

      return;
    }

    if (_proofImageError) {
      setState(() {
        _proofImageError =
            false;
      });
    }

    final donorId =
        context
            .read<AuthController>()
            .profile
            ?.userId;

    if (donorId == null) {
      return;
    }

    setState(() {
      _submitting =
          true;
    });

    try {
      final proofPath =
          await _uploadProofImage(
        donorId,
      );

      // Current Needs are display-only.
      // Nothing is added to Notes.
      await _service.createSubmission(
        donorId:
            donorId,
        schedDate:
            _schedDate,
        proofImg:
            proofPath,
        notes:
            _notesCtrl.text
                    .trim()
                    .isEmpty
                ? null
                : _notesCtrl.text
                    .trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Donation request submitted. Thank you!',
          ),
        ),
      );

      context.go(
        '/donation-history',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit donation: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting =
              false;
        });
      }
    }
  }

  // ==========================================================================
  // CURRENTLY NEEDED CARD
  // ==========================================================================

  Widget _buildCurrentlyNeededCard() {
    final preview =
        _currentNeeds.take(3).toList();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
              _fromCurrentlyNeeded
                  ? AppColors.roleDonor
                      .withValues(
                    alpha: 0.40,
                  )
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .warning
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    9,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .priority_high_rounded,
                  size: 18,
                  color:
                      AppColors.warning,
                ),
              ),

              const SizedBox(
                width: 9,
              ),

              const Expanded(
                child: Text(
                  'Currently Needed',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'Items the sanctuary currently needs.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors
                  .mutedForeground,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          if (_needsLoading)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 20,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_needsError !=
              null)
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  _needsError!,
                  style:
                      const TextStyle(
                    fontSize: 11.5,
                    color: AppColors
                        .destructive,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                OutlinedButton(
                  onPressed:
                      _loadCurrentNeeds,
                  child:
                      const Text(
                    'Retry',
                  ),
                ),
              ],
            )
          else if (_currentNeeds
              .isEmpty)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 12,
              ),
              child: Text(
                'Supply needs are currently covered.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            )
          else ...[
            for (var i = 0;
                i < preview.length;
                i++) ...[
              if (i > 0)
                const Divider(
                  height: 16,
                ),

              _NeededItemRow(
                item:
                    preview[i],
                compact: true,
              ),
            ],

            if (_currentNeeds.length >
                3) ...[
              const SizedBox(
                height: 12,
              ),

              const Divider(
                height: 1,
              ),

              const SizedBox(
                height: 7,
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    TextButton.icon(
                  onPressed:
                      _showAllNeededItems,
                  icon:
                      const Icon(
                    Icons
                        .list_alt_outlined,
                    size: 16,
                  ),
                  label: Text(
                    'View all ${_currentNeeds.length} items',
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // DONATION FORM
  // ==========================================================================

  Widget _buildDonationForm(
    bool isMobile,
  ) {
    return Container(
      width:
          double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 16 : 22,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Donation Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight
                        .w700,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            // ================================================================
            // DROP-OFF DATE
            // ================================================================

            const _FieldTitle(
              icon: Icons
                  .calendar_today_outlined,
              title:
                  'Preferred Drop-off',
              helper:
                  'When do you plan to bring your donation?',
            ),

            const SizedBox(
              height: 9,
            ),

            InkWell(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              onTap:
                  _submitting
                      ? null
                      : _pickDate,
              child:
                  InputDecorator(
                decoration:
                    const InputDecoration(
                  prefixIcon:
                      Icon(
                    Icons
                        .event_outlined,
                    size: 19,
                  ),
                  suffixIcon:
                      Icon(
                    Icons
                        .expand_more,
                    size: 20,
                  ),
                ),
                child: Text(
                  _schedDate ==
                          null
                      ? 'Select a date'
                      : _formatLongDate(
                          _schedDate!,
                        ),
                  style:
                      TextStyle(
                    fontSize:
                        13.5,
                    fontWeight:
                        _schedDate ==
                                null
                            ? FontWeight
                                .w400
                            : FontWeight
                                .w600,
                    color:
                        _schedDate ==
                                null
                            ? AppColors
                                .mutedForeground
                            : AppColors
                                .foreground,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // ================================================================
            // DONATION PHOTO
            // ================================================================

            const _FieldTitle(
              icon: Icons
                  .photo_camera_outlined,
              title:
                  'Donation Photo',
              helper:
                  'Upload a clear photo of the items.',
            ),

            const SizedBox(
              height: 9,
            ),

            InkWell(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              onTap:
                  _submitting
                      ? null
                      : _pickProofImage,
              child:
                  AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds:
                      150,
                ),
                width:
                    double.infinity,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.card,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        _proofImageError
                            ? AppColors
                                .destructive
                            : _proofImage ==
                                    null
                                ? AppColors
                                    .border
                                : AppColors
                                    .sageGreen,
                    width:
                        _proofImageError ||
                                _proofImage !=
                                    null
                            ? 1.4
                            : 1,
                  ),
                ),
                child:
                    _proofImageBytes ==
                            null
                        ? Padding(
                            padding:
                                EdgeInsets
                                    .symmetric(
                              vertical:
                                  isMobile
                                      ? 28
                                      : 34,
                              horizontal:
                                  18,
                            ),
                            child:
                                Column(
                              children: [
                                Container(
                                  width:
                                      48,
                                  height:
                                      48,
                                  decoration:
                                      BoxDecoration(
                                    color: AppColors
                                        .roleDonor
                                        .withValues(
                                      alpha:
                                          0.10,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      13,
                                    ),
                                  ),
                                  child:
                                      Icon(
                                    Icons
                                        .add_photo_alternate_outlined,
                                    size:
                                        25,
                                    color:
                                        _proofImageError
                                            ? AppColors
                                                .destructive
                                            : AppColors
                                                .roleDonor,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      10,
                                ),

                                Text(
                                  'Choose a photo',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        14,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    color:
                                        _proofImageError
                                            ? AppColors
                                                .destructive
                                            : AppColors
                                                .foreground,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      3,
                                ),

                                const Text(
                                  'Tap to browse your device',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        12,
                                    color: AppColors
                                        .mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .stretch,
                            children: [
                              ClipRRect(
                                borderRadius:
                                    const BorderRadius
                                        .vertical(
                                  top:
                                      Radius
                                          .circular(
                                    13,
                                  ),
                                ),
                                child:
                                    Image.memory(
                                  _proofImageBytes!,
                                  width:
                                      double
                                          .infinity,
                                  height:
                                      isMobile
                                          ? 190
                                          : 230,
                                  fit:
                                      BoxFit
                                          .cover,
                                ),
                              ),

                              Padding(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      14,
                                  vertical:
                                      11,
                                ),
                                child:
                                    Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .check_circle_outline,
                                      size:
                                          18,
                                      color: AppColors
                                          .sageGreen,
                                    ),

                                    const SizedBox(
                                      width:
                                          8,
                                    ),

                                    Expanded(
                                      child:
                                          Text(
                                        _proofImage!
                                            .name,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              12.5,
                                          fontWeight:
                                              FontWeight
                                                  .w500,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      width:
                                          10,
                                    ),

                                    const Text(
                                      'Change',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            12.5,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                        color: AppColors
                                            .sageGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ),

            if (_proofImageError) ...[
              const SizedBox(
                height: 7,
              ),

              const Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Icon(
                    Icons
                        .error_outline,
                    size: 15,
                    color:
                        AppColors
                            .destructive,
                  ),

                  SizedBox(
                    width: 6,
                  ),

                  Expanded(
                    child: Text(
                      'Donation photo is required.',
                      style:
                          TextStyle(
                        fontSize:
                            11.5,
                        fontWeight:
                            FontWeight
                                .w500,
                        color: AppColors
                            .destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(
              height: 24,
            ),

            // ================================================================
            // NOTES
            // ================================================================

            const _FieldTitle(
              icon:
                  Icons.notes_outlined,
              title:
                  'Notes',
              helper:
                  'Optional details for shelter Manager.',
            ),

            const SizedBox(
              height: 9,
            ),

            TextFormField(
              controller:
                  _notesCtrl,
              minLines: 3,
              maxLines: 4,
              enabled:
                  !_submitting,
              decoration:
                  const InputDecoration(
                hintText:
                    'Add a short note',
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            // ================================================================
            // NEXT STEP
            // ================================================================

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration:
                  BoxDecoration(
                color: AppColors
                    .roleDonor
                    .withValues(
                  alpha: 0.05,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
                border:
                    Border.all(
                  color: AppColors
                      .roleDonor
                      .withValues(
                    alpha: 0.16,
                  ),
                ),
              ),
              child:
                  const Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Icon(
                    Icons
                        .check_circle_outline,
                    size: 18,
                    color:
                        AppColors
                            .roleDonor,
                  ),

                  SizedBox(
                    width: 9,
                  ),

                  Expanded(
                    child: Text(
                      'Manager will review your request. Track its progress anytime in My Donations.',
                      style:
                          TextStyle(
                        fontSize:
                            12.5,
                        height:
                            1.35,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ================================================================
            // SUBMIT
            // ================================================================

            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _submitting
                        ? null
                        : _submit,
                icon:
                    _submitting
                        ? const SizedBox(
                            width:
                                17,
                            height:
                                17,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors
                                      .white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .send_outlined,
                            size:
                                18,
                          ),
                label: Text(
                  _submitting
                      ? 'Submitting…'
                      : 'Submit Donation Request',
                ),
                style:
                    ElevatedButton
                        .styleFrom(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical:
                        15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final screenWidth =
        MediaQuery.sizeOf(
      context,
    ).width;

    final compact =
        screenWidth < 900;

    // If the donor came specifically from Currently Needed,
    // let the list finish loading first.
    if (_fromCurrentlyNeeded &&
        _needsLoading) {
      return const SizedBox(
        height: 320,
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return ConstrainedBox(
      constraints:
          const BoxConstraints(
        maxWidth: 1080,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ================================================================
          // HEADER
          // ================================================================

          const Text(
            'Make a Donation',
            style: TextStyle(
              fontSize: 24,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          const Text(
            'Help support the animals in our care.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors
                  .mutedForeground,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          _DonationStepBar(
            isMobile:
                compact,
          ),

          const SizedBox(
            height: 20,
          ),

          // ================================================================
          // MOBILE / TABLET
          // ================================================================

          if (compact) ...[
            _buildCurrentlyNeededCard(),

            const SizedBox(
              height: 16,
            ),

            _buildDonationForm(
              true,
            ),
          ] else
            // ==============================================================
            // DESKTOP
            // ==============================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Expanded(
                  child:
                      _buildDonationForm(
                    false,
                  ),
                ),

                const SizedBox(
                  width: 18,
                ),

                SizedBox(
                  width: 300,
                  child:
                      _buildCurrentlyNeededCard(),
                ),
              ],
            ),

          const SizedBox(
            height: 24,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CURRENTLY NEEDED ITEM ROW
// ============================================================================

class _NeededItemRow
    extends StatelessWidget {
  final ReplenishmentAlert item;

  final bool compact;

  const _NeededItemRow({
    required this.item,
    this.compact = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final (
      label,
      color,
    ) = _needMeta(
      item.priority,
    );

    return Padding(
      padding:
          EdgeInsets.symmetric(
        vertical:
            compact ? 3 : 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin:
                const EdgeInsets.only(
              top: 5,
            ),
            decoration:
                BoxDecoration(
              color: color,
              shape:
                  BoxShape.circle,
            ),
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  item.itemName,
                  maxLines:
                      compact ? 1 : 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  item.stockQty <=
                          0
                      ? 'Currently out of stock'
                      : '${_formatQty(item.stockQty)} ${item.unitAbbr} remaining',
                  style:
                      const TextStyle(
                    fontSize:
                        10.8,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 7,
              vertical: 3,
            ),
            decoration:
                BoxDecoration(
              color:
                  color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                999,
              ),
            ),
            child: Text(
              label,
              style:
                  TextStyle(
                fontSize: 9.5,
                fontWeight:
                    FontWeight
                        .w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FIELD TITLE
// ============================================================================

class _FieldTitle
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String helper;

  const _FieldTitle({
    required this.icon,
    required this.title,
    required this.helper,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration:
              BoxDecoration(
            color: AppColors
                .roleDonor
                .withValues(
              alpha: 0.08,
            ),
            borderRadius:
                BorderRadius.circular(
              9,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color:
                AppColors.roleDonor,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize:
                      13.5,
                  fontWeight:
                      FontWeight
                          .w700,
                ),
              ),

              const SizedBox(
                height: 1,
              ),

              Text(
                helper,
                style:
                    const TextStyle(
                  fontSize:
                      11.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DONATION STEP BAR
// ============================================================================

class _DonationStepBar
    extends StatelessWidget {
  final bool isMobile;

  const _DonationStepBar({
    required this.isMobile,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.symmetric(
        horizontal:
            isMobile ? 12 : 22,
        vertical:
            isMobile ? 12 : 14,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniStep(
              number:
                  '1',
              label: isMobile
                  ? 'Date'
                  : 'Choose Date',
            ),
          ),

          const _StepLine(),

          Expanded(
            child: _MiniStep(
              number:
                  '2',
              label: isMobile
                  ? 'Photo'
                  : 'Add Photo',
            ),
          ),

          const _StepLine(),

          const Expanded(
            child: _MiniStep(
              number:
                  '3',
              label:
                  'Submit',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MINI STEP
// ============================================================================

class _MiniStep
    extends StatelessWidget {
  final String number;

  final String label;

  const _MiniStep({
    required this.number,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment:
              Alignment.center,
          decoration:
              const BoxDecoration(
            color:
                AppColors.roleDonor,
            shape:
                BoxShape.circle,
          ),
          child: Text(
            number,
            style:
                const TextStyle(
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w700,
              color:
                  Colors.white,
            ),
          ),
        ),

        const SizedBox(
          width: 7,
        ),

        Flexible(
          child: Text(
            label,
            overflow:
                TextOverflow
                    .ellipsis,
            style:
                const TextStyle(
              fontSize:
                  12.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STEP LINE
// ============================================================================

class _StepLine
    extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 22,
      height: 1,
      margin:
          const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      color:
          AppColors.border,
    );
  }
}

// ============================================================================
// CURRENT NEED HELPERS
// ============================================================================

(String, Color) _needMeta(
  ReplenishmentPriority priority,
) {
  switch (priority) {
    case ReplenishmentPriority.critical:
      return (
        'Urgent',
        AppColors.stockOut,
      );

    case ReplenishmentPriority.high:
      return (
        'Running Low',
        AppColors.stockLow,
      );

    case ReplenishmentPriority.medium:
      return (
        'Needed Soon',
        AppColors.stockNeedsRestock,
      );
  }
}

String _formatQty(
  double value,
) {
  if (value ==
      value.roundToDouble()) {
    return value
        .toInt()
        .toString();
  }

  return value
      .toStringAsFixed(
        2,
      )
      .replaceFirst(
        RegExp(
          r'0+$',
        ),
        '',
      )
      .replaceFirst(
        RegExp(
          r'\.$',
        ),
        '',
      );
}

// ============================================================================
// DATE FORMAT
// ============================================================================

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatLongDate(
  DateTime date,
) =>
    '${_monthNames[date.month - 1]} '
    '${date.day}, ${date.year}';