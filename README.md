A library for Dart developers.

## Usage

A simple usage example:

```dart
import 'package:action_box/action_box.dart';
//add
import 'example.config.dart';

@ActionBoxConfig(
    actionBoxTypeName: 'MyActionBox',
    actionRootTypeName: 'ActionRoot',
    generateForDir: ['*']
)
final actionBox = MyActionBox.instance;

void howToUse() {
  //request data
  actionBox.dispatch(action: (d) => d.valueConverter.getStringInStringOutValue);
  //or
  actionBox(
    action: (root) => root.valueConverter.getStringInStringOutValue,
    param: 'test',
  );

  //subscribe result
  actionBox.subscribe(
      action: (d) => d.valueConverter.getStringInStringOutValue,
      onNext: (String result) {
        print(result);
      }
  );
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/yookjy/action_box/issues
