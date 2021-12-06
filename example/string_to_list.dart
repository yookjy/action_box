import 'dart:async';

import 'package:action_box/action_box.dart';

@ActionConfig(alias: 'getStringToListValue', parents: ['valueConverter'])
class StringToList extends Action<String, List<String>?> {
  Channel ch1 = Channel();

  @override
  Stream<List<String>?> process([String? param]) {
    var list = <String>[];
    if (param != null && param.isNotEmpty) {
      for (var i = 0; i < param.length; i++) {
        // return Stream.error(Exception('error'));
        list.add(param[i]);
      }
    }
    print('request');
    return Stream.value(list);
  }

  // @override
  // TransformedResult<List<String>?> transform(Object error) {
  //   return TransformedResult(['t', 'r', 'a', 'n', 's', 'f', 'o', 'r', 'm']);
  // }

  @override
  Object? Function(Object? p1, Object? p2) get resultReviver => (Object? key, Object? value) {
    if (value is List) {
      return value.cast<String>().toList();
    }
    return value;
  };
}
