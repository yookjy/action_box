import 'dart:async';
import 'dart:convert';

import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/core/action.dart';

abstract class MemoryCache extends CacheStorage {
  const MemoryCache();

  factory MemoryCache.create() => _MemoryCache();
}

class _MemoryCache extends MemoryCache {

  final _cacheTable = <String, Map<String, Map<String, dynamic>>>{};

  @override
  FutureOr<Stream<TResult>> readCache<TParam, TResult>(Action<TParam, TResult> action, CacheStrategy strategy, TParam? param) {
    if (_cacheTable.isNotEmpty && _cacheTable.containsKey(action.defaultChannel.id)) {
      var cache = _cacheTable[action.defaultChannel.id];
      var sectionKey = 'param@${action.serializeParameter(param)}';
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
    return action.process(param);
  }

  @override
  Type get runtimeType => MemoryCache;

  @override
  void writeCache<TParam, TResult>(Action<TParam, TResult> action, CacheStrategy strategy, TResult data, TParam? param) {
    try {
      _cacheTable[action.defaultChannel.id] = {
        'param@${action.serializeParameter(param)}': {
          'expire': DateTime.now().add(strategy.expire),
          'data': data
        }
      };
    } catch(e) {
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