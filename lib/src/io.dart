import 'dart:async';

import 'result.dart';

import 'option.dart';

class Unit {}

class IO<A> {
  Result<Option<A>> _result = Result.ok(None());

  IO();

  IO<A> _setResult(Result<Option<A>> res) {
    _result = res;
    return this;
  }

  Result<Option<A>> get result => _result;

  A get value => switch (_result) {
        Ok(value: Some(value: var v)) => v,
        _ => throw Exception("can't get empty value")
      };

  bool get hasValue => switch (_result) { Ok(value: Some()) => true, _ => false };

  bool get hasError => _result.isFailure;

  Option<IO> get last => None();

  factory IO.fromResult(Result<Option<A>> res) => IO<A>()._setResult(res);

  factory IO.fromValue(A a) => IO<A>()._setResult(Result.ok(Some(a)));

  factory IO.empty() => IO<A>();

  factory IO.fromError(Exception err) => IO<A>()._setResult(Result.failure(err));

  factory IO.value(A value) => _Pure(() => value);

  factory IO.pure(A Function() f) => _Pure(f);

  static IO<Unit> nohup() => _Pure(() => Unit());

  factory IO.attempt(FutureOr<A> Function() f) => _Attempt(f);

  factory IO.fromFuture(Future<A> Function() f) => _Attempt(() async => await f());

  IO<B> map<B>(FutureOr<B> Function(A) f) => _Map(this, f);

  IO<B> as<B>() => _As<A, B>(this);

  IO<B> flatMap<B>(FutureOr<IO<B>> Function(A) f) => _FlatMap(this, f);

  IO<B> andThan<B>(FutureOr<IO<B>> Function() f) => _AndThan(this, f);

  IO<A> then(FutureOr<A> Function(A) f) => _Then(this, f);

  IO<A> filter(FutureOr<bool> Function(A) f) => _Filter(this, f);

  IO<A> or(FutureOr<A> Function() f) => _Or(this, f);

  IO<A> orElse(FutureOr<IO<A>> Function() f) => _OrElse(this, f);

  IO<A> foreach(FutureOr<void> Function(A) f) => _Foreach(this, f);

  IO<A> ifEmpty(FutureOr<void> Function() f) => _IfEmpty(this, f);

  IO<A> debug() => _Debug(this);

  IO<A> recover(FutureOr<IO<A>> Function(Exception) f) => _Recover(this, f);

  IO<A> catchAll(Function(Exception) f) => _CatchAll(this, f);

  IO<A> failWith(FutureOr<Exception?> Function(A) f) => _FailWith(this, f);

  IO<A> ensure(FutureOr<void> Function() f) => _Ensure(this, f);

  Future<IO<A>> unsafeRun() async {
    throw new Exception("not implemented");
  }

//Result<Option<A>> unsafeRun() {}
}

class IOApp {
  IO<T> pipe2<A, B, T>(IO<A> a, IO<B> b, T Function(A, B) f) {
    return a.flatMap((a) => b.flatMap((b) => IO.fromValue(f(a, b))));
  }

  IO<T> pipe3<A, B, C, T>(IO<A> a, IO<B> b, IO<C> c, T Function(A, B, C) f) {
    return a.flatMap((a) => b.flatMap((b) => c.flatMap((c) => IO.fromValue(f(a, b, c)))));
  }

  IO<T> pipe4<A, B, C, D, T>(IO<A> a, IO<B> b, IO<C> c, IO<D> d, T Function(A, B, C, D) f) {
    return a.flatMap(
        (a) => b.flatMap((b) => c.flatMap((c) => d.flatMap((d) => IO.fromValue(f(a, b, c, d))))));
  }

  IO<T> pipe5<A, B, C, D, E, T>(
      IO<A> a, IO<B> b, IO<C> c, IO<D> d, IO<E> e, T Function(A, B, C, D, E) f) {
    return a.flatMap((a) => b.flatMap((b) =>
        c.flatMap((c) => d.flatMap((d) => e.flatMap((e) => IO.fromValue(f(a, b, c, d, e)))))));
  }
}

final class _Attempt<T> extends IO<T> {
  FutureOr<T> Function() _attempt;

  _Attempt(this._attempt);

  Future<IO<T>> unsafeRun() async {
    try {
      return IO.fromValue(await _attempt());
    } catch (err) {
      return switch (err) {
        (String: var str) => IO.fromError(Exception(str)),
        Exception => IO.fromError(err as Exception),
        _ => IO.fromError(Exception("$err"))
      };
    }
  }
}

final class _Pure<T> extends IO<T> {
  final T Function() _pure;

  _Pure(this._pure);

  Future<IO<T>> unsafeRun() async {
    return IO.fromResult(Result.ok(Some(_pure())));
  }
}

final class _Map<A, B> extends IO<B> {
  final IO<A> _last;
  final FutureOr<B> Function(A) _map;

  _Map(this._last, this._map);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<B>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: Some(value: var v)) => IO.fromResult(Result.ok(Some(await _map(v)))),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _As<A, B> extends IO<B> {
  final IO<A> _last;

  _As(this._last);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<B>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: Some(value: var v)) => IO.fromResult(Result.ok(Some(v as B))),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _FlatMap<A, B> extends IO<B> {
  final IO<A> _last;
  final FutureOr<IO<B>> Function(A) _flatMap;

  _FlatMap(this._last, this._flatMap);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<B>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: Some(value: var v)) => await (await _flatMap(v)).unsafeRun(),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _AndThan<A, B> extends IO<B> {
  final IO<A> _last;
  final FutureOr<IO<B>> Function() _andThan;

  _AndThan(this._last, this._andThan);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<B>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: Some()) => await (await _andThan()).unsafeRun(),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _Filter<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<bool> Function(A) _filter;

  _Filter(this._last, this._filter);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: Some(value: var v)) => (await _filter(v)) ? IO.fromValue(v) : IO.empty(),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _Then<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<A> Function(A) _then;

  _Then(this._last, this._then);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: Some(value: var v)) => IO.fromValue(await _then(v)),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _OrElse<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<IO<A>> Function() _orElse;

  _OrElse(this._last, this._orElse);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: None()) => await (await _orElse()).unsafeRun(),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _Or<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<A> Function() _or;

  _Or(this._last, this._or);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok(value: None()) => IO.fromValue(await _or()),
      Failure(err: var err) => IO.fromError(err),
      _ => IO.empty()
    };
  }
}

final class _Foreach<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<void> Function(A) _foreach;

  _Foreach(this._last, this._foreach);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    switch (lastResult.result) {
      case Ok(value: Some(value: var v)):
        await _foreach(v);
        return IO.fromResult(lastResult.result);
      case Failure(err: var err):
        return IO.fromError(err);
      case _:
        return IO.empty();
    }
  }
}

final class _IfEmpty<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<void> Function() _ifEmpty;

  _IfEmpty(this._last, this._ifEmpty);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    switch (lastResult.result) {
      case Ok(value: None()):
        await _ifEmpty();
        return IO.empty();
      case Failure(err: var err):
        return IO.fromError(err);
      case Ok():
        return IO.fromResult(lastResult.result);
    }
  }
}

final class _Debug<A> extends IO<A> {
  final IO<A> _last;

  _Debug(this._last);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return debug(IO.fromResult(lastResult.result), "Debug IO>> ${lastResult.result}");
  }
}

final class _Recover<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<IO<A>> Function(Exception) _recover;

  _Recover(this._last, this._recover);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    return switch (lastResult.result) {
      Ok() => IO.fromResult(lastResult.result),
      Failure(err: var err) => await (await _recover(err)).unsafeRun(),
    };
  }
}

final class _CatchAll<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<void> Function(Exception) _catchAll;

  _CatchAll(this._last, this._catchAll);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    switch (lastResult.result) {
      case Failure(err: var err):
        await _catchAll(err);
        return IO.fromError(err);
      case Ok():
        return IO.fromResult(lastResult.result);
    }
    ;
  }
}

final class _FailWith<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<Exception?> Function(A) _failWith;

  _FailWith(this._last, this._failWith);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    switch (lastResult.result) {
      case Ok(value: Some(value: var v)):
        var res = await _failWith(v);
        if (res != null) return IO.fromError(res);
        return IO.fromValue(v);
      case Failure(err: var err):
        return IO.fromError(err);
      case _:
        return IO.empty();
    }
  }
}

final class _Ensure<A> extends IO<A> {
  final IO<A> _last;
  final FutureOr<void> Function() _ensure;

  _Ensure(this._last, this._ensure);

  Option<IO<A>> get last => Option.of(_last);

  Future<IO<A>> unsafeRun() async {
    var lastResult = await _last.unsafeRun();
    _ensure();
    return IO.fromResult(lastResult.result);
  }
}

T debug<T>(T value, String msg) {
  print("DEBUG >> $msg");
  return value;
}
