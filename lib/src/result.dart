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

  static Result<T> sync<T>(T Function() f) {
    try {
      return Result.ok(f());
    } on Exception catch (err, stackTrace) {
    return Result.failure(err, stackTrace);
    } on Object catch (err, stackTrace) {
    return Result.failure(Exception("$err"), stackTrace);
    }
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

  T get value => switch(this){
    Ok(:var value) => value,
    Failure(:var failure) => throw failure
  };

  Exception get err => switch(this){
    Ok(:var value) => throw Exception("Ok has not err value"),
    Failure(:var failure) => failure
  };

  Result<A> map<A>(A Function(T) f) =>
    switch(this) {
      Failure(:var failure) => Result.failure(failure),
      Ok(:var value) => Result.sync(() => f(value))
    };

  Result<A> flatMap<A>(Result<A> Function(T) f) =>
      switch(this) {
        Failure(:var failure) => Result.failure(failure),
        Ok(:var value) => f(value)
      };

  FutureOr<Result<A>> flatMapAsync<A>(Future<Result<A>> Function(T) f) =>
      switch(this) {
        Failure(:var failure) => Result.failure(failure),
        Ok(:var value) => f(value)
      };

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

  Result<A> cast<A>() {
    return this as Result<A>;
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
  final Exception failure;
  final StackTrace? stackTrace;

  Failure(this.failure, [this.stackTrace]);


  factory Failure.msg(String msg) => Failure(Exception(msg));
  factory Failure.exn(Exception ex, [StackTrace? stackTrace]) =>
      Failure(ex, stackTrace);

  Result<A> convert<A>() {
    return Result.failure(failure, stackTrace);
  }

  @override
  String toString() {
    return "Failure($err)";
  }
}

extension ResultLift<T> on T {
  Result<T> get liftOk => Result.ok(this);
}
