/// No-op fallback for native platforms.
///
/// The App Check provider-selection keys only exist in web storage (see the
/// web implementation). Nothing needs clearing on iOS/Android/etc.
void clearAppCheckProviderSelectionOnWeb() {}