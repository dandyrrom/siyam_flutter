import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pet.dart';
import '../../state/data_bus.dart';
import '../pet_service.dart';

/// Supabase-backed access for public.pet.
class SupabasePetService implements PetService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _columns =
      'id, name, species, breed, gender, spayed_neutered, status';

  Pet _mapPet(Map<String, dynamic> r) => Pet(
        petId: r['id'] as String,
        petName: (r['name'] as String?) ?? '',
        species: petSpeciesFromString((r['species'] as String?) ?? 'dog'),
        breed: r['breed'] as String?,
        gender: petGenderFromString((r['gender'] as String?) ?? 'male'),
        spayedNeutered: (r['spayed_neutered'] as bool?) ?? false,
        status: petStatusFromString((r['status'] as String?) ?? 'available'),
      );

  @override
  Future<List<Pet>> fetchPets() async {
    final rows = await _client.from('pet').select(_columns).order('name');
    return rows.map((r) => _mapPet(r)).toList();
  }

  @override
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
          'name': petName,
          'species': petSpeciesToString(species),
          'breed': breed,
          'gender': petGenderToString(gender),
          'spayed_neutered': spayedNeutered,
          'status': petStatusToString(PetStatus.available),
        })
        .select(_columns)
        .single();
    DataChangeBus.instance.ping();
    return _mapPet(row);
  }

  @override
  Future<Pet> updateStatus({
    required String petId,
    required PetStatus status,
  }) async {
    final row = await _client
        .from('pet')
        .update({'status': petStatusToString(status)})
        .eq('id', petId)
        .select(_columns)
        .single();
    DataChangeBus.instance.ping();
    return _mapPet(row);
  }

  @override
  Future<void> deletePet(String petId) async {
    await _client.from('pet').delete().eq('id', petId);
    DataChangeBus.instance.ping();
  }
}
