import 'dart:async';

final class Nothing {
  Nothing();
}

sealed class IO<A> {

  IO<B> map<B>(B Function(A) f) => IOMap(this, f);

  IO<B> flatMap<B>(IO<B> Function(A) f) => IOFlatMap(this, f);

  IO<B> andThan<B>(IO<B> Function() f) => IOAndThan(this, f);

  IO<A> foreach(Function(A) f) => IOForeach(this, f);

  IO<A> filter(bool Function(A) f) => IOFilter(this, f);

  IO<A> filterWith(IO<bool> Function(A) f) => IOFilterWith(this, f);

  IO<A> or(A value) => IOOr(this, value);

  IO<A> orElse(IO<A> Function() f) => IOOrElse(this, f);

  IO<A> debug({String? label}) => IODebug(this, label);

  IO<A> catchAll(void Function(Exception) f) => IOCatchAll(this, f);

  IO<A> recover(A Function(Exception) f) => IORecover(this, f);

  IO<A> recoverWith(IO<A> Function(Exception) f) => IORecoverWith(this, f);

  IO<A> failWith(FutureOr<Exception?> Function(A) f) => IOFailWith(this, f);

  IO<A> failIf(bool Function(A) f, {Exception? exception, String? message}) =>
      IOFailIf(this, f, exception ?? Exception(message ?? "IOApp error"));

  IO<A> retry(int retryCount, {Duration interval = const Duration(milliseconds: 10)}) =>
      IORetry(this, retryCount, interval);

  IO<A> retryIf(FutureOr<bool> Function(A) f, int retryCount, {Duration interval = const Duration(milliseconds: 10)}) =>
      IORetryIf(this, f, retryCount, interval);

  IO<A> timeout(Duration duration) => IOTimeout(this, duration);

  IO<A> sleep(Duration duration) => IOSleep(this, duration);

  IO<A> rateLimit(Duration rateInterval) => IORateLimit(this, rateInterval);

  IO<B> cast<B>() => this as IO<B>;

  IO<A> ensure(FutureOr Function() f)  => IOEnsure(this, f);

  IO<A> touch(FutureOr<void> Function(A) f) =>
      IOTouch(this, (A x) async { await f(x); return Nothing(); });

  static IO<A> fromError<A>(Exception err) => IOFromError(err);

  static IO<void> effect(FutureOr<void> Function() f) =>
      IOEffect(() {f(); return Nothing();});

  static IO<void> println(String msg) => effect(() => print(msg));

  static IO<List<B>> traverseM<A, B>(List<A> items, IO<B> Function(A) f,
      {int? maxParallelism}) => IOTraverseM(items, maxParallelism, f);

  static IO<List<B>> traverse<A, B>(
      List<A> items, FutureOr<B> Function(A) f, {int? maxParallelism}) =>
      IOTraverse(items, maxParallelism, f);


  static IO<A> pure<A>(A value) => IOPure(() => value);

  static IO<A> fromPure<A>(A Function() value) => IOPure(value);

  static IO<A> attempt<A>(FutureOr<A> Function() f) => IOAttempt(f);

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
  final FutureOr<B> Function() computation;
  IOAttempt(this.computation);

  FutureOr<B> apply() => computation();
}

class IOTraverseM<A, B> extends IO<List<B>> {
  final List<A> items;
  final IO<B> Function(A) computation;
  final int? maxParallelism;
  IOTraverseM(this.items, this.maxParallelism, this.computation);

  IO<B> apply(dynamic value) => computation(value as A);

  List<B> convert(List value) => value.map((x) => x as B).toList();
}

class IOTraverse<A, B> extends IO<List<B>> {
  final List<A> items;
  final FutureOr<B> Function(A) computation;
  final int? maxParallelism;
  IOTraverse(this.items, this.maxParallelism, this.computation);

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

  FutureOr apply(A value) => computation(value);
}

class IOFilter<A> extends IO<A> {
  final IO<A> last;
  final bool Function(A) computation;
  IOFilter(this.last, this.computation);

  bool apply(A value) => computation(value);
}

class IOFilterWith<A> extends IO<A> {
  final IO<A> last;
  final IO<bool> Function(A) computation;
  IOFilterWith(this.last, this.computation);

  IO<bool> apply(A value) => computation(value);
}

class IOOr<A> extends IO<A> {
  final IO<A> last;
  final A value;
  IOOr(this.last, this.value);
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
  final A Function(Exception) computation;
  IORecover(this.last, this.computation);
}

class IORecoverWith<A> extends IO<A> {
  final IO<A> last;
  final IO<A> Function(Exception) computation;
  IORecoverWith(this.last, this.computation);
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

class IOSleep<A> extends IO<A> {
  final IO<A> last;
  final Duration duration;
  IOSleep(this.last, this.duration);
}

class IORetry<A> extends IO<A> {
  final IO<A> last;
  final int retryCount;
  final Duration interval;
  IORetry(this.last, this.retryCount, this.interval);
}

class IORetryIf<A> extends IO<A> {
  final IO<A> last;
  final int retryCount;
  final Duration interval;
  final FutureOr<bool> Function(A) computation;
  IORetryIf(this.last, this.computation, this.retryCount, this.interval);
}

class IORateLimit<A> extends IO<A>{
  final IO<A> last;
  final Duration rateInterval;
  IORateLimit(this.last, this.rateInterval);
}

class IOFailWith<A> extends IO<A>{
  final IO<A> last;
  final FutureOr<Exception?> Function(A) computation;
  IOFailWith(this.last, this.computation);
}

class IOFailIf<A> extends IO<A>{
  final IO<A> last;
  final bool Function(A) computation;
  final Exception exception;
  IOFailIf(this.last, this.computation, this.exception);
}

class IOFromError<A> extends IO<A>{
  final Exception err;
  IOFromError(this.err);
}

class IOEnsure<A> extends IO<A> {
  final IO<A> last;
  final FutureOr Function() computation;
  IOEnsure(this.last, this.computation);
}

class IOEffect extends IO<Nothing> {
  final FutureOr<Nothing> Function() computation;
  IOEffect(this.computation);
}

class IOTouch<A> extends IO<A> {
  final IO<A> last;
  final FutureOr<Nothing> Function(A) computation;
  IOTouch(this.last, this.computation);

  FutureOr<Nothing> apply(A value) => computation(value);
}

T identity<T>(T value) => value;

extension Lift<T> on T {
  IO<T> get lift => IO.pure(this);
}

extension LiftFuture<T> on Future<T> {
  IO<T> get lift => IO.attempt(() => this);
}
