import 'package:action_box/action_box.dart';

import 'value_converter.dart';

class ActionRoot extends ActionDirectory {
  ValueConverter get valueConverter =>
      putIfAbsentDirectory(() => ValueConverter());
}
