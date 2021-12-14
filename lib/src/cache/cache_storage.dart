import 'dart:async';

import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/utils/disposable.dart';

abstract class CacheStorage implements Disposable {
  const CacheStorage();

  void writeCache<TParam, TResult>(Action<TParam, TResult> action,
      CacheStrategy strategy, TResult data, TParam? param);

  FutureOr<Stream<TResult>> readCache<TParam, TResult>(
      Action<TParam, TResult> action, CacheStrategy strategy, TParam? param);

  void clear();
}
