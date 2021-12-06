import 'dart:async';

import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/core/action.dart';

class CacheProvider extends CacheStorage {

  final List<CacheStorage?> _storages;

  CacheProvider(this._storages);

  @override
  FutureOr<Stream<TResult>>? readCache<TParam, TResult>(Action<TParam, TResult> action, CacheStrategy strategy, [TParam? param]) {
    return _getStorage(strategy)?.readCache(action, strategy, param);
  }

  @override
  void writeCache<TParam, TResult>(Action<TParam, TResult> action, CacheStrategy? strategy, TResult data, [TParam? param]) {
    if (strategy != null) {
      _getStorage(strategy)?.writeCache(action, strategy, data, param);
    }
  }

  FutureOr<Stream<TResult>> readCacheIfAbsent<TParam, TResult>(Action<TParam, TResult> action, CacheStrategy? strategy, [TParam? param]) {
    FutureOr<Stream<TResult>>? result;
    if (strategy == null || (result = readCache<TParam, TResult>(action, strategy, param)) ==  null) {
      return action.process(param);
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