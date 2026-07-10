import 'pet.dart';

/// Mirrors a row in the public.treatment table, joined with the pet it
/// was performed on. `treatment` itself has no user/date columns -- the
/// "who / when" for display is read off the first public.treatment_item
/// row instead, since every item row logged in one Add Treatment submission
/// shares the same givenby/givenon (the form only collects one such pair
/// per treatment).
class TreatmentRecord {
  final String treatId;
  final String petId;
  final String petName;
  final PetSpecies petSpecies;
  final String? petBreed;
  final String performedByName;
  final String treatName;
  final String? notes;
  final DateTime recDate;

  const TreatmentRecord({
    required this.treatId,
    required this.petId,
    required this.petName,
    required this.petSpecies,
    this.petBreed,
    required this.performedByName,
    required this.treatName,
    this.notes,
    required this.recDate,
  });

  factory TreatmentRecord.fromMap(Map<String, dynamic> map) {
    final pet = map['pet'] as Map<String, dynamic>? ?? const {};
    final items = map['treatment_item'] as List? ?? const [];
    final firstItem =
        items.isNotEmpty ? items.first as Map<String, dynamic> : const {};

    return TreatmentRecord(
      treatId: map['treatid'] as String,
      petId: map['petid'] as String,
      petName: pet['petname'] as String? ?? 'Unknown animal',
      petSpecies: petSpeciesFromString(pet['species'] as String? ?? 'dog'),
      petBreed: pet['breed'] as String?,
      performedByName: firstItem['givenby'] as String? ?? '',
      treatName: map['name'] as String? ?? '',
      notes: map['notes'] as String?,
      recDate: DateTime.tryParse(firstItem['givenon'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// A single item consumed during a treatment (joined public.treatment_item
/// with public.item for its name/unit).
class TreatmentItemUsed {
  final String itemId;
  final String itemName;
  final String itemUom;
  final double qtyUsed;
  final String usedUom;

  const TreatmentItemUsed({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.qtyUsed,
    required this.usedUom,
  });

  factory TreatmentItemUsed.fromMap(Map<String, dynamic> map) {
    final item = map['item'] as Map<String, dynamic>? ?? const {};
    return TreatmentItemUsed(
      itemId: item['itemid'] as String? ?? '',
      itemName: item['name'] as String? ?? 'Unknown item',
      itemUom: item['uom'] as String? ?? '',
      qtyUsed: (map['qtyused'] as num?)?.toDouble() ?? 0,
      usedUom: map['uom'] as String? ?? '',
    );
  }
}

/// Form-side input for one row in the "items used" list while logging a
/// treatment, before it's written to treatment_item.
///
/// [unit] starts out equal to [itemUom] and can be changed via a
/// dropdown in the form, and is persisted to treatment_item.uom as-is.
/// If [unit] no longer matches [itemUom] there's no safe way to convert
/// between units -- the form disables [deduct] in that case so stock
/// isn't touched, while the usage itself is still logged.
class TreatmentItemInput {
  final String itemId;
  final String itemName;
  final String itemUom;
  final double stockQty;
  double qty;
  String unit;
  bool deduct;

  TreatmentItemInput({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.stockQty,
    this.qty = 1,
    String? unit,
    this.deduct = true,
  }) : unit = unit ?? itemUom;
}
