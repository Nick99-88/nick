import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChunkedModelDownloader {
  final Dio _dio = Dio();
  static const int chunkSize = 10 * 1024 * 1024; // 10 MB per chunk

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, bool> _pauseRequested = {};

  Future<void> _saveDownloadProgress(String targetFileName, int downloadedBytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('download_progress_$targetFileName', downloadedBytes);
    await prefs.setInt('download_timestamp_$targetFileName', DateTime.now().millisecondsSinceEpoch);
  }

  Future<int?> _getDownloadProgress(String targetFileName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('download_progress_$targetFileName');
  }

  Future<void> _clearDownloadProgress(String targetFileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('download_progress_$targetFileName');
    await prefs.remove('download_timestamp_$targetFileName');
  }

  void requestPause(String targetFileName) {
    _pauseRequested[targetFileName] = true;
  }

  void requestCancel(String targetFileName) {
    _cancelTokens[targetFileName]?.cancel();
    _pauseRequested[targetFileName] = true;
  }

  Future<File?> downloadInChunks({
    required String modelUrl,
    required String targetFileName,
    required Function(double progress) onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[targetFileName] = cancelToken;
    _pauseRequested[targetFileName] = false;

    try {
      final appDir = await getApplicationSupportDirectory();
      final modelsDirectory = Directory('${appDir.path}/local_models');

      if (!await modelsDirectory.exists()) {
        await modelsDirectory.create(recursive: true);
      }

      final finalFile = File('${modelsDirectory.path}/$targetFileName');
      final tempFile = File('${modelsDirectory.path}/$targetFileName.tmp');

      if (await finalFile.exists()) {
        onStatusUpdate?.call('Model already installed');
        _cleanupTokens(targetFileName);
        return finalFile;
      }

      onStatusUpdate?.call('Connecting to download server...');

      final headResponse = await _dio.head(modelUrl, cancelToken: cancelToken);
      final totalBytes = int.parse(
        headResponse.headers.value('content-length') ?? '0',
      );

      if (totalBytes == 0) throw Exception("Could not retrieve file size.");

      int downloadedBytes = await tempFile.exists() ? await tempFile.length() : 0;

      final savedProgress = await _getDownloadProgress(targetFileName);
      if (savedProgress != null && savedProgress > downloadedBytes) {
        downloadedBytes = savedProgress;
      }

      if (cancelToken.isCancelled) {
        _cleanupTokens(targetFileName);
        return null;
      }

      if (downloadedBytes > 0) {
        onStatusUpdate?.call('Resuming download from ${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB...');
      } else {
        onStatusUpdate?.call('Starting download...');
      }

      final sink = tempFile.openWrite(mode: FileMode.append);
      int chunkNumber = (downloadedBytes / chunkSize).floor();

      while (downloadedBytes < totalBytes) {
        if (_pauseRequested[targetFileName] == true && !cancelToken.isCancelled) {
          onStatusUpdate?.call('Paused');
          await sink.close();
          _cleanupTokens(targetFileName);
          return null;
        }

        if (cancelToken.isCancelled) {
          await sink.close();
          if (await tempFile.exists()) await tempFile.delete();
          await _clearDownloadProgress(targetFileName);
          _cleanupTokens(targetFileName);
          return null;
        }

        int end = downloadedBytes + chunkSize - 1;
        if (end >= totalBytes) end = totalBytes - 1;

        final response = await _dio.get(
          modelUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Range': 'bytes=$downloadedBytes-$end',
            },
          ),
          cancelToken: cancelToken,
        );

        sink.add(response.data);
        await sink.flush();

        downloadedBytes += (end - downloadedBytes + 1);
        chunkNumber++;

        await _saveDownloadProgress(targetFileName, downloadedBytes);

        final progress = downloadedBytes / totalBytes;
        onProgress(progress);
        onStatusUpdate?.call('${(progress * 100).toStringAsFixed(0)}%');
      }

      await sink.close();

      if (cancelToken.isCancelled) {
        if (await tempFile.exists()) await tempFile.delete();
        await _clearDownloadProgress(targetFileName);
        _cleanupTokens(targetFileName);
        return null;
      }

      onStatusUpdate?.call('Finalizing installation...');

      final result = await tempFile.rename(finalFile.path);
      await _clearDownloadProgress(targetFileName);
      _cleanupTokens(targetFileName);
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        onStatusUpdate?.call('Cancelled');
      } else {
        onStatusUpdate?.call('Download failed: $e');
      }
      _cleanupTokens(targetFileName);
      return null;
    }
  }

  void _cleanupTokens(String targetFileName) {
    _cancelTokens.remove(targetFileName);
    _pauseRequested.remove(targetFileName);
  }

  Future<void> cancelDownload(String targetFileName) async {
    requestCancel(targetFileName);
    try {
      final appDir = await getApplicationSupportDirectory();
      final modelsDirectory = Directory('${appDir.path}/local_models');
      final tempFile = File('${modelsDirectory.path}/$targetFileName.tmp');

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await _clearDownloadProgress(targetFileName);
    } catch (e) {
      print("Error canceling download: $e");
    }
  }

  Future<bool> canResumeDownload(String targetFileName) async {
    final savedProgress = await _getDownloadProgress(targetFileName);
    final appDir = await getApplicationSupportDirectory();
    final modelsDirectory = Directory('${appDir.path}/local_models');
    final tempFile = File('${modelsDirectory.path}/$targetFileName.tmp');

    return (savedProgress != null && savedProgress > 0) || await tempFile.exists();
  }

  Future<bool> isModelDownloaded(String targetFileName) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final modelsDirectory = Directory('${appDir.path}/local_models');
      final finalFile = File('${modelsDirectory.path}/$targetFileName');

      final exists = await finalFile.exists();

      print('📁 Checking file: ${finalFile.path}');
      print('  - Directory exists: ${await modelsDirectory.exists()}');
      print('  - File exists: $exists');

      if (await modelsDirectory.exists()) {
        final files = await modelsDirectory.list().toList();
        print('  - Files in directory:');
        for (var file in files) {
          print('    * ${file.path}');
        }
      }

      return exists;
    } catch (e) {
      print('❌ Error checking model download: $e');
      return false;
    }
  }

  Future<int?> getDownloadedBytes(String targetFileName) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final modelsDirectory = Directory('${appDir.path}/local_models');
      final tempFile = File('${modelsDirectory.path}/$targetFileName.tmp');

      if (await tempFile.exists()) {
        return await tempFile.length();
      }
      return 0;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteModel(String targetFileName) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final modelsDirectory = Directory('${appDir.path}/local_models');
      final finalFile = File('${modelsDirectory.path}/$targetFileName');
      final tempFile = File('${modelsDirectory.path}/$targetFileName.tmp');

      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      await _clearDownloadProgress(targetFileName);
    } catch (e) {
      print("Error deleting model: $e");
    }
  }
}
