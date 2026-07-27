import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

abstract interface class ExerciseVideoCache {
  Future<File> getFile(String remoteUrl);

  Future<void> prefetch(Iterable<String> remoteUrls);
}

abstract interface class ExerciseVideoDownloader {
  Future<void> download(String remoteUrl, String destinationPath);
}

final class DioExerciseVideoDownloader implements ExerciseVideoDownloader {
  const DioExerciseVideoDownloader(this._dio);

  final Dio _dio;

  @override
  Future<void> download(String remoteUrl, String destinationPath) =>
      _dio.download(remoteUrl, destinationPath);
}

final class LocalExerciseVideoCache implements ExerciseVideoCache {
  LocalExerciseVideoCache(this._directory, this._downloader);

  final Directory _directory;
  final ExerciseVideoDownloader _downloader;
  final Map<String, Future<File>> _downloads = <String, Future<File>>{};
  int _temporaryFileSequence = 0;

  @override
  Future<File> getFile(String remoteUrl) {
    final active = _downloads[remoteUrl];
    if (active != null) return active;

    late final Future<File> download;
    download = _getOrDownload(remoteUrl).whenComplete(() {
      if (identical(_downloads[remoteUrl], download)) {
        _downloads.remove(remoteUrl);
      }
    });
    _downloads[remoteUrl] = download;
    return download;
  }

  @override
  Future<void> prefetch(Iterable<String> remoteUrls) async {
    await Future.wait<void>([
      for (final remoteUrl in remoteUrls.toSet())
        _ignoreFailure(getFile(remoteUrl)),
    ]);
  }

  Future<File> _getOrDownload(String remoteUrl) async {
    await _directory.create(recursive: true);
    final cachedFile = File(
      '${_directory.path}${Platform.pathSeparator}${_fileName(remoteUrl)}',
    );
    if (await _isUsable(cachedFile)) return cachedFile;
    if (await cachedFile.exists()) await cachedFile.delete();

    final temporaryFile = File(
      '${cachedFile.path}.part-'
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${_temporaryFileSequence++}',
    );
    try {
      await _downloader.download(remoteUrl, temporaryFile.path);
      if (!await _isUsable(temporaryFile)) {
        throw const FileSystemException(
          'Downloaded exercise video is empty or missing.',
        );
      }
      return await temporaryFile.rename(cachedFile.path);
    } on Object {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      rethrow;
    }
  }

  static Future<bool> _isUsable(File file) async =>
      await file.exists() && await file.length() > 0;

  static String _fileName(String remoteUrl) {
    final encoded = base64Url
        .encode(utf8.encode(remoteUrl))
        .replaceAll('=', '');
    return '$encoded.mp4';
  }

  static Future<void> _ignoreFailure(Future<File> download) async {
    try {
      await download;
    } on Object {
      // Prefetch is best effort. Playback keeps its placeholder on failure.
    }
  }
}
