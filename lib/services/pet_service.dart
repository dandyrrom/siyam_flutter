import '../mock/mock_database.dart';
import '../models/pet.dart';

/// In-memory equivalent of the old public.pet access layer.
class PetService {
  final MockDatabase _db = MockDatabase.instance;

  Future<List<Pet>> fetchPets() async {
    final list = List<Pet>.from(_db.pets);
    list.sort((a, b) => a.petName.compareTo(b.petName));
    return list;
  }

  Future<Pet> createPet({
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    String? breed,
    bool spayedNeutered = false,
  }) async {
    final pet = Pet(
      petId: newMockId('pet'),
      petName: petName,
      species: species,
      breed: breed,
      gender: gender,
      spayedNeutered: spayedNeutered,
      status: PetStatus.available,
    );
    _db.pets.add(pet);
    return pet;
  }

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
      gender: current.gender,
      spayedNeutered: current.spayedNeutered,
      status: status,
    );
    _db.pets[index] = updated;
    return updated;
  }

  Future<void> deletePet(String petId) async {
    _db.pets.removeWhere((p) => p.petId == petId);
  }
}
