import 'dart:async';

import 'package:action_box/src/cache/cache_provider.dart';
import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/core/action_descriptor.dart';
import 'package:action_box/src/core/action_directory.dart';

abstract class ActionBoxBase<TActionDirectory extends ActionDirectory> {
  late final TActionDirectory _root = _rootFactory.call();
  late final TActionDirectory Function() _rootFactory;
  late final StreamController _universalStreamController =
      _universalStreamFactory?.call() ?? StreamController.broadcast();
  final CacheProvider _cacheProvider;
  final StreamController Function()? _universalStreamFactory;

  final Duration _defaultTimeout;

  Stream get universalStream => _universalStreamController.stream;

  ActionBoxBase(this._rootFactory,
      {Duration? defaultTimeout,
      StreamController Function()? universalStreamFactory,
      List<CacheStorage?>? cacheStorages})
      : _defaultTimeout = defaultTimeout ?? const Duration(seconds: 3),
        _universalStreamFactory = universalStreamFactory,
        _cacheProvider = CacheProvider(cacheStorages ?? []);

  void clearCache() {
    _cacheProvider.clear();
  }

  void dispose() {
    _root.dispose();
    _universalStreamController.close();
    _cacheProvider.dispose();
  }

  ActionExecutor<TParam, TResult, TAction>
      call<TParam, TResult, TAction extends Action<TParam, TResult>>(
          ActionDescriptor<TAction, TParam, TResult> Function(TActionDirectory)
              action) {
    var descriptor = action(_root);
    return descriptor.call(
        _universalStreamController, _defaultTimeout, _cacheProvider);
  }
}
