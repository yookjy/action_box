class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  Tuple2(this.item1, this.item2);
}

class Tuple3<T1, T2, T3> extends Tuple2<T1, T2> {
  final T3 item3;
  Tuple3(item1, item2, this.item3) : super(item1, item2);
}

class Tuple4<T1, T2, T3, T4> extends Tuple3<T1, T2, T3> {
  final T4 item4;
  Tuple4(item1, item2, item3, this.item4) : super(item1, item2, item3);
}

class Tuple5<T1, T2, T3, T4, T5> extends Tuple4<T1, T2, T3, T4> {
  final T5 item5;
  Tuple5(item1, item2, item3, item4, this.item5)
      : super(item1, item2, item3, item4);
}