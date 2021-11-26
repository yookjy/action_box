import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/core/transformed_result.dart';
import 'package:action_box/src/core/channel.dart';
import 'package:action_box/src/utils/tuple.dart';

abstract class DataCachingAction<TParam, TResult> extends Action<TParam, TResult> {

  @override
  FutureOr<Stream<TResult>> process([TParam? param]);


}

/*
{
  'id: '9f2c7c23-c9f0-4635-8614-8c19753d8468',
  'expire': '2021-01-31 23:59:59.000',
  'param': {... param data},
  'result' : {... result data}
}
 */