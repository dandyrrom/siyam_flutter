import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pet.dart';
import '../../state/data_bus.dart';
import '../pet_service.dart';

// ============================================================================
// REAL SUPABASE PET SERVICE
// ============================================================================

class SupabasePetService implements PetService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _columns =
      'id, name, species, breed, owner, gender, spayed_neutered, status';

  // ==========================================================================
  // TEXT NORMALIZATION
  // ==========================================================================

  String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _cleanOptional(String? value) {
    if (value == null) return null;

    final cleaned = _cleanText(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  String _key(String? value) {
    return _cleanText(value ?? '').toLowerCase();
  }

  // ==========================================================================
  // DUPLICATE ANIMAL CHECK
  // ==========================================================================
  //
  // Same name alone is NOT considered a duplicate.
  //
  // We block:
  //
  // 1. Exact identifying details:
  //    name + species + gender + breed + owner + spayed/neutered
  //
  // 2. Strong ownership duplicate:
  //    same name + same species + same NON-EMPTY owner
  //
  // Status is deliberately excluded because the same animal's status changes.
  // ==========================================================================

  Future<void> _ensureNoDuplicate({
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    required bool spayedNeutered,
    String? breed,
    String? owner,
    String? excludePetId,
  }) async {
    final rows = await _client.from('pet').select(
      'id, name, species, breed, owner, gender, spayed_neutered',
    );

    final nameKey = _key(petName);
    final breedKey = _key(breed);
    final ownerKey = _key(owner);

    for (final row in rows) {
      final id = row['id'] as String;

      if (id == excludePetId) continue;

      final sameName =
          _key(row['name'] as String?) == nameKey;

      final sameSpecies =
          (row['species'] as String?) ==
              petSpeciesToString(species);

      final sameGender =
          (row['gender'] as String?) ==
              petGenderToString(gender);

      final sameBreed =
          _key(row['breed'] as String?) == breedKey;

      final sameOwner =
          _key(row['owner'] as String?) == ownerKey;

      final sameSpayStatus =
          (row['spayed_neutered'] as bool? ?? false) ==
              spayedNeutered;

      final exactIdentity =
          sameName &&
          sameSpecies &&
          sameGender &&
          sameBreed &&
          sameOwner &&
          sameSpayStatus;

      final sameOwnedAnimal =
          ownerKey.isNotEmpty &&
          sameName &&
          sameSpecies &&
          sameOwner;

      if (exactIdentity || sameOwnedAnimal) {
        throw Exception(
          'This animal already has a record with the same identifying details or owner.',
        );
      }
    }
  }

  // ==========================================================================
  // MAP PET
  // ==========================================================================

  Pet _mapPet(Map<String, dynamic> row) {
    return Pet(
      petId: row['id'] as String,
      petName: (row['name'] as String?) ?? '',
      species: petSpeciesFromString(
        row['species'] as String? ?? 'dog',
      ),
      breed: row['breed'] as String?,
      owner: row['owner'] as String?,
      gender: petGenderFromString(
        row['gender'] as String? ?? 'male',
      ),
      spayedNeutered:
          row['spayed_neutered'] as bool? ?? false,
      status: petStatusFromString(
        row['status'] as String? ?? 'healthy',
      ),
    );
  }

  // ==========================================================================
  // FETCH
  // ==========================================================================

  @override
  Future<List<Pet>> fetchPets() async {
    final rows = await _client
        .from('pet')
        .select(_columns)
        .order('name');

    return rows.map((row) => _mapPet(row)).toList();
  }

  // ==========================================================================
  // CREATE
  // ==========================================================================

  @override
  Future<Pet> createPet({
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    String? breed,
    String? owner,
    bool spayedNeutered = false,
    PetStatus status = PetStatus.healthy,
  }) async {
    final cleanName = _cleanText(petName);
    final cleanBreed = _cleanOptional(breed);
    final cleanOwner = _cleanOptional(owner);

    await _ensureNoDuplicate(
      petName: cleanName,
      species: species,
      gender: gender,
      breed: cleanBreed,
      owner: cleanOwner,
      spayedNeutered: spayedNeutered,
    );

    final row = await _client
        .from('pet')
        .insert({
          'name': cleanName,
          'species': petSpeciesToString(species),
          'breed': cleanBreed,
          'owner': cleanOwner,
          'gender': petGenderToString(gender),
          'spayed_neutered': spayedNeutered,
          'status': petStatusToString(status),
        })
        .select(_columns)
        .single();

    DataChangeBus.instance.ping();

    return _mapPet(row);
  }

  // ==========================================================================
  // UPDATE STATUS
  // ==========================================================================

  @override
  Future<Pet> updateStatus({
    required String petId,
    required PetStatus status,
  }) async {
    final row = await _client
        .from('pet')
        .update({
          'status': petStatusToString(status),
        })
        .eq('id', petId)
        .select(_columns)
        .single();

    DataChangeBus.instance.ping();

    return _mapPet(row);
  }

  // ==========================================================================
  // UPDATE PET
  // ==========================================================================

  @override
  Future<Pet> updatePet({
    required String petId,
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    required PetStatus status,
    String? breed,
    String? owner,
    bool spayedNeutered = false,
  }) async {
    final cleanName = _cleanText(petName);
    final cleanBreed = _cleanOptional(breed);
    final cleanOwner = _cleanOptional(owner);

    await _ensureNoDuplicate(
      petName: cleanName,
      species: species,
      gender: gender,
      breed: cleanBreed,
      owner: cleanOwner,
      spayedNeutered: spayedNeutered,
      excludePetId: petId,
    );

    final row = await _client
        .from('pet')
        .update({
          'name': cleanName,
          'species': petSpeciesToString(species),
          'breed': cleanBreed,
          'owner': cleanOwner,
          'gender': petGenderToString(gender),
          'spayed_neutered': spayedNeutered,
          'status': petStatusToString(status),
        })
        .eq('id', petId)
        .select(_columns)
        .single();

    DataChangeBus.instance.ping();

    return _mapPet(row);
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  @override
  Future<void> deletePet(String petId) async {
    await _client.from('pet').delete().eq('id', petId);

    DataChangeBus.instance.ping();
  }
}
