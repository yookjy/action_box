import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/cache/file_cache.dart';
import 'package:action_box/src/cache/memory_cache.dart';

abstract class CacheStrategy<TCacheType extends CacheStorage> {
  final Duration expire;
  Type get cacheStorageType => TCacheType;

  const CacheStrategy({required this.expire});
}

class FileCacheStrategy extends CacheStrategy<FileCache> {
  final String key;

  const FileCacheStrategy(this.key, {required Duration expire})
      : super(expire: expire);
}

class MemoryCacheStrategy extends CacheStrategy<MemoryCache> {
  const MemoryCacheStrategy({required Duration expire}) : super(expire: expire);
}
