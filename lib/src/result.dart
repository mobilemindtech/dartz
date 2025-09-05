import 'dart:async';

typedef void ifOk<T>(T value);
typedef void ifFailure(Exception value);

sealed  class Result<T> {
  static Result<A> ok<A>(A value) {
    return Ok(value);
  }

  static Result<A> failure<A>(Exception e, [StackTrace? stackTrace]) {
    return Failure(e, stackTrace);
  }

  static Future<Result<T>> of<T>(FutureOr<T> Function() f) async {
    try {
      return Result.ok(await f());
    } on Exception catch (err, stackTrace) {
      return Result.failure(err, stackTrace);
    } on Object catch (err, stackTrace) {
      return Result.failure(Exception("$err"), stackTrace);
    }
  }
  
  bool get isFailure => switch (this) { Failure<T>() => true, _ => false };

  bool get isOk => !isFailure;

  Result<T> always(Function f){
    f();
    return this;
  }

  Result<T> resolve(Function(T) fOk, Function(Exception, StackTrace?) fFailure, [Function()? fAlways]){
    switch(this){
      case Ok(:var value): fOk(value);
      case Failure failure: fFailure(failure.failure, failure.stackTrace);
    }
    if(fAlways != null){
      fAlways();
    }
    return this;
  }
}

class Ok<T> extends Result<T> {
  final T value;

  Ok(this.value);

  T get() {
    return this.value;
  }

  @override
  String toString() {
    return "Ok($value)";
  }
}

class Failure<T> extends Result<T> {
  final Exception err;
  final StackTrace? stackTrace;

  Failure(this.err, [this.stackTrace]);

  Exception get failure => err;

  factory Failure.msg(String msg) => Failure(Exception(msg));
  factory Failure.exn(Exception ex, [StackTrace? stackTrace]) =>
      Failure(ex, stackTrace);

  Result<A> convert<A>() {
    return Result.failure(err, stackTrace);
  }

  Result<A> cast<A>() {
    return this as Result<A>;
  }

  @override
  String toString() {
    return "Failure($err)";
  }
}

extension ResultLift<T> on T {
  Result<T> get liftOk => Result.ok(this);
}
