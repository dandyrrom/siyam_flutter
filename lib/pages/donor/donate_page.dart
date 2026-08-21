import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../services/donation_service.dart';
import '../../state/auth_state.dart';

class DonatePage extends StatefulWidget {
  const DonatePage({super.key});

  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  // ==========================================================================
  // SERVICES
  // ==========================================================================

  // Service used to create the donation submission in the database.
  final DonationService _service = DonationService();

  // Supabase client used to upload the donation proof image.
  final SupabaseClient _client = Supabase.instance.client;

  // Image picker used to select the donation photo.
  final ImagePicker _imagePicker = ImagePicker();

  // ==========================================================================
  // FORM CONTROLLERS
  // ==========================================================================

  final _formKey = GlobalKey<FormState>();

  // Optional donor notes.
  final TextEditingController _notesCtrl =
      TextEditingController();

  // Preferred drop-off date.
  DateTime? _schedDate;

  // Selected proof / donation image.
  XFile? _proofImage;
  Uint8List? _proofImageBytes;

  // Indicates whether the submission is currently being processed.
  bool _submitting = false;

  // ==========================================================================
  // ERROR STATE: SHOWN WHEN DONOR SUBMITS WITHOUT AN IMAGE
  // ==========================================================================
  //
  // When true:
  // - the upload box border becomes red
  // - a visible error message appears below the box
  //
  bool _proofImageError = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // DATE PICKER
  // ==========================================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _schedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(
        const Duration(days: 365),
      ),
    );

    if (picked == null) return;

    setState(() {
      _schedDate = picked;
    });
  }

  // ==========================================================================
  // IMAGE PICKER
  // ==========================================================================

  Future<void> _pickProofImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (!mounted) return;

    setState(() {
      _proofImage = picked;
      _proofImageBytes = bytes;

      // ==============================================================
      // CLEAR IMAGE ERROR AFTER A VALID IMAGE IS SELECTED
      // ==============================================================
      _proofImageError = false;
    });
  }

  // ==========================================================================
  // UPLOAD DONATION IMAGE
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
        await _proofImage!.readAsBytes();

    await _client.storage
        .from('donation-proofs')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: false,
          ),
        );

    return storagePath;
  }

  // ==========================================================================
  // SUBMIT DONATION
  // ==========================================================================

  Future<void> _submit() async {
    // Run normal Form validation first.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // =========================================================================
    // IMAGE REQUIRED ERROR TRAP
    // =========================================================================
    //
    // Donation photo is required.
    // If no image is attached:
    // 1. turn the upload box red
    // 2. show an error directly below the upload box
    // 3. show a SnackBar as additional feedback
    // 4. stop the submission
    //
    if (_proofImage == null) {
      setState(() {
        _proofImageError = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Donation photo is required before submitting.',
          ),
        ),
      );

      return;
    }

    // Clear any old photo validation error.
    if (_proofImageError) {
      setState(() {
        _proofImageError = false;
      });
    }

    final donorId =
        context
            .read<AuthController>()
            .profile
            ?.userId;

    if (donorId == null) return;

    setState(() {
      _submitting = true;
    });

    try {
      // Upload proof image first.
      final proofPath =
          await _uploadProofImage(
        donorId,
      );

      // Create donor submission.
      await _service.createSubmission(
        donorId: donorId,
        schedDate: _schedDate,
        proofImg: proofPath,
        notes:
            _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Donation request submitted. Thank you!',
          ),
        ),
      );

      context.go('/donation-history');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit donation: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final isMobile =
        screenWidth < 600;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 720,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ==================================================================
          // PAGE HEADER
          // ==================================================================

          const Text(
            'Make a Donation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Help support the animals in our care.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================================
          // SIMPLE 3-STEP GUIDE
          // ==================================================================

          _DonationStepBar(
            isMobile: isMobile,
          ),

          const SizedBox(height: 20),

          // ==================================================================
          // DONATION FORM CARD
          // ==================================================================

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(
              isMobile ? 16 : 22,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border,
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
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==========================================================
                  // PREFERRED DROP-OFF DATE
                  // ==========================================================

                  const _FieldTitle(
                    icon:
                        Icons.calendar_today_outlined,
                    title:
                        'Preferred Drop-off',
                    helper:
                        'When do you plan to bring your donation?',
                  ),

                  const SizedBox(height: 9),

                  InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    onTap:
                        _submitting
                            ? null
                            : _pickDate,
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(
                        prefixIcon: Icon(
                          Icons.event_outlined,
                          size: 19,
                        ),
                        suffixIcon: Icon(
                          Icons.expand_more,
                          size: 20,
                        ),
                      ),
                      child: Text(
                        _schedDate == null
                            ? 'Select a date'
                            : _formatLongDate(
                                _schedDate!,
                              ),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              _schedDate == null
                                  ? FontWeight
                                      .w400
                                  : FontWeight
                                      .w600,
                          color:
                              _schedDate == null
                                  ? AppColors
                                      .mutedForeground
                                  : AppColors
                                      .foreground,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================================
                  // DONATION PHOTO
                  // ==========================================================

                  const _FieldTitle(
                    icon:
                        Icons.photo_camera_outlined,
                    title: 'Donation Photo',
                    helper:
                        'Upload a clear photo of the items.',
                  ),

                  const SizedBox(height: 9),

                  InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    onTap:
                        _submitting
                            ? null
                            : _pickProofImage,
                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 150,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),

                        // ====================================================
                        // PHOTO BOX BORDER STATE
                        // ====================================================
                        //
                        // RED   = user tried to submit without a photo
                        // GREEN = valid photo attached
                        // GRAY  = no error yet
                        //
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
                                      EdgeInsets.symmetric(
                                    vertical:
                                        isMobile
                                            ? 28
                                            : 34,
                                    horizontal: 18,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
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
                                        child: Icon(
                                          Icons
                                              .add_photo_alternate_outlined,
                                          size: 25,

                                          // Make icon red when missing-photo
                                          // validation is active.
                                          color:
                                              _proofImageError
                                                  ? AppColors
                                                      .destructive
                                                  : AppColors
                                                      .roleDonor,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 10,
                                      ),

                                      Text(
                                        'Choose a photo',
                                        style: TextStyle(
                                          fontSize: 14,
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
                                        height: 3,
                                      ),

                                      const Text(
                                        'Tap to browse your device',
                                        style:
                                            TextStyle(
                                          fontSize: 12,
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
                                        top: Radius
                                            .circular(
                                          13,
                                        ),
                                      ),
                                      child: Image.memory(
                                        _proofImageBytes!,
                                        width:
                                            double
                                                .infinity,
                                        height:
                                            isMobile
                                                ? 190
                                                : 230,
                                        fit:
                                            BoxFit.cover,
                                      ),
                                    ),

                                    Padding(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal:
                                            14,
                                        vertical: 11,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons
                                                .check_circle_outline,
                                            size: 18,
                                            color:
                                                AppColors
                                                    .sageGreen,
                                          ),

                                          const SizedBox(
                                            width: 8,
                                          ),

                                          Expanded(
                                            child: Text(
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
                                            width: 10,
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
                                              color:
                                                  AppColors
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

                  // ==========================================================
                  // IMAGE REQUIRED ERROR MESSAGE
                  // ==========================================================
                  //
                  // This appears directly below the image box after the donor
                  // tries to submit without attaching a photo.
                  //
                  if (_proofImageError) ...[
                    const SizedBox(height: 7),

                    const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 15,
                          color:
                              AppColors.destructive,
                        ),

                        SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            'Donation photo is required.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  FontWeight.w500,
                              color: AppColors
                                  .destructive,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ==========================================================
                  // NOTES
                  // ==========================================================

                  const _FieldTitle(
                    icon: Icons.notes_outlined,
                    title: 'Notes',
                    helper:
                        'Optional details for shelter Manager.',
                  ),

                  const SizedBox(height: 9),

                  TextFormField(
                    controller: _notesCtrl,
                    minLines: 3,
                    maxLines: 4,
                    enabled: !_submitting,
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Add a short note',
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==========================================================
                  // NEXT-STEP INFORMATION
                  // ==========================================================

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.roleDonor
                          .withValues(
                        alpha: 0.05,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      border: Border.all(
                        color: AppColors.roleDonor
                            .withValues(
                          alpha: 0.16,
                        ),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .check_circle_outline,
                          size: 18,
                          color:
                              AppColors.roleDonor,
                        ),

                        SizedBox(width: 9),

                        Expanded(
                          child: Text(
                            'Manager will review your request. Track its progress anytime in My Donations.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppColors
                                  .mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================================
                  // SUBMIT BUTTON
                  // ==========================================================

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _submitting
                              ? null
                              : _submit,
                      icon:
                          _submitting
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .send_outlined,
                                  size: 18,
                                ),
                      label: Text(
                        _submitting
                            ? 'Submitting…'
                            : 'Submit Donation Request',
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================================
// FIELD TITLE
// ============================================================================

class _FieldTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String helper;

  const _FieldTitle({
    required this.icon,
    required this.title,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.roleDonor
                .withValues(
              alpha: 0.08,
            ),
            borderRadius:
                BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: AppColors.roleDonor,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 1),

              Text(
                helper,
                style: const TextStyle(
                  fontSize: 11.5,
                  color:
                      AppColors.mutedForeground,
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
// DONATION 3-STEP GUIDE
// ============================================================================

class _DonationStepBar
    extends StatelessWidget {
  final bool isMobile;

  const _DonationStepBar({
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: const Row(
          children: [
            Expanded(
              child: _MiniStep(
                number: '1',
                label: 'Date',
              ),
            ),

            _StepLine(),

            Expanded(
              child: _MiniStep(
                number: '2',
                label: 'Photo',
              ),
            ),

            _StepLine(),

            Expanded(
              child: _MiniStep(
                number: '3',
                label: 'Submit',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _MiniStep(
              number: '1',
              label: 'Choose Date',
            ),
          ),

          _StepLine(),

          Expanded(
            child: _MiniStep(
              number: '2',
              label: 'Add Photo',
            ),
          ),

          _StepLine(),

          Expanded(
            child: _MiniStep(
              number: '3',
              label: 'Submit',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP ITEM
// ============================================================================

class _MiniStep extends StatelessWidget {
  final String number;
  final String label;

  const _MiniStep({
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(
            color: AppColors.roleDonor,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(width: 7),

        Flexible(
          child: Text(
            label,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
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
// STEP CONNECTOR
// ============================================================================

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 1,
      margin:
          const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      color: AppColors.border,
    );
  }
}

// ============================================================================
// DATE FORMATTING
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