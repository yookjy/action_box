import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/actions/transformed_result.dart';
import 'package:action_box/src/channels/channel.dart';
import 'package:action_box/src/utils/tuple.dart';

abstract class DataCachingAction<TParam, TResult> extends Action<TParam, TResult> {

  @override
  FutureOr<Stream<TResult>> process([TParam? param]);

  void writeCache(IOSink ioSink, TResult data, [TParam? param]) ;

  // TResult readCache(Stream<String> stream, [TParam? param]) async {
  //   File file = File('');
  //   // var aa = await file.openRead()
  //   //   .transform(utf8.decoder)
  //   //   .transform(JsonObject())
  //   //   .forEach((line) {
  //   //
  //   // });
  //
  //
  // }
}

/*
{
  'id: '9f2c7c23-c9f0-4635-8614-8c19753d8468',
  'expire': '2021-01-31 23:59:59.000',
  'param': {... param data},
  'result' : {... result data}
}
 */