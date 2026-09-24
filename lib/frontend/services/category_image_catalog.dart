import 'pexels_service.dart';

/// Common, data-driven image resolution for the category catalogue screens.
///
/// Resolves the representative image for a category banner or a sub-category
/// tile from a single, cached source of truth — [PexelsService]'s seeded
/// catalogue of real, verified Pexels photos — and falls back to the
/// bundled asset shipped in the app when no seeded photo applies. This keeps
/// every category/sub-category visually distinct (no more repeated "blank"
/// tiles) while staying offline-safe and never showing a broken image.
class CategoryImageCatalog {
  CategoryImageCatalog._();

  static final PexelsService _pexels = PexelsService.instance;

  /// Primary image reference for a category banner: the seeded Pexels photo
  /// when one exists for [categoryName], otherwise [bundledPath].
  ///
  /// [bundledPath] is also the offline/error fallback to hand to
  /// [CatalogueImage.fallbackImage] so the banner always shows something real.
  static String categoryImage({
    required String categoryName,
    required String bundledPath,
  }) {
    return _pexels.seededImageFor(categoryName) ?? bundledPath;
  }

  /// The seeded Pexels photo for [categoryName], or null.
  static String? categorySeededImage(String categoryName) =>
      _pexels.seededImageFor(categoryName);

  /// Primary image reference for a sub-category tile, resolved in priority
  /// order: the sub-category's own seeded photo, then the category's seeded
  /// photo, then [bundledPath] (the sub-category/category asset).
  static String subcategoryImage({
    required String categoryName,
    required String subcategoryName,
    required String bundledPath,
  }) {
    return _pexels.seededImageFor(categoryName, subcategory: subcategoryName) ??
        _pexels.seededImageFor(categoryName) ??
        bundledPath;
  }
}