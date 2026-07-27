import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/features/session/data/exercise_video_cache.dart';

void main() {
  test('a cache miss downloads once and then serves the local file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exercise-video-cache-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final downloader = _FakeDownloader();
    final cache = LocalExerciseVideoCache(directory, downloader);

    final first = await cache.getFile(_remoteUrl);
    final second = await cache.getFile(_remoteUrl);

    expect(first.path, second.path);
    expect(await first.readAsBytes(), [1, 2, 3, 4]);
    expect(downloader.calls, 1);
  });

  test('a failed partial download is removed and never served', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exercise-video-cache-failure-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final downloader = _FakeDownloader(failAfterPartialWrite: true);
    final cache = LocalExerciseVideoCache(directory, downloader);

    await expectLater(cache.getFile(_remoteUrl), throwsStateError);
    expect(await directory.list().toList(), isEmpty);

    downloader.failAfterPartialWrite = false;
    final downloaded = await cache.getFile(_remoteUrl);

    expect(await downloaded.readAsBytes(), [1, 2, 3, 4]);
    expect(downloader.calls, 2);
  });
}

const _remoteUrl =
    'https://media.musclewiki.com/media/uploads/videos/branded/'
    'female-test-side.mp4';

final class _FakeDownloader implements ExerciseVideoDownloader {
  _FakeDownloader({this.failAfterPartialWrite = false});

  bool failAfterPartialWrite;
  int calls = 0;

  @override
  Future<void> download(String remoteUrl, String destinationPath) async {
    calls++;
    final destination = File(destinationPath);
    if (failAfterPartialWrite) {
      await destination.writeAsBytes([9, 9]);
      throw StateError('download interrupted');
    }
    await destination.writeAsBytes([1, 2, 3, 4]);
  }
}
