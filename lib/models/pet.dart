/// Mirrors the Postgres `pet_species` enum: 'dog', 'cat'.
enum PetSpecies { dog, cat }

PetSpecies petSpeciesFromString(String value) {
  switch (value) {
    case 'cat':
      return PetSpecies.cat;
    case 'dog':
    default:
      return PetSpecies.dog;
  }
}

String petSpeciesToString(PetSpecies species) => species.name;

/// Mirrors the Postgres `pet_gender` enum: 'male', 'female'.
enum PetGender { male, female }

PetGender petGenderFromString(String value) {
  switch (value) {
    case 'female':
      return PetGender.female;
    case 'male':
    default:
      return PetGender.male;
  }
}

String petGenderToString(PetGender gender) => gender.name;

/// Mirrors the Postgres pet status values.
enum PetStatus { healthy, underTreatment, adopted, deceased }

PetStatus petStatusFromString(String value) {
  switch (value) {
    case 'under_treatment':
      return PetStatus.underTreatment;
    case 'adopted':
      return PetStatus.adopted;
    case 'deceased':
      return PetStatus.deceased;
    case 'healthy':
    default:
      return PetStatus.healthy;
  }
}

String petStatusToString(PetStatus status) {
  switch (status) {
    case PetStatus.healthy:
      return 'healthy';
    case PetStatus.underTreatment:
      return 'under_treatment';
    case PetStatus.adopted:
      return 'adopted';
    case PetStatus.deceased:
      return 'deceased';
  }
}

/// Mirrors one row in public.pet.
class Pet {
  final String petId;
  final String petName;
  final PetSpecies species;
  final String? breed;
  final String? owner;
  final PetGender gender;
  final bool spayedNeutered;
  final PetStatus status;

  const Pet({
    required this.petId,
    required this.petName,
    required this.species,
    this.breed,
    this.owner,
    required this.gender,
    required this.spayedNeutered,
    required this.status,
  });

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      petId: (map['id'] ?? map['petid']) as String,
      petName: (map['name'] ?? map['petname']) as String? ?? '',
      species: petSpeciesFromString(
        map['species'] as String? ?? 'dog',
      ),
      breed: map['breed'] as String?,
      owner: map['owner'] as String?,
      gender: petGenderFromString(
        map['gender'] as String? ?? 'male',
      ),
      spayedNeutered:
          map['spayed_neutered'] as bool? ?? false,
      status: petStatusFromString(
        map['status'] as String? ?? 'healthy',
      ),
    );
  }
}