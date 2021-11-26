import 'dart:io';

import 'package:action_box/src/cache/cache_strategy.dart';

abstract class CacheStorageProvider {
  void writeCache<TParam, TResult>(String id, CacheStrategy strategy, TResult data, [TParam? param]) ;

  TResult readCache<TParam, TResult>(String id, CacheStrategy strategy, [TParam? param]);
}