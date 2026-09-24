import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A single photo result from the Pexels search API.
@immutable
class PexelsImage {
  final String id;
  final String url;
  final String alt;
  final String photographer;

  const PexelsImage({
    required this.id,
    required this.url,
    required this.alt,
    required this.photographer,
  });
}

/// Thin, category-aware client for the Pexels search API backing the Design
/// screen's search with real (network) images.
///
/// The API key is injected at build time via
/// `flutter run --dart-define=PEXELS_API_KEY=...` and is never hard-coded or
/// shipped inside the source tree. When no key is configured the service is
/// gracefully "not configured" and screens simply omit the Pexels section.
class PexelsService {
  static const String configuredApiKey =
      String.fromEnvironment('PEXELS_API_KEY');

  static final PexelsService instance = PexelsService();

  /// Test seam: when set, requests go through this client instead of a real
  /// HTTP client, and the service counts as configured without a key.
  @visibleForTesting
  http.Client? httpClientOverride;

  @visibleForTesting
  String? apiKeyOverride;

  bool get isConfigured =>
      configuredApiKey.isNotEmpty || httpClientOverride != null;

  static const Map<String, String> _categoryTerms = {
    'Sarees': 'saree',
    'Saree Borders': 'saree border',
    'T-Shirts': 't-shirt',
    'Mugs': 'mug',
    'Posters': 'poster',
    'Embroidery': 'embroidery',
    'Cardboard': 'cardboard',
    'Glass Art': 'glass art',
    'Dress Materials': 'dress material',
  };

  /// Canonical Pexels CDN photo URL for the given photo id (public CDN, no key
  /// required to *hotlink* a photo the shop seeded; the API key is only needed
  /// for live search).
  static String _photoUrl(int id) =>
      'https://images.pexels.com/photos/$id/pexels-photo-$id.jpeg'
      '?auto=compress&cs=tinysrgb&w=900';

  /// Seeded representative images for each category. These are real, verified
  /// Pexels photos (public CDN links — not API keys) chosen to match every
  /// store category, so category banners and sub-category tiles always have a
  /// relevant, non-placeholder image even before any live search runs.
  static final Map<String, String> _seededCategoryUrls = {
    'Sarees': _photoUrl(5447529),
    'Saree Borders': _photoUrl(6167463),
    'T-Shirts': _photoUrl(4440566),
    'Mugs': _photoUrl(9261414),
    'Posters': _photoUrl(7247514),
    'Embroidery': _photoUrl(35617659),
    'Cardboard': _photoUrl(4592995),
    'Glass Art': _photoUrl(31197303),
    'Dress Materials': _photoUrl(7171902),
  };

  /// Seeded representative images per named sub-category, keyed
  /// `'<Category>|<Sub-category>'` so every tile gets its own relevant photo
  /// (e.g. Sarees -> Silk Plain shows silk fabric, not the generic saree shot).
  static final Map<String, String> _seededSubcategoryUrls = {
    'Sarees|Silk Plain': _photoUrl(7956629),
    'Sarees|Cotton': _photoUrl(32459983),
    'Sarees|Crepe Silk': _photoUrl(4814062),
    'Sarees|Pattu': _photoUrl(10317113),
    'Sarees|Other': _photoUrl(6571744),
    'Saree Borders|Lace': _photoUrl(8752432),
    'Saree Borders|Traditional': _photoUrl(8710793),
    'Saree Borders|Decorative': _photoUrl(13446351),
    'Saree Borders|Other': _photoUrl(12991912),
    'T-Shirts|Half Sleeve': _photoUrl(4440572),
    'T-Shirts|Full Sleeve': _photoUrl(7764063),
    "T-Shirts|Women's": _photoUrl(31041770),
    'T-Shirts|Hoodies': _photoUrl(5840463),
    'T-Shirts|Plain Colour': _photoUrl(8146450),
    'T-Shirts|Plain White': _photoUrl(18257675),
    'Mugs|Small': _photoUrl(29783602),
    'Mugs|Large': _photoUrl(11390372),
    'Mugs|Other': _photoUrl(39361143),
    'Posters|Small': _photoUrl(4065192),
    'Posters|Medium': _photoUrl(19765934),
    'Posters|Large': _photoUrl(11556402),
    'Posters|XL Flex': _photoUrl(6620972),
    'Posters|Other': _photoUrl(14122051),
    'Embroidery|Floral': _photoUrl(30295968),
    'Embroidery|Traditional': _photoUrl(32480210),
    'Embroidery|Names': _photoUrl(29098234),
    'Embroidery|Borders': _photoUrl(29893325),
    'Embroidery|Figures': _photoUrl(7523526),
    'Embroidery|Devotional': _photoUrl(35977513),
    'Embroidery|Embroidery Bases': _photoUrl(8465947),
    'Cardboard|Standee': _photoUrl(5872172),
    'Cardboard|Event': _photoUrl(7509508),
    'Cardboard|Display': _photoUrl(11835350),
    'Cardboard|Template': _photoUrl(7464189),
    'Cardboard|Boards by Size': _photoUrl(8580789),
    'Glass Art|Painting': _photoUrl(34368490),
    'Glass Art|Decorative': _photoUrl(37879709),
    'Glass Art|Floral': _photoUrl(35225713),
    'Glass Art|Devotional': _photoUrl(39176222),
    'Glass Art|Abstract': _photoUrl(14787004),
    'Glass Art|Plain Glass': _photoUrl(1407487),
    'Dress Materials|Silk': _photoUrl(4614231),
    'Dress Materials|Cotton': _photoUrl(9824794),
    'Dress Materials|Crepe Silk': _photoUrl(4862901),
    'Dress Materials|All Dress Materials': _photoUrl(6487380),
  };

  /// The canonical Pexels term for [category].
  String categoryTerm(String category) =>
      _categoryTerms[category] ?? category.toLowerCase();

  /// Resolves the seeded, verified representative image for a category (and
  /// optionally a named sub-category) from [PexelsService]'s cached catalogue:
  /// sub-category photo when one exists, otherwise the category photo, or null
  /// when neither is seeded. Pure lookup — never hits the network, so it also
  /// works offline and without an API key.
  String? seededImageFor(String category, {String? subcategory}) {
    if (subcategory != null && subcategory.isNotEmpty) {
      final seeded = _seededSubcategoryUrls['$category|$subcategory'];
      if (seeded != null) return seeded;
    }
    return _seededCategoryUrls[category];
  }

  /// Builds a category-aware query: the user's terms plus the category term,
  /// without duplicating tokens the user already typed (e.g. "mug").
  String buildQuery({required String category, required String query}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return '';
    final userTokens = trimmed.toLowerCase().split(RegExp(r'\s+')).toSet();
    final additions = categoryTerm(category)
        .split(RegExp(r'\s+'))
        .where((t) => !userTokens.contains(t))
        .toList();
    if (additions.isEmpty) return trimmed;
    return '$trimmed ${additions.join(' ')}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Searches Pexels with a category-aware query and returns the photos.
  /// Throws a [PexelsException] (or [PexelsNotConfiguredException]) on failure.
  Future<List<PexelsImage>> search({
    required String category,
    required String query,
    int perPage = 20,
  }) async {
    final q = buildQuery(category: category, query: query).trim();
    if (q.isEmpty) return const [];
    if (!isConfigured) {
      throw const PexelsNotConfiguredException();
    }

    final client = httpClientOverride ?? http.Client();
    try {
      final uri = Uri.https('api.pexels.com', '/v1/search', {
        'query': q,
        'per_page': '$perPage',
        'page': '1',
      });
      final response = await client
          .get(uri, headers: {
            'Authorization': apiKeyOverride ?? configuredApiKey,
          })
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw PexelsApiException(
          'Pexels responded with ${response.statusCode}.',
          response.statusCode,
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final photos = body['photos'] as List<dynamic>? ?? const [];
      return photos.map<PexelsImage>((p) {
        final map = p as Map<String, dynamic>;
        final src = (map['src'] as Map<String, dynamic>?) ?? const {};
        return PexelsImage(
          id: '${map['id'] ?? DateTime.now().microsecondsSinceEpoch}',
          url: (src['large'] as String?) ??
              (src['landscape'] as String?) ??
              '',
          alt: (map['alt'] as String?)?.trim() ?? '',
          photographer: (map['photographer'] as String?) ?? '',
        );
      }).toList();
    } on TimeoutException {
      throw const PexelsNetworkException(
          'The Pexels search timed out. Please retry.');
    } on http.ClientException catch (e) {
      throw PexelsNetworkException('Could not reach Pexels (${e.message}).');
    } finally {
      if (httpClientOverride == null) client.close();
    }
  }
}

abstract class PexelsException implements Exception {
  final String message;
  const PexelsException(this.message);

  @override
  String toString() => message;
}

class PexelsApiException extends PexelsException {
  final int statusCode;
  const PexelsApiException(super.message, this.statusCode);
}

class PexelsNetworkException extends PexelsException {
  const PexelsNetworkException(super.message);
}

class PexelsNotConfiguredException extends PexelsException {
  const PexelsNotConfiguredException()
      : super('Pexels search is not configured. Run with '
            '--dart-define=PEXELS_API_KEY=<key>.');
}