import '../../../../utils/services/role_utils.dart';
import 'pet_care_progress.dart';

class PetCareIdentityMissingRole implements Exception {
  const PetCareIdentityMissingRole();
}

/// Giới tính quyết định bé của mình, không dùng selectedPet làm quyền chăm hộ.
PetCarePet? petCareOwnedPetForRole(String? role, {bool genderSwapped = false}) {
  final normalized = RoleUtils.normalizeNullable(role);
  if (normalized == null) return null;
  return RoleUtils.isFemaleRole(normalized, genderSwapped: genderSwapped)
      ? PetCarePet.rabbit
      : PetCarePet.bear;
}
