import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_print_shop/frontend/services/pexels_service.dart';

void main() {
  group('PexelsService', () {
    final service = PexelsService();

    tearDown(() {
      service.httpClientOverride = null;
      service.apiKeyOverride = null;
    });

    test('buildQuery is category-aware and never duplicates user tokens', () {
      expect(service.buildQuery(category: 'T-Shirts', query: 'cricket'),
          'cricket t-shirt');
      expect(service.buildQuery(category: 'Mugs', query: 'coffee mug'),
          'coffee mug');
      expect(service.buildQuery(category: 'Cardboard', query: 'wedding'),
          'wedding cardboard');
      expect(service.buildQuery(category: 'Posters', query: 'motivational'),
          'motivational poster');
      expect(service.buildQuery(category: 'Embroidery', query: 'floral'),
          'floral embroidery');
      expect(service.buildQuery(category: 'Glass Art', query: 'glass painting'),
          'glass painting art');
      expect(service.buildQuery(category: 'Saree Borders', query: 'border'),
          'border saree');
    });

    test('empty query resolves to no images without a request', () async {
      expect(await service.search(category: 'Mugs', query: '   '), isEmpty);
    });

    test('unconfigured service reports the graceful exception', () async {
      expect(
        () => service.search(category: 'Mugs', query: 'coffee'),
        throwsA(isA<PexelsNotConfiguredException>()),
      );
    });

    test('parses a successful response, picking src.large then src.landscape',
        () async {
      service.httpClientOverride = MockClient((request) async {
        expect(request.url.host, 'api.pexels.com');
        expect(request.url.path, '/v1/search');
        expect(request.url.queryParameters['query'], 'coffee mug');
        expect(request.url.queryParameters['per_page'], '20');
        expect(request.headers['Authorization'], 'TEST_KEY');
        return http.Response(
          jsonEncode({
            'photos': [
              {
                'id': 42,
                'alt': '  A coffee mug design  ',
                'photographer': 'Jane Doe',
                'src': {
                  'large': 'https://images.pexels.com/a.jpg',
                  'landscape': 'https://images.pexels.com/b.jpg',
                },
              },
              {
                'id': 43,
                'alt': '',
                'photographer': 'Bob',
                'src': {'landscape': 'https://images.pexels.com/c.jpg'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      service.apiKeyOverride = 'TEST_KEY';

      final images =
          await service.search(category: 'Mugs', query: 'coffee');
      expect(images, hasLength(2));
      expect(images[0].id, '42');
      expect(images[0].url, 'https://images.pexels.com/a.jpg');
      expect(images[0].alt, 'A coffee mug design');
      expect(images[0].photographer, 'Jane Doe');
      expect(images[1].url, 'https://images.pexels.com/c.jpg');
    });

    test('empty photos resolves to an empty list', () async {
      service.httpClientOverride = MockClient((request) async =>
          http.Response(jsonEncode({'photos': <Object>[]}), 200,
              headers: {'content-type': 'application/json'}));
      service.apiKeyOverride = 'TEST_KEY';

      expect(await service.search(category: 'T-Shirts', query: 'cricket'),
          isEmpty);
    });

    test('non-200 responses throw a PexelsApiException', () async {
      service.httpClientOverride =
          MockClient((request) async => http.Response('rate limited', 429));
      service.apiKeyOverride = 'TEST_KEY';

      expect(
        () => service.search(category: 'T-Shirts', query: 'cricket'),
        throwsA(isA<PexelsApiException>()
            .having((e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('transport errors throw a PexelsNetworkException', () async {
      service.httpClientOverride =
          MockClient((request) async => throw http.ClientException('down'));
      service.apiKeyOverride = 'TEST_KEY';

      expect(
        () => service.search(category: 'T-Shirts', query: 'cricket'),
        throwsA(isA<PexelsNetworkException>()),
      );
    });

    group('seeded catalogue', () {
      test('seededImageFor resolves a seeded category photo', () {
        expect(
          service.seededImageFor('Dress Materials'),
          'https://images.pexels.com/photos/7171902/'
          'pexels-photo-7171902.jpeg?auto=compress&cs=tinysrgb&w=900',
        );
      });

      test('seededImageFor prefers the sub-category photo', () {
        expect(
          service.seededImageFor('Dress Materials', subcategory: 'Silk'),
          'https://images.pexels.com/photos/4614231/'
          'pexels-photo-4614231.jpeg?auto=compress&cs=tinysrgb&w=900',
        );
      });

      test(
          'seededImageFor folds to the category photo for unknown sub-categories',
          () {
        expect(
          service.seededImageFor('Sarees', subcategory: 'Unknown'),
          'https://images.pexels.com/photos/5447529/'
          'pexels-photo-5447529.jpeg?auto=compress&cs=tinysrgb&w=900',
        );
      });

      test('seededImageFor is null for unknown categories', () {
        expect(service.seededImageFor('Watches'), isNull);
      });
    });
  });
}
