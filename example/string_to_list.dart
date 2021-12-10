import 'dart:async';
import 'dart:convert';

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
  List<String>? deserializeResult(String source) {
    return json.decode(source, reviver: (k, v) {
      if (v is List) {
        return v.cast<String>().toList();
      }
      return v;
    });
  }


}
