import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/utils/uuid.dart';

import 'cache_storage.dart';

abstract class FileCache extends CacheStorage {
  const FileCache();

  factory FileCache.fromPath(String path) => _FileCache(path);
}

class _FileCache extends FileCache {
  static final _cacheDirectory = 'local_cache/';

  final Map<String, dynamic> _indexMap = {};
  final String path;

  _FileCache(this.path) : assert(path.isNotEmpty);

  Future<Map?> _readIndex<TParam, TResult>(String id, String indexName,
      CacheStrategy strategy, TParam? param) async {
    if (!_indexMap.containsKey(id) || !_indexMap[id].containsKey(indexName)) {
      try {
        // The index file is loaded directly without using 'Isolate.spawn()', because the file size is small.
        var indexContents = await _readFile(
            _getCachePath(id), '$indexName.json', const Utf8Decoder());

        if (indexContents.isNotEmpty) {
          Map index = json.decode(indexContents);
          var expire = DateTime.parse(index['expire']);
          if (expire.compareTo(DateTime.now()) < 0) {
            _deleteCache(id, indexName, index['cache_name']);
            log('Delete expired cache & index files.');
          } else {
            var cache = _indexMap.putIfAbsent(id, () => {});
            cache[indexName] = index;
            log('Loaded index onto memory. => $index');
            return index;
          }
        }
      } catch (error) {
        //ignore
        log('Unable to read index file.');
        log(error.toString());
      }
    } else {
      var cache = _indexMap[id];
      var index = cache[indexName];
      log('A Index was founded in memory. => $index');
      return index;
    }
    return null;
  }

  @override
  FutureOr<Stream<TResult>> readCache<TParam, TResult>(
      String id,
      FutureOr<Stream<TResult>> Function([TParam?]) ifAbsent,
      CacheStrategy strategy,
      TParam? param) async {
    var index = await _readIndex(
        id, _getIndexName(json.encode(param)), strategy, param);
    TResult? data;
    if (index != null &&
        (data = await _readCacheData(id, strategy, index['cache_name'])) !=
            null) {
      return Stream.value(data!);
    }
    return ifAbsent(param);
  }

  Future<TResult?> _readCacheData<TParam, TResult>(
      String id, CacheStrategy strategy, String cacheFileName) {
    var completer = Completer<TResult?>();
    var isJson = strategy.codec is JsonCodec;
    _spawn(
        entryPoint: _readCacheFile,
        parameters: {
          'path': _getCachePath(id),
          'is_json': isJson,
          'cache_name': cacheFileName,
        },
        onData: (message) {
          if (message != null) {
            var result = strategy.codec.decode(message);
            completer.complete(result);
          } else {
            completer.complete(null);
          }
        });

    return completer.future;
  }

  @override
  void writeCache<TParam, TResult>(
      String id, CacheStrategy strategy, TResult data,
      [TParam? param]) {
    Map indexGroup = _indexMap.putIfAbsent(id, () => {});
    var indexName = _getIndexName(json.encode(param));
    var index = indexGroup.putIfAbsent(indexName, () => {});
    var iso8601 = index['expire'];

    if (iso8601 != null) {
      if (DateTime.parse(iso8601).compareTo(DateTime.now()) < 0) {
        indexGroup.remove(indexName);
        log('Delete expired cache & index files.');
        _deleteCache(id, indexName, index['cache_name']);
      } else {
        log('Skip saving cache because the stored cache is valid.');
        return;
      }
    }

    var cacheFileName = UUID.v4();
    indexGroup[indexName] = index;
    index['expire'] = DateTime.now().add(strategy.expire).toIso8601String();
    index['cache_name'] = cacheFileName;

    _spawn(
        entryPoint: _writeCacheFile,
        parameters: {
          'path': _getCachePath(id),
          'index_name': indexName,
          'index_data': json.encode(index),
          'cache_name': cacheFileName,
          'cache_data': strategy.codec.encode(data)
        },
        onData: (_) => null);
  }

  void _deleteCache(String id, String indexName, String cacheName) {
    _spawn(
        entryPoint: _deleteCacheFile,
        parameters: {
          'path': _getCachePath(id),
          'index_name': indexName,
          'cache_name': cacheName,
        },
        onData: (_) => null);
  }

  @override
  Type get runtimeType => FileCache;

  @override
  void clear() {
    var path = _getCacheRoot(this.path);
    var directory = Directory(path);
    if (directory.existsSync()) {
      directory.delete(recursive: true);
    }
  }

  @override
  FutureOr dispose() {
    if (_indexMap.isNotEmpty) {
      _indexMap.clear();
    }
  }

  String _getCachePath(String directory) =>
      _concatPath(_getCacheRoot(path), directory);
  String _getCacheRoot(String path) => _concatPath(path, _cacheDirectory);
  String _getIndexName(Object name) =>
      'index@${Uri.encodeFull(name.toString())}';

  void _spawn(
      {required Function(_Messenger) entryPoint,
      required Map<String, dynamic> parameters,
      required Function(dynamic) onData}) async {
    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();

    subscription = receivePort.listen((message) async {
      onData(message);
      await subscription?.cancel();
      receivePort.close();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(
        entryPoint, _Messenger(parameters, receivePort.sendPort));
  }

  static String _concatPath(String path, String path2) {
    var filePath = path;
    var separator = filePath.substring(filePath.length - 1, filePath.length);

    if (separator != r'/' && separator != r'\') {
      filePath += '/';
    }

    return filePath + path2;
  }

  static File _getFile(String path, String fileName) {
    var filePath = _concatPath(path, fileName);
    var file = File(filePath);
    if (!file.existsSync()) {
      file.createSync();
    }
    return file;
  }

  static void _readCacheFile(_Messenger messenger) async {
    Utf8Decoder? utf8decoder;
    var path = messenger.parameters['path'];
    var cacheName = messenger.parameters['cache_name'];

    if (messenger.parameters['is_json']) {
      utf8decoder = Utf8Decoder();
    }

    await _readFile(path, '$cacheName.cache', utf8decoder).then((value) {
      log('Read cache file => $value');
      messenger.reply(value);
    }, onError: (error, stackTrace) {
      log('Unable to read cache file.');
      messenger.reply(null);
    });
  }

  static void _writeCacheFile(_Messenger messenger) async {
    var path = messenger.parameters['path'];
    var indexName = messenger.parameters['index_name'];
    var indexData = messenger.parameters['index_data'];
    var cacheName = messenger.parameters['cache_name'];
    var cacheData = messenger.parameters['cache_data'];

    var success = false;
    try {
      log('Saving cache to file. => $indexData');
      await _writeFile(path, '$indexName.json', indexData);
      await _writeFile(path, '$cacheName.cache', cacheData);
      log('Save completed.');
      success = true;
    } catch (error) {
      //ignore
      log(error.toString());
    }
    messenger.reply(success);
  }

  static void _deleteCacheFile(_Messenger messenger) async {
    var path = messenger.parameters['path'];
    var indexName = messenger.parameters['index_name'];
    var cacheName = messenger.parameters['cache_name'];

    var success = false;
    try {
      await _deleteFile(path, '$indexName.json');
      await _deleteFile(path, '$cacheName.cache');
      success = true;
    } catch (error) {
      //ignore
      log(error.toString());
    }
    messenger.reply(success);
  }

  static Future<dynamic> _readFile(
      String path, String fileName, Utf8Decoder? decoder) async {
    var completer = Completer();

    var cacheDir = Directory(path);
    if (!await cacheDir.exists()) {
      cacheDir = await cacheDir.create(recursive: true);
    }

    var file = _getFile(cacheDir.path, fileName);
    if (file.lengthSync() == 0) {
      completer.complete();
    } else {
      (decoder == null ? file.openRead() : file.openRead().transform(decoder))
          .listen((data) {
        completer.complete(data);
      }, onError: (error, stackTrace) {
        completer.completeError(error, stackTrace);
      });
    }
    return completer.future;
  }

  static FutureOr _writeFile(String path, String fileName, dynamic data) async {
    var cacheDir = Directory(path);
    if (!await cacheDir.exists()) {
      cacheDir = await cacheDir.create(recursive: true);
    }

    var file = _getFile(cacheDir.path, fileName);
    var sink = file.openWrite();
    if (data is List<int>) {
      sink.add(data);
    } else {
      sink.write(data);
    }
    await sink.flush();
    return await sink.close();
  }

  static FutureOr _deleteFile(String path, String fileName) async {
    var filePath = _concatPath(path, fileName);
    var file = File(filePath);
    if (await file.exists()) {
      return file.delete();
    }
  }
}

class _Messenger {
  final SendPort _reply;
  final Map<String, dynamic> parameters;

  _Messenger(this.parameters, this._reply);

  void reply(Object? value) => _reply.send(value);
}