/// Compile-time backend selector.
///
/// Controls whether the service layer resolves to the in-memory mock
/// implementations or (once built) the Supabase implementations. Set at
/// build/run time, e.g.:
///
///   flutter run -d chrome --dart-define=USE_MOCK=false
///
/// Defaults to the mock backend so the app runs with no external
/// dependencies. Each service reads this flag in its factory constructor.
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
