import 'package:flutter/material.dart';

import '../../frontend/constants/asset_paths.dart';
import '../services/catalogue_image_registry.dart';

/// A form field for a product/design image.
///
/// Supports the project's existing image approach: bundled asset paths
/// (`assets/images/...`, rendered with [Image.asset]) and http(s) URLs
/// (rendered with [Image.network]). A live preview updates as the admin types,
/// and quick-pick chips offer valid existing assets for the chosen category so
/// admins never need to fabricate a path.
class CatalogueImageField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String category;
  final String hintText;

  const CatalogueImageField({
    super.key,
    required this.controller,
    required this.category,
    this.validator,
    this.hintText = 'assets/images/… or https://…',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Preview(controller: controller),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            labelText: 'Image path / URL',
            hintText: hintText,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        _SuggestionChips(controller: controller, category: category),
      ],
    );
  }
}

/// Live image preview that falls back gracefully when the path is invalid.
class _Preview extends StatelessWidget {
  final TextEditingController controller;
  const _Preview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: _image(controller.text),
      ),
    );
  }

  Widget _image(String path) {
    final v = path.trim();
    if (v.isEmpty) {
      return const _Placeholder(icon: Icons.add_photo_alternate_outlined);
    }
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return Image.network(
        v,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _Placeholder(
          icon: Icons.broken_image_outlined,
        ),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()),
      );
    }
    return Image.asset(
      v,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _Placeholder(
        icon: Icons.broken_image_outlined,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  const _Placeholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(icon, size: 42, color: Colors.grey.shade500),
    );
  }
}

/// Quick-pick chips of valid existing assets for the chosen category.
class _SuggestionChips extends StatelessWidget {
  final TextEditingController controller;
  final String category;
  const _SuggestionChips({required this.controller, required this.category});

  @override
  Widget build(BuildContext context) {
    final fromRegistry =
        CatalogueImageRegistry.instance.suggestionPathsFor(category);
    final options = fromRegistry.isNotEmpty
        ? fromRegistry
        : _legacyOptionsFor(category);
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing images (tap to use)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final path in options)
              ActionChip(
                label: const Text('Use'),
                avatar: _thumb(path),
                visualDensity: VisualDensity.compact,
                onPressed: () => controller.text = path,
              ),
          ],
        ),
      ],
    );
  }

  Widget _thumb(String path) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          path,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 22,
            height: 22,
            color: Colors.grey.shade300,
          ),
        ),
      );

  /// Fallback quick-pick paths for a category when the image registry (which
  /// is seeded from the live catalogue) is unexpectedly empty — e.g. a brand
  /// new category with no products yet. Guaranteed to render.
  static List<String> _legacyOptionsFor(String category) {
    final cat = category.trim().isEmpty ? '' : category;
    return <String, List<String>>{
      'Sarees': [
        AssetPaths.sareeProd,
        AssetPaths.plainSilkSaree,
        AssetPaths.plainGeorgetteSaree,
        AssetPaths.plainCottonSaree,
      ],
      'Saree Borders': [
        AssetPaths.borderProd,
        AssetPaths.plainZariBorder,
        AssetPaths.plainContrastBorder,
        AssetPaths.plainMirrorBorder,
      ],
      'T-Shirts': [
        AssetPaths.tshirtProd,
        AssetPaths.plainCottonTshirt,
        AssetPaths.plainOversizedTshirt,
        AssetPaths.plainPoloTshirt,
      ],
      'Mugs': [
        AssetPaths.mugProd,
        AssetPaths.plainCeramicMug,
        AssetPaths.plainMagicMug,
        AssetPaths.plainTravelMug,
      ],
      'Posters': [
        AssetPaths.posterProd,
        AssetPaths.blankPoster,
        AssetPaths.blankCanvasPoster,
      ],
      'Embroidery': [
        AssetPaths.embroideryProd,
        AssetPaths.plainFabricBase,
        AssetPaths.plainFabricBase2,
      ],
      'Cardboard': [
        AssetPaths.cardboardProd,
        AssetPaths.blankCardboardBoard,
        AssetPaths.blankCardboardStandee,
      ],
      'Glass Art': [
        AssetPaths.glassProd,
        AssetPaths.plainGlassPanel,
        AssetPaths.plainGlassFrame,
      ],
      'Dress Materials': [
        AssetPaths.dressProd,
        AssetPaths.dress1,
        AssetPaths.dress2,
        AssetPaths.dress3,
      ],
    }[cat] ??
        [];
  }
}
