class UnhandledException implements Exception {
  final String _message;

  UnhandledException(this._message);

  @override
  String toString() => 'UnhandledException: $_message';
}