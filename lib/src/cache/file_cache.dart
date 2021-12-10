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
    var paramKey = 'pk@${action.serializeParameter(param)}';

    // 메모리에 인덱스가 존재하지 않거나 파람키가 존재하지 않거나 만료되었으면, 인덱스 로드
    if (!_indexMap.containsKey(strategy.key) || !_indexMap[strategy.key].containsKey(paramKey)) {
      var receivePort = ReceivePort();
      Isolate? isolate;
      StreamSubscription? subscription;

      subscription = receivePort.listen((message) {
        if (message == null) {
          completer.complete(null);
        } else {
          Map cache = json.decode(message);
          var index = cache[paramKey];
          var expire = DateTime.parse(index['expire']);

          if (expire.compareTo(DateTime.now()) < 0) {
            // 캐시가 만료 되었으므로 삭제 하고 중단.
            cache.remove(paramKey);
            deleteCache(strategy.key, cache, index['cache_file_name']);
            completer.complete(null);
          } else {
            // 메모리에 캐시 내용 저장
            _indexMap.putIfAbsent(strategy.key, () => cache);
            completer.complete(index);
          }
        }
        receivePort.close();
        subscription?.cancel();
        isolate?.kill();
      });

      isolate = await Isolate.spawn(_readIndexFile, Messenger({
        'path': _getCachePath(strategy.key),
      }, receivePort.sendPort));
    } else {
      var cache = _indexMap[strategy.key];
      var index = cache[paramKey];
      completer.complete(index);
    }

    return completer.future;
  }

  @override
  FutureOr<Stream<TResult>> readCache<TParam, TResult>(Action<TParam, TResult> action, covariant FileCacheStrategy strategy, TParam? param) async {
    var index = await _readIndex(action, strategy, param);
    print('인덱스: $index');
    TResult? data;
    if (index != null && (data = await _readCacheData(action, strategy, index['cache_file_name'])) != null){
      return Stream.value(data!);
    }
    return action.process(param);
  }

  Future<TResult?> _readCacheData<TParam, TResult>(Action<TParam, TResult> action, FileCacheStrategy strategy, String cacheFileName) async {
    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();
    var completer = Completer<TResult?>();

    subscription = receivePort.listen((message) {
      var result = action.deserializeResult(message);
      completer.complete(result);

      receivePort.close();
      subscription?.cancel();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(_readCacheFile, Messenger({
      'path': _getCachePath(strategy.key),
      'cache_file_name': cacheFileName,
    }, receivePort.sendPort));

    return completer.future;
  }

  @override
  FutureOr writeCache<TParam, TResult>(Action<TParam, TResult> action, covariant FileCacheStrategy strategy, TResult data, [TParam? param]) async {

    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();
    Map index = _indexMap.putIfAbsent(strategy.key, () => {});

    var paramKey = 'pk@${action.serializeParameter(param)}';
    var paramKeySection = index.putIfAbsent(paramKey, () => {});
    var iso8601 = paramKeySection['expire'];

    if (iso8601 != null) {
      if (DateTime.parse(iso8601).compareTo(DateTime.now()) < 0) {
        //만료된 캐시 및 인덱스 제거
        index.remove(paramKey);
        deleteCache(strategy.key, index, paramKeySection['cache_file_name']);
      } else {
        //캐시가 유효하므로 스킵
        return;
      }
    }

    var cacheFileName = UUID.v4();
    index[paramKey] = paramKeySection;
    paramKeySection['expire'] = DateTime.now().add(strategy.expire).toIso8601String();
    paramKeySection['cache_file_name'] = cacheFileName;

    subscription = receivePort.listen((message) {
      receivePort.close();
      subscription?.cancel();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(_writeCacheFile, Messenger({
      'path': _getCachePath(strategy.key),
      'index': json.encode(index),
      'cache_file_name': cacheFileName,
      'data': action.serializeResult(data)
    }, receivePort.sendPort));
  }

  void deleteCache(String strategyKey, Map index, String cacheFileName) async {
    Isolate? isolate;
    StreamSubscription? subscription;
    var receivePort = ReceivePort();

    subscription = receivePort.listen((message) {
      receivePort.close();
      subscription?.cancel();
      isolate?.kill();
    });

    isolate = await Isolate.spawn(_deleteCacheFile, Messenger({
      'path': _getCachePath(strategyKey),
      'index': index.isEmpty ? null : json.encode(index),
      'cache_file_name': cacheFileName,
    }, receivePort.sendPort));
  }

  static void _writeCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var index = messenger.parameters['index'];
    var fileName = messenger.parameters['cache_file_name'];
    var data = messenger.parameters['data'];

    var success = false;
    try {
      print('인덱스 쓰기 : $index');
      await _writeFile(path, 'index', index);
      await _writeFile(path, '$fileName', data);
      success = true;
    } catch(error) {
      //ignore
      print(error);
    }
    messenger.sendPort.send(success);
  }

  static void _readIndexFile(Messenger messenger) async {
    var path = messenger.parameters['path'];

    await _readFile(path, 'index').then((value) {
      print('인덱스 읽기 성공: $value');
      messenger.sendPort.send(value);
    }, onError: (error, stackTrace) {
      print('인덱스 읽기 실패');
      messenger.sendPort.send(null);
    });
  }

  static void _readCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var fileName = messenger.parameters['cache_file_name'];

    await _readFile(path, fileName).then((value) {
      print('캐시 읽기 성공: $value');
      messenger.sendPort.send(value);
    }, onError: (error, stackTrace) {
      print('캐시 읽기 실패');
      messenger.sendPort.send(null);
    });
  }

  static void _deleteCacheFile(Messenger messenger) async {
    var path = messenger.parameters['path'];
    var index = messenger.parameters['index'];
    var fileName = messenger.parameters['cache_file_name'];

    var success = false;
    try {
      if (index == null) {
        print('인덱스 삭제');
        await _deleteFile(path, 'index');
      } else {
        print('(삭제요청)인덱스 덮어 쓰기 : $index');
        await _writeFile(path, 'index', index);
      }
      await _deleteFile(path, fileName);
      success = true;
    } catch(error) {
      //ignore
      print(error);
    }
    messenger.sendPort.send(success);
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

  static Future _writeFile(String path, String fileName, dynamic data) async {
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

  static Future _deleteFile(String path, String fileName) async {
    var filePath = _concatPath(path, '$fileName.json');
    var file = File(filePath);
    if (await file.exists()) {
      return file.delete();
    }
  }
}

class Messenger {

  final SendPort sendPort;

  final Map<String, dynamic> parameters;

  Messenger(this.parameters, this.sendPort);
}
