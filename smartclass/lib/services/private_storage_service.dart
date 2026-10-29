import 'package:supabase_flutter/supabase_flutter.dart';

/// Creates short-lived authenticated URLs for files in private Supabase buckets.
/// Database rows may contain legacy public URLs or raw storage paths; both are
/// parsed without treating the URL itself as proof of access.
class PrivateStorageService {
  PrivateStorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const buckets = <String>{'lessons', 'questions', 'notes'};

  static String? bucketFromReference(String? reference) {
    if (reference == null || reference.trim().isEmpty) return null;
    final uri = Uri.tryParse(reference.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments;
    for (var i = 0; i + 2 < segments.length; i++) {
      if (segments[i] == 'object' &&
          (segments[i + 1] == 'public' ||
              segments[i + 1] == 'sign' ||
              segments[i + 1] == 'authenticated') &&
          buckets.contains(segments[i + 2])) {
        return segments[i + 2];
      }
    }
    return null;
  }

  static String? pathFromReference(String? reference, String bucket) {
    if (reference == null || reference.trim().isEmpty) return null;
    final value = reference.trim();
    final uri = Uri.tryParse(value);

    if (uri != null && (uri.hasScheme || value.startsWith('/'))) {
      final segments = uri.pathSegments;
      for (var i = 0; i + 3 < segments.length; i++) {
        if (segments[i] == 'object' &&
            (segments[i + 1] == 'public' ||
                segments[i + 1] == 'sign' ||
                segments[i + 1] == 'authenticated') &&
            segments[i + 2] == bucket) {
          final path = segments.skip(i + 3).join('/');
          return path.isEmpty ? null : path;
        }
      }
      // A local path may be provided as "/<bucket>/<path>".
      final bucketIndex = segments.indexOf(bucket);
      if (!uri.hasScheme && bucketIndex >= 0) {
        final path = segments.skip(bucketIndex + 1).join('/');
        return path.isEmpty ? null : path;
      }
      if (uri.hasScheme) return null;
    }

    return value.replaceFirst(RegExp(r'^/+'), '');
  }

  Future<String> createSignedUrl(
    String reference, {
    required String bucket,
    int expiresInSeconds = 3600,
  }) async {
    final path = pathFromReference(reference, bucket);
    if (path == null || path.isEmpty) {
      throw ArgumentError('Could not resolve a $bucket storage path.');
    }

    return _client.storage
        .from(bucket)
        .createSignedUrl(path, expiresInSeconds);
  }

  Future<String> createSignedUrlForReference(
    String reference, {
    int expiresInSeconds = 3600,
  }) async {
    final bucket = bucketFromReference(reference);
    if (bucket == null) {
      throw ArgumentError('The file reference does not identify a supported bucket.');
    }
    return createSignedUrl(
      reference,
      bucket: bucket,
      expiresInSeconds: expiresInSeconds,
    );
  }
}
