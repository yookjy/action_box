import 'package:action_box/src/cache/cache_storage.dart';

class CacheStrategy {
  final Duration expire;

  final Type cacheStorageType;

  const CacheStrategy({required this.expire, required this.cacheStorageType});
}