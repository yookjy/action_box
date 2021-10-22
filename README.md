A library for Dart developers.

## Usage

A simple usage example:

```dart
import 'package:action_box/action_box.dart';
//add generated file
import 'example.a.b.dart';

@ActionBoxConfig(
    actionBoxType: 'MyActionBox',
    actionRootType: 'ActionRoot',
    generateSourceDir: ['*']
)
final actionBox = MyActionBox.instance;

void howToUse() {
  //request data
  actionBox.go(action: (d) => d.valueConverter.getStringInStringOutValue);
  //or
  actionBox(
    action: (root) => root.valueConverter.getStringInStringOutValue,
    param: 'test',
  );

  //subscribe result
  actionBox(
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
