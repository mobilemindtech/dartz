
import 'dart:async';
import 'io.dart';

class Resource<R> {
  FutureOr<R> Function() acquire;
  FutureOr Function(R) release;
  Resource(this.acquire, this.release);
  IO<A> use<A>(IO<A> Function(R) f) =>
      IO.attempt(acquire)
          .flatMap((r) => f(r).ensure(() => release(r)));
}