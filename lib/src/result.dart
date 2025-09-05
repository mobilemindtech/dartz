import 'dart:async';

typedef void ifOk<T>(T value);
typedef void ifFailure(Exception value);

sealed  class Result<T> {
  static Result<A> ok<A>(A value) {
    return Ok(value);
  }

  static Result<A> failure<A>(Exception e) {
    return Failure(e);
  }

  static Future<Result<T>> of<T>(FutureOr<T> Function() f) async {
    try {
      return Result.ok(await f());
    } on Exception catch (err, _) {
      return Result.failure(err);
    } on Object catch (err, _) {
      return Result.failure(Exception("$err"));
    }
  }
  
  bool get isFailure => switch (this) { Failure<T>() => true, _ => false };

  bool get isOk => !isFailure;

  Result<T> allways(Function f){
    f();
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

  Failure(this.err);

  Exception get failure => err;

  factory Failure.msg(String msg) => Failure(Exception(msg));
  factory Failure.exn(Exception ex) => Failure(ex);
  
  @override
  String toString() {
    return "Failure($err)";
  }
}

extension ResultLift<T> on T {
  Result<T> get liftOk => Result.ok(this);
}
