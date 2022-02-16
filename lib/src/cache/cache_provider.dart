import 'dart:async';

import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/cache/cache_strategy.dart';

class CacheProvider extends CacheStorage {
  final List<CacheStorage?> _storages;

  CacheProvider(this._storages);

  @override
  FutureOr<Stream<TResult>> readCache<TParam, TResult>(
      String id,
      FutureOr<Stream<TResult>> Function(TParam) ifAbsent,
      CacheStrategy? strategy,
      TParam param) {
    CacheStorage? storage;
    if (strategy == null || (storage = _getStorage(strategy)) == null) {
      return ifAbsent(param);
    }

    return storage!.readCache(id, ifAbsent, strategy, param);
  }

  @override
  void writeCache<TParam, TResult>(
      String id, CacheStrategy? strategy, TResult data, TParam param) {
    if (strategy != null) {
      _getStorage(strategy)?.writeCache(id, strategy, data, param);
    }
  }

  CacheStorage? _getStorage(CacheStrategy strategy) => _storages
      .cast<CacheStorage?>()
      .firstWhere((c) => c.runtimeType == strategy.cacheStorageType,
          orElse: () => null);

  @override
  void clear() {
    _storages.forEach((storage) {
      storage?.clear();
    });
  }

  @override
  FutureOr dispose() {
    _storages.forEach((storage) {
      storage?.dispose();
    });
  }
}
