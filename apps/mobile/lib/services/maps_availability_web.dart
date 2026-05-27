import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool googleMapsWebSdkReady() {
  final google = globalContext.getProperty<JSAny?>('google'.toJS);
  if (google == null) return false;

  final maps = (google as JSObject).getProperty<JSAny?>('maps'.toJS);
  return maps != null;
}
