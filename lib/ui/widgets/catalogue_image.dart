import 'package:flutter/material.dart';

/// Renders a catalogue image whose source can be either a bundled asset (the
/// vast majority of the shipped catalogue) or a network URL (as admins can set
/// from the product/design forms). Never crashes: any load failure or missing
/// source falls back to a neutral grey placeholder, mirroring the previous
/// per-widget [Image] `errorBuilder` behaviour.
class CatalogueImage extends StatelessWidget {
  const CatalogueImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackImage,
  });

  /// Bundled asset path or `http(s)://` URL.
  final String imagePath;

  /// Optional bundled asset used when [imagePath] is a network URL that fails
  /// to load (e.g. offline). Lets callers keep the rich network image and only
  /// degrade to the bundled photo — never straight to the grey placeholder.
  /// Ignored for asset [imagePath]s.
  final String? fallbackImage;

  final double? width;
  final double? height;
  final BoxFit fit;

  bool get _isNetwork =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');

  Widget _placeholder(ColorScheme scheme) => Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported,
          color: scheme.outline, size: 40),
    );

  Widget _loading(ColorScheme scheme) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isNetwork) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _loading(scheme),
        errorBuilder: (_, _, _) {
          final fallback = fallbackImage;
          if (fallback != null && fallback.isNotEmpty) {
            return CatalogueImage(
              imagePath: fallback,
              width: width,
              height: height,
              fit: fit,
            );
          }
          return _placeholder(scheme);
        },
      );
    }
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(scheme),
    );
  }
}