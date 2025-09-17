import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/services/file_content_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileContentProcessor.processFiles', () {
    late FileContentProcessor processor;

    setUp(() {
      processor = FileContentProcessor();
    });

    tearDown(() {
      processor.dispose();
    });

    test('returns cancellation entry when cancelled before processing starts',
        () async {
      final progressUpdates = <FileProcessingProgress>[];

      final results = await processor.processFiles(
        ['path/to/file.txt'],
        onProgress: (update) => progressUpdates.add(update),
        isCancelled: () => true,
      );

      expect(results, hasLength(1));
      final cancelled = results.first;
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.fileName, 'file.txt');

      expect(progressUpdates, isNotEmpty);
      final lastUpdate = progressUpdates.last;
      expect(lastUpdate.filePath, 'path/to/file.txt');
      expect(lastUpdate.status, 'Cancelled');
      expect(lastUpdate.progress, 1.0);
    });

    test(
        'returns cancellation entry when cancellation triggers during processing',
        () async {
      var callCount = 0;
      final progressUpdates = <FileProcessingProgress>[];

      final results = await processor.processFiles(
        ['path/to/another.txt'],
        onProgress: (update) => progressUpdates.add(update),
        isCancelled: () {
          callCount += 1;
          return callCount > 1;
        },
      );

      expect(results, hasLength(1));
      final cancelled = results.first;
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.fileName, 'another.txt');

      expect(progressUpdates, isNotEmpty);
      final lastUpdate = progressUpdates.last;
      expect(lastUpdate.filePath, 'path/to/another.txt');
      expect(lastUpdate.status, 'Cancelled');
      expect(lastUpdate.progress, 1.0);
    });
  });
}
