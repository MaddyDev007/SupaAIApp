import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDioUploadService {
  final SupabaseClient supabase;
  final String bucket;
  final String rootPath;

  final dio.Dio _dio = dio.Dio();        // ✅ prefix
  dio.CancelToken? _cancelToken;         // ✅ prefix

  SupabaseDioUploadService(
    this.supabase,
    this.bucket, {
    required this.rootPath,
  });

  /// Cancel upload (call this on Cancel button)
  void cancelUpload() {
    _cancelToken?.cancel('Upload cancelled by user');
  }

  /// Upload file with real cancel support
  Future<String> uploadFile(
    File file, {
    required void Function(double progress) onUploadProgress,
    required void Function(int sent, int total) onBytesProgress,
  }) async {
    _cancelToken = dio.CancelToken();

    final fileName = path.basename(file.path);
    final filePath = '$rootPath/$fileName';

    final uploadUrl =
        '${supabase.storage.url}/object/$bucket/$filePath';

    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    try {
      await _dio.post(
        uploadUrl,
        data: formData,
        options: dio.Options(
          headers: {
            'Authorization':
                'Bearer ${supabase.auth.currentSession!.accessToken}',
            'x-upsert': 'true',
          },
        ),
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          onBytesProgress(sent, total);
          onUploadProgress((sent / total) * 100);
        },
      );

      return supabase.storage.from(bucket).getPublicUrl(filePath);
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) {
        throw UploadCancelledException();
      }
      rethrow;
    }
  }
}

class UploadCancelledException implements Exception {
  @override
  String toString() => 'Upload cancelled';
}
