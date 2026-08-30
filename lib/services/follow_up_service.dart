import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// MEDICAL FOLLOW-UP REMINDERS
// ============================================================================
//
// Lightweight read model used by Staff dashboard/notifications.
//
// This service intentionally does NOT call TreatmentService.fetchTreatments().
// Dashboard reminders only need:
// - treatment ID/name
// - pet ID/name
// - next follow-up date
// - optional note
//
// No occurrences, treatment items, inventory batches, or user maps are loaded.
// ============================================================================

enum FollowUpReminderStatus {
  overdue,
  dueToday,
  dueSoonUrgent,
  dueSoon,
}

class MedicalFollowUpReminder {
  final String treatmentId;
  final String petId;
  final String petName;
  final String treatmentName;
  final DateTime dueDate;
  final String? note;

  const MedicalFollowUpReminder({
    required this.treatmentId,
    required this.petId,
    required this.petName,
    required this.treatmentName,
    required this.dueDate,
    this.note,
  });

  // Returns whole calendar days from today to the due date.
  int daysUntil(DateTime now) {
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final due = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );

    return due.difference(today).inDays;
  }

  // Shared urgency rule for dashboard and future notification surfaces.
  FollowUpReminderStatus statusAt(DateTime now) {
    final days = daysUntil(now);

    if (days < 0) {
      return FollowUpReminderStatus.overdue;
    }

    if (days == 0) {
      return FollowUpReminderStatus.dueToday;
    }

    if (days <= 3) {
      return FollowUpReminderStatus.dueSoonUrgent;
    }

    return FollowUpReminderStatus.dueSoon;
  }
}

class FollowUpService {
  final SupabaseClient _client = Supabase.instance.client;

  // Returns active reminders that are overdue, due today, or due within 7 days.
  //
  // There is deliberately no timer/stream here. The caller refreshes through
  // the app's existing DataChangeBus and normal page loads.
  Future<List<MedicalFollowUpReminder>> fetchActionableReminders({
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();

    final today = DateTime(
      current.year,
      current.month,
      current.day,
    );

    final horizon = today.add(
      const Duration(days: 7),
    );

    final rows = await _client
        .from('treatment')
        .select(
          'id, name, petid, next_followup_date, followup_note, '
          'pet(name)',
        )
        .eq('followup_required', true)
        .eq('followup_active', true)
        .not('next_followup_date', 'is', null)
        .lte(
          'next_followup_date',
          _dateParam(horizon),
        )
        .order(
          'next_followup_date',
          ascending: true,
        );

    final reminders = <MedicalFollowUpReminder>[];

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final dueRaw = row['next_followup_date'];

      if (dueRaw == null) {
        continue;
      }

      final pet = row['pet'] as Map<String, dynamic>?;

      reminders.add(
        MedicalFollowUpReminder(
          treatmentId: row['id'] as String,
          petId: row['petid'] as String,
          petName: (pet?['name'] as String?)?.trim().isNotEmpty == true
              ? (pet!['name'] as String).trim()
              : 'Unknown animal',
          treatmentName:
              ((row['name'] as String?) ?? 'Unnamed treatment').trim(),
          dueDate: _dateOnly(dueRaw),
          note: row['followup_note'] as String?,
        ),
      );
    }

    // Database ordering already puts overdue first. These tie-breakers keep
    // equal dates stable and predictable for the dashboard.
    reminders.sort((a, b) {
      final dueCompare = a.dueDate.compareTo(b.dueDate);

      if (dueCompare != 0) {
        return dueCompare;
      }

      final petCompare =
          a.petName.toLowerCase().compareTo(b.petName.toLowerCase());

      if (petCompare != 0) {
        return petCompare;
      }

      return a.treatmentName
          .toLowerCase()
          .compareTo(b.treatmentName.toLowerCase());
    });

    return reminders;
  }

  DateTime _dateOnly(Object value) {
    final parsed = DateTime.parse(value.toString());

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  String _dateParam(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}
