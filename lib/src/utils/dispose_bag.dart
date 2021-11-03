import 'dart:async';
import 'dart:developer';

import 'package:action_box/src/utils/disposable.dart';
import 'package:rxdart/rxdart.dart';

class DisposeBag extends Disposable {
  final Map _bag = {};

  @override
  void dispose() {
    _bag.entries.forEach((pair) {
      if (pair.value is Disposable) {
        pair.value.dispose();
      } else if (pair.value is StreamSubscription) {
        pair.value.cancel();
      } else if (pair.value is Subject) {
        pair.value.close();
      }

      log('${pair.key} : ${pair.value.runtimeType.toString()}\'s instance has been released.');
    });
    _bag.clear();
  }

  void add<T>(T disposable, [String? key]) {
    var id = (key?.isNotEmpty == true) ? key! : createKey(disposable);
    if (_bag.containsKey(id)) {
      throw ArgumentError('Duplicated key for disposable object.');
    }
    _bag[id] = disposable;
  }

  bool containsKey(String key) => _bag.containsKey(key);

  String createKey<T>(T disposable) => disposable.hashCode.toString();
}

extension StreamSubscriptionExtension on StreamSubscription {
  StreamSubscription disposedBy(DisposeBag bag, [String? key]) {
    bag.add(this, key);
    return this;
  }
}

extension SubjectBagExtension on Subject {
  T disposedBy<T extends Subject>(DisposeBag bag, [String? key]) {
    bag.add(this, key);
    return this as T;
  }
}
