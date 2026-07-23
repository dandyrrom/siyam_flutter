/// Mirrors a row in public.units.
class Unit {
  final String id;
  /// Full unit name (e.g. "Bottle", "Tablet") -- shown in unit picker
  /// dropdowns/options.
  final String name;
  /// Short form (e.g. "bot", "tab") -- used for compact inline display
  /// (stock quantities, table cells).
  final String abbrName;

  const Unit({required this.id, required this.name, required this.abbrName});
}
