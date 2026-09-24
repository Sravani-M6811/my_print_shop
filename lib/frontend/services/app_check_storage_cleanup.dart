// Exposes [clearAppCheckProviderSelectionOnWeb] only where it is meaningful.
// The web implementation clears FlutterFire's persisted App Check *provider
// selection* from browser storage; on native platforms the keys never exist,
// so the stub is a no-op. Using a conditional import keeps `package:web` out of
// the native build, because its DOM bindings can only be compiled for a
// JavaScript/Wasm backend.
export 'app_check_storage_cleanup_stub.dart'
    if (dart.library.js_interop) 'app_check_storage_cleanup_web.dart';