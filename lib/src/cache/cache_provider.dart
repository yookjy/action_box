import 'dart:async';

import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/cache/cache_strategy.dart';

class CacheProvider extends CacheStorage {

  final List<CacheStorage?> _storages;

  CacheProvider(this._storages);

  @override
  FutureOr<Stream<TResult>>? readCache<TParam, TResult>(String id, CacheStrategy strategy, [TParam? param]) {
    return _getStorage(strategy)?.readCache(id, strategy, param);
  }

  @override
  void writeCache<TParam, TResult>(String id, CacheStrategy? strategy, TResult data, [TParam? param]) {
    if (strategy != null) {
      _getStorage(strategy)?.writeCache(id, strategy, data, param);
    }
  }

  FutureOr<Stream<TResult>> readCacheIfAbsent<TParam, TResult>(String id, CacheStrategy? strategy, FutureOr<Stream<TResult>> Function([TParam? param]) ifAbsent, [TParam? param]) {
    FutureOr<Stream<TResult>>? result;
    if (strategy == null || (result = readCache<TParam, TResult>(id, strategy, param)) ==  null) {
      return ifAbsent(param);
    }
    return result!;
  }

  CacheStorage? _getStorage(CacheStrategy strategy) =>
    _storages
      .cast<CacheStorage?>()
      .firstWhere((c) => c.runtimeType == strategy.cacheStorageType, orElse: () => null);

  @override
  void clear() {
    _storages.forEach((storage) {
      storage?.clear();
    });
  }
}