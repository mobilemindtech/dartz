import 'dart:async';

sealed class IO<A> {

  IO<B> map<B>(B Function(A) f) => IOMap(this, f);

  IO<B> flatMap<B>(IO<B> Function(A) f) => IOFlatMap(this, f);

  IO<B> andThan<B>(IO<B> Function() f) => IOAndThan(this, f);

  IO<A> foreach(Function(A) f) => IOForeach(this, f);

  IO<A> filter(bool Function(A) f) => IOFilter(this, f);

  IO<A> or(A Function() f) => IOOr(this, f);

  IO<A> orElse(IO<A> Function() f) => IOOrElse(this, f);

  IO<A> debug({String? label}) => IODebug(this, label);

  IO<A> catchAll(Function(Exception) f) => IOCatchAll(this, f);

  IO<A> recover(IO<A> Function(Exception) f) => IORecover(this, f);

  IO<A> retry(int retryCount) => IORetry(this, retryCount);

  IO<A> timeout(Duration duration) => IOTimeout(this, duration);

  static IO<List<B>> parMapM<A, B>(List<A> items, IO<B> Function(A) f,
      {int? maxParallelism}) => IOParMapM(items, maxParallelism, f);

  static IO<List<B>> parMap<A, B>(
      List<A> items, FutureOr<B> Function(A) f, {int? maxParallelism}) =>
      IOParMap(items, maxParallelism, f);


  static IO<A> pure<A>(A value) => IOPure(() => value);

  static IO<A> fromPure<A>(A Function() value) => IOPure(value);

  static IO<A> attempt<A>(A Function() f) => IOAttempt(f);

  static IO<A> fromAsync<A>(Future<A> Function() f) => IOAsync(f);

  static IO<B> fold<A, B>(List<A> items, B initialValue, B Function(B, A) f) =>
    IOFold(items, initialValue, f);

  static IO<A> raceM<A>(List<IO<A>> ios, {bool ignoreErrors = false}) =>
      IORaceM(ios, ignoreErrors);

  static IO<B> race<A, B>(List<A> items, FutureOr<B> Function(A) f, {bool ignoreErrors = false}) =>
      IORace(items, ignoreErrors, f);

}

class IOMap<A, B> extends IO<B> {
  final IO<A> last;
  final B Function(A) computation;
  IOMap(this.last, this.computation);

  B apply(A value) => computation(value);
}

class IOFlatMap<A, B> extends IO<B> {
  final IO<A> last;
  final IO<B> Function(A) computation;
  IOFlatMap(this.last, this.computation);

  IO<B> apply(A value) => computation(value);
}

class IOFold<A, B> extends IO<B> {
  final B Function(B, A) computation;
  final B initialValue;
  final List<A> items;
  IOFold(this.items, this.initialValue, this.computation);

  B apply(B acc, A value) => computation(acc, value);
}

class IOPure<A> extends IO<A> {
  final A Function() computation;
  IOPure(this.computation);
}

class IOAttempt<A, B> extends IO<B> {
  final B Function() computation;
  IOAttempt(this.computation);
}

class IOAsync<A, B> extends IO<B> {
  final Future<B> Function() computation;
  IOAsync(this.computation);
}

class IOParMapM<A, B> extends IO<List<B>> {
  final List<A> items;
  final IO<B> Function(A) computation;
  final int? maxParallelism;
  IOParMapM(this.items, this.maxParallelism, this.computation);

  IO<B> apply(dynamic value) => computation(value as A);

  List<B> convert(List value) => value.map((x) => x as B).toList();
}

class IOParMap<A, B> extends IO<List<B>> {
  final List<A> items;
  final FutureOr<B> Function(A) computation;
  final int? maxParallelism;
  IOParMap(this.items, this.maxParallelism, this.computation);

  FutureOr<B> apply(dynamic value) => computation(value as A);

  List<B> convert(List value) => value.map((x) => x as B).toList();
}

class IORaceM<A> extends IO<A> {
  final List<IO<A>> items;
  final bool ignoreErrors;
  IORaceM(this.items, this.ignoreErrors);
}

class IORace<A, B> extends IO<B> {
  final List<A> items;
  final bool ignoreErrors;
  final FutureOr<B> Function(A) computation;
  IORace(this.items, this.ignoreErrors, this.computation);

  FutureOr<B> apply(A value) => computation(value);
}

class IOAndThan<A, B> extends IO<B> {
  final IO<A> last;
  final IO<B> Function() computation;
  IOAndThan(this.last, this.computation);
}

class IOForeach<A> extends IO<A> {
  final IO<A> last;
  final Function(A) computation;
  IOForeach(this.last, this.computation);

  dynamic apply(A value) => computation(value);
}

class IOFilter<A> extends IO<A> {
  final IO<A> last;
  final bool Function(A) computation;
  IOFilter(this.last, this.computation);

  bool apply(A value) => computation(value);
}

class IOOr<A> extends IO<A> {
  final IO<A> last;
  final A Function() computation;
  IOOr(this.last, this.computation);
}

class IOOrElse<A> extends IO<A> {
  final IO<A> last;
  final IO<A> Function() computation;
  IOOrElse(this.last, this.computation);
}

class IOCatchAll<A> extends IO<A> {
  final IO<A> last;
  final Function(Exception) computation;
  IOCatchAll(this.last, this.computation);
}

class IORecover<A> extends IO<A> {
  final IO<A> last;
  final IO<A> Function(Exception) computation;
  IORecover(this.last, this.computation);
}

class IODebug<A> extends IO<A> {
  final IO<A> last;
  final String? label;
  IODebug(this.last, this.label);
}

class IOTimeout<A> extends IO<A> {
  final IO<A> last;
  final Duration duration;
  IOTimeout(this.last, this.duration);
}

class IORetry<A> extends IO<A> {
  final IO<A> last;
  final int retryCount;
  IORetry(this.last, this.retryCount);
}

extension IntToDuration on int {
  Duration get seconds => Duration(seconds: this);
  Duration get minutes => Duration(minutes: this);
  Duration get micros => Duration(microseconds: this);
  Duration get millis => Duration(milliseconds: this);
}