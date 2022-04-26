import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:action_box/action_box.dart';
// import 'package:rxdart/rxdart.dart';

import 'action_box.dart';

//import 'package:rxdart/rxdart.dart';
// You can use code generator. https://pub.dev/packages/action_box_generator
// If you use a generator, the following files are automatically created.
//  => action descriptor(directory) files : value_converter.dart, action_root.dart
//  => action_box.dart
@ActionBoxConfig(
    //actionRootType: 'ActionRoot', //optional
    generateSourceDir: ['lib', 'example']) //optional
final actionBox = ActionBox.shared(
    // You can use rx dart's operator to avoid duplication of errors.
    // createUniversalStreamController: () => PublishSubject()
    // ..bufferTime(Duration(milliseconds: 500))
    //   .where((x) => x.isNotEmpty)
    //   .flatMap((x) =>
    //   (x as PublishSubject<Object>).distinct((pre, cur) => pre == cur))
    handleCommonError: (error, universalSink) {
      // if (error.innerError is Exception) {
      //   universalSink.add('convert error to global data');
      //   error.handled = true;
      //   //return true;
      // }
    },
    cacheStorages: [
      MemoryCache.create(),
      FileCache.fromPath(Directory.current.path)
    ])
  ..universalStream.listen((event) {
    print('global data listener => $event');
  }, onError: (error, stackTrace) {
    print('global error handler => $error');
  });

void main() async {
  var bag = DisposeBag();

  //receive result
  // actionBox((a) => a.valueConverter.getStringToListValue)
  //     .map(channel: (a) => a.ch1)
  //     .listen((result) {
  //   result?.forEach((v) => print(v));
  // }, onError: (e) {
  //   print('error $e');
  // }).disposedBy(bag);
  //
  actionBox((a) => a.valueConverter.getStringToListValue)
      .map(channel: (a) => a.ch1 | a.general)
      .listen((result) {
    result?.forEach((v) => print(v));
  }, onError: (e) {
    print('error $e');
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getStringToListValue).map().listen(
      (result) {
    result?.forEach((v) => print(v));
  }, onError: (e) {
    print('error $e');
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getListToTupleValue).map().listen((result) {
    print(result);
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getStringToNullableValue)
      .map()
      .listen((result) {
    print('nullable => $result');
  }).disposedBy(bag);

  //request data
  // actionBox((a) => a.valueConverter.getStringToListValue).go(
  //     channel: (c) => c.ch1,
  //     param: 'value',
  //     cacheStrategy: const CacheStrategy.file(Duration(minutes: 5),
  //         codec: JsonCodec(reviver: Revivers.stringArr)),
  //     begin: () {/* before dispatching */},
  //     end: (success) {/* after dispatching */},
  //     timeout: Duration(seconds: 10));
  //
  // actionBox((a) => a.valueConverter.getListToTupleValue).go(
  //     param: ['apple', 'graph', 'orange', 'strawberry'],
  //     cacheStrategy: const CacheStrategy.file(Duration(minutes: 5),
  //         codec: JsonCodec(reviver: Revivers.stringTuple3)),
  //     timeout: Duration(seconds: 10));

  // await Future.delayed(Duration(seconds: 1));
  //
  // actionBox((a) => a.valueConverter.getStringToListValue).go(
  //     channel: (c) => c.ch1,
  //     param: 'value',
  //     cacheStrategy: const CacheStrategy.file(Duration(minutes: 2),
  //         codec: JsonCodec(reviver: Revivers.stringArr)),
  //     begin: () {/* before dispatching */},
  //     end: (success) {/* after dispatching */},
  //     timeout: Duration(seconds: 10));

  // actionBox((a) => a.valueConverter.getListToTupleValue).go(
  //     param: ['apple', 'graph', 'orange', 'strawberry'],
  //     cacheStrategy: const CacheStrategy.file(Duration(minutes: 5),
  //         codec: JsonCodec(reviver: Revivers.stringTuple3)),
  //     timeout: Duration(seconds: 10));

  // actionBox((a) => a.valueConverter.getStringToListValue)
  //     .when(() => true, (a) => a.echo(value: ['e', 'c', 'h', 'o']))
  //     .when(() => true, (a) => a.echo(value: null))
  //     .when(() => true, (a) => a.drain(param: 'ignore'))
  //     .go(param: 'real value');
  //
  // actionBox((a) => a.valueConverter.getStringToListValue).drain(
  //     param: 'waste',
  //     end: (success) {
  //       print(success);
  //     });

  var errStream = StreamController()..disposedBy(bag);
  errStream.stream.listen((event) {
    print('local onData => $event');
  }, onError: (error, stackTrace) {
    print('local onError => $error \n $stackTrace');
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getStringToCharValue).map().listen((v) {
    print(v);
  }, onError: (error, stackTrace) {
    print('inline onError => $error \n $stackTrace');
  });

  actionBox((a) => a.valueConverter.getStringToCharValue).go(
      param: 'This is test for iterable stream!',
      handleError: (error, stackTrace) {
        errStream.addError(error.innerError, stackTrace);
        error.handled = true;
      });

  actionBox((a) => a.valueConverter.getStringToNullableValue).go(param: '');

  await Future.delayed(Duration(seconds: 5));
  //call dispose method when completed

  bag.dispose();
  actionBox.dispose();
  print('terminated!');
}

class Revivers {
  static Object stringArr(k, v) {
    if (k == null && v is List) {
      return v.cast<String>().toList();
    }
    return v;
  }

  static Object stringTuple3(k, v) {
    if (k == null && v is Map) {
      return Tuple3<String, String, String>.fromMap(v);
    }
    return v;
  }
}
