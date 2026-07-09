import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet.dart';

/// Thin wrapper around the public.pet table.
///
/// Table reference (from your schema):
///   pet(petid uuid PK, petname, species pet_species, breed, gender
///       pet_gender, spayed_neutered bool, status pet_status)
///
/// Note: age, weight, image, medical conditions, admission date, and
/// last-checkup date are NOT part of the current schema, so this
/// service (and the Animal Records page) only touches columns that
/// actually exist.
class PetService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Pet>> fetchPets() async {
    final rows = await _client.from('pet').select().order('petname', ascending: true);
    return (rows as List)
        .map((r) => Pet.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Pet> createPet({
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    String? breed,
    bool spayedNeutered = false,
  }) async {
    final row = await _client
        .from('pet')
        .insert({
          'petname': petName,
          'species': petSpeciesToString(species),
          'gender': petGenderToString(gender),
          'breed': breed,
          'spayed_neutered': spayedNeutered,
        })
        .select()
        .single();
    return Pet.fromMap(row);
  }

  Future<Pet> updateStatus({
    required String petId,
    required PetStatus status,
  }) async {
    final row = await _client
        .from('pet')
        .update({'status': petStatusToString(status)})
        .eq('petid', petId)
        .select()
        .single();
    return Pet.fromMap(row);
  }

  Future<void> deletePet(String petId) async {
    await _client.from('pet').delete().eq('petid', petId);
  }
}
