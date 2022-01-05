import 'dart:convert';

import 'package:action_box/src/cache/file_cache.dart';
import 'package:action_box/src/cache/memory_cache.dart';

class CacheStrategy {
  final Duration expire;
  final Type cacheStorageType;
  final Codec codec;

  const CacheStrategy(
      {required this.cacheStorageType,
      required this.expire,
      this.codec = const JsonCodec()});
  const CacheStrategy.file(this.expire, {Codec? codec})
      : cacheStorageType = FileCache,
        codec = codec ?? const JsonCodec();
  const CacheStrategy.memory(this.expire, {Codec? codec})
      : cacheStorageType = MemoryCache,
        codec = codec ?? const JsonCodec();
}
