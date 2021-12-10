import 'dart:async';

import 'package:action_box/action_box.dart';

@ActionConfig(alias: 'getStringToCharValue', parents: ['valueConverter'])
class StringToChar extends Action<String, String> {

  @override
  Stream<String> process([String? param]) {
    return Stream.error(Exception('error test'));
    // return Stream.fromIterable(
    //     param!.codeUnits.map((e) => String.fromCharCode(e)));
  }
}
