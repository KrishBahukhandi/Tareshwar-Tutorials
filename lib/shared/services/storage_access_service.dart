import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'supabase_service.dart';

final storageAccessServiceProvider = Provider<StorageAccessService>((ref) {
  return StorageAccessService(ref.watch(supabaseClientProvider));
});

class StorageAssetRef {
  final String bucket;
  final String path;

  const StorageAssetRef({required this.bucket, required this.path});
}

class StorageAccessService {
  final SupabaseClient _client;

  const StorageAccessService(this._client);

  static const _scheme = 'storage://';
  static const _protectedBuckets = {
    AppConstants.lectureVideosBucket,
    AppConstants.notesBucket,
    AppConstants.pdfsBucket,
    AppConstants.videosBucket,
  };

  static String buildStorageRef({
    required String bucket,
    required String path,
  }) => '$_scheme$bucket/$path';

  static StorageAssetRef? parseStorageRef(String? value) {
    if (value == null || value.isEmpty || !value.startsWith(_scheme)) {
      return null;
    }

    final withoutScheme = value.substring(_scheme.length);
    final slash = withoutScheme.indexOf('/');
    if (slash <= 0 || slash == withoutScheme.length - 1) return null;

    return StorageAssetRef(
      bucket: withoutScheme.substring(0, slash),
      path: withoutScheme.substring(slash + 1),
    );
  }

  StorageAssetRef? parseStorageUrl(String? value) {
    if (value == null || value.isEmpty) return null;

    final directRef = parseStorageRef(value);
    if (directRef != null) return directRef;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final objectIndex = uri.pathSegments.indexOf('object');
    if (objectIndex == -1 || objectIndex + 2 >= uri.pathSegments.length) {
      return null;
    }

    final visibility = uri.pathSegments[objectIndex + 1];
    final bucket = uri.pathSegments[objectIndex + 2];
    if (!_protectedBuckets.contains(bucket)) return null;
    if (visibility != 'public' && visibility != 'sign') return null;

    final assetPath = uri.pathSegments.skip(objectIndex + 3).join('/');
    if (assetPath.isEmpty) return null;

    return StorageAssetRef(bucket: bucket, path: assetPath);
  }

  Future<String?> resolveAssetUrl(
    String? value, {
    int expiresInSeconds = 3600,
  }) async {
    if (value == null || value.isEmpty) return null;

    final ref = parseStorageRef(value) ?? parseStorageUrl(value);
    if (ref == null) return value;

    return _client.storage
        .from(ref.bucket)
        .createSignedUrl(ref.path, expiresInSeconds);
  }
}
