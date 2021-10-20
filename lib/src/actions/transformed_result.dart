class TransformedResult<TResult> {
  final TResult result;
  final bool isTransformed;

  TransformedResult(this.isTransformed, this.result);
}
