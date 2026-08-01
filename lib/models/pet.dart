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

/// Mirrors the Postgres `pet_status` enum: 'available', 'adopted',
/// 'under_treatment'.
enum PetStatus { available, adopted, underTreatment }

PetStatus petStatusFromString(String value) {
  switch (value) {
    case 'adopted':
      return PetStatus.adopted;
    case 'under_treatment':
      return PetStatus.underTreatment;
    case 'available':
    default:
      return PetStatus.available;
  }
}

String petStatusToString(PetStatus status) {
  switch (status) {
    case PetStatus.available:
      return 'available';
    case PetStatus.adopted:
      return 'adopted';
    case PetStatus.underTreatment:
      return 'under_treatment';
  }
}

/// Mirrors a row in the public.pet table.
class Pet {
  final String petId;
  final String petName;
  final PetSpecies species;
  final String? breed;
  final PetGender gender;
  final bool spayedNeutered;
  final PetStatus status;

  const Pet({
    required this.petId,
    required this.petName,
    required this.species,
    this.breed,
    required this.gender,
    required this.spayedNeutered,
    required this.status,
  });

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      petId: map['petid'] as String,
      petName: map['petname'] as String? ?? '',
      species: petSpeciesFromString(map['species'] as String? ?? 'dog'),
      breed: map['breed'] as String?,
      gender: petGenderFromString(map['gender'] as String? ?? 'male'),
      spayedNeutered: map['spayed_neutered'] as bool? ?? false,
      status: petStatusFromString(map['status'] as String? ?? 'available'),
    );
  }
}
