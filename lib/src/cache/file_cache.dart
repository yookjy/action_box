import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/utils/uuid.dart';

import 'cache_storage.dart';

abstract class FileCache extends CacheStorage {
  const FileCache();

  factory FileCache.fromPath(String path) => _FileCache(path);
}

class _FileCache extends FileCache {
  static final _cacheDirectory = 'local_cache/';
  static final _fileExt = '.json';

  final Map<String, dynamic> _indexMap = {};
  final String path;

  _FileCache(this.path) : assert(path.isNotEmpty);

  Future<Map?> _readIndex<TParam, TResult>(Action<TParam, TResult> action,
      covariant FileCacheStrategy strategy, TParam? param) async {
    var indexName = _getIndexName(action.serializeParameter(param));

    if (!_indexMap.containsKey(strategy.key) ||
        !_indexMap[strategy.key].containsKey(indexName)) {
      try {
        // The index file is loaded directly without using 'Isolate.spawn()', because the file size is small.
        var indexContents =
            await _readFile(_getCachePath(strategy.key), indexName);

        if (indexContents != null) {
          Map index = json.decode(indexContents);
          var expire = DateTime.parse(index['expire']);
          if (expire.compareTo(DateTime.now()) < 0) {
            deleteCache(strategy.key, indexName, index['cache_name']);
            log('Delete expired cache & index files.');
          } else {
            var cache = _indexMap.putIfAbsent(strategy.key, () => {});
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
      var cache = _indexMap[strategy.key];
      var index = cache[indexName];
      // completer.complete(index);
      log('A Index was founded in memory. => $index');
      return index;
    }
    return null;
  }

  @override
  FutureOr<Stream<TResult>> readCache<TParam, TResult>(
      Action<TParam, TResult> action,
      covariant FileCacheStrategy strategy,
      TParam? param) async {
    var index = await _readIndex(action, strategy, param);
    TResult? data;
    if (index != null &&
        (data = await _readCacheData(action, strategy, index['cache_name'])) !=
            null) {
      return Stream.value(data!);
    }
    return action.process(param);
  }

  Future<TResult?> _readCacheData<TParam, TResult>(
      Action<TParam, TResult> action,
      FileCacheStrategy strategy,
      String cacheFileName) async {
    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();
    var completer = Completer<TResult?>();

    subscription = receivePort.listen((message) async {
      if (message != null) {
        var result = action.deserializeResult(message);
        completer.complete(result);
      } else {
        completer.complete(null);
      }
      await subscription?.cancel();
      receivePort.close();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(
        _readCacheFile,
        Messenger({
          'path': _getCachePath(strategy.key),
          'cache_name': cacheFileName,
        }, receivePort.sendPort));

    return completer.future;
  }

  @override
  FutureOr writeCache<TParam, TResult>(Action<TParam, TResult> action,
      covariant FileCacheStrategy strategy, TResult data,
      [TParam? param]) async {
    Map indexGroup = _indexMap.putIfAbsent(strategy.key, () => {});
    var indexName = _getIndexName(action.serializeParameter(param));
    var index = indexGroup.putIfAbsent(indexName, () => {});
    var iso8601 = index['expire'];

    if (iso8601 != null) {
      if (DateTime.parse(iso8601).compareTo(DateTime.now()) < 0) {
        indexGroup.remove(indexName);
        log('Delete expired cache & index files.');
        deleteCache(strategy.key, indexName, index['cache_name']);
      } else {
        log('Skip saving cache because the stored cache is valid.');
        return;
      }
    }

    var cacheFileName = UUID.v4();
    indexGroup[indexName] = index;
    index['expire'] = DateTime.now().add(strategy.expire).toIso8601String();
    index['cache_name'] = cacheFileName;

    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();

    subscription = receivePort.listen((_) async {
      await subscription?.cancel();
      receivePort.close();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(
        _writeCacheFile,
        Messenger({
          'path': _getCachePath(strategy.key),
          'index_name': indexName,
          'index_data': json.encode(index),
          'cache_name': cacheFileName,
          'cache_data': action.serializeResult(data)
        }, receivePort.sendPort));
  }

  String _getIndexName(String name) => 'index@${Uri.encodeFull(name)}';

  void deleteCache(
      String strategyKey, String indexName, String cacheName) async {
    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();

    subscription = receivePort.listen((_) async {
      await subscription?.cancel();
      receivePort.close();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(
        _deleteCacheFile,
        Messenger({
          'path': _getCachePath(strategyKey),
          'index_name': indexName,
          'cache_name': cacheName,
        }, receivePort.sendPort));
  }

  static void _writeCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var indexName = messenger.parameters['index_name'];
    var indexData = messenger.parameters['index_data'];
    var cacheName = messenger.parameters['cache_name'];
    var cacheData = messenger.parameters['cache_data'];

    var success = false;
    try {
      log('Saving cache to file. => $indexData');
      await _writeFile(path, indexName, indexData);
      await _writeFile(path, cacheName, cacheData);
      log('Save completed.');
      success = true;
    } catch (error) {
      //ignore
      log(error.toString());
    }
    messenger.reply(success);
  }

  static void _readCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var cacheName = messenger.parameters['cache_name'];

    await _readFile(path, cacheName).then((value) {
      log('Read cache file => $value');
      messenger.reply(value);
    }, onError: (error, stackTrace) {
      log('Unable to read cache file.');
      messenger.reply(null);
    });
  }

  static void _deleteCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var indexName = messenger.parameters['index_name'];
    var cacheName = messenger.parameters['cache_name'];

    var success = false;
    try {
      await _deleteFile(path, indexName);
      await _deleteFile(path, cacheName);
      success = true;
    } catch (error) {
      //ignore
      log(error.toString());
    }
    messenger.reply(success);
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

  static File _getFile(String path, String fileName) {
    var filePath = _concatPath(path, fileName);
    var file = File(filePath);
    if (!file.existsSync()) {
      file.createSync();
    }
    return file;
  }

  String _getCachePath(String directory) =>
      _concatPath(_getCacheRoot(path), directory);

  String _getCacheRoot(String path) => _concatPath(path, _cacheDirectory);

  static String _concatPath(String path, String path2) {
    var filePath = path;
    var separator = filePath.substring(filePath.length - 1, filePath.length);

    if (separator != r'/' && separator != r'\') {
      filePath += '/';
    }

    return filePath + path2;
  }

  static Future<String?> _readFile(String path, String fileName) async {
    var completer = Completer<String?>();

    var cacheDir = Directory(path);
    if (!await cacheDir.exists()) {
      cacheDir = await cacheDir.create(recursive: true);
    }

    var file = _getFile(cacheDir.path, '$fileName$_fileExt');
    if (file.lengthSync() == 0) {
      completer.complete(null);
    } else {
      file.openRead().transform(utf8.decoder).listen((data) {
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

    var file = _getFile(cacheDir.path, '$fileName$_fileExt');
    var sink = file.openWrite();
    sink.write(data);
    await sink.flush();
    return await sink.close();
  }

  static FutureOr _deleteFile(String path, String fileName) async {
    var filePath = _concatPath(path, '$fileName$_fileExt');
    var file = File(filePath);
    if (await file.exists()) {
      return file.delete();
    }
  }

  @override
  FutureOr dispose() {
    if (_indexMap.isNotEmpty) {
      _indexMap.clear();
    }
  }
}

class Messenger {
  final SendPort _reply;
  final Map<String, dynamic> parameters;

  Messenger(this.parameters, this._reply);

  void reply(Object? value) => _reply.send(value);
}
