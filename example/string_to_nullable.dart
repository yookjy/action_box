import 'dart:async';

import 'package:action_box/action_box.dart';

@ActionConfig(alias: 'getStringToNullableValue', parents: ['valueConverter'])
class StringToNullable extends Action<String, String?> {
  @override
  Stream<String?> process(String param) {
    return Stream.value(param.isEmpty ? null : param);
  }
}
