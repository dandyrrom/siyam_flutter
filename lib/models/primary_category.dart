/// Mirrors a row in public.primary_category.
class PrimaryCategory {
  final String id;
  final String type;

  /// Whether items directly under this primary category require an expiry
  /// date at Stock In. A subcategory's own [Subcategory.requiresExpiry], if
  /// set, overrides this for items under that subcategory.
  final bool requiresExpiry;

  const PrimaryCategory({
    required this.id,
    required this.type,
    required this.requiresExpiry,
  });
}
