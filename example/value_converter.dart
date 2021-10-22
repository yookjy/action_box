import 'package:action_box/action_box.dart';

import 'string_to_list.dart';

class ValueConverter extends ActionDirectory {
  ActionDescriptor<StringToListOut, String, List<String>?>
      get getStringToListValue => putIfAbsentDescriptor(
          'getStringToListValue', () => StringToListOut());
}
