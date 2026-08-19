import '../models/pet.dart';
import 'supabase/supabase_pet_service.dart';

// ============================================================================
// PET SERVICE
// ============================================================================
//
// SIYAM uses the real Supabase database.
// ============================================================================

abstract interface class PetService {
  factory PetService() => SupabasePetService();

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