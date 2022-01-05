import 'dart:async';

import 'package:action_box/action_box.dart';

@ActionConfig(alias: 'getListToTupleValue', parents: ['valueConverter'])
class ListToTuple
    extends Action<List<String>, Tuple3<String, String, String>?> {
  final Channel ch1 = Channel();

  @override
  Stream<Tuple3<String, String, String>?> process([List<String>? param]) {
    if ((param?.length ?? 0) >= 3) {
      return Stream.value(Tuple3(param![0], param[1], param[2]));
    }
    return Stream.empty();
  }
}
