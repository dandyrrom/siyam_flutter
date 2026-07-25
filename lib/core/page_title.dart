// Sets the browser tab title (a no-op on platforms with no browser tab).
export 'page_title_stub.dart' if (dart.library.js_interop) 'page_title_web.dart';
