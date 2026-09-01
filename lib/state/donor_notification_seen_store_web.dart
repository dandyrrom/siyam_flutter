import 'package:web/web.dart' as web;

// Reads donor notification state from browser localStorage.
String? getItem(String key) {
  return web.window.localStorage.getItem(key);
}

// Saves donor notification state to browser localStorage.
void setItem(
  String key,
  String value,
) {
  web.window.localStorage.setItem(
    key,
    value,
  );
}
