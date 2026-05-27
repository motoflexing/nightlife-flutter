import 'maps_availability_stub.dart'
    if (dart.library.js_interop) 'maps_availability_web.dart';

bool get isGoogleMapsWebSdkReady => googleMapsWebSdkReady();
