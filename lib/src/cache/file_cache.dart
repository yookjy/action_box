import 'dart:async';
import 'dart:convert';
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

  final Map<String, dynamic> _indexMap = {};
  final String path;

  _FileCache(this.path) : assert(path.isNotEmpty);
  
  String _getCachePath(String directory) => _concatPath(_getLocalCacheDir(path), directory);

  Future<Map?> _readIndex<TParam, TResult>(Action<TParam, TResult> action, covariant FileCacheStrategy strategy,  TParam? param) async {
    var completer = Completer<Map?>();
    var indexName = _getIndexName(action.serializeParameter(param));

    // 메모리에 인덱스가 존재하지 않거나 파람키가 존재하지 않거나 만료되었으면, 인덱스 로드
    if (!_indexMap.containsKey(strategy.key) || !_indexMap[strategy.key].containsKey(indexName)) {
      var receivePort = ReceivePort();
      Isolate? isolate;
      StreamSubscription? subscription;

      subscription = receivePort.listen((message) async {
        await subscription?.cancel();
        receivePort.close();
        isolate?.kill();

        if (message != null) {
          Map index = json.decode(message);
          var expire = DateTime.parse(index['expire']);
          if (expire.compareTo(DateTime.now()) < 0) {
            // 캐시가 만료 되었으므로 삭제 하고 중단.
            deleteCache(strategy.key, indexName, index['cache_name']);
          } else {
            // 메모리에 캐시 내용 저장
            var cache = _indexMap.putIfAbsent(strategy.key, () => {});
            cache[indexName] = index;
            completer.complete(index);
            return;
          }
        }
        completer.complete(null);
      });

      isolate = await Isolate.spawn(_readIndexFile, Messenger({
        'path': _getCachePath(strategy.key),
        'index_name': indexName,
      }, receivePort.sendPort));
    } else {
      var cache = _indexMap[strategy.key];
      var index = cache[indexName];
      completer.complete(index);
    }

    return completer.future;
  }

  @override
  FutureOr<Stream<TResult>> readCache<TParam, TResult>(Action<TParam, TResult> action, covariant FileCacheStrategy strategy, TParam? param) async {
    var index = await _readIndex(action, strategy, param);
    print('인덱스: $index');
    TResult? data;
    if (index != null && (data = await _readCacheData(action, strategy, index['cache_name'])) != null){
      return Stream.value(data!);
    }
    return action.process(param);
  }

  Future<TResult?> _readCacheData<TParam, TResult>(Action<TParam, TResult> action, FileCacheStrategy strategy, String cacheFileName) async {
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

    isolate = await Isolate.spawn(_readCacheFile, Messenger({
      'path': _getCachePath(strategy.key),
      'cache_name': cacheFileName,
    }, receivePort.sendPort));

    return completer.future;
  }

  @override
  FutureOr writeCache<TParam, TResult>(Action<TParam, TResult> action, covariant FileCacheStrategy strategy, TResult data, [TParam? param]) async {
    Map indexGroup = _indexMap.putIfAbsent(strategy.key, () => {});
    var indexName = _getIndexName(action.serializeParameter(param));
    var index = indexGroup.putIfAbsent(indexName, () => {});
    var iso8601 = index['expire'];

    if (iso8601 != null) {
      if (DateTime.parse(iso8601).compareTo(DateTime.now()) < 0) {
        //만료된 캐시 및 인덱스 제거
        indexGroup.remove(indexName);
        deleteCache(strategy.key, indexName, index['cache_name']);
      } else {
        //캐시가 유효하므로 스킵
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

    isolate = await Isolate.spawn(_writeCacheFile, Messenger({
      'path': _getCachePath(strategy.key),
      'index_name': indexName,
      'index_data': json.encode(index),
      'cache_name': cacheFileName,
      'cache_data': action.serializeResult(data)
    }, receivePort.sendPort));
  }

  String _getIndexName(String name) => 'index@${Uri.encodeFull(name)}';

  void deleteCache(String strategyKey, String indexName, String cacheName) async {
    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();

    subscription = receivePort.listen((_) async {
      await subscription?.cancel();
      receivePort.close();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(_deleteCacheFile, Messenger({
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
      print('인덱스 쓰기 : $indexData');
      await _writeFile(path, indexName, indexData);
      await _writeFile(path, cacheName, cacheData);
      success = true;
    } catch(error) {
      //ignore
      print(error);
    }
    messenger.reply(success);
  }

  static void _readIndexFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var indexName = messenger.parameters['index_name'];

    await _readFile(path, indexName).then((value) {
      print('인덱스 읽기 성공: $value');
      messenger.reply(value);
    }, onError: (error, stackTrace) {
      print('인덱스 읽기 실패');
      messenger.reply(null);
    });
  }

  static void _readCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var fileName = messenger.parameters['cache_name'];

    await _readFile(path, fileName).then((value) {
      print('캐시 읽기 성공: $value');
      messenger.reply(value);
    }, onError: (error, stackTrace) {
      print('캐시 읽기 실패');
      messenger.reply(null);
    });
  }

  static void _deleteCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var indexName = messenger.parameters['index_name'];
    var fileName = messenger.parameters['cache_name'];

    var success = false;
    try {
      await _deleteFile(path, indexName);
      await _deleteFile(path, fileName);
      success = true;
    } catch(error) {
      //ignore
      print(error);
    }
    messenger.reply(success);
  }

  @override
  Type get runtimeType => FileCache;

  @override
  void clear() {
    var path = _getLocalCacheDir(this.path);
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

  static String _getLocalCacheDir(String path, [String? path2]) {
    return _concatPath(path, 'local_cache/');
  }

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

    var file = _getFile(cacheDir.path, '$fileName.json');
    if (file.lengthSync() == 0) {
      completer.complete(null);
    } else {
      file.openRead()
        .transform(utf8.decoder)
        .listen((data) {
          completer.complete(data);
        }, onError: (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      );
    }
    return completer.future;
  }

  static FutureOr _writeFile(String path, String fileName, dynamic data) async {
    var cacheDir = Directory(path);
    if (!await cacheDir.exists()) {
      cacheDir = await cacheDir.create(recursive: true);
    }

    var file = _getFile(cacheDir.path, '$fileName.json');
    var sink = file.openWrite();
    sink.write(data);
    await sink.flush();
    return await sink.close();
  }

  static FutureOr _deleteFile(String path, String fileName) async {
    var filePath = _concatPath(path, '$fileName.json');
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