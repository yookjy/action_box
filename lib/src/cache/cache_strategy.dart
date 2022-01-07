import 'dart:convert';

import 'package:action_box/src/cache/file_cache.dart';
import 'package:action_box/src/cache/memory_cache.dart';

class CacheStrategy {
  final Duration duration;
  final Type cacheStorageType;
  final Codec codec;

  const CacheStrategy(
      {required this.cacheStorageType,
      required this.duration,
      this.codec = const JsonCodec()});
  const CacheStrategy.file(this.duration, {Codec? codec})
      : cacheStorageType = FileCache,
        codec = codec ?? const JsonCodec();
  const CacheStrategy.memory(this.duration, {Codec? codec})
      : cacheStorageType = MemoryCache,
        codec = codec ?? const JsonCodec();
}
