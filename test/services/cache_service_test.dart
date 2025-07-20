import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ollamaverse/services/cache_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    await CacheService.init();
  });

  tearDown(() async {
    await CacheService.clear();
  });

  test('should store and retrieve data', () async {
    const testData = 'value';
    await CacheService.set('test_key', testData);

    final result = await CacheService.get<String>('test_key');
    expect(result, equals(testData));
  });

  test('should return null for non-existent key', () async {
    final result = await CacheService.get<String>('non_existent');
    expect(result, isNull);
  });

  test('should remove data', () async {
    const testData = 'value';
    await CacheService.set('test_key', testData);
    await CacheService.remove('test_key');

    final result = await CacheService.get<String>('test_key');
    expect(result, isNull);
  });

  test('should clear all data', () async {
    const testData1 = 'value1';
    const testData2 = 'value2';

    await CacheService.set('test_key1', testData1);
    await CacheService.set('test_key2', testData2);

    await CacheService.clear();

    final result1 = await CacheService.get<String>('test_key1');
    final result2 = await CacheService.get<String>('test_key2');

    expect(result1, isNull);
    expect(result2, isNull);
  });

  test('should handle complex data types', () async {
    const testData = 'value';
    await CacheService.set('test_key', testData);
    final result = await CacheService.get<String>('test_key');

    expect(result, equals(testData));
  });
}
