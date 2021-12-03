import 'dart:async';

import 'package:action_box/src/cache/cache_strategy.dart';

abstract class CacheStorage {

  const CacheStorage();

  void writeCache<TParam, TResult>(String id, CacheStrategy strategy, TResult data, [TParam? param]);

  // FutureOr<Stream<TResult>> readCache<TParam, TResult>(String id, CacheStrategy strategy, FutureOr<Stream<TResult>> Function([TParam? param]) ifAbsent, [TParam? param]);
  FutureOr<Stream<TResult>>? readCache<TParam, TResult>(String id, CacheStrategy strategy, [TParam? param]);

  void clear();

}
