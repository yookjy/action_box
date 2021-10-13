class TransformedResult<TResult> {
  final TResult _result;
  TResult get result => _result;

  final bool _isTransformed;
  bool get isTransformed => _isTransformed;

  TransformedResult(this._isTransformed, this._result);
}