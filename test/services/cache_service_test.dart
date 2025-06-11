import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/services/cache_service.dart';

void main() {
  late CacheService cacheService;

  setUp(() async {
    await CacheService.init();
    cacheService = CacheService();
  });

  tearDown(() async {
    await cacheService.clear();
  });

  test('should store and retrieve data', () async {
    final testData = {'key': 'value'};
    await cacheService.set('test_key', testData, (data) => data);

    final result = await cacheService.get('test_key', (data) => data);
    expect(result, equals(testData));
  });

  test('should return null for non-existent key', () async {
    final result = await cacheService.get('non_existent', (data) => data);
    expect(result, isNull);
  });

  test('should remove data', () async {
    final testData = {'key': 'value'};
    await cacheService.set('test_key', testData, (data) => data);
    await cacheService.remove('test_key');

    final result = await cacheService.get('test_key', (data) => data);
    expect(result, isNull);
  });

  test('should clear all data', () async {
    final testData1 = {'key1': 'value1'};
    final testData2 = {'key2': 'value2'};

    await cacheService.set('test_key1', testData1, (data) => data);
    await cacheService.set('test_key2', testData2, (data) => data);

    await cacheService.clear();

    final result1 = await cacheService.get('test_key1', (data) => data);
    final result2 = await cacheService.get('test_key2', (data) => data);

    expect(result1, isNull);
    expect(result2, isNull);
  });

  test('should handle expiration', () async {
    final testData = {'key': 'value'};
    await cacheService.set(
      'test_key',
      testData,
      (data) => data,
      expiration: const Duration(milliseconds: 100),
    );

    // Wait for expiration
    await Future.delayed(const Duration(milliseconds: 200));

    final result = await cacheService.get('test_key', (data) => data);
    expect(result, isNull);
  });

  test('should handle complex data types', () async {
    final testData = {
      'string': 'value',
      'number': 42,
      'boolean': true,
      'list': [1, 2, 3],
      'map': {'nested': 'value'},
    };

    await cacheService.set('test_key', testData, (data) => data);
    final result = await cacheService.get('test_key', (data) => data);

    expect(result, equals(testData));
  });
}
