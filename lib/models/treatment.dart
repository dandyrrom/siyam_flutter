import 'pet.dart';

/// Mirrors a row in public.treatment, joined with the pet it was performed
/// on. [recordedByUserId]/[recordedByName]/[loggedDate] come straight off
/// `treatment` itself (who/when it was entered into the system);
/// [performedByName]/[recDate] are the free text `givenby`/`consumeddate` off
/// the first `treatment_item` row (who actually administered it and when --
/// may differ from when it was logged; every item row in one Add Treatment
/// submission shares the same value, since the form only collects one such
/// pair per treatment).
class TreatmentRecord {
  final String treatId;
  final String petId;
  final String petName;
  final PetSpecies petSpecies;
  final String? petBreed;
  final String performedByName;
  final String recordedByUserId;
  final String recordedByName;
  final String treatName;
  final String? notes;
  final DateTime recDate;
  final DateTime loggedDate;

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
  });
}

/// A single item consumed during a treatment -- the full set of
/// TREATMENT_ITEM columns (joined with item for its name).
class TreatmentItemUsed {
  final String itemId;
  final String itemName;
  final double dispensedQty;
  final String dispenseUnitAbbr;
  final DateTime consumedDate;
  final String givenBy;
  final String recordedByName;
  final DateTime recordedDate;

  const TreatmentItemUsed({
    required this.itemId,
    required this.itemName,
    required this.dispensedQty,
    required this.dispenseUnitAbbr,
    required this.consumedDate,
    required this.givenBy,
    required this.recordedByName,
    required this.recordedDate,
  });
}

/// Form-side input for one row in the "items used" list while logging a
/// treatment, before it's written to treatment_item.
///
/// The dose unit is NOT chosen per-transaction -- it's fixed to the item's
/// own configuration ([doseUnitId]/[doseUnitAbbr], resolved as
/// dispense_unit, falling back to package_unit then purchase_unit).
/// [deductible] mirrors [InventoryItem.stockOutIsDeductible] at the time the
/// row was added: when false, the usage is still logged on treatment_item,
/// but stock isn't touched, since there's no known conversion between the
/// item's package_unit and dispense_unit.
class TreatmentItemInput {
  final String itemId;
  final String itemName;
  final String doseUnitId;
  final String doseUnitAbbr;
  final bool deductible;
  final double stockQty; // current purchase_stocks, for validation
  final double? packageQuantity; // for converting dose -> purchase_units
  double qty;

  TreatmentItemInput({
    required this.itemId,
    required this.itemName,
    required this.doseUnitId,
    required this.doseUnitAbbr,
    required this.deductible,
    required this.stockQty,
    this.packageQuantity,
    this.qty = 1,
  });
}
