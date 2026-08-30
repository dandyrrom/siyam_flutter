import 'pet.dart';

// =============================================================================
// FOLLOW-UP TYPES
// =============================================================================

enum FollowUpType {
  oneTime,
  repeating,
}

FollowUpType? followUpTypeFromString(String? value) {
  switch (value) {
    case 'one_time':
      return FollowUpType.oneTime;
    case 'repeating':
      return FollowUpType.repeating;
    default:
      return null;
  }
}

String followUpTypeToString(FollowUpType value) {
  switch (value) {
    case FollowUpType.oneTime:
      return 'one_time';
    case FollowUpType.repeating:
      return 'repeating';
  }
}

enum FollowUpIntervalUnit {
  days,
  weeks,
  months,
  years,
}

FollowUpIntervalUnit? followUpIntervalUnitFromString(String? value) {
  switch (value) {
    case 'days':
      return FollowUpIntervalUnit.days;
    case 'weeks':
      return FollowUpIntervalUnit.weeks;
    case 'months':
      return FollowUpIntervalUnit.months;
    case 'years':
      return FollowUpIntervalUnit.years;
    default:
      return null;
  }
}

String followUpIntervalUnitToString(FollowUpIntervalUnit value) => value.name;

String followUpIntervalUnitLabel(
  FollowUpIntervalUnit value, {
  int amount = 2,
}) {
  final plural = amount != 1;

  switch (value) {
    case FollowUpIntervalUnit.days:
      return plural ? 'days' : 'day';
    case FollowUpIntervalUnit.weeks:
      return plural ? 'weeks' : 'week';
    case FollowUpIntervalUnit.months:
      return plural ? 'months' : 'month';
    case FollowUpIntervalUnit.years:
      return plural ? 'years' : 'year';
  }
}

// =============================================================================
// FOLLOW-UP SCHEDULE INPUT
// =============================================================================

/// Form-side schedule attached to one treatment series.
///
/// This is only a reminder schedule. Every actual follow-up administration is
/// still recorded as a real treatment occurrence with inventory usage.
class FollowUpScheduleInput {
  final FollowUpType type;
  final DateTime nextFollowUpDate;
  final int? intervalValue;
  final FollowUpIntervalUnit? intervalUnit;
  final DateTime? endDate;
  final String? note;

  const FollowUpScheduleInput({
    required this.type,
    required this.nextFollowUpDate,
    this.intervalValue,
    this.intervalUnit,
    this.endDate,
    this.note,
  });
}

// =============================================================================
// TREATMENT RECORD
// =============================================================================

/// One treatment/series under an animal's medical history.
///
/// Example: "Anti-rabies" remains one [TreatmentRecord] even when it is
/// administered again next year. Each actual administration is represented by
/// a [TreatmentOccurrence].
class TreatmentRecord {
  final String treatId;
  final String petId;
  final String petName;
  final PetSpecies petSpecies;
  final String? petBreed;

  /// Latest administration's performer. Kept for compact list cards.
  final String performedByName;

  final String recordedByUserId;
  final String recordedByName;
  final String treatName;
  final String? notes;

  /// Latest administration date. Existing UI uses this as the treatment's
  /// activity date and sorts the animal's treatment list by it.
  final DateTime recDate;

  final DateTime loggedDate;
  final int administrationCount;

  final bool followUpRequired;
  final FollowUpType? followUpType;
  final DateTime? nextFollowUpDate;
  final int? followUpIntervalValue;
  final FollowUpIntervalUnit? followUpIntervalUnit;
  final DateTime? followUpEndDate;
  final String? followUpNote;
  final bool followUpActive;
  final DateTime? followUpStoppedAt;
  final String? followUpStopReason;

  const TreatmentRecord({
    required this.treatId,
    required this.petId,
    required this.petName,
    required this.petSpecies,
    this.petBreed,
    required this.performedByName,
    required this.recordedByUserId,
    required this.recordedByName,
    required this.treatName,
    this.notes,
    required this.recDate,
    required this.loggedDate,
    this.administrationCount = 1,
    this.followUpRequired = false,
    this.followUpType,
    this.nextFollowUpDate,
    this.followUpIntervalValue,
    this.followUpIntervalUnit,
    this.followUpEndDate,
    this.followUpNote,
    this.followUpActive = false,
    this.followUpStoppedAt,
    this.followUpStopReason,
  });

  bool get hasActiveFollowUp =>
      followUpRequired && followUpActive && nextFollowUpDate != null;
}

// =============================================================================
// TREATMENT OCCURRENCE
// =============================================================================

/// One actual administration inside a treatment series.
///
/// Multiple inventory items used at the same administration share the same
/// occurrence ID, so the medical history can display the correct date, Staff,
/// notes, and items together.
class TreatmentOccurrence {
  final String occurrenceId;
  final String treatId;
  final DateTime administeredDate;
  final String administeredBy;
  final String recordedByUserId;
  final String recordedByName;
  final DateTime recordedDate;
  final String? notes;
  final bool isFollowUp;
  final DateTime? scheduledDate;

  const TreatmentOccurrence({
    required this.occurrenceId,
    required this.treatId,
    required this.administeredDate,
    required this.administeredBy,
    required this.recordedByUserId,
    required this.recordedByName,
    required this.recordedDate,
    this.notes,
    required this.isFollowUp,
    this.scheduledDate,
  });
}

// =============================================================================
// TREATMENT ITEM USED
// =============================================================================

/// One inventory item consumed during one treatment occurrence.
class TreatmentItemUsed {
  final String itemId;
  final String itemName;
  final double dispensedQty;
  final String dispenseUnitAbbr;
  final DateTime consumedDate;
  final String givenBy;
  final String recordedByName;
  final DateTime recordedDate;
  final String? occurrenceId;

  const TreatmentItemUsed({
    required this.itemId,
    required this.itemName,
    required this.dispensedQty,
    required this.dispenseUnitAbbr,
    required this.consumedDate,
    required this.givenBy,
    required this.recordedByName,
    required this.recordedDate,
    this.occurrenceId,
  });
}

// =============================================================================
// FORM ITEM INPUT
// =============================================================================

/// Form-side input for one row in the "items used" list before it is written
/// to treatment_item.
class TreatmentItemInput {
  final String itemId;
  final String itemName;
  final String doseUnitId;
  final String doseUnitAbbr;
  final bool deductible;
  final double stockQty;
  final double? packageQuantity;
  final double? packageStockQty;
  double qty;

  TreatmentItemInput({
    required this.itemId,
    required this.itemName,
    required this.doseUnitId,
    required this.doseUnitAbbr,
    required this.deductible,
    required this.stockQty,
    this.packageQuantity,
    this.packageStockQty,
    this.qty = 1,
  });
}
