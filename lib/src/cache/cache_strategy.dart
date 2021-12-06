class CacheStrategy<TResult> {
  final Duration expire;

  final Type cacheStorageType;

  CacheStrategy({required this.expire, required this.cacheStorageType});
}