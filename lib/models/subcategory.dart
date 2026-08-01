/// Mirrors a row in public.subcategory.
class Subcategory {
  final String id;
  final String pCategoryId;
  final String type;

  /// Whether items under this subcategory require an expiry date at Stock
  /// In. Null means "inherit" -- fall back to the parent
  /// [PrimaryCategory.requiresExpiry]. Non-null overrides the parent for
  /// this subcategory specifically.
  final bool? requiresExpiry;

  const Subcategory({
    required this.id,
    required this.pCategoryId,
    required this.type,
    this.requiresExpiry,
  });
}
