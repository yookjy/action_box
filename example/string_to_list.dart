import 'package:action_box/action_box.dart';

@ActionConfig(alias: 'getStringToListValue', parents: ['valueConverter'])
class StringToListOut extends Action<String, List<String>?> {
  @override
  Stream<List<String>?> process([String? param]) {
    var list = <String>[];
    if (param != null && param.isNotEmpty) {
      for (var i = 0; i < param.length; i++) {
        list.add(param[i]);
      }
    }
    return Stream.value(list);
  }
}
