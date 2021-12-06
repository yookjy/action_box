import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/utils/disposable.dart';
import 'package:action_box/src/utils/dispose_bag.dart';
import 'package:action_box/src/utils/tuple.dart';
import 'package:action_box/src/utils/uuid.dart';

import 'cache_storage.dart';

abstract class FileCache extends CacheStorage implements Disposable {
  const FileCache();

  factory FileCache.fromPath(String path) => _FileCache(path);
}

class _FileCache extends FileCache {

  final String path;

  Isolate? _isolate;
  final _receivePort = ReceivePort();
  final _sendPortCompleter = Completer<SendPort>();
  SendPort? _sendPort;

  _FileCache(this.path) : assert(path.isNotEmpty) {
    _initIsolate();
  }

  void _initIsolate() async {
    _receivePort.listen((message) async {
      if (message is SendPort)  {
        //_sendPortCompleter.complete(message);
        _sendPort = message;
        _sendPortCompleter.complete(_sendPort);
        message.send(Tuple3<String, String, dynamic>('read_index', path, null));
      } else {
        // 수신
        _callBackProcessIO(message);
      }
    });

    _isolate = await Isolate.spawn(processFileIO, _receivePort.sendPort);
  }

  void _callBackProcessIO(Tuple2<String, dynamic> message) {
    switch(message.item1) {
      case 'index_map':
        _indexMap = message.item2;
        break;
    }
  }

  @override
  FutureOr<Stream<TResult>>? readCache<TParam, TResult>(Action<TParam, TResult> action, CacheStrategy strategy,  [TParam? param]) {
    if (_indexMap == null || !_indexMap!.containsKey(action.defaultChannel.id)) {
      return null;
    }

    var section = _indexMap![action.defaultChannel.id];
    var index = section[json.encode(param)];
    var expire = DateTime.parse(index['expire']);
    var cacheFileId = index['cache_id'];

    if (expire.compareTo(DateTime.now()) < 0) {
      return null;
    }

    var completer = Completer<Stream<TResult>>();
    var file = _getFile(path, '$cacheFileId.json');
    file.openRead()
      .transform(utf8.decoder)
      .listen((data) {
        var controller = StreamController<TResult>();
        var cache = json.decode(data, reviver: action.resultReviver);
        completer.complete(controller.stream);
        controller.sink.add(cache);
    });
    return completer.future;
  }

  @override
  FutureOr writeCache<TParam, TResult>(Action<TParam, TResult> action, CacheStrategy strategy, TResult data, [TParam? param]) async {
    _indexMap ??= {};

    var cacheFileId = UUID.v4();
    _indexMap![action.defaultChannel.id] = {
      // if param is empty?
      json.encode(param) : {
        'expire' : DateTime.now().add(strategy.expire).toIso8601String(),
        'cache_id' : cacheFileId
      }
    };

    //var sendPort = await _sendPortCompleter.future;
    //sendPort.send(Tuple3<String, String, dynamic>('write_index', path, _indexMap));
    // sendPort.send(Tuple3<String, String, dynamic>('write_cache', path,
    //     {
    //       'id' : cacheFileId,
    //       'data' : jsonEncode(data, toEncodable: action.resultToJson)
    //     }));

    Isolate? isolate;
    var exit = ReceivePort();
    exit.listen((message) {
      isolate?.kill();
    });

    isolate = await Isolate.spawn(_writeCacheFile, Messenger({
      'path': path,
      'index_map': _indexMap,
      // 'cache_index_id': action.defaultChannel.id,
      // 'param': json.encode(param),
      // 'expire': DateTime.now().add(strategy.expire).toIso8601String(),
      'cache_file_id': cacheFileId,
      'data': jsonEncode(data, toEncodable: action.resultToJson)
    }/*, () {
      isolate?.kill();
    }*/), onExit: exit.sendPort);
  }

  static void _writeCacheFile(Messenger messenger) async {
    var index = messenger.parameters['index_map'];
    var path = messenger.parameters['path'];
    var cacheFileId = index['cache_file_id'];
    await _writeFile(
      path,
      'ab_cache_index.json',
      index);

    await _writeFile(
      path,
      '$cacheFileId.json',
      messenger.parameters['data']
    );

   // msg.completed();
  }



  @override
  Type get runtimeType => FileCache;

  @override
  FutureOr dispose() {
    _receivePort.close();
    _isolate?.kill();
  }

  @override
  void clear() {
    //TODO: implements
  }

  /*
  File structure
    <ab_cache_index.json - index file>
    file_name : <uuid>.json
      <uuid - action's default channel id> : {
        parameter(web url format) : {
          expire: 2021-12-31 23:59:59,
          cache_id: <uuid - in data directory>
        },
        parameter(web url format) : {
          expire: 2021-12-31 23:59:59,
          cache_id: <uuid - in data directory>
        },
        ...
      }

   */


  static void processFileIO(SendPort to) {
    final indexFileName = 'ab_cache_index.json';
    var from = ReceivePort();
    to.send(from.sendPort);

    from.listen((message) async {
      var tuple = message as Tuple3<String, String, dynamic>;
      switch(tuple.item1) {
        case 'read_index':
          var indexMap = await _readFile(tuple.item2, indexFileName);
          to.send(Tuple2('index_map', indexMap));
          break;
        case 'read_cache':
          break;
        case 'write_index':
         _writeFile(tuple.item2, indexFileName, tuple.item3);
          break;
        case 'write_cache':
         _writeFile(tuple.item2, '${tuple.item3['id']}.json', tuple.item3['data']);
          break;
        case 'kill':
          from.close();
          break;
      }
    });
  }


  static File _getFile(String path, String fileName) {
    var indexFilePath = _getFilePath(path, fileName);
    var indexFile = File(indexFilePath);
    if (!indexFile.existsSync()) {
      indexFile.createSync();
    }
    return indexFile;
  }

  static String _getFilePath(String path, String fileName) {
    var filePath = path;
    var separator = filePath.substring(filePath.length - 1, filePath.length);

    if (separator != r'/' && separator != r'\') {
      filePath += '/';
    }

    return filePath + fileName;
  }

  Map<String, dynamic>? _indexMap;

  static Future<Map<String, dynamic>> _readFile(String path, String fileName) {
    var completer = Completer<Map<String, dynamic>>();
    var file = _getFile(path, fileName);
    file.openRead()
      .transform(utf8.decoder)
      .listen((data) {
        var indexJson = json.decode(data);
        if (indexJson is Map<String, dynamic>) {
          //_indexMap = indexJson;
          completer.complete(indexJson);
        }
      }
    );
    return completer.future;
  }

  static Future _writeFile(String path, String fileName, dynamic data) async {
    var file = _getFile(path, fileName);
    var sink = file.openWrite();
    sink.write(data);
    await sink.flush();
    return await sink.close();
  }

}

class TwoWayPort extends SendPort implements Disposable {

  final SendPort sendPort;

  final ReceivePort _receivePort = ReceivePort();

  SendPort get receivePort => _receivePort.sendPort;

  TwoWayPort(this.sendPort);

  @override
  void send(Object? message) {
    sendPort.send(message);
  }

  @override
  FutureOr dispose() {
    _receivePort.close();
  }
}

class Messenger extends Disposable {

  final DisposeBag _disposeBag = DisposeBag();

  final StreamController _streamController = StreamController();

  final Map<String, dynamic> parameters;

  Messenger(this.parameters/*, this.completed*/) {
    _streamController.disposedBy(_disposeBag);

  }

  @override
  FutureOr dispose() {
    _disposeBag.dispose();
  }

}

class Message {
  //final Function() completed;

  final Map<String, dynamic> parameters;

  Message(this.parameters/*, this.completed*/);
}