import 'dart:async';

import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/utils/disposable.dart';

abstract class CacheStorage implements Disposable {
  const CacheStorage();

  void writeCache<TParam, TResult>(
      String id, CacheStrategy strategy, TResult data, TParam? param);

  FutureOr<Stream<TResult>> readCache<TParam, TResult>(
      String id,
      FutureOr<Stream<TResult>> Function([TParam?]) ifAbsent,
      CacheStrategy strategy,
      TParam? param);

  void clear();
}
