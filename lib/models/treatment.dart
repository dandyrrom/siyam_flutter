import 'pet.dart';

/// Mirrors a row in the public.treatment table, joined with the pet it
/// was performed on and the staff/manager user who performed it.
class TreatmentRecord {
  final String treatId;
  final String petId;
  final String petName;
  final PetSpecies petSpecies;
  final String? petBreed;
  final String userId;
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
    required this.userId,
    required this.performedByName,
    required this.treatName,
    this.notes,
    required this.recDate,
  });

  factory TreatmentRecord.fromMap(Map<String, dynamic> map) {
    final pet = map['pet'] as Map<String, dynamic>? ?? const {};
    final user = map['users'] as Map<String, dynamic>? ?? const {};
    final fname = user['userfname'] as String? ?? '';
    final lname = user['userlname'] as String? ?? '';

    return TreatmentRecord(
      treatId: map['treatid'] as String,
      petId: map['petid'] as String,
      petName: pet['petname'] as String? ?? 'Unknown animal',
      petSpecies: petSpeciesFromString(pet['species'] as String? ?? 'dog'),
      petBreed: pet['breed'] as String?,
      userId: map['userid'] as String,
      performedByName: [fname, lname].where((s) => s.isNotEmpty).join(' '),
      treatName: map['treatname'] as String? ?? '',
      notes: map['notes'] as String?,
      recDate: DateTime.tryParse(map['recdate'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// A single item consumed during a treatment (joined public.treatment_item
/// with public.item for its name/unit).
class TreatmentItemUsed {
  final String itemId;
  final String itemName;
  final String itemUom;
  final int qtyUsed;

  const TreatmentItemUsed({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.qtyUsed,
  });

  factory TreatmentItemUsed.fromMap(Map<String, dynamic> map) {
    final item = map['item'] as Map<String, dynamic>? ?? const {};
    return TreatmentItemUsed(
      itemId: item['itemid'] as String? ?? '',
      itemName: item['itemname'] as String? ?? 'Unknown item',
      itemUom: item['item_uom'] as String? ?? '',
      qtyUsed: (map['qtyused'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Form-side input for one row in the "items used" list while logging a
/// treatment, before it's written to treatment_item.
class TreatmentItemInput {
  final String itemId;
  final String itemName;
  final String itemUom;
  final int stockQty;
  int qty;

  TreatmentItemInput({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.stockQty,
    this.qty = 1,
  });
}
