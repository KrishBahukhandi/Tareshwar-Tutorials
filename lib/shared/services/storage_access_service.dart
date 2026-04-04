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

  // ── Signed URL cache ────────────────────────────────────────
  // Each lecture list page fires 2×N signed-URL requests
  // (video + notes per lecture). At 5k concurrent students
  // this hammers the Storage API. Cache URLs for 5 minutes
  // so repeated renders hit memory instead of the network.
  // Cache is static (shared across all service instances).
  static const _urlTtl = Duration(minutes: 5);
  // Shorter default expiry (300 s) so URLs expire shortly after
  // the cache entry does — the previous 3600 s default let
  // shared/leaked URLs stay valid for an hour.
  static const _defaultExpiresIn = 300;
  static const _maxCacheEntries = 500; // ~500 lectures max in memory
  static final Map<String, (String, DateTime)> _urlCache = {};

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
    int expiresInSeconds = _defaultExpiresIn,
  }) async {
    if (value == null || value.isEmpty) return null;

    final ref = parseStorageRef(value) ?? parseStorageUrl(value);
    if (ref == null) return value;

    final cacheKey = '${ref.bucket}/${ref.path}';
    final now = DateTime.now();

    // Return cached URL if still valid
    final cached = _urlCache[cacheKey];
    if (cached != null && now.isBefore(cached.$2)) {
      return cached.$1;
    }

    final url = await _client.storage
        .from(ref.bucket)
        .createSignedUrl(ref.path, expiresInSeconds);

    // Evict oldest entries when cache is full
    if (_urlCache.length >= _maxCacheEntries) {
      final oldest = _urlCache.entries
          .reduce((a, b) => a.value.$2.isBefore(b.value.$2) ? a : b)
          .key;
      _urlCache.remove(oldest);
    }

    _urlCache[cacheKey] = (url, now.add(_urlTtl));
    return url;
  }
}
