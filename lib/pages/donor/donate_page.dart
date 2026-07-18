import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../services/donation_service.dart';
import '../../state/auth_state.dart';

class DonatePage extends StatefulWidget {
  const DonatePage({super.key});

  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  // Service for donation operations
  final DonationService _service = DonationService();
  
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final TextEditingController _proofCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // State variables
  DateTime? _schedDate;
  bool _submitting = false;

  @override
  void dispose() {
    // Clean up controllers
    _proofCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Opens date picker for selecting drop-off date
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _schedDate = picked);
  }

  // Submits the donation form to the database
  Future<void> _submit() async {
    // Validate the form
    if (!_formKey.currentState!.validate()) return;
    
    // Get the donor ID from the auth state
    final donorId = context.read<AuthController>().profile?.userId;
    if (donorId == null) return;

    setState(() => _submitting = true);
    try {
      // Submit the donation to the service
      await _service.createSubmission(
        donorId: donorId,
        schedDate: _schedDate,
        proofImg: _proofCtrl.text.trim().isEmpty ? null : _proofCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation submitted -- thank you!')),
      );
      
      // Navigate to donation history
      context.go('/donation-history');
    } catch (e) {
      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not submit donation: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title
          const Text('Donate Now',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          // Subtitle / Instruction
          const Text(
            'Let us know when you\'d like to drop off your donation. '
            'Staff will confirm the items received once it arrives.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          
          // Donation Form Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== DATABASE FIELD: drop_off_sched =====
                  const Text('Preferred Drop-off Date',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        _schedDate == null
                            ? 'Select a date'
                            : '${_schedDate!.month}/${_schedDate!.day}/${_schedDate!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== DATABASE FIELD: proofimg =====
                  TextFormField(
                    controller: _proofCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Proof photo URL (optional)',
                      helperText:
                          'Paste a link to a photo of the items. Direct photo upload isn\'t wired up yet.',
                      prefixIcon: Icon(Icons.image_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== DATABASE FIELD: notes =====
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      helperText: 'Anything staff should know ahead of time.',
                      prefixIcon: Icon(Icons.notes_outlined, size: 18),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // ===== SUBMIT BUTTON =====
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Donation'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}