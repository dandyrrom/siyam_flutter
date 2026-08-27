import '../mock/mock_database.dart';
import '../models/pet.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'supabase/supabase_pet_service.dart';

// ============================================================================
// PET SERVICE
// ============================================================================
//
// Factory resolves to mock or Supabase based on [kUseMock].
// ============================================================================

abstract interface class PetService {
  factory PetService() =>
      kUseMock ? MockPetService() : SupabasePetService();

  Future<List<Pet>> fetchPets();

  Future<Pet> createPet({
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    String? breed,
    String? owner,
    bool spayedNeutered,
    PetStatus status,
  });

  Future<Pet> updateStatus({
    required String petId,
    required PetStatus status,
  });

  Future<Pet> updatePet({
    required String petId,
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    required PetStatus status,
    String? breed,
    String? owner,
    bool spayedNeutered,
  });

  Future<void> deletePet(String petId);
}

/// In-memory equivalent of public.pet, backed by [MockDatabase.pets].
class MockPetService implements PetService {
  final MockDatabase _db = MockDatabase.instance;

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

  void _ensureNoDuplicate({
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    required bool spayedNeutered,
    String? breed,
    String? owner,
    String? excludePetId,
  }) {
    final nameKey = _key(petName);
    final breedKey = _key(breed);
    final ownerKey = _key(owner);

    for (final pet in _db.pets) {
      if (pet.petId == excludePetId) continue;

      final sameName = _key(pet.petName) == nameKey;
      final sameSpecies = pet.species == species;
      final sameGender = pet.gender == gender;
      final sameBreed = _key(pet.breed) == breedKey;
      final sameOwner = _key(pet.owner) == ownerKey;
      final sameSpayStatus = pet.spayedNeutered == spayedNeutered;

      final exactIdentity = sameName &&
          sameSpecies &&
          sameGender &&
          sameBreed &&
          sameOwner &&
          sameSpayStatus;

      final sameOwnedAnimal =
          ownerKey.isNotEmpty && sameName && sameSpecies && sameOwner;

      if (exactIdentity || sameOwnedAnimal) {
        throw Exception(
          'This animal already has a record with the same identifying details or owner.',
        );
      }
    }
  }

  @override
  Future<List<Pet>> fetchPets() async {
    final list = List<Pet>.from(_db.pets);
    list.sort(
      (a, b) => a.petName.toLowerCase().compareTo(b.petName.toLowerCase()),
    );
    return list;
  }

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

    _ensureNoDuplicate(
      petName: cleanName,
      species: species,
      gender: gender,
      breed: cleanBreed,
      owner: cleanOwner,
      spayedNeutered: spayedNeutered,
    );

    final pet = Pet(
      petId: newMockId('pet'),
      petName: cleanName,
      species: species,
      breed: cleanBreed,
      owner: cleanOwner,
      gender: gender,
      spayedNeutered: spayedNeutered,
      status: status,
    );
    _db.pets.add(pet);
    DataChangeBus.instance.ping();
    return pet;
  }

  @override
  Future<Pet> updateStatus({
    required String petId,
    required PetStatus status,
  }) async {
    final index = _db.pets.indexWhere((p) => p.petId == petId);
    if (index == -1) throw Exception('Pet not found');

    final current = _db.pets[index];
    final updated = Pet(
      petId: current.petId,
      petName: current.petName,
      species: current.species,
      breed: current.breed,
      owner: current.owner,
      gender: current.gender,
      spayedNeutered: current.spayedNeutered,
      status: status,
    );
    _db.pets[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

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
    final index = _db.pets.indexWhere((p) => p.petId == petId);
    if (index == -1) throw Exception('Pet not found');

    final cleanName = _cleanText(petName);
    final cleanBreed = _cleanOptional(breed);
    final cleanOwner = _cleanOptional(owner);

    _ensureNoDuplicate(
      petName: cleanName,
      species: species,
      gender: gender,
      breed: cleanBreed,
      owner: cleanOwner,
      spayedNeutered: spayedNeutered,
      excludePetId: petId,
    );

    final updated = Pet(
      petId: petId,
      petName: cleanName,
      species: species,
      breed: cleanBreed,
      owner: cleanOwner,
      gender: gender,
      spayedNeutered: spayedNeutered,
      status: status,
    );
    _db.pets[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

  @override
  Future<void> deletePet(String petId) async {
    _db.pets.removeWhere((p) => p.petId == petId);
    DataChangeBus.instance.ping();
  }
}
