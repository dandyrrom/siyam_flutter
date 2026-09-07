// =============================================================================
// DONOR NOTIFICATION SEEN STORE
// =============================================================================
//
// This file selects the correct implementation depending on the platform.
//
// Web:
//   Uses browser localStorage through package:web.
//
// Android / iOS:
//   Uses the native implementation and does NOT compile package:web.
//
// Existing files in SIYAM should continue importing this file normally.
// =============================================================================

export 'donor_notification_seen_store_native.dart'
    if (dart.library.js_interop) 'donor_notification_seen_store_web.dart';
