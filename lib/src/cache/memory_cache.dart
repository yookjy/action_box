import 'dart:async';
import 'dart:convert';

import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/cache/cache_strategy.dart';

abstract class MemoryCache extends CacheStorage {
  const MemoryCache();

  factory MemoryCache.create() => _MemoryCache();
}

class _MemoryCache extends MemoryCache {
  final _cacheTable = <String, Map<String, Map<String, dynamic>>>{};

  @override
  FutureOr<Stream<TResult>> readCache<TParam, TResult>(
      String id,
      FutureOr<Stream<TResult>> Function([TParam?]) ifAbsent,
      CacheStrategy strategy,
      TParam? param) {
    if (_cacheTable.isNotEmpty && _cacheTable.containsKey(id)) {
      var cache = _cacheTable[id];
      var sectionKey = 'param@${Uri.encodeFull(json.encode(param))}';
      var section = cache?[sectionKey];
      if (section != null) {
        var expire = (section['expire'] as DateTime).compareTo(DateTime.now());
        if (expire < 0) {
          cache!.remove(sectionKey);
        } else {
          print('mem cache');
          return Stream.value(section['data']);
        }
      }
    }
    return ifAbsent(param);
  }

  @override
  Type get runtimeType => MemoryCache;

  @override
  void writeCache<TParam, TResult>(
      String id, CacheStrategy strategy, TResult data, TParam? param) {
    try {
      _cacheTable[id] = {
        'param@${Uri.encodeFull(json.encode(param))}': {
          'expire': DateTime.now().add(strategy.expire),
          'data': data
        }
      };
    } catch (e) {
      //ignore
      print(e);
    }
  }

  @override
  void clear() {
    _cacheTable.clear();
  }

  @override
  FutureOr dispose() {
    if (_cacheTable.isNotEmpty) {
      clear();
    }
  }
}
