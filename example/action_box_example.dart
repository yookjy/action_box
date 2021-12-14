import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/cache/file_cache.dart';
import 'package:action_box/src/cache/memory_cache.dart';
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
    // errorStreamFactory: () => PublishSubject()
    // ..bufferTime(Duration(milliseconds: 500))
    //   .where((x) => x.isNotEmpty)
    //   .flatMap((x) =>
    //   (x as PublishSubject<Object>).distinct((pre, cur) => pre == cur))
    cacheStorageProviders: [
      MemoryCache.create(),
      FileCache.fromPath(Directory.current.path)
    ])
  ..exceptionStream.listen((event) {
    print('global error handler => $event');
  });

void main() async {
  var bag = DisposeBag();

  //receive result
  actionBox((a) => a.valueConverter.getStringToListValue)
      .map(channel: (a) => a.ch1)
      .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);
  //
  actionBox((a) => a.valueConverter.getStringToListValue)
      .map(channel: (a) => a.ch1 | a.defaultChannel)
      .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getStringToListValue)
      .map(channel: (a) => a.ch1)
      .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);

  //request data
  actionBox((a) => a.valueConverter.getStringToListValue).go(
      channel: (c) => c.ch1,
      param: 'value',
      cacheStrategy: FileCacheStrategy('test_key_0000',
          expire: const Duration(minutes: 5)),
      // cacheStrategy: MemoryCacheStrategy(expire: const Duration(minutes: 5)),
      begin: () {/* before dispatching */},
      end: (success) {/* after dispatching */},
      timeout: Duration(seconds: 10));

  await Future.delayed(Duration(seconds: 1));

  actionBox((a) => a.valueConverter.getStringToListValue).go(
      channel: (c) => c.ch1,
      param: 'value',
      cacheStrategy: FileCacheStrategy('test_key_0000',
          expire: const Duration(minutes: 2)),
      begin: () {/* before dispatching */},
      end: (success) {/* after dispatching */},
      timeout: Duration(seconds: 10));

  actionBox((a) => a.valueConverter.getStringToListValue)
      .when(() => true, (a) => a.echo(value: ['e', 'c', 'h', 'o']))
      .when(() => true, (a) => a.echo(value: null))
      .when(() => true, (a) => a.drain(param: 'ignore'))
      .go(param: 'real value');

  actionBox((a) => a.valueConverter.getStringToListValue).drain(
      param: 'waste',
      end: (success) {
        print(success);
      });

  var errStream = StreamController()..disposedBy(bag);
  errStream.stream.listen((event) {
    print('local => $event');
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getStringToCharValue).map().listen((v) {
    print(v);
  }, onError: (error) {
    print('onError => $error');
  });

  actionBox((a) => a.valueConverter.getStringToCharValue).go(
      param: 'This is iterable stream test!',
      errorSinks: (global, pipeline) => [global, pipeline, errStream]);

  await Future.delayed(Duration(seconds: 5));
  //call dispose method when completed

  bag.dispose();
  actionBox.dispose();
  print('terminated!');
}